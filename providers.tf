terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Pinned — update only after vulnerability review
    }
    # gcp = {
    #   source  = "hashicorp/google"
    #   version = "~> 5.0"
    # }
  }

  # Remote state backend — configure before first apply
  # backend "s3" {
  #   bucket         = var.state_bucket
  #   key            = "shell-space/terraform.tfstate"
  #   region         = var.aws_region
  #   encrypt        = true
  #   dynamodb_table = var.state_lock_table
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "shell-space"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
