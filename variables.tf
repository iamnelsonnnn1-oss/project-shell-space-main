variable "project_id" {
  description = "GCP project ID that hosts Shell Space"
  type        = string
}

variable "region" {
  description = "GCP region — must be us-west1, us-central1 or us-east1 for the e2-micro Always Free tier"
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(["us-west1", "us-central1", "us-east1"], var.region)
    error_message = "Always Free e2-micro is only available in us-west1, us-central1 and us-east1."
  }
}

variable "zone" {
  description = "GCP zone inside var.region"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# --- Networking ---
variable "subnet_cidr" {
  description = "CIDR block for the Shell Space subnet"
  type        = string
  default     = "10.0.0.0/24" # PLACEHOLDER — confirm address space
}

variable "allowed_cidr_blocks" {
  description = "Source ranges allowed to reach HTTPS. Restrict to Cloudflare ranges before prod."
  type        = list(string)
  default     = ["0.0.0.0/0"] # PLACEHOLDER — replace with Cloudflare IP ranges
}

# --- Compute ---
variable "app_machine_type" {
  description = "Compute Engine machine type for the app tier (e2-micro = Always Free)"
  type        = string
  default     = "e2-micro"
}

variable "app_disk_size_gb" {
  description = "Boot disk size in GB (Always Free covers 30 GB standard disk)"
  type        = number
  default     = 30
}

# --- Encryption ---
variable "kms_key_name" {
  description = "Cloud KMS crypto key name"
  type        = string
  default     = "shell-space-key"
}
