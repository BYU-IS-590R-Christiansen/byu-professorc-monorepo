#!/bin/bash
# Caddy in front of Apache: HTTP :80 + automatic HTTPS on <public-ip>.sslip.io
# and professorccs260.click (Route53 A records on the Elastic IP).
# Safe to re-run. PUBLIC_IP may be passed in; otherwise IMDS is used.
set -eo pipefail

CLASS_DOMAIN="${CLASS_DOMAIN:-professorccs260.click}"

if [ -z "$PUBLIC_IP" ]; then
  IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2160" || true)
  if [ -n "$IMDS_TOKEN" ]; then
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
  fi
fi

if [ -z "$PUBLIC_IP" ]; then
  echo "ERROR: PUBLIC_IP is empty (pass PUBLIC_IP=... or wait for IMDS)"
  exit 1
fi

echo "[caddy] public hosts $PUBLIC_IP.sslip.io $CLASS_DOMAIN www.$CLASS_DOMAIN"

# Apache keeps PHP on 4444 (public, existing API clients) and the Angular
# docroot on loopback :8080. Caddy owns :80 and :443.
FRONTEND_CONF=/etc/apache2/sites-available/byu-590r-frontend.conf
if [ -f "$FRONTEND_CONF" ]; then
  sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' "$FRONTEND_CONF"
fi

sudo sed -i 's/^Listen 8080$/Listen 127.0.0.1:8080/' /etc/apache2/ports.conf
if ! grep -qE '^Listen 127\.0\.0\.1:8080$' /etc/apache2/ports.conf; then
  echo "Listen 127.0.0.1:8080" | sudo tee -a /etc/apache2/ports.conf >/dev/null
fi
sudo sed -i 's/^Listen 80$/# Listen 80  # Caddy owns :80/' /etc/apache2/ports.conf

# Prevent Apache from grabbing 443 if ssl is later enabled
sudo sed -i 's/^\tListen 443$/\t# Listen 443  # Caddy owns :443/' /etc/apache2/ports.conf

sudo mkdir -p /var/www/html/app/browser /var/www/html/api/public

# Caddy package (Cloudsmith stable), same source as CS 260 / neuronova
if ! command -v caddy >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
  sudo apt-get update -y
  sudo apt-get install -y caddy
fi

# Quoted delimiter so Caddy {host} placeholders are not expanded by bash.
sudo tee /etc/caddy/Caddyfile >/dev/null << CADDY
# BYU 590R — Caddy reverse_proxy in front of Apache
# :80 stays on the raw Elastic IP (existing bookmarks / Playwright HTTP).
# <eip>.sslip.io and CLASS_DOMAIN get Let's Encrypt certs.

:80 {
	header Cache-Control no-store
	header -server
	header -etag
	handle /api* {
		reverse_proxy 127.0.0.1:4444
	}
	handle {
		reverse_proxy 127.0.0.1:8080
	}
}

$PUBLIC_IP.sslip.io, $CLASS_DOMAIN, www.$CLASS_DOMAIN {
	encode gzip
	header Cache-Control no-store
	header -server
	header -etag
	header Access-Control-Allow-Origin *
	handle /api* {
		reverse_proxy 127.0.0.1:4444
	}
	handle {
		reverse_proxy 127.0.0.1:8080
	}
}
CADDY

sudo systemctl restart apache2
sudo systemctl enable caddy
sudo systemctl restart caddy
sleep 2
echo "[caddy] apache=$(systemctl is-active apache2) caddy=$(systemctl is-active caddy)"
