variable "bucket_name" {
  type        = string
  description = "Nom du bucket Cloud Storage contenant les médias"
}

variable "name" {
  type        = string
  description = "Nom du Backend Bucket CDN"
  default     = "streambox-backend-media"
}