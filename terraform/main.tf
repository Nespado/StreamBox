module "catalogue" {
  source = "./modules/catalogue"

  project_id    = "streambox-insset-m1-2026"
  region        = "europe-west9"
  service_name  = "streambox-catalogue"
  image         = "europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/catalogue@sha256:501148f78b866e2f1494ce96e37d351e2e48403b54e172cfefd8ce60c338a034"
  max_instances = 2
}

module "bucket-media" {
  source       = "./modules/buckets"
  name         = "bucket-insset-streambox-media"
  bucket-class = "STANDARD"
}

module "bucket-logs" {
  source       = "./modules/buckets"
  name         = "bucket-insset-streambox-logs"
  bucket-class = "COLDLINE"
}

module "media" {
  source      = "./modules/media"
  bucket_name = module.bucket-media.name
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

module "grafana" {
  source       = "./modules/grafana"
  project_id   = "streambox-insset-m1-2026"
  region       = "europe-west9"
  service_name = "streambox-grafana"
  public_url   = "https://streambox.chaleonm.ovh/monitoring/"
  image        = "europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/grafana@sha256:9d1fd4241d432e858c0ad8523287c3fbef9f1537117e6e6ee028e0b4ff9eaaac"
}

module "delivery" {
  source                 = "./modules/delivery"
  project_id             = "streambox-insset-m1-2026"
  region                 = module.catalogue.region
  cloud_run_service_name = module.catalogue.service_name
  backend_bucket_id      = module.media.backend_bucket_id
  domain_name            = "streambox.chaleonm.ovh"
  enable_https_redirect  = var.enable_https_redirect
  monitoring = {
    service_name = module.grafana.service_name
    region       = module.grafana.region
  }
}
