output "service_name" {
  description = "Nom du service à raccorder au Serverless NEG."
  value       = google_cloud_run_v2_service.catalogue.name
}

output "region" {
  description = "Région du service Cloud Run."
  value       = google_cloud_run_v2_service.catalogue.location
}

output "service_uri" {
  description = "URL directe du service Cloud Run."
  value       = google_cloud_run_v2_service.catalogue.uri
}

output "service_account_email" {
  description = "Identité utilisée par l'application."
  value       = google_service_account.catalogue.email
}
