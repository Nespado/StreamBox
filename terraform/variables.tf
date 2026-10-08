variable "backend_bucket_id" {
  description = "Identifiant du backend bucket."
  type        = string
  default     = "projects/streambox-insset-m1-2026/global/backendBuckets/streambox-backend-media"
}
variable "enable_https_redirect" {
  description = "Activer la redirection HTTP vers HTTPS après validation du certificat."
  type        = bool
  default     = true
}

