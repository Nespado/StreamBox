variable "project_id" {
  description = "Identifiant du projet GCP à surveiller."
  type        = string
}

variable "region" {
  description = "Région du service Cloud Run."
  type        = string
}

variable "cloud_run_service_name" {
  description = "Nom du service Cloud Run à surveiller."
  type        = string
}

variable "load_balancer_url_map_name" {
  description = "Nom de l'URL map du Load Balancer à surveiller."
  type        = string
}

variable "notification_email" {
  description = "Adresse email destinataire des alertes."
  type        = string
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "Fournir une adresse email valide pour les alertes."
  }
}

variable "alerts_enabled" {
  description = "Active les deux politiques après déploiement."
  type        = bool
  default     = true
}

variable "error_ratio_threshold" {
  description = "Ratio maximal de 5xx, entre 0 et 1 (0.01 = 1 %)."
  type        = number
  default     = 0.01
  validation {
    condition     = var.error_ratio_threshold > 0 && var.error_ratio_threshold < 1
    error_message = "Le seuil d'erreurs doit être strictement compris entre 0 et 1."
  }
}

variable "minimum_requests" {
  description = "Trafic minimum sur 5 minutes avant d'alerter sur le ratio de 5xx."
  type        = number
  default     = 100
  validation {
    condition     = var.minimum_requests >= 1 && floor(var.minimum_requests) == var.minimum_requests
    error_message = "Le trafic minimum doit être un entier positif."
  }
}

variable "latency_p95_threshold_ms" {
  description = "Seuil p95 en millisecondes, à confirmer avec la mesure de référence."
  type        = number
  default     = 1000
  validation {
    condition     = var.latency_p95_threshold_ms > 0
    error_message = "Le seuil de latence doit être positif."
  }
}

variable "enable_log_archive" {
  description = "Crée le sink et son droit d'écriture dans le bucket fourni."
  type        = bool
  default     = false
}

variable "log_archive_bucket_name" {
  description = "Nom du bucket d'archives existant, sans préfixe gs://."
  type        = string
  default     = ""
}

variable "create_prometheus_reader" {
  description = "Crée une identité de lecture Monitoring pour l'exporter Prometheus."
  type        = bool
  default     = false
}
