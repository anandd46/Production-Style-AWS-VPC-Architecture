#!/bin/bash
# ============================================================
# Private Application Server Bootstrap Script
# ============================================================
# This user data script runs once on first boot as root.
# It installs Apache, starts the web service, enables it on
# boot, and creates a simple status HTML page that exposes
# server metadata for verification purposes.
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
# Install Apache HTTP Server
# ----------------------------
echo "==> Installing Apache (httpd)..."
dnf install -y httpd curl

# ----------------------------
# Set Hostname
# ----------------------------
hostnamectl set-hostname prod-app-server
echo "127.0.0.1 prod-app-server" >> /etc/hosts

# ----------------------------
# Retrieve Instance Metadata
# ----------------------------
# IMDSv2 requires a token — fetch it first, then use it for metadata calls.
echo "==> Retrieving instance metadata via IMDSv2..."

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/hostname)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-type)

LAUNCH_TIME=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# ----------------------------
# Create the Application HTML Page
# ----------------------------
echo "==> Creating application HTML page..."

cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Production App Server</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: 'Courier New', monospace;
      background: #0d1117;
      color: #c9d1d9;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
    }

    .card {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 10px;
      padding: 40px 50px;
      max-width: 620px;
      width: 100%;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
    }

    .status-badge {
      display: inline-block;
      background: #1a7f37;
      color: #ffffff;
      font-size: 12px;
      font-weight: bold;
      letter-spacing: 1px;
      padding: 4px 12px;
      border-radius: 20px;
      margin-bottom: 20px;
      text-transform: uppercase;
    }

    h1 {
      color: #58a6ff;
      font-size: 26px;
      margin-bottom: 8px;
    }

    .subtitle {
      color: #8b949e;
      font-size: 13px;
      margin-bottom: 30px;
    }

    .divider {
      border: none;
      border-top: 1px solid #30363d;
      margin: 24px 0;
    }

    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }

    .info-item {
      background: #0d1117;
      border: 1px solid #21262d;
      border-radius: 6px;
      padding: 14px 16px;
    }

    .info-label {
      color: #8b949e;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 6px;
    }

    .info-value {
      color: #00e5a0;
      font-size: 14px;
      word-break: break-all;
    }

    .info-item.wide {
      grid-column: 1 / -1;
    }

    .env-tag {
      color: #f78166;
      font-weight: bold;
    }

    .footer {
      margin-top: 28px;
      color: #484f58;
      font-size: 11px;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="status-badge">● Healthy</div>
    <h1>Production App Server</h1>
    <p class="subtitle">AWS VPC — Private Subnet — Apache/2.4</p>

    <hr class="divider" />

    <div class="info-grid">
      <div class="info-item">
        <div class="info-label">Instance ID</div>
        <div class="info-value">${INSTANCE_ID}</div>
      </div>

      <div class="info-item">
        <div class="info-label">Instance Type</div>
        <div class="info-value">${INSTANCE_TYPE}</div>
      </div>

      <div class="info-item">
        <div class="info-label">Private IP</div>
        <div class="info-value">${PRIVATE_IP}</div>
      </div>

      <div class="info-item">
        <div class="info-label">Availability Zone</div>
        <div class="info-value">${AZ}</div>
      </div>

      <div class="info-item wide">
        <div class="info-label">Hostname</div>
        <div class="info-value">${HOSTNAME}</div>
      </div>

      <div class="info-item">
        <div class="info-label">Environment</div>
        <div class="info-value env-tag">Production</div>
      </div>

      <div class="info-item">
        <div class="info-label">Launched</div>
        <div class="info-value">${LAUNCH_TIME}</div>
      </div>

      <div class="info-item wide">
        <div class="info-label">Network</div>
        <div class="info-value">Private Subnet — No Public IP — NAT Outbound</div>
      </div>
    </div>

    <div class="footer">
      Served by Apache httpd | prod-vpc | Managed by Terraform
    </div>
  </div>
</body>
</html>
HTML

# ----------------------------
# Create a simple health check endpoint for the ALB
# ----------------------------
cat > /var/www/html/health << 'HEALTH'
OK
HEALTH

# ----------------------------
# Configure Apache
# ----------------------------
echo "==> Configuring Apache..."

# Set the server name to suppress warnings
echo "ServerName prod-app-server" >> /etc/httpd/conf/httpd.conf

# ----------------------------
# Start and Enable Apache
# ----------------------------
echo "==> Starting and enabling Apache..."
systemctl start httpd
systemctl enable httpd

# Verify Apache is running
systemctl is-active httpd && echo "==> Apache is running successfully."

# ----------------------------
# Fix Permissions
# ----------------------------
chmod -R 755 /var/www/html/
chown -R apache:apache /var/www/html/

# ----------------------------
# Quick Self-Test
# ----------------------------
echo "==> Running self-test..."
sleep 2
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
echo "==> Local HTTP response: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
  echo "==> Self-test PASSED — Apache serving HTTP 200"
else
  echo "==> Self-test WARNING — Expected 200, got $HTTP_STATUS"
fi

# ----------------------------
# Done
# ----------------------------
echo "==> Application server bootstrap complete."
echo "==> Server ready at: $(date)"
