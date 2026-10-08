output "catalogue_url" {
  value = module.catalogue.service_uri
}

output "catalogue_name" {
  value = module.catalogue.service_name
}

output "catalogue_region" {
  value = module.catalogue.region
}

output "observability" {
  description = "Liens et identifiants utiles pour vérifier l'observabilité après déploiement."
  value = {
    dashboard_url                    = module.observability.dashboard_url
    dashboard_id                     = module.observability.dashboard_id
    notification_channel_id          = module.observability.notification_channel_id
    alert_policy_ids                 = module.observability.alert_policy_ids
    log_filter                       = module.observability.log_filter
    archive_bucket                   = module.bucket-logs.name
    archive_writer_identity          = module.observability.archive_writer_identity
    prometheus_service_account_email = module.observability.prometheus_service_account_email
  }
}

output "load_balancer_ip" {
  value = module.delivery.ip_address
}

output "url_map_id" {
  value = module.delivery.url_map_id
}

output "streambox_url" {
  value = module.delivery.https_url
}

output "grafana" {
  description = "Accès Grafana après déploiement ; aucune valeur secrète."
  value = {
    url                      = module.grafana.public_url
    username                 = "admin"
    admin_password_secret_id = module.grafana.admin_password_secret_id
    service_account_email    = module.grafana.service_account_email
  }
}
