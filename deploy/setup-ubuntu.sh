#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/www/on-my-block"
CONFIG_DIR="/etc/on-my-block"
REPO_URL="${REPO_URL:-https://github.com/itsjimba/on-my-block.git}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script with sudo: sudo bash deploy/setup-ubuntu.sh"
  exit 1
fi

read -r -p "Public domain name (example.com): " DOMAIN
read -r -p "Supabase project URL: " SUPABASE_URL
read -r -p "Supabase public/publishable key: " SUPABASE_KEY

apt-get update
apt-get install -y git nginx

if [[ -d "$APP_DIR/.git" ]]; then
  git -C "$APP_DIR" pull --ff-only
else
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
fi

install -d -m 755 "$CONFIG_DIR"
cat > "$CONFIG_DIR/config.json" <<EOF
{
  "url": "${SUPABASE_URL}",
  "key": "${SUPABASE_KEY}"
}
EOF
chmod 640 "$CONFIG_DIR/config.json"
chown root:www-data "$CONFIG_DIR/config.json"

install -d -m 755 /etc/nginx/sites-available /etc/nginx/sites-enabled
sed "s|YOUR_DOMAIN|$DOMAIN|g; s|YOUR_WWW_DOMAIN|www.$DOMAIN|g" \
  "$APP_DIR/deploy/nginx/on-my-block.conf.example" \
  > /etc/nginx/sites-available/on-my-block
ln -sfn /etc/nginx/sites-available/on-my-block /etc/nginx/sites-enabled/on-my-block
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo
echo "On My Block is now served by Nginx at http://$DOMAIN"
echo "For HTTPS, run: sudo apt-get install -y certbot python3-certbot-nginx"
echo "Then: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
