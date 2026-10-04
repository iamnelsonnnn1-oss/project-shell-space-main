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

output "app_external_ip" {
  description = "App tier public IP — feeds Cloudflare DNS and Ansible inventory"
  value       = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
}
