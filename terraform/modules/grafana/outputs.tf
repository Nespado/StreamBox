output "service_name" {
  value = google_cloud_run_v2_service.grafana.name
}

output "region" {
  value = google_cloud_run_v2_service.grafana.location
}

output "public_url" {
  value = var.public_url
}

output "service_account_email" {
  value = google_service_account.grafana.email
}

output "admin_password_secret_id" {
  description = "Identifiant du secret, jamais la valeur du mot de passe."
  value       = google_secret_manager_secret.grafana["admin-password"].secret_id
}
