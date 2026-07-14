# ============================================================
# Input Variables
# ============================================================
# All configurable parameters for the VPC stack are defined
# here. Sensitive or environment-specific values (like my_ip)
# should be set in terraform.tfvars or via environment
# variables — never hardcoded in .tf files.
# ============================================================

# ----------------------------
# General / Provider
# ----------------------------

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in resource tags and naming (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "project_owner" {
  description = "Name or team responsible for this infrastructure (used in tags)"
  type        = string
  default     = "cloud-engineering"
}

# ----------------------------
# VPC and Networking
# ----------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for Public Subnet A (us-east-1a)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for Public Subnet B (us-east-1b)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for Private Subnet A (us-east-1a)"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for Private Subnet B (us-east-1b)"
  type        = string
  default     = "10.0.12.0/24"
}

variable "availability_zone_a" {
  description = "First Availability Zone (used for Public Subnet A, Private Subnet A)"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_b" {
  description = "Second Availability Zone (used for Public Subnet B, Private Subnet B)"
  type        = string
  default     = "us-east-1b"
}

# ----------------------------
# Security
# ----------------------------

variable "my_ip" {
  description = "Your public IP address in CIDR notation(e.g., 203.0.113.42/32). Used to restrict SSH access to the bastion host. Find your IP at https://checkip.amazonaws.com"
  type        = string
  sensitive   = true

  validation {
    condition     = can(cidrnetmask(var.my_ip))
    error_message = "my_ip must be a valid CIDR block,e.g., 203.0.113.42/32"
  }
}

# ----------------------------
# EC2 / Compute
# ----------------------------

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair to attach to the Bastion and App instances. The .pem file must be available locally for SSH access."
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion host"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for the Application server"
  type        = string
  default     = "t3.micro"
}

variable "amazon_linux_ami" {
  description = "AMI ID for Amazon Linux 2023 in us-east-1. Update this if deploying to a different region — AMI IDs are region-specific."
  type        = string
  # Amazon Linux 2023 (AL2023) — us-east-1, x86_64, as of mid-2025
  # To find the latest: aws ec2 describe-images --owners amazon \
  #   --filters 'Name=name,Values=al2023-ami-*-x86_64' \
  #   --query 'sort_by(Images, &CreationDate)[-1].ImageId'
  default = "ami-0453ec754f44f9a4a"
}
