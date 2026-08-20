output "vpc_id" {
  description = "Shell Space VPC ID"
  value       = aws_vpc.shell_space.id
}

output "kms_key_arn" {
  description = "KMS encryption key ARN — pass to Ansible and downstream tools"
  value       = aws_kms_key.shell_space.arn
}

output "kms_key_alias" {
  description = "KMS key alias"
  value       = aws_kms_alias.shell_space.name
}

output "app_security_group_id" {
  description = "App tier security group ID"
  value       = aws_security_group.app.id
}

# PLACEHOLDER: Uncomment when database is active
# output "db_endpoint" {
#   description = "RDS database endpoint — feeds into Ansible inventory"
#   value       = aws_db_instance.shell_space.endpoint
#   sensitive   = true
# }

# PLACEHOLDER: Uncomment when compute tier is active
# output "app_container_url" {
#   description = "App container / load balancer URL"
#   value       = aws_lb.shell_space.dns_name
# }
