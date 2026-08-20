variable "aws_region" {
  description = "AWS region to deploy Shell Space infrastructure"
  type        = string
  default     = "us-east-1" # PLACEHOLDER — confirm target region
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
variable "vpc_cidr" {
  description = "CIDR block for the Shell Space VPC"
  type        = string
  default     = "10.0.0.0/16" # PLACEHOLDER — confirm address space
}

variable "allowed_cidr_blocks" {
  description = "Least-privilege ingress CIDRs (no 0.0.0.0/0 in prod)"
  type        = list(string)
  default     = ["10.0.0.0/16"] # PLACEHOLDER — restrict before prod
}

# --- Compute ---
variable "app_instance_type" {
  description = "EC2 / container instance size for the app tier"
  type        = string
  default     = "t3.micro" # PLACEHOLDER — size for production workload
}

# --- Database ---
variable "db_instance_class" {
  description = "RDS instance class for the Shell Space database"
  type        = string
  default     = "db.t3.micro" # PLACEHOLDER — size for production workload
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
  default     = "shellspacedb" # PLACEHOLDER — confirm DB name
}

# --- Encryption ---
variable "kms_key_alias" {
  description = "KMS key alias for encryption at rest"
  type        = string
  default     = "alias/shell-space-key" # PLACEHOLDER — confirm key alias
}

# --- Secrets (never set defaults for sensitive values) ---
variable "db_username" {
  description = "Database master username — set via tfvars or secrets manager"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password — set via tfvars or secrets manager"
  type        = string
  sensitive   = true
}
