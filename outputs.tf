# ============================================================
# Outputs
# ============================================================
# These values are printed after terraform apply and can be
# referenced by other Terraform configurations using the
# terraform_remote_state data source.
# ============================================================

# ----------------------------
# VPC
# ----------------------------

output "vpc_id" {

  description = "The ID of the production VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the production VPC"
  value       = aws_vpc.main.cidr_block
}

# ----------------------------
# Subnets
# ----------------------------

output "public_subnet_ids" {
  description = "List of public subnet IDs (used for ALB, Bastion, NAT GW)"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (used for application workloads)"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "public_subnet_a_id" {
  description = "ID of Public Subnet A (us-east-1a)"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "ID of Public Subnet B (us-east-1b)"
  value       = aws_subnet.public_b.id
}

output "private_subnet_a_id" {
  description = "ID of Private Subnet A (us-east-1a)"
  value       = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  description = "ID of Private Subnet B (us-east-1b)"
  value       = aws_subnet.private_b.id
}

# ----------------------------
# Gateways
# ----------------------------

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_ip" {
  description = "Elastic IP address associated with the NAT Gateway (outbound source IP for private instances)"
  value       = aws_eip.nat.public_ip
}

# ----------------------------
# Security Groups
# ----------------------------

output "bastion_sg_id" {
  description = "ID of the Bastion Host security group"
  value       = aws_security_group.bastion_sg.id
}

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "app_sg_id" {
  description = "ID of the App Server security group"
  value       = aws_security_group.app_sg.id
}

# ----------------------------
# EC2 Instances
# ----------------------------

output "bastion_public_ip" {
  description = "Public IP of the Bastion host — use this to SSH into the jump box"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the Bastion host"
  value       = aws_instance.bastion.id
}

output "app_server_private_ip" {
  description = "Private IP of the application server — reachable only from within the VPC"
  value       = aws_instance.app_server.private_ip
}

output "app_server_instance_id" {
  description = "Instance ID of the App server"
  value       = aws_instance.app_server.id
}

# ----------------------------
# Load Balancer
# ----------------------------

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer — use this to access the app in a browser"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (needed for Route 53 alias records)"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the ALB Target Group (useful for health check queries)"
  value       = aws_lb_target_group.app.arn
}

# ----------------------------
# Convenience Output
# ----------------------------

output "ssh_bastion_command" {
  description = "Ready-to-run SSH command to connect to the Bastion host"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "app_url" {
  description = "URL to access the application via the ALB"
  value       = "http://${aws_lb.main.dns_name}"
}
