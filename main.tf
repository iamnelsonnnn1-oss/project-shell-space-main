# =============================================================================
# Shell Space — main.tf (GCP free tier)
# Core infrastructure entry point. No hardcoded secrets, IPs, or domains.
# Nelson must approve this file before any `terraform apply`.
# =============================================================================

# --- Network Boundary ---
resource "google_compute_network" "shell_space" {
  name                    = "shell-space-vpc-${var.environment}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "app" {
  name          = "shell-space-app-${var.environment}"
  region        = var.region
  network       = google_compute_network.shell_space.id
  ip_cidr_range = var.subnet_cidr
}

# --- Cloud KMS Encryption Key ---
# Created but intentionally unused until the encryption model is approved.
resource "google_kms_key_ring" "shell_space" {
  name     = "shell-space-keyring-${var.environment}"
  location = var.region
}

resource "google_kms_crypto_key" "shell_space" {
  name            = var.kms_key_name
  key_ring        = google_kms_key_ring.shell_space.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# --- Ingress ---
# No public 443 rule: Cloudflare Tunnel (outbound-only cloudflared) is the only application ingress.
# The VPC's implicit deny-ingress applies to everything not explicitly allowed below.

# --- Firewall (SSH via IAP only) ---
# Source ranges are limited to Google's IAP range by variable validation; there is no public SSH rule.
resource "google_compute_firewall" "app_ssh" {
  count       = length(var.ssh_allowed_cidrs) > 0 ? 1 : 0
  name        = "shell-space-allow-ssh-${var.environment}"
  network     = google_compute_network.shell_space.name
  description = "SSH from the IAP range only"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_allowed_cidrs
  target_tags   = ["shell-space-app"]
}

# --- OS Login access (admins only) ---
resource "google_project_iam_member" "os_admin_login" {
  for_each = toset(var.admin_emails)
  project  = var.project_id
  role     = "roles/compute.osAdminLogin"
  member   = "user:${each.value}"
}

resource "google_project_iam_member" "iap_tunnel" {
  for_each = toset(var.admin_emails)
  project  = var.project_id
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${each.value}"
}

# --- Service account (least privilege) ---
# Deliberately holds NO roles. No KMS binding exists: a KMS consumer is created only after the
# encryption and key-custody model is approved.
resource "google_service_account" "app" {
  account_id   = "shell-space-app-${var.environment}"
  display_name = "Shell Space app VM (${var.environment}), no roles"
}

# --- App Compute (e2-micro) ---
resource "google_compute_instance" "app" {
  name         = "shell-space-app-${var.environment}"
  machine_type = var.app_machine_type
  zone         = var.zone
  tags         = ["shell-space-app"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.app_disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app.id
    # Ephemeral public IP for OUTBOUND connectivity only (no Cloud NAT this iteration).
    # No firewall rule admits inbound traffic through it.
    access_config {}
  }

  service_account {
    email  = google_service_account.app.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    block-project-ssh-keys = "true"
    enable-oslogin         = "TRUE"
    enable-oslogin-2fa     = "TRUE" # Requires Google 2-Step Verification (authenticator app) at SSH login
  }
}

# --- Database ---
# PostgreSQL runs on the VM and is configured by Ansible (no Terraform resource).

# --- Monitoring / Budget ---
# PLACEHOLDER: google_billing_budget with alert thresholds — add before first apply.
