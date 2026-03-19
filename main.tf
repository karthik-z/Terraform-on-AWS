###############################################################
# main.tf  –  Provider configuration & Terraform backend
###############################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ─── Remote State (S3 + DynamoDB for locking) ─────────────
  # Uncomment after manually creating the S3 bucket and DynamoDB table.
  # Run: terraform init -reconfigure
  #
  # backend "s3" {
  #   bucket         = "your-tf-state-bucket-name"    # must be globally unique
  #   key            = "aws-iac-project/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"          # for state locking
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  # Tag every resource automatically
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
