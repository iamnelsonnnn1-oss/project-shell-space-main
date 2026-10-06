output "network_id" {
  description = "Shell Space VPC network ID"
  value       = google_compute_network.shell_space.id
}

output "kms_key_id" {
  description = "Cloud KMS crypto key ID — pass to Ansible and downstream tools"
  value       = google_kms_crypto_key.shell_space.id
}

output "app_instance_name" {
  description = "App tier instance name"
  value       = google_compute_instance.app.name
}

output "app_zone" {
  description = "App tier zone — used by the Ansible IAP ProxyCommand"
  value       = google_compute_instance.app.zone
}

output "app_service_account_email" {
  description = "App VM service account (holds no roles)"
  value       = google_service_account.app.email
}
