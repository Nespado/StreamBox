resource "google_service_account" "catalogue" {
  project      = var.project_id
  account_id   = var.service_name
  display_name = "API catalogue Streambox"
}

resource "google_cloud_run_v2_service" "catalogue" {
  project  = var.project_id
  name     = var.service_name
  location = var.region

  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.catalogue.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }
    containers {
      image = var.image
      ports {
        container_port = 8080
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = var.project_id
  location = google_cloud_run_v2_service.catalogue.location
  name     = google_cloud_run_v2_service.catalogue.name

  role   = "roles/run.invoker"
  member = "allUsers"
}
