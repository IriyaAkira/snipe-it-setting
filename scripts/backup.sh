#!/bin/bash
set -eu

# ===== 固定パス定義 =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_BIN="/usr/bin/docker"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
LOG_DIR="$(cd "${SCRIPT_DIR}/logs" && pwd)"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.*}.log"

# ===== root チェック =====
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ${SCRIPT_NAME} must be run as root."
  exit 1
fi
echo "${SCRIPT_NAME} running as root"

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

# ===== .env読み込み =====
log_info "Load env file"
ENV_FILE="${BASE_DIR}/.env"
set -a
. "${ENV_FILE}"
set +a

# ===== DBバックアップ =====
BACKUP_FILE="${BASE_DIR}/db_init/db_dump_cron.sql"
log_info "start creating db dump..."
cd "$BASE_DIR"

"$DOCKER_BIN" compose exec -T db \
  mariadb-dump \
    -u"$DB_USERNAME" \
    -p"$DB_PASSWORD" \
    "$DB_DATABASE" \
  > "$BACKUP_FILE"

log_info "db dump created successfully."

# ===== プロジェクトバックアップ =====
log_info "Starting project backup."
# 終了処理
log_info "Execute the stop script"
if bash "${SCRIPT_DIR}/stop.sh"; then
    log_info "Stop script completed successfully."
else
    log_error "Stop script failed."
    exit 1
fi

# .smbcredentialsファイルの存在チェック
log_info "Check for the existance of the .smbcredentials file."
CRED_FILE="/root/.smbcredentials"
if [ ! -f "${CRED_FILE}" ]; then
    log_error "A backup of the project cannot be created because the relevant file is not found."
    log_error "file: ${CRED_FILE}"
    exit 1
fi

# バックアップ先のマウント
log_info "Mount file server."
MOUNT_POINT="/mnt/docker_backup"
if [ ! -d "${MOUNT_POINT}" ]; then
    mkdir -p "${MOUNT_POINT}"
fi

if ! mountpoint -q "${MOUNT_POINT}"; then
    if mount -t cifs "//${BK_SERVER}/${BK_SHARE}" "${MOUNT_POINT}" \
        -o credentials="${CRED_FILE}",iocharset=utf8,vers=3.0 \
        2>&1 | tee -a "${LOG_FILE}"; then
        log_info "File server mounted successfully."
    else
        log_error "Failed to mount file server."
    fi
fi

# バックアップ
log_info "Execute backup"
SRC_DIR="${BASE_DIR}/"
DST_DIR="${MOUNT_POINT}/docker/$(basename "${BASE_DIR}")/"
rsync -av --delete --exclude='*/.git/'\
    "${SRC_DIR}" \
    "${DST_DIR}" \
    2>&1 | tee -a "${LOG_FILE}"

# バックアップ先のアンマウント
log_info "Unmount file server."
if umount "${MOUNT_POINT}" 2>&1 | tee -a "${LOG_FILE}"; then
    log_info "File server unmounted successfully."
else
    log_error "Failed to unmount file server. Continuing..."
fi

# 再スタート処理
log_info "Execute the start script"
if bash "${SCRIPT_DIR}/start.sh"; then
    log_info "Start script completed successfully."
else
    log_error "Start script failed."
    exit 1
fi

# ===== ログ終了 =====
log_info "===== Finished ${SCRIPT_NAME} (PID: $$) ====="
