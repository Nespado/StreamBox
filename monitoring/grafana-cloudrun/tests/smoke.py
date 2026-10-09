"""Test de l'image seule ; aucune connexion a GCP ni identifiant reel.

Depuis la racine : python monitoring/grafana-cloudrun/tests/smoke.py
"""
import base64
import http.cookiejar
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

IMAGE = sys.argv[1] if len(sys.argv) > 1 else "streambox-grafana:13.2.3-1"


def docker(*args, **kwargs):
    return subprocess.run(["docker", *args], text=True, capture_output=True, **kwargs)


def require(result):
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()


def check_instance():
    name = "streambox-grafana-smoke-" + uuid.uuid4().hex[:10]
    env = dict(os.environ, GF_SECURITY_ADMIN_PASSWORD=secrets.token_urlsafe(32))
    auth = base64.b64encode(("admin:" + env["GF_SECURITY_ADMIN_PASSWORD"]).encode()).decode()
    try:
        require(docker(
            "run", "-d", "--name", name, "-p", "127.0.0.1::8080",
            "--memory=512m", "--memory-swap=512m",
            "-e", "GF_SECURITY_ADMIN_PASSWORD", "-e", "PORT=8080",
            "-e", "GF_PLUGINS_PREINSTALL_DISABLED=true",
            "-e", "GF_PLUGINS_PREINSTALL_AUTO_UPDATE=false",
            "-e", "GF_SERVER_ROOT_URL=http://localhost/monitoring/",
            "-e", "PROMETHEUS_URL=http://127.0.0.1:9090", IMAGE, env=env,
        ))
        port = require(docker("port", name, "8080/tcp")).rsplit(":", 1)[1]
        base = "http://127.0.0.1:" + port + "/monitoring"

        def get(path, authenticated=True):
            headers = {"Authorization": "Basic " + auth} if authenticated else {}
            with urllib.request.urlopen(urllib.request.Request(base + path, headers=headers), timeout=3) as r:
                return r.read()

        for _ in range(45):
            try:
                assert json.loads(get("/api/health"))["database"] == "ok"
                break
            except (OSError, AssertionError):
                time.sleep(1)
        else:
            raise RuntimeError("Grafana ne demarre pas en 45 secondes")

        assert b"<html" in get("/login", authenticated=False).lower()
        data = json.loads(get("/api/dashboards/uid/streambox-observability"))
        assert data["meta"]["provisioned"]
        assert len(data["dashboard"]["panels"]) == 11
        client = json.loads(get("/api/dashboards/uid/streambox-client-test"))
        assert client["meta"]["provisioned"]
        assert len(client["dashboard"]["panels"]) == 2
        assert "latency_mean_ms" in client["dashboard"]["panels"][0]["targets"][0]["expr"]
        assert all("stackdriver_" not in t["expr"] for p in data["dashboard"]["panels"] for t in p["targets"])
        source = json.loads(get("/api/datasources/uid/streambox-prometheus"))
        assert source["url"] == "http://127.0.0.1:9090"
        assert source["jsonData"]["httpMethod"] == "GET"
        try:
            get("/api/dashboards/uid/streambox-observability", authenticated=False)
        except urllib.error.HTTPError as error:
            assert error.code == 401
        else:
            raise AssertionError("Dashboard accessible sans authentification")

        # Parcours navigateur : cookie de session, et fichiers du plugin frontend.
        # Le test API avec Basic auth seul ne détectait pas les plugins manquants.
        session = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        login = urllib.request.Request(base + "/login", data=json.dumps({
            "user": "admin", "password": env["GF_SECURITY_ADMIN_PASSWORD"],
        }).encode(), headers={"Content-Type": "application/json"})
        with session.open(login, timeout=10) as response:
            assert json.load(response)["message"] == "Logged in"
        for _ in range(3):
            for path in ["/api/user", "/api/plugins/prometheus/settings", "/api/dashboards/uid/streambox-observability"]:
                with session.open(base + path, timeout=10) as response:
                    assert response.status == 200
                    assert "application/json" in response.headers.get("Content-Type", "")
            with session.open(base + "/public/plugins/prometheus/module.js", timeout=10) as response:
                assert response.status == 200
                assert "javascript" in response.headers.get("Content-Type", "")
                assert len(response.read()) > 1000
            time.sleep(5)
        logs = require(docker("logs", name))
        assert 'msg="Installing plugin"' not in logs
        assert 'msg="Updating plugin"' not in logs
        state = json.loads(require(docker("inspect", name)))[0]["State"]
        assert state["Running"] and not state["OOMKilled"]
    finally:
        docker("rm", "-f", "-v", name)


# Aucun mot de passe admin par defaut ne doit permettre un lancement accidentel.
result = docker("run", "--rm", "-e", "PROMETHEUS_URL=http://127.0.0.1:9090",
                "-e", "GF_SERVER_ROOT_URL=http://localhost/monitoring/", IMAGE)
assert result.returncode != 0 and "Fournir GF_SECURITY_ADMIN_PASSWORD" in result.stderr
check_instance()
check_instance()  # Nouvelle base ephemere : provisioning identique sans volume.
print("OK : deux instances neuves a 512 Mio, secret obligatoire, session par cookie, plugin Prometheus disponible, aucun telechargement de plugin, datasource et 11 panneaux.")
