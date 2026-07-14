# ============================================================
# main.tf — Production AWS VPC Architecture
# ============================================================
# Resources are organized in logical deployment order:
#   1. VPC
#   2. Subnets
#   3. Internet Gateway
#   4. NAT Gateway
#   5. Route Tables
#   6. Security Groups
#   7. Network ACLs
#   8. EC2 Instances (Bastion + App Server)
#   9. Application Load Balancer
# ============================================================

# ============================================================
# 1. VPC
# ============================================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # enable_dns_hostnames is required for EC2 instances to receive
  # a public DNS hostname, and for some AWS services to resolve
  # internal endpoints correctly.
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "prod-vpc"
  }
}


# ============================================================
# 2. Subnets
# ============================================================

# --- Public Subnets ---
# Public subnets host internet-facing resources: the ALB, Bastion
# host, and the NAT Gateway. Instances here can receive public IPs.

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true # Instances launched here get a public IP

  tags = {
    Name = "prod-public-subnet-a"
    Tier = "Public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = true

  tags = {
    Name = "prod-public-subnet-b"
    Tier = "Public"
  }
}

# --- Private Subnets ---
# Private subnets host application workloads. No public IP is
# assigned to instances here. Outbound internet access is
# provided via the NAT Gateway in the public subnet.

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = {
    Name = "prod-private-subnet-a"
    Tier = "Private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_b_cidr
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false

  tags = {
    Name = "prod-private-subnet-b"
    Tier = "Private"
  }
}


# ============================================================
# 3. Internet Gateway
# ============================================================
# The IGW enables two-way communication between public subnets
# and the internet. Without this, even instances with public
# IPs cannot communicate outside the VPC.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "prod-igw"
  }
}


# ============================================================
# 4. NAT Gateway + Elastic IP
# ============================================================
# The NAT Gateway sits in a public subnet and provides outbound
# internet access for private subnet instances. It performs
# network address translation — private IPs are translated to
# the EIP for outbound requests, responses are routed back.
#
# Note: NAT Gateways are AZ-specific. For full HA, you would
# deploy one per AZ. This project uses a single NAT GW in
# public-subnet-a (a cost-vs-HA trade-off for study purposes).

resource "aws_eip" "nat" {
  domain = "vpc" # "vpc" is the correct value for modern AWS provider versions

  # The EIP must be created before the NAT Gateway that uses it,
  # and the IGW must exist before the EIP can be associated.
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "prod-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id # NAT GW lives in a public subnet

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "prod-nat-gw"
  }
}


# ============================================================
# 5. Route Tables
# ============================================================

# --- Public Route Table ---
# Directs all non-local traffic (0.0.0.0/0) to the Internet Gateway.
# Attached to both public subnets.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "prod-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table ---
# Directs outbound traffic to the NAT Gateway. Inbound from the
# internet is not possible — only responses to outbound requests
# are returned via NAT. Attached to both private subnets.

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "prod-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}


# ============================================================
# 6. Security Groups
# ============================================================
# Security Groups are stateful — return traffic is automatically
# allowed. Rules reference other SGs as sources where possible,
# which is more maintainable and precise than CIDR ranges.

# --- Bastion Security Group ---
# Only allows SSH from a known IP. This prevents brute-force
# attempts against the jump host from arbitrary internet IPs.

resource "aws_security_group" "bastion_sg" {
  name        = "prod-bastion-sg"
  description = "Allow SSH inbound from admin IP only. Outbound unrestricted."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-bastion-sg"
  }
}

# --- ALB Security Group ---
# Accepts HTTP on port 80 from the internet. Only sends traffic
# to the app tier on port 80.

resource "aws_security_group" "alb_sg" {
  name        = "prod-alb-sg"
  description = "Allow HTTP inbound from internet. Send to app tier only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to app servers on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "prod-alb-sg"
  }
}

# --- App Server Security Group ---
# Application servers only accept HTTP from the ALB (by SG reference)
# and SSH from the Bastion (by SG reference). This means even if
# someone obtained the private IP, they couldn't reach the server
# unless coming from an instance in the referenced SG.

resource "aws_security_group" "app_sg" {
  name        = "prod-app-sg"
  description = "Allow HTTP from ALB SG and SSH from Bastion SG only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "SSH from Bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    description = "Allow all outbound (NAT handles internet routing)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-app-sg"
  }
}


# ============================================================
# 7. Network ACLs (NACLs)
# ============================================================
# NACLs are stateless — both inbound AND outbound rules are
# evaluated independently. Return traffic (ephemeral ports
# 1024–65535) must be explicitly allowed in both directions.
# NACLs are the subnet-level firewall; SGs are instance-level.

# --- Public Subnet NACL ---

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  # Inbound rules
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Ephemeral ports — required for return traffic from internet
  # (TCP connections initiated from inside return on these ports)
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound rules
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Ephemeral ports for outbound responses
  egress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "prod-public-nacl"
  }
}

# --- Private Subnet NACL ---

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  # Allow HTTP from within the VPC (ALB to app servers)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 80
    to_port    = 80
  }

  # Allow SSH from the public subnet CIDR (Bastion host)
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 22
    to_port    = 22
  }

  # Ephemeral ports — return traffic from internet via NAT GW
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow outbound HTTP (for package downloads via NAT)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow outbound HTTPS (for secure package repos, APIs)
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Ephemeral ports for returning responses to VPC clients
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "prod-private-nacl"
  }
}


# ============================================================
# 8. EC2 Instances
# ============================================================

# --- Bastion Host ---
# The bastion (jump host) is the only way to SSH into private
# instances. It's hardened by SG rules and sits in a public
# subnet with a public IP. Use SSH agent forwarding to avoid
# storing the private key on the bastion itself.

resource "aws_instance" "bastion" {
  ami                    = var.amazon_linux_ami
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public_a.id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  # Public IP is auto-assigned because map_public_ip_on_launch = true
  # on the public subnet. The associate_public_ip_address flag here
  # explicitly ensures it regardless of subnet setting.
  associate_public_ip_address = true

  user_data = file("bastion-userdata.sh")

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "prod-bastion-root-vol"
    }
  }

  tags = {
    Name = "prod-bastion"
    Role = "BastionHost"
  }
}

# --- Private Application Server ---
# No public IP. Receives traffic only from the ALB on port 80
# and SSH from the Bastion on port 22. Outbound via NAT GW.

resource "aws_instance" "app_server" {
  ami                    = var.amazon_linux_ami
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.private_b.id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  associate_public_ip_address = false

  user_data = file("private-app-userdata.sh")

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "prod-app-server-root-vol"
    }
  }

  tags = {
    Name = "prod-app-server"
    Role = "ApplicationServer"
  }
}


# ============================================================
# 9. Application Load Balancer
# ============================================================
# The ALB is internet-facing and spans both public subnets for
# high availability. It terminates HTTP connections and forwards
# traffic to healthy targets in the target group.

resource "aws_lb" "main" {
  name               = "prod-alb"
  internal           = false # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # ALB must span at least 2 subnets in different AZs
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  # Enable deletion protection in real production environments.
  # Set to false here to allow easy cleanup during development.
  enable_deletion_protection = false

  tags = {
    Name = "prod-alb"
  }
}

# --- Target Group ---
# Defines how the ALB health-checks and routes to targets.
# The health check hits the root path (/) on port 80 expecting
# an HTTP 200 response from Apache.

resource "aws_lb_target_group" "app" {
  name     = "prod-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2 # 2 consecutive successes = healthy
    unhealthy_threshold = 2 # 2 consecutive failures = unhealthy
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "prod-app-tg"
  }
}

# --- Target Group Attachment ---
# Registers the app EC2 instance as a target in the group.
# In a production ASG setup, this would be handled by the
# ASG launch template instead of a manual attachment.

resource "aws_lb_target_group_attachment" "app_server" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_server.id
  port             = 80
}

# --- ALB Listener ---
# Listens on port 80 and forwards all traffic to the target group.
# In production, you would also add:
#   - Port 443 listener with SSL certificate (ACM)
#   - Port 80 → redirect to HTTPS rule

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "prod-alb-http-listener"
  }
}
