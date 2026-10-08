variable "name" {
    type = string
    description = "Nom du bucket"
  
}

variable "bucket-class" {
    type = string
    description = "Classe du bucket. Ex : STANDARD"
    default = "STANDARD"
  
}