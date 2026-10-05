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
# Note: not part of Always Free; an active key version costs a few cents/month.
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

# --- Firewall (App Tier) ---
resource "google_compute_firewall" "app_https" {
  name        = "shell-space-allow-https-${var.environment}"
  network     = google_compute_network.shell_space.name
  description = "HTTPS only into the app tier"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.allowed_cidr_blocks
  target_tags   = ["shell-space-app"]
}

# --- Firewall (SSH for Ansible) ---
# count = 0 until ssh_allowed_cidrs is set, so SSH stays closed by default.
resource "google_compute_firewall" "app_ssh" {
  count       = length(var.ssh_allowed_cidrs) > 0 ? 1 : 0
  name        = "shell-space-allow-ssh-${var.environment}"
  network     = google_compute_network.shell_space.name
  description = "SSH from admin ranges only"
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

# --- App Compute (Always Free e2-micro) ---
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
    access_config {} # Ephemeral public IP
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
# PLACEHOLDER: No managed SQL on free tier. Run Postgres on the VM via Ansible,
# or use Firestore (has a free tier).

# --- Monitoring / Budget ---
# PLACEHOLDER: google_billing_budget with alert thresholds — add before first apply.
