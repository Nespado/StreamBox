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

