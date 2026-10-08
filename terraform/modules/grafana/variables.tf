variable "project_id" {
  description = "Projet GCP hébergeant Grafana et les métriques."
  type        = string
}

variable "region" {
  description = "Région du service Cloud Run et des secrets."
  type        = string
}

variable "service_name" {
  description = "Nom du service Cloud Run et du compte de service dédié."
  type        = string
  default     = "streambox-grafana"
}

variable "image" {
  description = "Image Grafana publiée, identifiée par son digest."
  type        = string
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image))
    error_message = "Utiliser un digest sha256 pour figer l'image déployée."
  }
}

variable "proxy_image" {
  description = "Frontend officiel Google : proxy OAuth vers l'API Prometheus, sans stockage local."
  type        = string
  default     = "gke.gcr.io/prometheus-engine/frontend@sha256:615ba6fcb89717b7346de2746e18fd6d31979cf89eb7b3583c7cea05be827664"
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.proxy_image))
    error_message = "Utiliser un digest sha256 pour figer le proxy."
  }
}

variable "public_url" {
  description = "URL HTTPS publique de Grafana, terminée par /monitoring/."
  type        = string
  validation {
    condition     = can(regex("^https://[^/?#]+/monitoring/$", var.public_url))
    error_message = "L'URL doit être de la forme https://domaine/monitoring/."
  }
}

variable "secret_rotation" {
  description = "Incrémenter pour créer de nouvelles versions du mot de passe et de la clé Grafana."
  type        = number
  default     = 1
  validation {
    condition     = var.secret_rotation >= 1 && floor(var.secret_rotation) == var.secret_rotation
    error_message = "Le numéro de rotation doit être un entier positif."
  }
}
