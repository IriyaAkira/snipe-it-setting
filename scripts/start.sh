#!/bin/bash
set -eu

# ===== 固定パス定義 =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_BIN="/usr/bin/docker"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
LOG_FILE="${SCRIPT_DIR}/logs/${SCRIPT_NAME%.*}.log"
ENV_FILE="$BASE_DIR/.env"

# ===== root チェック =====
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ${SCRIPT_NAME} must be run as root."
  exit 1
fi
echo "${SCRIPT_NAME} running as root"

# ===== .env 読み込み =====
set -a
. "$ENV_FILE"
set +a

# ===== ログディレクトリ作成 =====
mkdir -p "${LOG_DIR}"

# ===== ログ関数 =====
log_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "${LOG_FILE}"
}
log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "${LOG_FILE}" >&2
}

# ===== エラーハンドラ =====
trap 'log_error "Script failed at line $LINENO"' ERR

# ===== ログ開始 =====
log_info "===== Starting ${SCRIPT_NAME} (PID: $$) ====="

# ===== ログファイルの容量制限 =====
log_info "Starting log file size limit."
MAX_LINES=10000
if [[ -f "${LOG_FILE}" ]] && [[ $(wc -l < "${LOG_FILE}") -gt ${MAX_LINES} ]]; then
  tail -n "${MAX_LINES}" "${LOG_FILE}" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "${LOG_FILE}"
  log_info "Log file rotated (kept last ${MAX_LINES} lines)."
fi

# ===== 立ち上げ =====
log_info "Changing directory to ${BASE_DIR}"
cd "${BASE_DIR}"

## dbコンテナ立ち上げ
log_info "Starting db container..."
if "${DOCKER_BIN}" compose up -d db 2>&1 | tee -a "${LOG_FILE}"; then
    log_info "db container started successfully."
else
  log_error "Failed to start db container."
    exit 1
fi

# DB healthcheck 待ち
DB_CONTAINER="$("${DOCKER_BIN}" compose ps -q db)"
if [[ -z "${DB_CONTAINER}" ]]; then
  log_error "Failed to get db container ID"
  exit 1
fi

# DB healthcheck ループ
MAX_RETRY=60
RETRY_COUNT=0
HEALTH_STATUS=""

log_info "Waiting for DB to become healthy... (Container ID: ${DB_CONTAINER})"
while [ $RETRY_COUNT -lt $MAX_RETRY ]; do
  HEALTH_STATUS="$("$DOCKER_BIN" inspect --format='{{.State.Health.Status}}' "$DB_CONTAINER" 2>&1 || echo "unknown")"
  log_info "DB health check attempt $((RETRY_COUNT + 1))/$MAX_RETRY: Status = $HEALTH_STATUS"
  
  if [ "$HEALTH_STATUS" = "healthy" ]; then
    log_info "DB is healthy"
    break
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  
  if [ $RETRY_COUNT -lt $MAX_RETRY ]; then
    sleep 2
  fi
done

if [ "$HEALTH_STATUS" != "healthy" ]; then
  log_error "DB failed to become healthy after $((MAX_RETRY * 2)) seconds (Final status: $HEALTH_STATUS)"
  exit 1
fi

# APP_KEY 生成
log_info "Generating APP_KEY..."
# disable errexit temporarily to capture command output and exit code
set +e
APP_KEY="$(
  "$DOCKER_BIN" compose run --rm app \
    php artisan key:generate --show 2>&1 \
    | tr -d '\r'
)"
RC=$?
set -e

if [ $RC -ne 0 ]; then
  log_error "APP_KEY generation command failed (rc=$RC). Output: ${APP_KEY}"
  exit 1
fi

if [[ -z "$APP_KEY" ]]; then
  log_error "APP_KEY is empty after generation"
  exit 1
fi
log_info "APP_KEY generated successfully"

# .env 更新
log_info "Update env file..."
if grep -q '^APP_KEY=' "$ENV_FILE"; then
  sed -i "s|^APP_KEY=.*|APP_KEY=$APP_KEY|" "$ENV_FILE"
else
  echo "APP_KEY=$APP_KEY" >> "$ENV_FILE"
fi
log_info "APP_KEY updated successfully"

# APP起動
log_info "Starting snipeit server..."
if "${DOCKER_BIN}" compose up -d 2>&1 | tee -a "${LOG_FILE}"; then
    log_info "snipeit server started successfully."
else
    log_error "Failed to start snipeit server."
    exit 1
fi

# ===== 定期バックアップ用のcron設定 =====
log_info "Setting cron..."
## cron 設定
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
CRON_TAG="snipeit_backup"
CRON_LINE="0 3 * * * PATH=/usr/bin:/bin ${BACKUP_SCRIPT} # ${CRON_TAG}"

## 既存crontab取得
log_info "Retrieving existing crontab..."
CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

## 既存登録があれば削除
log_info "Filtering existing cron entries..."
FILTERED_CRON="$(printf "%s\n" "${CURRENT_CRON}" | grep -v "${CRON_TAG}" || true)"

## 新規登録
if printf "%s\n%s\n" "${FILTERED_CRON}" "${CRON_LINE}" | crontab - 2>&1 | tee -a "${LOG_FILE}"; then
    log_info "Cron job registered successfully"
else
    log_error "Failed to register cron job."
    exit 1
fi

# ===== ログ終了 =====
log_info "===== Finished ${SCRIPT_NAME} (PID: $$) ====="