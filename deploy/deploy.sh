#!/usr/bin/env bash
# HAIRPLACE VPS deploy script (run as root or with sudo)
# Usage:
#   sudo bash deploy.sh                            # IP only, no SSL
#   sudo DOMAIN=hairplace.id bash deploy.sh        # with domain, no SSL
#   sudo DOMAIN=hairplace.id SSL=1 EMAIL=you@x.com bash deploy.sh   # with HTTPS

set -euo pipefail

DOMAIN="${DOMAIN:-_}"
SSL="${SSL:-0}"
EMAIL="${EMAIL:-admin@example.com}"
WEBROOT="/var/www/hairplace"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Updating package index"
apt-get update -y

echo "==> Installing nginx"
apt-get install -y nginx

echo "==> Preparing webroot at $WEBROOT"
mkdir -p "$WEBROOT"
cp -r "$REPO_DIR/index.html" "$REPO_DIR/styles.css" "$REPO_DIR/script.js" "$WEBROOT/"
chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"

echo "==> Writing nginx site config"
SITE_CONF="/etc/nginx/sites-available/hairplace"
sed "s/hairplace.id www.hairplace.id/${DOMAIN} www.${DOMAIN}/" \
    "$REPO_DIR/deploy/nginx-hairplace.conf" > "$SITE_CONF"

# If no real domain, listen on default
if [[ "$DOMAIN" == "_" ]]; then
  sed -i 's/server_name _ www._;/server_name _;/' "$SITE_CONF"
fi

ln -sf "$SITE_CONF" /etc/nginx/sites-enabled/hairplace
rm -f /etc/nginx/sites-enabled/default

echo "==> Testing nginx config"
nginx -t

echo "==> Reloading nginx"
systemctl reload nginx
systemctl enable nginx

if [[ "$SSL" == "1" && "$DOMAIN" != "_" ]]; then
  echo "==> Installing certbot for HTTPS"
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
    --non-interactive --agree-tos --email "$EMAIL" --redirect
fi

echo ""
echo "✅ Deploy complete."
if [[ "$DOMAIN" == "_" ]]; then
  echo "   Open: http://<VPS-IP>/"
else
  PROTO="http"
  [[ "$SSL" == "1" ]] && PROTO="https"
  echo "   Open: $PROTO://$DOMAIN/"
fi
