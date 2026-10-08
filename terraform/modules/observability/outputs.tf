output "notification_channel_id" {
  description = "Identifiant complet du canal de notification email."
  value       = google_monitoring_notification_channel.email.name
}

output "dashboard_id" {
  description = "Identifiant du dashboard Cloud Monitoring."
  value       = google_monitoring_dashboard.streambox.id
}

output "dashboard_url" {
  description = "Lien vers le dashboard après déploiement."
  value       = "https://console.cloud.google.com/monitoring/dashboards/builder/${basename(google_monitoring_dashboard.streambox.id)}?project=${var.project_id}"
}

output "alert_policy_ids" {
  description = "Identifiants des deux politiques d'alerte."
  value = {
    errors  = google_monitoring_alert_policy.catalogue_errors.name
    latency = google_monitoring_alert_policy.catalogue_latency.name
  }
}

output "log_filter" {
  description = "Filtre à coller dans Logs Explorer pour retrouver les logs StreamBox."
  value       = local.log_filter
}

output "archive_writer_identity" {
  description = "Identité du sink, ou null si l'archivage est désactivé."
  value       = try(google_logging_project_sink.archive[0].writer_identity, null)
}

output "prometheus_service_account_email" {
  description = "Identité à usurper pour la lecture des métriques, ou null si désactivée."
  value       = try(google_service_account.prometheus[0].email, null)
}
