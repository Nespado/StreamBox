# Ces tests utilisent un provider simulé : aucun appel GCP, aucun apply réel.
mock_provider "google" {}

variables {
  project_id                 = "streambox-test-project"
  region                     = "europe-west9"
  cloud_run_service_name     = "test-catalogue"
  load_balancer_url_map_name = "test-url-map"
  notification_email         = "test@example.com"
}

run "dashboard_and_alerts" {
  command = plan
  module { source = "./modules/observability" }

  assert {
    condition     = length(jsondecode(google_monitoring_dashboard.streambox.dashboard_json).gridLayout.widgets) == 11
    error_message = "Le dashboard doit contenir les 11 graphiques prévus."
  }
  assert {
    condition = alltrue([
      for widget in jsondecode(google_monitoring_dashboard.streambox.dashboard_json).gridLayout.widgets :
      try(
        strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilter.filter, "streambox-test-project"),
        strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilterRatio.numerator.filter, "streambox-test-project") &&
        strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilterRatio.denominator.filter, "streambox-test-project")
      )
    ])
    error_message = "Toutes les requêtes du dashboard doivent être limitées au projet."
  }
  assert {
    condition = alltrue([
      for widget in jsondecode(google_monitoring_dashboard.streambox.dashboard_json).gridLayout.widgets :
      try(strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilter.filter, "BACKEND_BUCKET"),
      strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilterRatio.denominator.filter, "BACKEND_BUCKET"))
      if startswith(widget.title, "Médias")
    ])
    error_message = "Les mesures médias ne doivent pas compter le trafic du catalogue."
  }
  assert {
    condition = alltrue([
      for widget in jsondecode(google_monitoring_dashboard.streambox.dashboard_json).gridLayout.widgets :
      strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilter.filter, "cache_result=\"MISS\"") &&
      strcontains(widget.xyChart.dataSets[0].timeSeriesQuery.timeSeriesFilter.filter, "cache_result=\"DISABLED\"")
      if strcontains(widget.title, "origine")
    ])
    error_message = "Les mesures d'origine doivent exclure les hits synthétiques."
  }
  assert {
    condition     = google_monitoring_alert_policy.catalogue_errors.combiner == "AND" && length(google_monitoring_alert_policy.catalogue_errors.conditions) == 2
    error_message = "L'alerte 5xx doit exiger le pourcentage ET le trafic minimum."
  }
  assert {
    condition = anytrue([
      for condition in google_monitoring_alert_policy.catalogue_errors.conditions :
      try(condition.condition_threshold[0].denominator_filter == local.run_requests &&
      condition.condition_threshold[0].threshold_value == 0.01, false)
      ]) && anytrue([
      for condition in google_monitoring_alert_policy.catalogue_errors.conditions :
      condition.condition_threshold[0].threshold_value == 99
    ])
    error_message = "L'alerte doit utiliser 1 % et au moins 100 requêtes par défaut."
  }
  assert {
    condition     = google_monitoring_alert_policy.catalogue_latency.conditions[0].condition_threshold[0].threshold_value == 1000
    error_message = "Le seuil de latence est exprimé en millisecondes."
  }
  assert {
    condition     = length(google_monitoring_alert_policy.catalogue_errors.notification_channels) == 1 && length(google_monitoring_alert_policy.catalogue_latency.notification_channels) == 1
    error_message = "Les deux alertes doivent référencer le canal email."
  }
  assert {
    condition     = length(google_logging_project_sink.archive) == 0 && length(google_storage_bucket_iam_member.archive_writer) == 0 && length(google_service_account.prometheus) == 0
    error_message = "Les compléments doivent être désactivés par défaut dans le module."
  }
}

run "archive_and_reader" {
  command = plan
  module { source = "./modules/observability" }
  variables {
    enable_log_archive       = true
    log_archive_bucket_name  = "streambox-test-archives"
    create_prometheus_reader = true
    alerts_enabled           = false
  }
  assert {
    condition     = google_logging_project_sink.archive[0].destination == "storage.googleapis.com/streambox-test-archives" && google_logging_project_sink.archive[0].unique_writer_identity
    error_message = "Le sink doit cibler le bucket fourni avec une identité dédiée."
  }
  assert {
    condition     = google_storage_bucket_iam_member.archive_writer[0].bucket == "streambox-test-archives" && google_storage_bucket_iam_member.archive_writer[0].role == "roles/storage.objectCreator"
    error_message = "Le sink doit seulement pouvoir créer des objets dans le bucket d'archives."
  }
  assert {
    condition     = google_project_iam_member.prometheus_reader[0].role == "roles/monitoring.viewer"
    error_message = "L'exporter ne doit recevoir qu'un rôle de lecture Monitoring."
  }
  assert {
    condition     = !google_monitoring_alert_policy.catalogue_errors.enabled && !google_monitoring_alert_policy.catalogue_latency.enabled
    error_message = "Le commutateur d'alertes doit désactiver les deux politiques."
  }
}

run "archive_requires_bucket" {
  command = plan
  module { source = "./modules/observability" }
  variables { enable_log_archive = true }
  expect_failures = [google_logging_project_sink.archive]
}

run "reject_invalid_thresholds" {
  command = plan
  module { source = "./modules/observability" }
  variables {
    notification_email       = "adresse-invalide"
    error_ratio_threshold    = 1.5
    minimum_requests         = 0
    latency_p95_threshold_ms = -1
  }
  expect_failures = [
    var.notification_email,
    var.error_ratio_threshold,
    var.minimum_requests,
    var.latency_p95_threshold_ms
  ]
}
