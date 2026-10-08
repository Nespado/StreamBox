module "bucket-media" {
  source       = "./modules/buckets"
  name         = "bucket-insset-streambox-media"
  bucket-class = "STANDARD"
}

module "bucket-logs" {
  source                   = "./modules/buckets"
  name                     = "bucket-insset-streambox-logs"
  bucket-class             = "COLDLINE"
  public_access_prevention = "enforced"
  delete_after_days        = 90
}

module "observability" {
  source = "./modules/observability"

  project_id                 = "streambox-insset-m1-2026"
  region                     = "europe-west9"
  cloud_run_service_name     = "streambox-catalogue"
  load_balancer_url_map_name = "streambox-url-map"
  notification_email         = "swann.defossezanceaux@gmail.com"
  enable_log_archive         = true
  log_archive_bucket_name    = module.bucket-logs.name
  create_prometheus_reader   = true
}
