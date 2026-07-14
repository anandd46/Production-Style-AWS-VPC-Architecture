#!/bin/bash
# ============================================================
# Bastion Host Bootstrap Script
# ============================================================
# This user data script runs once on first boot as root.
# It hardens the bastion host and installs useful tools for
# troubleshooting the VPC environment.
#
# Execution log: /var/log/cloud-init-output.log
# ============================================================


set -euxo pipefail

# ----------------------------
# System Updates
# ----------------------------
echo "==> Updating system packages..."
dnf update -y

# ----------------------------
# Install Useful Networking Tools
# ----------------------------
# These tools are helpful for diagnosing VPC connectivity issues
# from the bastion host.
echo "==> Installing networking and diagnostic tools..."
dnf install -y \
  telnet \
  nmap \
  curl \
  wget \
  net-tools \
  bind-utils \
  traceroute \
  tcpdump \
  htop \
  vim \
  jq

# ----------------------------
# SSH Hardening
# ----------------------------
echo "==> Hardening SSH configuration..."

# Back up the original sshd config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply hardened SSH settings
cat >> /etc/ssh/sshd_config << 'EOF'

# Hardened SSH settings applied by user data
Protocol 2
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
EOF

# Restart SSH to apply changes
systemctl restart sshd

# ----------------------------
# Set Hostname
# ----------------------------
hostnamectl set-hostname prod-bastion
echo "127.0.0.1 prod-bastion" >> /etc/hosts

# ----------------------------
# Set a Login Banner
# ----------------------------
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════╗
║            Production VPC — Bastion Host                 ║
║                                                          ║
║  ⚠️  Authorized access only. All activity is logged.    ║
║  SSH to private instances using: ssh ec2-user@<PRIV_IP>  ║
║  Ensure SSH agent forwarding is enabled (-A flag).       ║
╚══════════════════════════════════════════════════════════╝
EOF

# ----------------------------
# Configure AWS CLI (no credentials needed — uses instance metadata)
# ----------------------------
echo "==> Configuring AWS CLI region..."
mkdir -p /home/ec2-user/.aws
cat > /home/ec2-user/.aws/config << 'EOF'
[default]
region = us-east-1
output = json
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.aws

# ----------------------------
# Create a helper script for common VPC commands
# ----------------------------
cat > /usr/local/bin/vpc-info << 'SCRIPT'
#!/bin/bash
# Quick VPC diagnostic helper
echo "=== Network Interfaces ==="
ip addr show

echo ""
echo "=== Routing Table ==="
ip route

echo ""
echo "=== DNS Resolution Test ==="
dig +short google.com

echo ""
echo "=== Outbound Internet Test ==="
curl -s --max-time 5 https://checkip.amazonaws.com && echo " (NAT GW EIP)"
SCRIPT

chmod +x /usr/local/bin/vpc-info

# ----------------------------
# Done
# ----------------------------
echo "==> Bastion host bootstrap complete."
echo "==> Instance ready at: $(date)"
