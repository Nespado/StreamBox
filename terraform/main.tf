module "catalogue" {
  source = "./modules/catalogue"

  depends_on = [google_project_iam_member.ci_artifact_reader]

  project_id    = "streambox-insset-m1-2026"
  region        = "europe-west9"
  service_name  = "streambox-catalogue"
  image         = "europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/catalogue@sha256:70cab4767e44df66078db219c6eda470e20965f1008a7a7844d0e11527ccbf08"
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
  depends_on = [google_project_iam_member.ci_artifact_reader]

  source       = "./modules/grafana"
  project_id   = "streambox-insset-m1-2026"
  region       = "europe-west9"
  service_name = "streambox-grafana"
  public_url   = "https://streambox.chaleonm.ovh/monitoring/"
  image        = "europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/grafana@sha256:5e5159e83c13aa94df503627d0c11367e834bfb7406aa0354c34262d5cbfe033"
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
