terraform {
  required_version = "> 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.46.1"
    }
  }
}

provider "google" {
  project = "streambox-insset-m1-2026"
  region  = "europe-west9"
}