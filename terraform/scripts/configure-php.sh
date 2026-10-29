#!/bin/bash
# Install or upgrade to PHP 8.5.12+ and apply PHP2Shell mitigations.
# Covers CVE-2026-109618, CVE-2026-109619, and leftover CVE-2026-115560.
# Idempotent. Safe to re-run from Terraform user_data or once on an existing box.

set -eo pipefail

MIN_PHP="${MIN_PHP:-8.5.12}"
PHP_MM="${PHP_MM:-8.5}"

export DEBIAN_FRONTEND=noninteractive

if [ ! -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
  echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 >/dev/null
fi

sudo apt-get update -y
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install -y \
  "php${PHP_MM}" \
  "php${PHP_MM}-cli" \
  "php${PHP_MM}-common" \
  "php${PHP_MM}-mysql" \
  "php${PHP_MM}-xml" \
  "php${PHP_MM}-mbstring" \
  "php${PHP_MM}-curl" \
  "php${PHP_MM}-zip" \
  "php${PHP_MM}-gd" \
  "libapache2-mod-php${PHP_MM}"

if [ -x "/usr/bin/php${PHP_MM}" ]; then
  sudo update-alternatives --install /usr/bin/php php "/usr/bin/php${PHP_MM}" 85
  sudo update-alternatives --set php "/usr/bin/php${PHP_MM}"
fi

if command -v a2dismod >/dev/null 2>&1; then
  for mod in php8.4 php8.3 php8.2 php8.1 php8.0 php; do
    sudo a2dismod "$mod" 2>/dev/null || true
  done
  sudo a2enmod "php${PHP_MM}"
fi

# Must be set in php.ini / conf.d (or php_admin_value) before request parsing.
# ini_set() and .user.ini do not close these paths.
write_ini() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  sudo tee "$dir/99-php2shell.ini" >/dev/null <<'INI'
; Residual PHP2Shell / session-upload-progress mitigations
; CVE-2026-109619, CVE-2026-115560
session.upload_progress.enabled=0
fatal_error_backtraces=0
; Match nginx client_max_body_size. Default 2M makes Laravel report
; "The image failed to upload." for iPhone / simulator photos.
upload_max_filesize=20M
post_max_size=20M
INI
}

write_ini "/etc/php/${PHP_MM}/apache2/conf.d"
write_ini "/etc/php/${PHP_MM}/cli/conf.d"
write_ini "/etc/php/${PHP_MM}/fpm/conf.d"

# If an older Apache module is still present, close the same paths there too.
for ver in 8.4 8.3 8.2 8.1; do
  write_ini "/etc/php/${ver}/apache2/conf.d"
  write_ini "/etc/php/${ver}/cli/conf.d"
  write_ini "/etc/php/${ver}/fpm/conf.d"
done

PHP_BIN="$(command -v php 2>/dev/null || true)"
[ -z "$PHP_BIN" ] && [ -x "/usr/bin/php${PHP_MM}" ] && PHP_BIN="/usr/bin/php${PHP_MM}"
if [ -z "$PHP_BIN" ]; then
  echo "ERROR: php ${PHP_MM} not found after install"
  exit 1
fi

ACTUAL="$($PHP_BIN -r 'echo PHP_VERSION;')"
if ! $PHP_BIN -r "exit(version_compare(PHP_VERSION, '${MIN_PHP}', '>=') ? 0 : 1);"; then
  echo "ERROR: PHP ${ACTUAL} is below required ${MIN_PHP} (PHP2Shell CVE-2026-109618 / CVE-2026-109619)"
  exit 1
fi

UPLOAD_PROGRESS="$($PHP_BIN -d display_errors=0 -r 'echo ini_get("session.upload_progress.enabled") ? "1" : "0";')"
if [ "$UPLOAD_PROGRESS" != "0" ]; then
  echo "ERROR: session.upload_progress.enabled is still on (CVE-2026-115560)"
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet apache2; then
    sudo systemctl restart apache2
  fi
  if systemctl list-unit-files "php${PHP_MM}-fpm.service" >/dev/null 2>&1 && systemctl is-active --quiet "php${PHP_MM}-fpm"; then
    sudo systemctl restart "php${PHP_MM}-fpm"
  fi
fi

echo "[SUCCESS] PHP ${ACTUAL} (>= ${MIN_PHP}); session.upload_progress disabled"
