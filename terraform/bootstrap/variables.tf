variable "project_id" {
  description = "Identifiant du projet Google Cloud"
  type        = string
  default     = "streambox-insset-m1-2026"
}

variable "region" {
  description = "Région principale de déploiement"
  type        = string
  default     = "europe-west9"
}

variable "state_bucket_name" {
  description = "Nom du bucket GCS hébergeant le remote state Terraform"
  type        = string
  default     = "bucket-insset-streambox-remote-state"
}

variable "github_repository" {
  description = "Chemin du dépôt GitHub au format 'owner/repo' autorisé pour WIF"
  type        = string
  default     = "Nespado/StreamBox"
}
