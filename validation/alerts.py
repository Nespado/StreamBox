"""Test isole 5xx/latence : service prive temporaire et copies des deux alertes.
120 s de 500 lentes (120 requetes), puis 180 s de 200 (36 requetes).
Le catalogue reel et ses politiques ne sont jamais modifies.
Suppression des seules ressources creees par ce script dans finally.
"""
import concurrent.futures
import datetime
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

PROJECT = "streambox-insset-m1-2026"
STAMP = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
SERVICE = "streambox-obs-test-" + STAMP.lower()
OUT = Path(__file__).parent / "results" / (STAMP + "-alerts")
OUT.mkdir(parents=True, exist_ok=False)
CLI = Path.home() / "AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd"
TOKEN = subprocess.run([str(CLI), "auth", "print-access-token"], capture_output=True, check=True).stdout.decode().strip()
IDENTITY = subprocess.run([str(CLI), "auth", "print-identity-token"], capture_output=True, check=True).stdout.decode().strip()
RUN = "https://run.googleapis.com/v2/"
MON = "https://monitoring.googleapis.com/v3/"
PARENT = "projects/" + PROJECT
RUN_PARENT = PARENT + "/locations/europe-west9"
created_service = False
policies = []
evidence = {"test": STAMP, "service": SERVICE, "requests": [], "alerts": [], "cleanup": []}


def save():
    (OUT / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")


def api(url, method="GET", body=None):
    headers = {"Authorization": "Bearer " + TOKEN, "x-goog-user-project": PROJECT}
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, method=method, headers=headers,
        data=json.dumps(body).encode() if body is not None else None)
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read()
        return json.loads(raw) if raw else {}


def operation(op):
    deadline = time.monotonic() + 180
    while not op.get("done"):
        if time.monotonic() > deadline:
            raise RuntimeError("Operation Cloud Run trop longue")
        time.sleep(5)
        op = api(RUN + op["name"])
    if "error" in op:
        raise RuntimeError(str(op["error"]))
    return op.get("response", {})


def invoke(url, fault):
    started = time.perf_counter()
    req = urllib.request.Request(url + ("/fail" if fault else "/ok"), headers={"Authorization": "Bearer " + IDENTITY})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            status = r.status
            r.read(1024)
    except urllib.error.HTTPError as e:
        status = e.code
        e.read(1024)
    evidence["requests"].append({"time": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "fault": fault, "status": status, "elapsed_ms": round((time.perf_counter()-started)*1000, 2)})
    if status != (500 if fault else 200):
        raise RuntimeError("Reponse inattendue du service de test : " + str(status))


def incidents():
    data = api(MON + PARENT + "/alerts?pageSize=100")
    ids = {p.rsplit("/", 1)[-1] for p in policies}
    return [a for a in data.get("alerts", []) if a.get("policy", {}).get("name", "").rsplit("/", 1)[-1] in ids]


try:
    code = 'const http=require("http");http.createServer((q,s)=>{const fail=q.url==="/fail";setTimeout(()=>{s.writeHead(fail?500:200,{"Content-Type":"application/json"});s.end(JSON.stringify({test:"streambox-observability",fault:fail}));},fail?1500:0);}).listen(Number(process.env.PORT||8080));'
    spec = {
        "labels": {"purpose": "observability-validation"},
        "ingress": "INGRESS_TRAFFIC_ALL",
        "scaling": {"minInstanceCount": 0, "maxInstanceCount": 1},
        "template": {
            "serviceAccount": "streambox-catalogue@" + PROJECT + ".iam.gserviceaccount.com",
            "timeout": "15s", "maxInstanceRequestConcurrency": 10,
            "containers": [{
                "image": "europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/catalogue@sha256:6e89cd9106adfcf10698efb7b6749c3b13ee2095929483b5e168d495703cc594",
                "command": ["node"], "args": ["-e", code],
                "ports": [{"containerPort": 8080}],
                "resources": {"limits": {"cpu": "1", "memory": "256Mi"}, "cpuIdle": True},
            }],
        },
    }
    op = api(RUN + RUN_PARENT + "/services?serviceId=" + SERVICE, "POST", spec)
    created_service = True
    save()
    svc = operation(op)
    url = svc["uri"]
    assert url.startswith("https://") and url.endswith(".run.app")
    print("Service prive de test pret :", SERVICE, flush=True)
    invoke(url, False)
    for kind, source_id in [("5xx", "9270737116467430119"), ("latence", "16119519148211603686")]:
        source = api(MON + PARENT + "/alertPolicies/" + source_id)
        policy = {k: source[k] for k in ["conditions", "combiner", "notificationChannels", "alertStrategy", "severity"] if k in source}
        policy.update(displayName="TEST StreamBox " + kind + " " + STAMP, enabled=True,
            userLabels={"purpose": "observability-validation"},
            documentation={"mimeType": "text/markdown", "content": "TEST AUTORISE ET ISOLE. Service temporaire " + SERVICE + ". Le site StreamBox reste disponible. Copie des alertes du catalogue ; latence : maintien reduit de 300 a 60 secondes. Nettoyage automatique apres verification."})
        for condition in policy["conditions"]:
            condition.pop("name", None)
            threshold = condition["conditionThreshold"]
            for key in ["filter", "denominatorFilter"]:
                if key in threshold:
                    threshold[key] = threshold[key].replace('service_name="streambox-catalogue"', 'service_name="' + SERVICE + '"')
            if kind == "latence":
                threshold["duration"] = "60s"
                condition["displayName"] = "TEST p95 superieur a 1000 ms pendant 60 secondes"
        created = api(MON + PARENT + "/alertPolicies", "POST", policy)
        policies.append(created["name"])
        evidence.setdefault("policies", []).append(created)
        save()
    print("Deux politiques TEST creees ; debut des 120 s d'erreurs lentes.", flush=True)
    start = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for i in range(30):
            time.sleep(max(0, start + i*4 - time.monotonic()))
            list(pool.map(lambda _: invoke(url, True), range(4)))
    save()
    print("120 erreurs 500 attendues ; retour aux reponses 200 pendant 180 s.", flush=True)
    start = time.monotonic()
    for i in range(36):
        time.sleep(max(0, start + i*5 - time.monotonic()))
        invoke(url, False)
        if i % 6 == 0:
            evidence["alerts"] = incidents()
            print("Incidents observes :", [(a.get("policy", {}).get("displayName"), a.get("state")) for a in evidence["alerts"]], flush=True)
            save()
    # Attendre l'ingestion/evaluation et la fermeture, sans trafic supplementaire.
    deadline = time.monotonic() + 600
    while time.monotonic() < deadline:
        evidence["alerts"] = incidents()
        save()
        states = [(a.get("policy", {}).get("displayName"), a.get("state")) for a in evidence["alerts"]]
        print("Etat des alertes :", states, flush=True)
        if len({a.get("policy", {}).get("name") for a in evidence["alerts"]}) == 2 and all(a.get("state") == "CLOSED" for a in evidence["alerts"]):
            break
        time.sleep(30)
    evidence["completed"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
finally:
    for name in policies:
        try:
            api(MON + name, "DELETE")
            evidence["cleanup"].append({"resource": name, "deleted": True})
        except Exception as e:
            evidence["cleanup"].append({"resource": name, "error": type(e).__name__})
    if created_service:
        try:
            operation(api(RUN + RUN_PARENT + "/services/" + SERVICE, "DELETE"))
            evidence["cleanup"].append({"resource": SERVICE, "deleted": True})
        except Exception as e:
            evidence["cleanup"].append({"resource": SERVICE, "error": type(e).__name__})
    save()
    print("Preuves et nettoyage :", OUT, evidence["cleanup"], flush=True)
