"""Essai du labo : 1 utilisateur/120 s, 5/60 s, 10/60 s, une iteration/5 s.
Une iteration = catalogue + petit media. Aucun test de saturation.
"""
import collections
import concurrent.futures
import datetime
import json
import math
from pathlib import Path
import threading
import time
import urllib.error
import urllib.request

BASE = "https://streambox.chaleonm.ovh"
MEDIA = "/media/demo-1.mp4"
PHASES = [(1, 120), (5, 60), (10, 60)]
MAX_REQUESTS = 450
MAX_BYTES = 10 * 1024 * 1024
OUT = Path(__file__).parent / "results" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
OUT.mkdir(parents=True, exist_ok=False)
rows = []
lock = threading.Lock()
stop = threading.Event()
total_bytes = 0
reserved = 0


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def request(path, users, user):
    global total_bytes, reserved
    with lock:
        if reserved >= MAX_REQUESTS or total_bytes >= MAX_BYTES or stop.is_set():
            stop.set()
            return
        reserved += 1
    start = time.perf_counter()
    status, size, cache, error = 0, 0, "", ""
    try:
        req = urllib.request.Request(BASE + path, headers={"User-Agent": "StreamBox-lab-bounded-test/1.0"})
        with urllib.request.urlopen(req, timeout=5) as r:
            status = r.status
            cache = r.headers.get("X-Cache-Status", "")
            size = len(r.read(1_000_001))
            if size >= 1_000_000:
                stop.set()
                error = "Reponse >= 1 Mo : arret"
    except urllib.error.HTTPError as e:
        status, error = e.code, "HTTP " + str(e.code)
    except OSError as e:
        error = type(e).__name__
    row = dict(time=utc(), users=users, user=user, path=path, status=status,
               elapsed_ms=round((time.perf_counter()-start)*1000, 2), bytes=size,
               cache=cache, error=error)
    with lock:
        rows.append(row)
        total_bytes += size
        # Stop global sur trois echecs consecutifs ou > 5 % d'echecs apres 20 requetes.
        bad = lambda r: r["status"] == 0 or r["status"] >= 500
        if (len(rows) >= 3 and all(bad(r) for r in rows[-3:])) or (len(rows) >= 20 and sum(bad(r) for r in rows)/len(rows) > .05):
            stop.set()


def worker(user, users, seconds, start):
    for iteration in range(seconds // 5):
        delay = start + iteration * 5 + user * .05 - time.monotonic()
        if delay > 0 and stop.wait(delay):
            return
        if stop.is_set():
            return
        request("/api/catalogue", users, user)
        request(MEDIA, users, user)


with urllib.request.urlopen(urllib.request.Request(BASE + MEDIA, method="HEAD"), timeout=10) as r:
    media_size = int(r.headers["Content-Length"])
    assert 0 < media_size < 1_000_000, "Le media doit faire moins de 1 Mo"
protocol = dict(target=BASE, media=MEDIA, media_bytes=media_size, phases=PHASES,
                interval_seconds=5, max_requests=MAX_REQUESTS, max_bytes=MAX_BYTES,
                max_active_seconds=240, start=utc())
(OUT / "protocol.json").write_text(json.dumps(protocol, indent=2)+"\n", encoding="utf-8")
print("Protocole enregistre :", OUT, flush=True)
try:
    for users, seconds in PHASES:
        if stop.is_set():
            break
        print("Phase", users, "utilisateur(s),", seconds, "s", flush=True)
        start = time.monotonic()
        with concurrent.futures.ThreadPoolExecutor(max_workers=users) as pool:
            list(pool.map(lambda user: worker(user, users, seconds, start), range(users)))
        stop.wait(max(0, seconds - (time.monotonic()-start)))
finally:
    summary = dict(start=protocol["start"], end=utc(), stopped=stop.is_set(), total_requests=len(rows), total_bytes=total_bytes, phases=[])
    for users, _ in PHASES:
        for path in ["/api/catalogue", MEDIA]:
            group = [r for r in rows if r["users"] == users and r["path"] == path]
            if not group:
                continue
            values = sorted(r["elapsed_ms"] for r in group)
            summary["phases"].append(dict(users=users, path=path, requests=len(group),
                p95_ms=values[math.ceil(.95*len(values))-1], statuses=dict(collections.Counter(str(r["status"]) for r in group)),
                cache=dict(collections.Counter(r["cache"] for r in group if r["cache"])), bytes=sum(r["bytes"] for r in group)))
    (OUT / "requests.json").write_text(json.dumps(rows, indent=2)+"\n", encoding="utf-8")
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)
if stop.is_set():
    raise SystemExit("Essai interrompu par une regle d'arret ; examiner les resultats.")
