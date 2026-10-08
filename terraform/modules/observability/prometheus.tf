# Identité facultative de lecture pour l'exporter local. Aucune clé JSON créée.
resource "google_project_service" "iam" {
  count              = var.create_prometheus_reader ? 1 : 0
  project            = var.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "prometheus" {
  count        = var.create_prometheus_reader ? 1 : 0
  project      = var.project_id
  account_id   = "streambox-metrics-reader"
  display_name = "StreamBox - Lecture des métriques pour Prometheus"
  depends_on   = [google_project_service.iam]
}

resource "google_project_service" "iam_credentials" {
  count              = var.create_prometheus_reader ? 1 : 0
  project            = var.project_id
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_iam_member" "prometheus_reader" {
  count   = var.create_prometheus_reader ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.prometheus[0].email}"
}
