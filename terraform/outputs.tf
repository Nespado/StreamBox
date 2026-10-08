output "catalogue_url" {
  value = module.catalogue.service_uri
}

output "catalogue_name" {
  value = module.catalogue.service_name
}

output "catalogue_region" {
  value = module.catalogue.region
}

output "load_balancer_ip" {
  value = module.delivery.ip_address
}

output "url_map_id" {
  value = module.delivery.url_map_id
}

output "streambox_url" {
  value = module.delivery.http_url
}
