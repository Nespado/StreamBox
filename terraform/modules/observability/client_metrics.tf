# Mesures côté générateur : distinctes des latences de traitement Cloud Run.
locals {
  client_metrics = {
    latency_mean_ms = {
      unit        = "ms"
      description = "Moyenne des requêtes réussies d'un cycle de 5 secondes, mesurée côté générateur."
      labels      = ["run_id", "route"]
    }
    users = {
      unit        = "1"
      description = "Nombre d'utilisateurs virtuels configurés pour le palier du générateur."
      labels      = ["run_id"]
    }
    phase_p95_ms = {
      unit        = "ms"
      description = "p95 exact (nearest rank) des réponses réussies d'un palier complet, côté générateur."
      labels      = ["run_id", "route", "users"]
    }
  }
}

resource "google_monitoring_metric_descriptor" "client_test" {
  for_each     = local.client_metrics
  project      = var.project_id
  type         = "custom.googleapis.com/streambox/load_test/${each.key}"
  metric_kind  = "GAUGE"
  value_type   = "DOUBLE"
  unit         = each.value.unit
  display_name = "StreamBox - Essai client - ${each.key}"
  description  = each.value.description
  dynamic "labels" {
    for_each = each.value.labels
    content {
      key        = labels.value
      value_type = "STRING"
    }
  }
  depends_on = [google_project_service.observability]
}
