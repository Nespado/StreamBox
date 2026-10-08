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