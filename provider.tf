# ============================================================
# AWS Provider Configuration
# ============================================================
# This file defines the AWS provider settings. The region is
# pulled from variables so the same configuration can be
# deployed to different regions without code changes.
# ============================================================

provider "aws" {
  region = var.aws_region

  # Default tags applied to every resource created by this provider.
  # This ensures consistent tagging across the entire stack without
  # having to repeat tags on every individual resource block.
  default_tags {
    tags = {
      Project     = "production-aws-vpc"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.project_owner
    }
  }
}
