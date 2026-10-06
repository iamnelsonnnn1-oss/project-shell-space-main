terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 5.45.2" # Exact pin; lock file is committed. Update only after vulnerability review
    }
    # Enable when Cloudflare DNS/CDN is wired in
    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~> 4.0"
    # }
  }

  # Remote state (GCS with locking) must be established before any production apply.
  # Enable only after the bucket/project are confirmed: uncomment, then run
  #   terraform init -backend-config=backend.hcl   (see backend.hcl.example)
  # backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = {
    project     = "shell-space"
    environment = var.environment
    managed_by  = "terraform"
  }
}
