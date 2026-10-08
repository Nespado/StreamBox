resource "google_project_service" "secret_manager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

locals {
  secrets = toset(["admin-password", "secret-key"])
}

# Les valeurs existent uniquement en mémoire pendant l'exécution Terraform.
ephemeral "random_password" "grafana" {
  for_each = local.secrets
  length   = 48
  special  = false
}

resource "google_secret_manager_secret" "grafana" {
  for_each  = local.secrets
  project   = var.project_id
  secret_id = "${var.service_name}-${each.key}"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "grafana" {
  for_each               = local.secrets
  secret                 = google_secret_manager_secret.grafana[each.key].id
  secret_data_wo         = ephemeral.random_password.grafana[each.key].result
  secret_data_wo_version = tostring(var.secret_rotation)
  deletion_policy        = "DELETE"
}

resource "google_secret_manager_secret_iam_member" "grafana" {
  for_each  = local.secrets
  project   = var.project_id
  secret_id = google_secret_manager_secret.grafana[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.grafana.email}"
}
