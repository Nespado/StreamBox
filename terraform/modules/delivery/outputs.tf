output "ip_address" {
  description = "IP publique du Load Balancer."
  value       = google_compute_global_address.main.address
}

output "url_map_id" {
  description = "Identifiant dela configuration du routage."
  value       = google_compute_url_map.main.id
}

output "http_url" {
  description = "Adresse HTTP du domaine, redirigée vers HTTPS après activation."
  value       = "http://${var.domain_name}"
}

output "https_url" {
  description = "Adresse HTTPS de StreamBox, utilisable après activation du certificat."
  value       = "https://${var.domain_name}"
}
