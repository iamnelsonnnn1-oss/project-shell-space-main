terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Pinned — update only after vulnerability review
    }
    # Enable when Cloudflare DNS/CDN is wired in
    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~> 4.0"
    # }
  }

  # Remote state backend — configure before first apply
  # backend "gcs" {
  #   bucket = "REPLACE_WITH_STATE_BUCKET" # backend blocks cannot use variables
  #   prefix = "shell-space/terraform.tfstate"
  # }
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
