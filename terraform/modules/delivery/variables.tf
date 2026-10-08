variable "project_id" {
  description = "Identifiant du projet GCP ."
  type        = string
}

variable "region" {
  description = "Région de déploiement."
  type        = string
}
variable "cloud_run_service_name" {
  description = "Nom du service Cloud Run."
  type        = string
}

variable "backend_bucket_id" {
  description = "Identifiant du backend bucket fourni par le module de media."
  type        = string
}

variable "name_prefix" {
  description = "Préfixe des ressources du Load Balancer."
  type        = string
  default     = "streambox"
}
<<<<<<< HEAD
variable "domain_name" {
  description = "Domaine HTTPS de StreamBox, sans protocole ni chemin."
  type        = string
}

variable "enable_https_redirect" {
  description = "Activer après que le certificat HTTPS est ACTIVE."
  type        = bool
  default     = false
}

=======
>>>>>>> f33deac2bbe86546ebf4182f71cdf799abc45eae
