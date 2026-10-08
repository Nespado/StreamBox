"""Compare deux politiques sur une copie temporaire de 39,6 Ko, puis la supprime."""
import datetime
import json
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

PROJECT = "streambox-insset-m1-2026"
BUCKET = "bucket-insset-streambox-media"
STAMP = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
NAME = "media/validation-cache-" + STAMP + ".mp4"
OUT = Path(__file__).parent / "results" / (STAMP + "-cache")
OUT.mkdir(parents=True, exist_ok=False)
CLI = Path.home() / "AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd"
TOKEN = subprocess.run([str(CLI), "auth", "print-access-token"], capture_output=True, check=True).stdout.decode().strip()
GCS = "https://storage.googleapis.com/storage/v1/b/" + BUCKET + "/o/"
quote = lambda x: urllib.parse.quote(x, safe="")
obj = None
evidence = {"object": NAME, "policies": [], "cleanup": []}


def api(url, method="GET", body=None):
    headers = {"Authorization": "Bearer " + TOKEN}
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, method=method, headers=headers,
        data=json.dumps(body).encode() if body is not None else None)
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read()
        return json.loads(raw) if raw else {}


def invalidate():
    op = api("https://compute.googleapis.com/compute/v1/projects/" + PROJECT + "/global/urlMaps/streambox-url-map/invalidateCache", "POST", {"path": "/" + NAME, "host": "streambox.chaleonm.ovh"})
    deadline = time.monotonic() + 180
    while op.get("status") != "DONE":
        if time.monotonic() > deadline:
            raise RuntimeError("Invalidation CDN trop longue")
        time.sleep(5)
        op = api(op["selfLink"])
    assert not op.get("error"), op.get("error")
    return op["name"]


try:
    source = api(GCS + quote("media/demo-1.mp4"))
    assert int(source["size"]) < 1_000_000
    result = api(GCS + quote("media/demo-1.mp4") + "/rewriteTo/b/" + BUCKET + "/o/" + quote(NAME) + "?ifGenerationMatch=0", "POST", {"cacheControl": "public,max-age=60", "contentType": "video/mp4"})
    assert result["done"]
    obj = result["resource"]
    for policy in ["public,max-age=60", "no-store"]:
        if policy == "no-store":
            obj = api(GCS + quote(NAME) + "?ifMetagenerationMatch=" + obj["metageneration"], "PATCH", {"cacheControl": policy})
            evidence["policy_change_invalidation"] = invalidate()
        # Les backend buckets peuvent ignorer les parametres arbitraires dans leur cle.
        # Invalidation explicite de cette seule copie entre les deux politiques.
        url = "https://streambox.chaleonm.ovh/" + NAME
        if policy == "no-store":
            for attempt in range(10):
                with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=15) as r:
                    if r.headers.get("Cache-Control") == policy:
                        break
                time.sleep(10)
            else:
                raise RuntimeError("La politique no-store n'est pas encore visible")
        row = {"policy": policy, "requests": []}
        for _ in range(3):
            started = time.perf_counter()
            with urllib.request.urlopen(url, timeout=15) as r:
                payload = r.read(1_000_001)
                assert len(payload) == int(source["size"])
                assert r.headers.get("Cache-Control") == policy
                row["requests"].append({"status": r.status, "cache": r.headers.get("X-Cache-Status"), "age": r.headers.get("Age"), "cache_control": r.headers.get("Cache-Control"), "bytes": len(payload), "elapsed_ms": round((time.perf_counter()-started)*1000,2)})
            time.sleep(2)
        evidence["policies"].append(row)
        print(policy, row["requests"], flush=True)
finally:
    if obj is not None:
        api(GCS + quote(NAME) + "?ifGenerationMatch=" + obj["generation"], "DELETE")
        evidence["cleanup"].append("Objet temporaire supprime ; les objets du catalogue sont inchanges.")
        evidence["cleanup"].append({"cache_invalidation_operation": invalidate(), "done": True})
    (OUT / "evidence.json").write_text(json.dumps(evidence, indent=2)+"\n", encoding="utf-8")
    print("Preuves :", OUT, flush=True)
