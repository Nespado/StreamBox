"""Essai borné, mesures côté générateur et publication Cloud Monitoring.

Aucun import ne lance le test. Exécution réelle explicite : --execute --publish.
"""
import argparse
import collections
import concurrent.futures
import datetime as dt
import json
import math
import os
from pathlib import Path
import subprocess
import threading
import time
import urllib.error
import urllib.request

TARGET = "https://streambox.chaleonm.ovh"
PROJECT = "streambox-insset-m1-2026"
PATHS = {"api": "/api/catalogue", "media": "/media/demo-1.mp4"}
PHASES = ((1, 120), (5, 60), (10, 60))
MAX_BYTES, MAX_REQUESTS, MAX_RESPONSE = 10 * 1024 * 1024, 450, 1_000_000
PREFIX = "custom.googleapis.com/streambox/load_test/"


def iso(epoch):
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def p95(values):
    return sorted(values)[math.ceil(.95 * len(values)) - 1] if values else None


def statistics(rows):
    result = []
    for users, _ in PHASES:
        for route, path in PATHS.items():
            group = [r for r in rows if r["users"] == users and r["route"] == route]
            if not group:
                continue
            good = [r["elapsed_ms"] for r in group if r["ok"]]
            result.append(dict(users=users, route=route, path=path, requests=len(group),
                               p95_ms=p95(good), statuses=dict(collections.Counter(str(r["status"]) for r in group)),
                               cache=dict(collections.Counter(r["cache"] for r in group if r["cache"]))))
    return result


def must_stop(rows):
    return (len(rows) >= 3 and all(not r["ok"] for r in rows[-3:])) or (
        len(rows) >= 20 and sum(not r["ok"] for r in rows) / len(rows) > .05)


def series(metric, labels, value, stamp):
    return {"metric": {"type": PREFIX + metric, "labels": labels},
            "resource": {"type": "global", "labels": {"project_id": PROJECT}},
            "metricKind": "GAUGE", "valueType": "DOUBLE",
            "points": [{"interval": {"endTime": iso(stamp)}, "value": {"doubleValue": value}}]}


def cycle_metrics(rows, run_id, users, stamp):
    batch = [series("users", {"run_id": run_id}, users, stamp)]
    for route in PATHS:
        values = [r["elapsed_ms"] for r in rows if r["route"] == route and r["ok"]]
        if values:
            batch.append(series("latency_mean_ms", {"run_id": run_id, "route": route},
                                sum(values) / len(values), stamp))
    return batch


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise OSError("Redirection refusée")


class LoadTest:
    def __init__(self):
        self.rows, self.bytes, self.sent = [], 0, 0
        self.lock, self.stop = threading.Lock(), threading.Event()
        self.reason = ""
        self.deadline = math.inf

    def halt(self, reason):
        with self.lock:
            if not self.reason:
                self.reason = reason
        self.stop.set()

    def request(self, route, users, user, cycle):
        with self.lock:
            if self.stop.is_set() or time.monotonic() >= self.deadline:
                return
            if self.sent >= MAX_REQUESTS or self.bytes >= MAX_BYTES:
                self.stop.set()
                self.reason = "Plafond de requêtes ou de volume"
                return
            self.sent += 1
        begin = time.perf_counter()
        status, size, cache, error = 0, 0, "", ""
        try:
            req = urllib.request.Request(TARGET + PATHS[route], headers={"User-Agent": "StreamBox-CI-bounded-load/1.0"})
            timeout = min(5, max(.01, self.deadline - time.monotonic()))
            with urllib.request.build_opener(NoRedirect).open(req, timeout=timeout) as response:
                status = response.status
                cache = response.headers.get("X-Cache-Status", "").upper()
                if int(response.headers.get("Content-Length", "0")) >= MAX_RESPONSE:
                    self.halt("Réponse >= 1 Mo")
                    raise ValueError("Réponse >= 1 Mo")
                while True:
                    if self.stop.is_set() or time.monotonic() >= self.deadline:
                        raise TimeoutError("Arrêt de l'essai")
                    chunk = response.read(8192)
                    if not chunk:
                        break
                    size += len(chunk)
                    with self.lock:
                        self.bytes += len(chunk)
                        total = self.bytes
                    if size >= MAX_RESPONSE or total >= MAX_BYTES:
                        self.halt("Plafond de volume atteint")
                        raise ValueError("Plafond de volume atteint")
        except urllib.error.HTTPError as exc:
            status, error = exc.code, "HTTP " + str(exc.code)
        except (OSError, ValueError) as exc:
            error = type(exc).__name__
        row = dict(time=iso(time.time()), users=users, user=user, cycle=cycle, route=route,
                   path=PATHS[route], status=status, ok=200 <= status < 300 and not error,
                   elapsed_ms=round((time.perf_counter() - begin) * 1000, 2), bytes=size, cache=cache, error=error)
        with self.lock:
            self.rows.append(row)
            failed = must_stop(self.rows)
        if failed:
            self.halt("3 erreurs consécutives ou > 5 % après 20 réponses")

    def pair(self, user, users, cycle):
        if self.stop.wait(user * .05):
            return
        for route in PATHS:
            self.request(route, users, user, cycle)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    if not args.execute:
        parser.error("--execute est requis pour lancer le trafic réel")
    stamp = time.time()
    run_id = os.environ.get("GITHUB_RUN_ID", dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    run_id += "-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
    out = Path("tests/load/results") / run_id
    out.mkdir(parents=True, exist_ok=False)
    load = LoadTest()
    token = None
    if args.publish:
        token = subprocess.run(["gcloud", "auth", "print-access-token"], check=True, text=True, capture_output=True).stdout.strip()
    protocol = dict(target=TARGET, media=PATHS["media"], phases=PHASES, interval_seconds=5,
                    max_requests=MAX_REQUESTS, max_bytes=MAX_BYTES, max_active_seconds=240,
                    run_id=run_id, source="GitHub Actions client" if os.environ.get("GITHUB_ACTIONS") else "CLI client",
                    commit=os.environ.get("GITHUB_SHA"), workflow_url=f"https://github.com/Nespado/StreamBox/actions/runs/{os.environ.get('GITHUB_RUN_ID', '')}",
                    created_at=iso(stamp), stop_rule="3 erreurs consécutives ou > 5 % après 20 réponses")
    (out / "protocol.json").write_text(json.dumps(protocol, indent=2), encoding="utf-8")
    print(json.dumps(protocol, indent=2), flush=True)
    published = []

    def publish(batch):
        if not token:
            return
        body = json.dumps({"timeSeries": batch}).encode()
        req = urllib.request.Request(f"https://monitoring.googleapis.com/v3/projects/{PROJECT}/timeSeries",
                                     data=body, headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                response.read()
            published.extend(batch)
        except Exception:
            load.halt("Échec de publication Cloud Monitoring")
            raise

    started = None
    writes = []
    try:
        with urllib.request.build_opener(NoRedirect).open(urllib.request.Request(TARGET + PATHS["media"], method="HEAD"), timeout=5) as response:
            media_size = int(response.headers.get("Content-Length", "0"))
            if not 0 < media_size < MAX_RESPONSE:
                raise ValueError("Le média doit avoir une taille connue inférieure à 1 Mo")
        protocol["media_bytes"] = media_size
        started, epoch = time.monotonic(), time.time()
        protocol["start"] = iso(epoch)
        load.deadline = started + 240
        (out / "protocol.json").write_text(json.dumps(protocol, indent=2), encoding="utf-8")
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as clients, concurrent.futures.ThreadPoolExecutor(max_workers=1) as writer:
            cycle, offset = 0, 0
            for users, seconds in PHASES:
                print(f"Phase {users} utilisateur(s), {seconds} s", flush=True)
                for tick in range(0, seconds, 5):
                    due = started + offset + tick
                    if load.stop.wait(max(0, due - time.monotonic())):
                        break
                    if time.monotonic() >= due + 5:
                        continue  # Ne pas rattraper en rafale un cycle manqué.
                    cycle += 1
                    futures = [clients.submit(load.pair, user, users, cycle) for user in range(users)]
                    for future in futures:
                        future.result()
                    rows = [r for r in load.rows if r["cycle"] == cycle]
                    writes.append(writer.submit(publish, cycle_metrics(rows, run_id, users, epoch + offset + tick)))
                    if load.stop.is_set():
                        break
                if load.stop.is_set():
                    break
                offset += seconds
                if load.stop.wait(max(0, started + offset - time.monotonic())):
                    break
                batch = [series("phase_p95_ms", {"run_id": run_id, "route": p["route"], "users": str(users)},
                                p["p95_ms"], epoch + offset) for p in statistics(load.rows) if p["users"] == users and p["p95_ms"] is not None]
                writes.append(writer.submit(publish, batch))
            if not load.stop.is_set():
                writes.append(writer.submit(publish, [series("users", {"run_id": run_id}, 0, epoch + 240)]))
            for future in writes:
                future.result()
    except Exception as exc:
        load.halt(f"Essai interrompu : {type(exc).__name__}")
        raise
    finally:
        summary = dict(start=protocol.get("start"), end=iso(time.time()), run_id=run_id,
                       stopped=load.stop.is_set(), reason=load.reason, total_requests=len(load.rows),
                       total_bytes=load.bytes, phases=statistics(load.rows), published_points=len(published))
        for name, data in (("requests", load.rows), ("summary", summary), ("published-metrics", published)):
            (out / (name + ".json")).write_text(json.dumps(data, indent=2), encoding="utf-8")
        print(json.dumps(summary, indent=2), flush=True)
        print("Résultats :", out, flush=True)
    if load.stop.is_set() or len(load.rows) != 408:
        raise SystemExit("Essai arrêté ou incomplet : examiner les résultats")


if __name__ == "__main__":
    main()
