# Chaque filtre cible uniquement les ressources StreamBox.
locals {
  run_filter = join(" AND ", [
    "resource.type=\"cloud_run_revision\"",
    "resource.labels.project_id=\"${var.project_id}\"",
    "resource.labels.service_name=\"${var.cloud_run_service_name}\"",
    "resource.labels.location=\"${var.region}\""
  ])
  lb_filter = join(" AND ", [
    "resource.type=\"https_lb_rule\"",
    "resource.labels.project_id=\"${var.project_id}\"",
    "resource.labels.url_map_name=\"${var.load_balancer_url_map_name}\""
  ])
  # Cloud Logging utilise http_load_balancer ; https_lb_rule est réservé aux métriques.
  lb_log_filter = join(" AND ", [
    "resource.type=\"http_load_balancer\"",
    "resource.labels.project_id=\"${var.project_id}\"",
    "resource.labels.url_map_name=\"${var.load_balancer_url_map_name}\""
  ])
  media_filter = "${local.lb_filter} AND resource.labels.backend_target_type=\"BACKEND_BUCKET\""
  # Les métriques backend incluent aussi des hits synthétiques.
  # MISS et DISABLED sélectionnent les accès à l'origine, UNKNOWN est exclu.
  origin_filter    = "${local.media_filter} AND (metric.labels.cache_result=\"MISS\" OR metric.labels.cache_result=\"DISABLED\")"
  lb_errors_filter = "${local.lb_filter} AND metric.labels.response_code_class=500"
  run_requests     = "metric.type=\"run.googleapis.com/request_count\" AND ${local.run_filter}"
  run_errors       = "${local.run_requests} AND metric.labels.response_code_class=\"5xx\""
  lb_requests      = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND ${local.media_filter}"
  log_filter       = "(${local.run_filter}) OR (${local.lb_log_filter})"
}

# L'activation est additive : destroy ne désactive pas les API du projet.
resource "google_project_service" "observability" {
  for_each           = toset(["monitoring.googleapis.com", "logging.googleapis.com"])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
