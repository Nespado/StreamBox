resource "google_compute_region_network_endpoint_group" "catalogue" {
  project               = var.project_id
  name                  = "${var.name_prefix}-catalogue-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

resource "google_compute_backend_service" "catalogue" {
  project               = var.project_id
  name                  = "${var.name_prefix}-catalogue-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.catalogue.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "main" {
  project         = var.project_id
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_service.catalogue.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "streambox"
  }
  path_matcher {
    name            = "streambox"
    default_service = google_compute_backend_service.catalogue.id

    path_rule {
      paths   = ["/media/*"]
      service = var.backend_bucket_id
    }
  }
}

resource "google_compute_global_address" "main" {
  project = var.project_id
  name    = "${var.name_prefix}-ip"
}

resource "google_compute_target_http_proxy" "main" {
  project = var.project_id
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.main.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.name_prefix}-http"
  ip_address            = google_compute_global_address.main.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.main.id
}
