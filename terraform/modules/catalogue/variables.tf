variable "project_id" {
  description = "Identifiant du projet GCP ."
  type        = string
}

variable "region" {
  description = "Région de déploiement."
  type        = string
}

variable "image" {
  description = "Image du catalogue dans Artifact Registry."
  type        = string
}

variable "service_name" {
  description = "Nom du service Cloud run."
  type        = string
  default     = "streambox-catalogue"
}

variable "max_instances" {
  description = "Nombre maximal d'instances de la révision."
  type        = number
  default     = 2
}