# Backend Bucket GCP avec Cloud CDN activé
resource "google_compute_backend_bucket" "media" {
  name        = var.name
  bucket_name = var.bucket_name
  enable_cdn  = true

  # En-tête personnalisé attendu par l'interface StreamBox pour afficher le statut du cache (HIT/MISS)
  custom_response_headers = [
    "X-Cache-Status: {cdn_cache_status}"
  ]

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    client_ttl        = 3600
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400
  }
}

# Autoriser la lecture publique des objets du bucket pour que le CDN puisse les distribuer
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = var.bucket_name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
