mock_provider "google" {}

run "grafana_service" {
  command = plan
  module {
    source = "./modules/grafana"
  }
  variables {
    project_id = "streambox-test"
    region     = "europe-west9"
    public_url = "https://streambox.example/monitoring/"
    image      = "europe-west9-docker.pkg.dev/streambox-test/images/grafana@sha256:9d1fd4241d432e858c0ad8523287c3fbef9f1537117e6e6ee028e0b4ff9eaaac"
  }

  assert {
    condition = (
      google_cloud_run_v2_service.grafana.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" &&
      google_cloud_run_v2_service.grafana.scaling[0].min_instance_count == 0 &&
      google_cloud_run_v2_service.grafana.scaling[0].max_instance_count == 1
    )
    error_message = "Grafana doit passer par le LB et rester borné à une instance en régime normal."
  }
  assert {
    condition = (
      length(google_cloud_run_v2_service.grafana.template[0].containers) == 2 &&
      google_cloud_run_v2_service.grafana.template[0].containers[0].depends_on == tolist(["metrics-proxy"]) &&
      length(google_cloud_run_v2_service.grafana.template[0].containers[1].ports) == 0
    )
    error_message = "Le proxy doit précéder Grafana sans devenir un port d'entrée public."
  }
  assert {
    condition = alltrue([
      for env in google_cloud_run_v2_service.grafana.template[0].containers[0].env :
      length(env.value_source) == 1 if contains(["GF_SECURITY_ADMIN_PASSWORD", "GF_SECURITY_SECRET_KEY"], env.name)
    ]) && length(google_secret_manager_secret.grafana) == 2
    error_message = "Les deux secrets doivent être injectés depuis Secret Manager."
  }
  assert {
    condition = (
      google_project_iam_member.metrics_reader.role == "roles/monitoring.viewer" &&
      alltrue([for binding in google_secret_manager_secret_iam_member.grafana : binding.role == "roles/secretmanager.secretAccessor"])
    )
    error_message = "Grafana doit uniquement lire les métriques et ses secrets dédiés."
  }
}

run "delivery_routes" {
  command = plan
  module {
    source = "./modules/delivery"
  }
  variables {
    project_id             = "streambox-test"
    region                 = "europe-west9"
    cloud_run_service_name = "streambox-catalogue"
    backend_bucket_id      = "projects/streambox-test/global/backendBuckets/media"
    domain_name            = "streambox.example"
    enable_https_redirect  = true
    monitoring = {
      service_name = "streambox-grafana"
      region       = "europe-west9"
    }
  }
  assert {
    condition = (
      toset(flatten([for rule in google_compute_url_map.main.path_matcher[0].path_rule : rule.paths])) ==
      toset(["/media/*", "/monitoring", "/monitoring/*"])
    )
    error_message = "Conserver les médias et router les deux formes du chemin Grafana."
  }
  assert {
    condition     = google_compute_backend_service.grafana[0].enable_cdn == false
    error_message = "Le contenu authentifié de Grafana ne doit pas être mis en cache par Cloud CDN."
  }
}

run "reject_monitoring_over_http" {
  command = plan
  module {
    source = "./modules/delivery"
  }
  variables {
    project_id             = "streambox-test"
    region                 = "europe-west9"
    cloud_run_service_name = "streambox-catalogue"
    backend_bucket_id      = "projects/streambox-test/global/backendBuckets/media"
    domain_name            = "streambox.example"
    enable_https_redirect  = false
    monitoring = {
      service_name = "streambox-grafana"
      region       = "europe-west9"
    }
  }
  expect_failures = [google_compute_url_map.main]
}

run "delivery_without_grafana" {
  command = plan
  module {
    source = "./modules/delivery"
  }
  variables {
    project_id             = "streambox-test"
    region                 = "europe-west9"
    cloud_run_service_name = "streambox-catalogue"
    backend_bucket_id      = "projects/streambox-test/global/backendBuckets/media"
    domain_name            = "streambox.example"
  }
  assert {
    condition     = length(google_compute_backend_service.grafana) == 0 && length(google_compute_region_network_endpoint_group.grafana) == 0
    error_message = "Le module delivery doit rester utilisable sans Grafana."
  }
}
