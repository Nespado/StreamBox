resource "google_storage_bucket" "static" {
 name          = var.name
 location      = "europe-west9"
 storage_class = var.bucket-class
 uniform_bucket_level_access = true
}
