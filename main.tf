# =============================================================================
# Shell Space — main.tf
# Core infrastructure entry point. All sensitive values use variables.
# NO hardcoded secrets, IPs, or domain names.
# Nelson must approve this file before any `terraform apply`.
# =============================================================================

# --- VPC (Isolated Network Boundary) ---
resource "aws_vpc" "shell_space" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "shell-space-vpc-${var.environment}"
  }
}

# PLACEHOLDER: Subnets (public + private) — to be defined when AZs are confirmed
# resource "aws_subnet" "public" { ... }
# resource "aws_subnet" "private" { ... }

# PLACEHOLDER: Internet Gateway — required for public-facing app tier
# resource "aws_internet_gateway" "igw" { ... }

# PLACEHOLDER: NAT Gateway — required for private subnet egress
# resource "aws_nat_gateway" "nat" { ... }

# --- KMS Encryption Key ---
resource "aws_kms_key" "shell_space" {
  description             = "Shell Space encryption key — at rest and in transit"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "shell-space-kms-${var.environment}"
  }
}

resource "aws_kms_alias" "shell_space" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.shell_space.key_id
}

# --- Security Group (App Tier) ---
resource "aws_security_group" "app" {
  name        = "shell-space-app-sg-${var.environment}"
  description = "Least-privilege security group for Shell Space app tier"
  vpc_id      = aws_vpc.shell_space.id

  # PLACEHOLDER: ingress rules — define exact ports/protocols before prod
  ingress {
    description = "HTTPS only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound — restrict before prod"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # PLACEHOLDER — tighten egress rules for prod
  }

  tags = {
    Name = "shell-space-app-sg-${var.environment}"
  }
}

# --- Database (Encrypted RDS) ---
# PLACEHOLDER: Subnet group requires private subnets — uncomment after subnets defined
# resource "aws_db_subnet_group" "shell_space" {
#   name       = "shell-space-db-subnet-group"
#   subnet_ids = [aws_subnet.private.id]
# }

# resource "aws_db_instance" "shell_space" {
#   identifier              = "shell-space-db-${var.environment}"
#   engine                  = "postgres"           # PLACEHOLDER — confirm DB engine
#   engine_version          = "15"                 # PLACEHOLDER — pin version
#   instance_class          = var.db_instance_class
#   db_name                 = var.db_name
#   username                = var.db_username
#   password                = var.db_password
#   storage_encrypted       = true
#   kms_key_id              = aws_kms_key.shell_space.arn
#   deletion_protection     = true
#   backup_retention_period = 7
#   db_subnet_group_name    = aws_db_subnet_group.shell_space.name
#   vpc_security_group_ids  = [aws_security_group.app.id]
#   skip_final_snapshot     = false
# }

# --- App Container / Compute ---
# PLACEHOLDER: ECS Fargate or EC2 — confirm compute model before defining
# resource "aws_ecs_cluster" "shell_space" { ... }
# resource "aws_ecs_task_definition" "app" { ... }
# resource "aws_ecs_service" "app" { ... }

# --- Monitoring ---
# PLACEHOLDER: CloudWatch alarms and log groups — define after app tier is set
# resource "aws_cloudwatch_log_group" "shell_space" { ... }
