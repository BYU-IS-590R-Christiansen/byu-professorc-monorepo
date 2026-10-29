provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Data source to get default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "byu_590r_sg" {
  name        = "byu-590r-sg"
  description = "Security group for BYU 590R application"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name    = "byu-590r-sg"
    Project = "590r"
  }
}

# Security Group Rules
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.byu_590r_sg.id
  description       = "SSH access"
}

resource "aws_security_group_rule" "http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.byu_590r_sg.id
  description       = "HTTP access"
}

resource "aws_security_group_rule" "https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.byu_590r_sg.id
  description       = "HTTPS access"
}

resource "aws_security_group_rule" "backend_api" {
  type              = "ingress"
  from_port         = 4444
  to_port           = 4444
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.byu_590r_sg.id
  description       = "Backend API access"
}

# Allow all outbound traffic (apt, curl, Composer, etc.)
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.byu_590r_sg.id
  description       = "Allow all outbound"
}

# User data script for EC2 instance setup
locals {
  user_data = <<-EOF
#!/bin/bash
set -e

# Force apt to use IPv4 only (avoids IPv6 unreachable / timeouts in VPCs without IPv6 egress)
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PHP 8.3 (8.3.36+ security release) and extensions
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.3 php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl php8.3-zip php8.3-gd php8.3-cli php8.3-common libapache2-mod-php8.3

# Install Composer (non-fatal: Apache/MySQL still set up if getcomposer.org is unreachable)
curl -sS --connect-timeout 30 https://getcomposer.org/installer | php 2>/dev/null || true
if [ -f composer.phar ]; then
  sudo mv composer.phar /usr/local/bin/composer && sudo chmod +x /usr/local/bin/composer && echo "[SUCCESS] Composer installed"
else
  echo "[WARN] Composer install skipped (getcomposer.org unreachable); CI/CD will provide composer.phar on deploy"
fi

# Install MySQL
sudo apt install -y mysql-server
sudo systemctl enable mysql
sudo systemctl start mysql

# Install Apache
sudo apt install -y apache2
sudo systemctl enable apache2
sudo systemctl start apache2

# Install Git
sudo apt install -y git

# Create application directories
sudo mkdir -p /var/www/html/app
sudo mkdir -p /var/www/html/api
sudo chown -R ubuntu:ubuntu /var/www/html/app
sudo chown -R ubuntu:ubuntu /var/www/html/api

# Create database/users used by local .env and GitHub Actions DB_* secrets
sudo mysql -u root << 'MYSQL_EOF'
CREATE DATABASE IF NOT EXISTS app_db;
CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'app_password';
CREATE USER IF NOT EXISTS 'byu_user'@'localhost' IDENTIFIED BY 'byu_password';
GRANT ALL PRIVILEGES ON app_db.* TO 'app_user'@'localhost';
GRANT ALL PRIVILEGES ON app_db.* TO 'byu_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF

# Enable Apache modules
sudo a2enmod rewrite
sudo a2enmod headers

# Create virtual hosts with port-based routing
sudo tee /etc/apache2/sites-available/byu-590r-backend.conf > /dev/null << 'APACHE_BACKEND_EOF'
<VirtualHost *:4444>
    ServerName localhost
    DocumentRoot /var/www/html/api/public
    
    <Directory /var/www/html/api/public>
        AllowOverride All
        Require all granted
        
        # Laravel routing
        RewriteEngine On
        RewriteCond %%{REQUEST_FILENAME} !-f
        RewriteCond %%{REQUEST_FILENAME} !-d
        RewriteRule ^(.*)$ index.php [QSA,L]
        
        # Set index files
        DirectoryIndex index.php index.html
    </Directory>
    
    ErrorLog $${APACHE_LOG_DIR}/byu590r_backend_error.log
    CustomLog $${APACHE_LOG_DIR}/byu590r_backend_access.log combined
</VirtualHost>
APACHE_BACKEND_EOF

sudo tee /etc/apache2/sites-available/byu-590r-frontend.conf > /dev/null << 'APACHE_FRONTEND_EOF'
<VirtualHost *:8080>
    ServerName localhost
    DocumentRoot /var/www/html/app/browser
    
    <Directory /var/www/html/app/browser>
        AllowOverride All
        Require all granted
        
        # Angular routing support
        RewriteEngine On
        RewriteRule ^index\.html$ - [L]
        RewriteCond %%{REQUEST_FILENAME} !-f
        RewriteCond %%{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
        
        # Set index files
        DirectoryIndex index.html
    </Directory>
    
    ErrorLog $${APACHE_LOG_DIR}/byu590r_frontend_error.log
    CustomLog $${APACHE_LOG_DIR}/byu590r_frontend_access.log combined
</VirtualHost>
APACHE_FRONTEND_EOF

# Enable sites and disable default
sudo a2ensite byu-590r-backend.conf
sudo a2ensite byu-590r-frontend.conf
sudo a2dissite 000-default

# Add ports to Apache configuration (Caddy owns :80/:443)
echo "Listen 127.0.0.1:8080" | sudo tee -a /etc/apache2/ports.conf
echo "Listen 4444" | sudo tee -a /etc/apache2/ports.conf
sudo sed -i 's/^Listen 80$/# Listen 80  # Caddy owns :80/' /etc/apache2/ports.conf

sudo systemctl reload apache2

# Final Apache restart to ensure all changes take effect
sudo systemctl restart apache2
echo "[SUCCESS] Apache configuration complete"

# Set proper permissions for Laravel (if directories exist)
if [ -d "/var/www/html/api" ]; then
    sudo chown -R www-data:www-data /var/www/html/api
    sudo chmod -R 755 /var/www/html/api
    
    # Create Laravel directories if they don't exist
    sudo mkdir -p /var/www/html/api/storage
    sudo mkdir -p /var/www/html/api/bootstrap/cache
    
    # Set permissions for Laravel-specific directories
    sudo chmod -R 775 /var/www/html/api/storage
    sudo chmod -R 775 /var/www/html/api/bootstrap/cache
else
    echo "[INFO] Laravel application directory not found yet - permissions will be set during deployment"
fi

# Ensure Laravel can write to all necessary directories (if they exist)
if [ -d "/var/www/html/api/storage" ]; then
    sudo mkdir -p /var/www/html/api/storage/logs
    sudo mkdir -p /var/www/html/api/storage/framework
    sudo mkdir -p /var/www/html/api/storage/app
    sudo chmod -R 775 /var/www/html/api/storage/logs
    sudo chmod -R 775 /var/www/html/api/storage/framework
    sudo chmod -R 775 /var/www/html/api/storage/app
fi

# Create .env file if it doesn't exist
if [ ! -f /var/www/html/api/.env ]; then
    if [ -f /var/www/html/api/.env.example ]; then
        sudo cp /var/www/html/api/.env.example /var/www/html/api/.env
        sudo chown www-data:www-data /var/www/html/api/.env
        sudo chmod 644 /var/www/html/api/.env
        echo "[SUCCESS] Created .env file from .env.example"
    else
        echo "[INFO] .env.example not found - .env will be created during deployment"
    fi
fi

# Ensure Apache is running (frontend :8080, API :4444). Caddy binds :80/:443.
sudo systemctl enable apache2
sudo systemctl start apache2 || sudo systemctl restart apache2
sleep 2
sudo systemctl status apache2 --no-pager || true
echo "[SUCCESS] Apache enabled and started"

# Caddy: automatic HTTPS reverse_proxy (CS 260 / neuronova pattern)
sudo tee /usr/local/sbin/byu-590r-configure-caddy.sh > /dev/null << 'CADDY_SETUP'
${file("${path.module}/scripts/configure-caddy.sh")}
CADDY_SETUP
sudo chmod +x /usr/local/sbin/byu-590r-configure-caddy.sh
sudo /usr/local/sbin/byu-590r-configure-caddy.sh || echo "[WARN] Caddy setup deferred until EIP/deploy"

echo "Server setup complete! Ready for GitHub Actions deployment."
EOF
}

# EC2 Instance (in default VPC/subnet so it gets a public IP for outbound until EIP is associated)
resource "aws_instance" "byu_590r_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.byu_590r_sg.id]
  associate_public_ip_address = true
  user_data                   = base64encode(local.user_data)

  tags = {
    Name = "${var.project_name}-server"
  }

  lifecycle {
    create_before_destroy = true
    # Existing boxes are configured by terraform/scripts/configure-caddy.sh
    # (CI and manual SSH). Do not replace the instance when user_data changes.
    ignore_changes = [user_data]
  }
}

# Elastic IP
resource "aws_eip" "byu_590r_eip" {
  domain = "vpc"

  tags = {
    Name    = var.project_name
    Project = "590r"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Associate Elastic IP with EC2 instance
resource "aws_eip_association" "byu_590r_eip_assoc" {
  instance_id   = aws_instance.byu_590r_server.id
  allocation_id = aws_eip.byu_590r_eip.id
}

# Random ID for prod bucket suffix (equivalent to openssl rand -hex 4)
resource "random_id" "prod_bucket_suffix" {
  byte_length = 2 # 2 bytes = 4 hex characters
}

# Stable bucket names. Do not use timestamp() — that forced a replace on every apply.
locals {
  dev_bucket_name  = "${var.project_name}-dev"
  prod_bucket_name = "${var.project_name}-prod-${random_id.prod_bucket_suffix.hex}"
}

# S3 Bucket - Dev
resource "aws_s3_bucket" "dev" {
  bucket        = local.dev_bucket_name
  force_destroy = true

  tags = {
    Name        = "byu-590r-dev"
    Project     = "byu-590r"
    Environment = "development"
  }

  # Keep the existing timestamped name already in state (e.g. byu-590r-dev-20260402013907)
  lifecycle {
    ignore_changes = [bucket]
  }
}

resource "aws_s3_bucket_public_access_block" "dev" {
  bucket = aws_s3_bucket.dev.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# S3 Bucket - Prod
resource "aws_s3_bucket" "prod" {
  bucket        = local.prod_bucket_name
  force_destroy = true

  tags = {
    Name        = "byu-590r-prod"
    Project     = "byu-590r"
    Environment = "production"
  }

  lifecycle {
    ignore_changes = [bucket]
  }
}

resource "aws_s3_bucket_public_access_block" "prod" {
  bucket = aws_s3_bucket.prod.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Book images: upload from backend/public/assets/books to images/ in both dev and prod buckets.
# Uses placeholder.jpg for any key whose file is missing so production always has all seeded image keys.
# path.module/.. is repo root when this module lives at <repo>/terraform
locals {
  book_images_dir  = abspath("${path.module}/../${var.book_images_path}")
  book_image_keys  = toset(var.book_images)
  placeholder_path = "${local.book_images_dir}/placeholder.jpg"
  # For each key: use the real file if present, else the committed placeholder image
  book_image_source = {
    for f in local.book_image_keys : f =>
    fileexists("${local.book_images_dir}/${f}") ? "${local.book_images_dir}/${f}" : local.placeholder_path
  }
}

# Upload book images to dev bucket (images/hp1.jpeg, images/bom.jpg, etc.)
resource "aws_s3_object" "dev_book_images" {
  for_each = local.book_image_keys

  bucket = aws_s3_bucket.dev.id
  key    = "images/${each.value}"
  source = local.book_image_source[each.value]

  etag = filemd5(local.book_image_source[each.value])

  depends_on = [aws_s3_bucket.dev]
}

# Upload book images to prod bucket (images/hp1.jpeg, images/bom.jpg, etc.)
resource "aws_s3_object" "prod_book_images" {
  for_each = local.book_image_keys

  bucket = aws_s3_bucket.prod.id
  key    = "images/${each.value}"
  source = local.book_image_source[each.value]

  etag = filemd5(local.book_image_source[each.value])

  depends_on = [aws_s3_bucket.prod]
}
