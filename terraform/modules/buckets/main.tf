resource "google_storage_bucket" "static" {
  name                        = var.name
  location                    = "europe-west9"
  storage_class               = var.bucket-class
  uniform_bucket_level_access = true
  public_access_prevention    = var.public_access_prevention

  dynamic "lifecycle_rule" {
    for_each = var.delete_after_days == null ? [] : [var.delete_after_days]
    content {
      condition { age = lifecycle_rule.value }
      action { type = "Delete" }
    }
  }
}
