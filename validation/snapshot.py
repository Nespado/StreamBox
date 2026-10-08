"""Lecture seule : conserve les 11 requetes du dashboard sur une periode UTC."""
import argparse
import datetime
import json
from pathlib import Path
import shutil
import subprocess
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--start", required=True)
parser.add_argument("--end", required=True)
parser.add_argument("--service", default="streambox-catalogue")
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
project = "streambox-insset-m1-2026"
cli = shutil.which("gcloud") or str(Path.home() / "AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd")
token = subprocess.run([cli, "auth", "print-access-token"], capture_output=True, check=True).stdout.decode().strip()
dashboard = json.loads((Path(__file__).parents[1] / "monitoring/grafana-cloudrun/dashboards/streambox.json").read_text(encoding="utf-8"))
result = {"checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "start": args.start, "end": args.end, "service": args.service, "panels": []}
for panel in dashboard["panels"]:
    for target in panel.get("targets", []):
        query = target.get("expr")
        if not query:
            continue
        for key, value in {"project": project, "region": "europe-west9", "service": args.service, "url_map": "streambox-url-map"}.items():
            query = query.replace("${" + key + "}", value).replace("$" + key, value)
        # Variables internes de Grafana pour une resolution d'une minute.
        query = query.replace("$__rate_interval", "1m").replace("$__interval", "1m").replace("$__range", "5m")
        params = urllib.parse.urlencode({"query": query, "start": args.start, "end": args.end, "step": "60s"})
        url = "https://monitoring.googleapis.com/v1/projects/" + project + "/location/global/prometheus/api/v1/query_range?" + params
        request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.load(response)
        result["panels"].append({"title": panel["title"], "query": query, "response": data})
args.out.parent.mkdir(parents=True, exist_ok=True)
args.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print("Requetes et reponses conservees :", args.out)
