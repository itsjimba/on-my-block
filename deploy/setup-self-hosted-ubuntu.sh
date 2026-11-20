#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/www/on-my-block"
SUPABASE_DIR="/opt/my-block-supabase"
SUPABASE_SOURCE="/tmp/my-block-supabase-source"
SUPABASE_REF="${SUPABASE_REF:-self-hosted/v0.8.4}"
REPO_URL="${REPO_URL:-https://github.com/itsjimba/on-my-block.git}"
SUPABASE_REPO="https://github.com/supabase/supabase.git"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run with sudo: sudo bash deploy/setup-self-hosted-ubuntu.sh"
  exit 1
fi

read -r -p "Public My Block hostname (example: myblock.example.com): " DOMAIN
read -r -p "Supabase publishable key from the generated self-hosted .env (leave blank to fill later): " PUBLIC_KEY

apt-get update
apt-get install -y ca-certificates git nginx curl jq openssl docker.io docker-compose-plugin
systemctl enable --now docker

if [[ -d "$APP_DIR/.git" ]]; then
  git -C "$APP_DIR" pull --ff-only
elif [[ -e "$APP_DIR" ]]; then
  echo "$APP_DIR already exists and is not a Git checkout; refusing to overwrite it."
  exit 1
else
  git clone "$REPO_URL" "$APP_DIR"
fi

if [[ ! -f "$SUPABASE_DIR/docker-compose.yml" ]]; then
  if [[ -e "$SUPABASE_DIR" ]]; then
    echo "$SUPABASE_DIR exists without the expected Compose file; refusing to overwrite it."
    exit 1
  fi
  rm -rf "$SUPABASE_SOURCE"
  git clone --depth 1 --branch "$SUPABASE_REF" "$SUPABASE_REPO" "$SUPABASE_SOURCE"
  install -d -m 755 "$SUPABASE_DIR"
  cp -a "$SUPABASE_SOURCE/docker/." "$SUPABASE_DIR/"
fi

cd "$SUPABASE_DIR"
if [[ ! -f .env ]]; then
  cp .env.example .env
  sh utils/generate-keys.sh
  sh utils/add-new-auth-keys.sh
fi

set_env() {
  local key="$1" value="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    printf '\n%s=%s\n' "$key" "$value" >> .env
  fi
}

set_env SUPABASE_PUBLIC_URL "https://${DOMAIN}/supabase"
set_env API_EXTERNAL_URL "https://${DOMAIN}/supabase"
set_env SITE_URL "https://${DOMAIN}"
set_env PROXY_DOMAIN "$DOMAIN"

cp "$APP_DIR/deploy/supabase/docker-compose.my-block.yml" "$SUPABASE_DIR/docker-compose.my-block.yml"
cat > "$SUPABASE_DIR/.env.functions" <<EOF
APP_ORIGINS=https://${DOMAIN},http://127.0.0.1:8080
EOF

mkdir -p "$SUPABASE_DIR/volumes/functions/create-account" "$SUPABASE_DIR/volumes/functions/login-with-photo"
cp "$APP_DIR/supabase/functions/create-account/index.ts" "$SUPABASE_DIR/volumes/functions/create-account/index.ts"
cp "$APP_DIR/supabase/functions/login-with-photo/index.ts" "$SUPABASE_DIR/volumes/functions/login-with-photo/index.ts"

docker compose -f docker-compose.yml -f docker-compose.my-block.yml pull
docker compose -f docker-compose.yml -f docker-compose.my-block.yml up -d --wait
docker compose -f docker-compose.yml -f docker-compose.my-block.yml exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$APP_DIR/supabase-schema.sql"

if [[ -z "$PUBLIC_KEY" ]]; then
  PUBLIC_KEY="$(grep -E '^SUPABASE_PUBLISHABLE_KEY=' .env | cut -d= -f2- || true)"
fi
if [[ -z "$PUBLIC_KEY" ]]; then
  PUBLIC_KEY="$(grep -E '^ANON_KEY=' .env | cut -d= -f2- || true)"
fi
install -d -m 755 /etc/on-my-block
printf '{\n  "url": "https://%s/supabase",\n  "key": "%s"\n}\n' "$DOMAIN" "$PUBLIC_KEY" > /etc/on-my-block/config.json
chmod 640 /etc/on-my-block/config.json
chown root:www-data /etc/on-my-block/config.json

sed "s|YOUR_DOMAIN|$DOMAIN|g; s|YOUR_WWW_DOMAIN|www.$DOMAIN|g" \
  "$APP_DIR/deploy/nginx/on-my-block.conf.example" \
  > /etc/nginx/sites-available/on-my-block
ln -sfn /etc/nginx/sites-available/on-my-block /etc/nginx/sites-enabled/on-my-block
nginx -t
systemctl reload nginx

install -m 755 "$APP_DIR/deploy/backup.sh" /usr/local/sbin/my-block-backup
install -m 755 "$APP_DIR/deploy/restore.sh" /usr/local/sbin/my-block-restore
install -m 644 "$APP_DIR/deploy/systemd/my-block-supabase.service" /etc/systemd/system/
install -m 644 "$APP_DIR/deploy/systemd/my-block-backup.service" /etc/systemd/system/
install -m 644 "$APP_DIR/deploy/systemd/my-block-backup.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now my-block-supabase.service my-block-backup.timer

echo "My Block is available locally through Nginx on 127.0.0.1:8080."
echo "Configure the existing HTTPS tunnel to forward $DOMAIN to 127.0.0.1:8080."
echo "Do not modify underpunk-tunnel.service; use its existing tunnel configuration."
