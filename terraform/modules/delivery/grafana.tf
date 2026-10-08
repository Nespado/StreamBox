resource "google_compute_region_network_endpoint_group" "grafana" {
  count                 = var.monitoring == null ? 0 : 1
  project               = var.project_id
  name                  = "${var.name_prefix}-grafana-neg"
  region                = var.monitoring.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = var.monitoring.service_name
  }
}

resource "google_compute_backend_service" "grafana" {
  count                 = var.monitoring == null ? 0 : 1
  project               = var.project_id
  name                  = "${var.name_prefix}-grafana-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  enable_cdn            = false
  backend {
    group = google_compute_region_network_endpoint_group.grafana[0].id
  }
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}
