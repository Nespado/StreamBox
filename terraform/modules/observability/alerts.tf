# Deux conditions sur le même service : pourcentage ET trafic minimal.
resource "google_monitoring_alert_policy" "catalogue_errors" {
  project               = var.project_id
  display_name          = "StreamBox - Taux d'erreurs du catalogue"
  enabled               = var.alerts_enabled
  combiner              = "AND"
  severity              = "ERROR"
  notification_channels = [google_monitoring_notification_channel.email.name]

  conditions {
    display_name = "Plus de ${var.error_ratio_threshold * 100} % de 5xx sur 5 minutes"
    condition_threshold {
      filter                  = local.run_errors
      denominator_filter      = local.run_requests
      comparison              = "COMPARISON_GT"
      threshold_value         = var.error_ratio_threshold
      duration                = "60s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
      denominator_aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
      trigger { count = 1 }
    }
  }

  conditions {
    display_name = "Au moins ${var.minimum_requests} requêtes sur 5 minutes"
    condition_threshold {
      filter                  = local.run_requests
      comparison              = "COMPARISON_GT"
      threshold_value         = var.minimum_requests - 1
      duration                = "60s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
      trigger { count = 1 }
    }
  }

  alert_strategy {
    auto_close           = "1800s"
    notification_prompts = ["OPENED", "CLOSED"]
  }

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      Service : ${var.cloud_run_service_name} (${var.region}).
      Plus de ${var.error_ratio_threshold * 100} % de 5xx et au moins ${var.minimum_requests}
      requêtes sur 5 minutes, conditions maintenues 60 secondes.

      Ouvrir le dashboard StreamBox et les logs Cloud Run, comparer les révisions
      et vérifier mémoire, concurrence et limite d'instances. Si l'incident suit
      un déploiement, coordonner un retour à une révision connue avec le responsable
      catalogue. Vérifier une requête réussie ET la fermeture de l'incident.
      Une disparition des données ne prouve pas un retour au service.
      Voir le README du module, section Diagnostic et preuves.
    EOT
  }
}

resource "google_monitoring_alert_policy" "catalogue_latency" {
  project               = var.project_id
  display_name          = "StreamBox - Latence p95 du catalogue"
  enabled               = var.alerts_enabled
  combiner              = "OR"
  severity              = "WARNING"
  notification_channels = [google_monitoring_notification_channel.email.name]

  conditions {
    display_name = "p95 supérieur à ${var.latency_p95_threshold_ms} ms pendant 5 minutes"
    condition_threshold {
      filter                  = "metric.type=\"run.googleapis.com/request_latencies\" AND ${local.run_filter}"
      comparison              = "COMPARISON_GT"
      threshold_value         = var.latency_p95_threshold_ms
      duration                = "300s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
      trigger { count = 1 }
    }
  }

  alert_strategy {
    auto_close           = "1800s"
    notification_prompts = ["OPENED", "CLOSED"]
  }
  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      Service : ${var.cloud_run_service_name} (${var.region}).
      p95 du traitement dans le conteneur > ${var.latency_p95_threshold_ms} ms
      pendant 5 minutes. Le démarrage et le trajet réseau du navigateur sont exclus.

      Comparer trafic, instances, logs de la révision et limites de capacité.
      Arrêter le test si sa règle d'arrêt est atteinte. Ne pas augmenter les plafonds
      sans vérifier le budget avec le groupe. Vérifier le retour sous le seuil avec
      du trafic normal et conserver la notification de fermeture.
    EOT
  }
}
