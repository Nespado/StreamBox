variable "name" {
  type        = string
  description = "Nom du bucket"

}

variable "bucket-class" {
  type        = string
  description = "Classe du bucket. Ex : STANDARD"
  default     = "STANDARD"

}
variable "public_access_prevention" {
  description = "Protection contre l'accès public, activée pour les archives."
  type        = string
  default     = "inherited"
  validation {
    condition     = contains(["inherited", "enforced"], var.public_access_prevention)
    error_message = "Utiliser inherited ou enforced."
  }
}

variable "delete_after_days" {
  description = "Suppression automatique des objets après ce nombre de jours ; null la désactive."
  type        = number
  default     = null
  validation {
    condition     = var.delete_after_days == null ? true : var.delete_after_days >= 1 && floor(var.delete_after_days) == var.delete_after_days
    error_message = "La durée doit être un entier positif ou null."
  }
}
