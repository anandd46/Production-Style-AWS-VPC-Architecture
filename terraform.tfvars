# ============================================================
# Variable Values — terraform.tfvars
# ============================================================
# This file provides concrete values for the input variables
# defined in variables.tf. Update the values below before
# running terraform apply.
#
# IMPORTANT:
#   - Replace my_ip with YOUR actual public IP + /32
#     Find it at: https://checkip.amazonaws.com
#   - Replace key_pair_name with your actual EC2 key pair
#   - Add this file to .gitignore if it contains sensitive IPs
# ============================================================

# ----------------------------
# General
# ----------------------------
aws_region    = "us-east-1"
environment   = "prod"
project_owner = "cloud-engineering"

# ----------------------------
# Networking
# ----------------------------
vpc_cidr              = "10.0.0.0/16"
public_subnet_a_cidr  = "10.0.1.0/24"
public_subnet_b_cidr  = "10.0.2.0/24"
private_subnet_a_cidr = "10.0.11.0/24"
private_subnet_b_cidr = "10.0.12.0/24"
availability_zone_a   = "us-east-1a"
availability_zone_b   = "us-east-1b"

# ----------------------------
# Security — UPDATE BEFORE DEPLOY
# ----------------------------
# Replace with your actual IP from https://checkip.amazonaws.com
my_ip = "0.0.0.0/0" # ⚠️ Replace with your IP, e.g., "203.0.113.42/32"

# ----------------------------
# Compute — UPDATE BEFORE DEPLOY
# ----------------------------
# Replace with the name of your EC2 key pair in the target region
key_pair_name = "prod-vpc-key" # ⚠️ Must exist in your AWS account

bastion_instance_type = "t3.micro"
 app_instance_type    = "t3.micro"

# Amazon Linux 2023 — us-east-1
# Run this to get the latest AMI ID for your region:
# aws ec2 describe-images --owners amazon \
#   --filters 'Name=name,Values=al2023-ami-*-x86_64' \
#   --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
#   --output text
amazon_linux_ami = "ami-0453ec754f44f9a4a"
