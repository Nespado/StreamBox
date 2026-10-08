# ==============================================================================
# Bootstrap StreamBox : Remote State & Workload Identity Federation (CI/CD)
# À déployer une seule fois au démarrage du projet.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------------------------
# 1. Bucket GCS pour le Remote State Terraform
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "terraform_state" {
  name                        = var.state_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Compte de Service pour la CI/CD
# ------------------------------------------------------------------------------
resource "google_service_account" "ci_deployer" {
  account_id   = "streambox-ci-deployer"
  display_name = "Compte de Service CI/CD GitHub Actions"
  description  = "Utilisé exclusivement par le pipeline GitHub Actions via Workload Identity Federation (sans clé JSON)"
}

# Permissions requises pour déployer l'infrastructure
locals {
  ci_roles = [
    "roles/run.admin",
    "roles/compute.loadBalancerAdmin",
    "roles/compute.networkAdmin",
    "roles/storage.admin",
    "roles/monitoring.admin",
    "roles/logging.admin",
    "roles/iam.serviceAccountUser"
  ]
}

resource "google_project_iam_member" "ci_roles" {
  for_each = toset(local.ci_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.ci_deployer.email}"
}

# Droit d'écriture et de verrouillage sur le bucket de state
resource "google_storage_bucket_iam_member" "ci_state_access" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ci_deployer.email}"
}

# ------------------------------------------------------------------------------
# 3. Workload Identity Federation (WIF) pour GitHub Actions
# ------------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "streambox-github-pool"
  display_name              = "Pool GitHub Actions StreamBox"
  description               = "Authentification sans clé JSON pour les pipelines GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "streambox-github-provider"
  display_name                       = "Provider OIDC GitHub"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Autoriser GitHub Actions à emprunter l'identité du compte de service CI
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.ci_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}
