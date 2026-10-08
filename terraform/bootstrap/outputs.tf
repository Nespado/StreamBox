output "state_bucket_name" {
  description = "Nom du bucket GCS pour le backend remote state"
  value       = google_storage_bucket.terraform_state.name
}

output "workload_identity_provider" {
  description = "Nom complet de la ressource Workload Identity Provider à configurer dans GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "ci_service_account_email" {
  description = "Adresse email du compte de service utilisé par GitHub Actions"
  value       = google_service_account.ci_deployer.email
}
