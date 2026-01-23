#!/bin/bash
set -eu

# ===== 固定パス =====
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/.env"
DOCKER_BIN="/usr/bin/docker"

cd "$BASE_DIR"

# ===== .env 読み込み =====
set -a
. "$ENV_FILE"
set +a

# ===== コンテナ・イメージ・ボリューム削除 =====
"$DOCKER_BIN" compose down -v --rmi all

# ===== DB 起動 =====
"$DOCKER_BIN" compose up -d db

# ===== DB healthcheck 待ち =====
DB_CONTAINER="$("$DOCKER_BIN" compose ps -q db)"

echo "Waiting for DB to become healthy..."

until [ "$("$DOCKER_BIN" inspect --format='{{.State.Health.Status}}' "$DB_CONTAINER")" = "healthy" ]; do
  sleep 2
done

echo "DB is healthy"

# ===== APP_KEY 生成 =====
APP_KEY="$(
  "$DOCKER_BIN" compose run --rm app \
    php artisan key:generate --show \
    | tr -d '\r'
)"

if [[ -z "$APP_KEY" ]]; then
  echo "ERROR: APP_KEY generation failed"
  exit 1
fi

# ===== .env 更新 =====
if grep -q '^APP_KEY=' "$ENV_FILE"; then
  sed -i "s|^APP_KEY=.*|APP_KEY=$APP_KEY|" "$ENV_FILE"
else
  echo "APP_KEY=$APP_KEY" >> "$ENV_FILE"
fi

echo "APP_KEY updated successfully"

# ===== APP 起動 =====
"$DOCKER_BIN" compose up -d
