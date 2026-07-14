# ============================================================
# Terraform Version Constraints
# ============================================================
# Locking provider and Terraform versions prevents unexpected
# behavior when team members or CI pipelines use different
# versions. The ~> operator allows patch-level updates only.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure this block to use S3 as a remote backend
  # (recommended for team environments and production workloads).
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "prod-vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
