# Canal de notification utilisé par les deux politiques d'alerte.
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "StreamBox - Alertes email"
  type         = "email"
  depends_on   = [google_project_service.observability]

  labels = {
    email_address = var.notification_email
  }
}

# Dashboard Cloud Monitoring.
resource "google_monitoring_dashboard" "streambox" {
  depends_on = [google_project_service.observability]
  project    = var.project_id

  dashboard_json = jsonencode({
    displayName = "StreamBox - Observabilité"

    gridLayout = {
      columns = "2"

      widgets = [
        {
          title = "Cloud Run - Requêtes par seconde"

          xyChart = {
            dataSets = [
              {
                plotType = "LINE"

                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/request_count\"",
                      "resource.type=\"cloud_run_revision\"",
                      "resource.labels.project_id=\"${var.project_id}\"",
                      "resource.labels.service_name=\"${var.cloud_run_service_name}\"",
                      "resource.labels.location=\"${var.region}\""
                    ])

                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ]

            yAxis = {
              label = "Requêtes / seconde"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Cloud Run - Latence p95"

          xyChart = {
            dataSets = [
              {
                plotType = "LINE"

                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/request_latencies\"",
                      "resource.type=\"cloud_run_revision\"",
                      "resource.labels.project_id=\"${var.project_id}\"",
                      "resource.labels.service_name=\"${var.cloud_run_service_name}\"",
                      "resource.labels.location=\"${var.region}\""
                    ])

                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_SUM"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    }
                  }
                }
              }
            ]

            yAxis = {
              label = "Latence (ms)"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Cloud Run - Erreurs 5xx par seconde"

          xyChart = {
            dataSets = [
              {
                plotType = "LINE"

                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/request_count\"",
                      "resource.type=\"cloud_run_revision\"",
                      "resource.labels.project_id=\"${var.project_id}\"",
                      "resource.labels.service_name=\"${var.cloud_run_service_name}\"",
                      "resource.labels.location=\"${var.region}\"",
                      "metric.labels.response_code_class=\"5xx\""
                    ])

                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ]

            yAxis = {
              label = "Erreurs / seconde"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Cloud Run - Nombre moyen d'instances"

          xyChart = {
            dataSets = [
              {
                plotType = "LINE"

                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/container/instance_count\"",
                      "resource.type=\"cloud_run_revision\"",
                      "resource.labels.project_id=\"${var.project_id}\"",
                      "resource.labels.service_name=\"${var.cloud_run_service_name}\"",
                      "resource.labels.location=\"${var.region}\""
                    ])

                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ]

            yAxis = {
              label = "Instances moyennes"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Médias - Requêtes par statut du cache"

          xyChart = {
            dataSets = [
              {
                plotType = "LINE"

                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"loadbalancing.googleapis.com/https/request_count\"",
                      "resource.type=\"https_lb_rule\"",
                      "resource.labels.project_id=\"${var.project_id}\"",
                      "resource.labels.url_map_name=\"${var.load_balancer_url_map_name}\"",
                      "resource.labels.backend_target_type=\"BACKEND_BUCKET\""
                    ])

                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.labels.cache_result"]
                    }
                  }
                }
              }
            ]

            yAxis = {
              label = "Requêtes / seconde"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Médias - Octets distribués par minute",
          xyChart = {
            dataSets = [
              {
                plotType = "LINE",
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/response_bytes_count\" AND ${local.media_filter}",
                    aggregation = {
                      alignmentPeriod    = "60s",
                      perSeriesAligner   = "ALIGN_SUM",
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ],
            yAxis = {
              label = "Octets par fenêtre de 60 s",
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Médias - Requêtes à l’origine",
          xyChart = {
            dataSets = [
              {
                plotType = "LINE",
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/backend_request_count\" AND ${local.origin_filter}",
                    aggregation = {
                      alignmentPeriod    = "60s",
                      perSeriesAligner   = "ALIGN_RATE",
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ],
            yAxis = {
              label = "Requêtes / seconde",
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Médias - Octets reçus de l’origine par minute",
          xyChart = {
            dataSets = [
              {
                plotType = "LINE",
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/backend_response_bytes_count\" AND ${local.origin_filter}",
                    aggregation = {
                      alignmentPeriod    = "60s",
                      perSeriesAligner   = "ALIGN_SUM",
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ],
            yAxis = {
              label = "Octets par fenêtre de 60 s",
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Load Balancer - Erreurs 5xx, tous chemins",
          xyChart = {
            dataSets = [
              {
                plotType = "LINE",
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND ${local.lb_errors_filter}",
                    aggregation = {
                      alignmentPeriod    = "60s",
                      perSeriesAligner   = "ALIGN_RATE",
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }
            ],
            yAxis = {
              label = "Erreurs / seconde",
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Cloud Run - Proportion de 5xx",
          xyChart = {
            dataSets = [
              {
                plotType = "LINE",
                timeSeriesQuery = {
                  timeSeriesFilterRatio = {
                    numerator = {
                      filter = local.run_errors,
                      aggregation = {
                        alignmentPeriod    = "60s",
                        perSeriesAligner   = "ALIGN_RATE",
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    },
                    denominator = {
                      filter = local.run_requests,
                      aggregation = {
                        alignmentPeriod    = "60s",
                        perSeriesAligner   = "ALIGN_RATE",
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                }
              }
            ],
            yAxis = {
              label = "Ratio (0 à 1)",
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Médias - Proportion de HIT complets",
          xyChart = {
            dataSets = [
              {
                plotType = "LINE",
                timeSeriesQuery = {
                  timeSeriesFilterRatio = {
                    numerator = {
                      filter = "${local.lb_requests} AND metric.labels.cache_result=\"HIT\"",
                      aggregation = {
                        alignmentPeriod    = "60s",
                        perSeriesAligner   = "ALIGN_RATE",
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    },
                    denominator = {
                      filter = local.lb_requests,
                      aggregation = {
                        alignmentPeriod    = "60s",
                        perSeriesAligner   = "ALIGN_RATE",
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                }
              }
            ],
            yAxis = {
              label = "Ratio (0 à 1)",
              scale = "LINEAR"
            }
          }
        }
      ]
    }
  })
}
