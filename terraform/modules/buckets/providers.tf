terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.5.0"
    }
  }
}

provider "google" {
  project = "streambox-insset-m1-2026"
  region  = "europe-west9"
  zone    = "europe-west9-a"
}