resource "google_service_account" "grafana" {
  project      = var.project_id
  account_id   = var.service_name
  display_name = "StreamBox - Grafana et lecture des métriques"
}

resource "google_project_iam_member" "metrics_reader" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

resource "google_cloud_run_v2_service" "grafana" {
  project             = var.project_id
  name                = var.service_name
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  scaling {
    min_instance_count = 0
    max_instance_count = 1
  }

  template {
    service_account                  = google_service_account.grafana.email
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = 20
    timeout                          = "120s"
    session_affinity                 = true

    containers {
      name       = "grafana"
      image      = var.image
      depends_on = ["metrics-proxy"]

      ports {
        container_port = 8080
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = {
          GF_SERVER_ROOT_URL                = var.public_url
          GF_SECURITY_ADMIN_USER            = "admin"
          GF_SECURITY_COOKIE_SECURE         = "true"
          GF_PLUGINS_PREINSTALL_DISABLED    = "true"
          GF_PLUGINS_PREINSTALL_AUTO_UPDATE = "false"
          PROMETHEUS_URL                    = "http://127.0.0.1:9090"
        }
        content {
          name  = env.key
          value = env.value
        }
      }
      dynamic "env" {
        for_each = {
          GF_SECURITY_ADMIN_PASSWORD = "admin-password"
          GF_SECURITY_SECRET_KEY     = "secret-key"
        }
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.grafana[env.value].secret_id
              version = google_secret_manager_secret_version.grafana[env.value].version
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/monitoring/api/health"
          port = 8080
        }
        period_seconds    = 5
        timeout_seconds   = 2
        failure_threshold = 24
      }
    }

    # Cloud Run fournit les identifiants temporaires de l'identité du service.
    # Aucun exporteur, clé JSON ou processus de collecte périodique.
    containers {
      name  = "metrics-proxy"
      image = var.proxy_image
      args = [
        "--web.listen-address=:9090",
        "--query.project-id=${var.project_id}",
      ]
      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        cpu_idle = true
      }
      startup_probe {
        http_get {
          path = "/-/ready"
          port = 9090
        }
        period_seconds    = 2
        timeout_seconds   = 1
        failure_threshold = 30
      }
    }
  }

  depends_on = [
    google_project_iam_member.metrics_reader,
    google_secret_manager_secret_iam_member.grafana,
  ]
}

# Le LB peut appeler Grafana ; la connexion utilisateur est contrôlée par Grafana.
# L'ingress restreint empêche un accès Internet direct par l'URL run.app.
resource "google_cloud_run_v2_service_iam_member" "load_balancer" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.grafana.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
