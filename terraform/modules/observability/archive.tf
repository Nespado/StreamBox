# Le bucket est fourni par le module buckets : aucune seconde copie n'est créée.
resource "google_logging_project_sink" "archive" {
  count                  = var.enable_log_archive ? 1 : 0
  project                = var.project_id
  name                   = "streambox-log-archive"
  destination            = "storage.googleapis.com/${var.log_archive_bucket_name}"
  filter                 = local.log_filter
  unique_writer_identity = true
  description            = "Export des nouveaux logs du catalogue et du Load Balancer StreamBox."

  lifecycle {
    precondition {
      condition     = var.log_archive_bucket_name != ""
      error_message = "Un bucket d'archives est obligatoire lorsque enable_log_archive vaut true."
    }
  }
  depends_on = [google_project_service.observability]
}

resource "google_storage_bucket_iam_member" "archive_writer" {
  count  = var.enable_log_archive ? 1 : 0
  bucket = var.log_archive_bucket_name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.archive[0].writer_identity
}
