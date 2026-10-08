output "backend_bucket_id" {
  description = "Identifiant du Backend Bucket pour l'URL Map du Load Balancer"
  value       = google_compute_backend_bucket.media.id
}

output "backend_bucket_self_link" {
  description = "Self-link du Backend Bucket"
  value       = google_compute_backend_bucket.media.self_link
}
