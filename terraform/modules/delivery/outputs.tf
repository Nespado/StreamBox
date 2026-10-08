output "ip_address" {
  description = "IP publique du Load Balancer."
  value       = google_compute_global_address.main.address
}

output "url_map_id" {
  description = "Identifiant dela configuration du routage."
  value       = google_compute_url_map.main.id
}

output "http_url" {
  description = "Adresse HTTP de StreamBox pour le laboratoire sans domaine."
  value       = "http://${google_compute_global_address.main.address}"
}
