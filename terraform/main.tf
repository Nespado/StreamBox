module "catalogue" {
  source = "./modules/Catalogue"

  project_id    = "streambox-insset-m1-2026"
  region        = "europe-west9"
  service_name  = "streambox-catalogue"
  image         = "europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/catalogue:v1"
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

module "delivery" {
  source = "./modules/delivery"

  project_id             = "streambox-insset-m1-2026"
  region                 = module.catalogue.region
  cloud_run_service_name = module.catalogue.service_name
  backend_bucket_id      = var.backend_bucket_id
}
