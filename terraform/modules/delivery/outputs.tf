output "ip_address" {
  description = "IP publique du Load Balancer."
  value       = google_compute_global_address.main.address
}

output "url_map_id" {
  description = "Identifiant dela configuration du routage."
  value       = google_compute_url_map.main.id
}

output "http_url" {
<<<<<<< HEAD
  description = "Adresse HTTP du domaine, redirigée vers HTTPS après activation."
  value       = "http://${var.domain_name}"
}

output "https_url" {
  description = "Adresse HTTPS de StreamBox, utilisable après activation du certificat."
  value       = "https://${var.domain_name}"
=======
  description = "Adresse HTTP de StreamBox pour le laboratoire sans domaine."
  value       = "http://${google_compute_global_address.main.address}"
>>>>>>> f33deac2bbe86546ebf4182f71cdf799abc45eae
}
