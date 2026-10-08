output "name" {
  description = "Nom du bucket créé"
  value       = google_storage_bucket.static.name
}

output "id" {
  description = "Identifiant du bucket créé"
  value       = google_storage_bucket.static.id
}
