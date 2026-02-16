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

# ===== 終了処理 =====
log_info "Changing directory to ${BASE_DIR}"
cd "${BASE_DIR}"

log_info "Stop snipeit server..."
if "${DOCKER_BIN}" compose down 2>&1 | tee -a "${LOG_FILE}"; then
    log_info "snipeit server stopped successfully."
else
    log_error "Failed to stop snipeit server."
fi

# ===== コンテナ停止確認 =====
log_info "Waiting for all containers to be down..."
MAX_RETRIES=30
RETRY_COUNT=0
WAIT_INTERVAL=1

while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
    RUNNING_CONTAINERS=$("${DOCKER_BIN}" compose ps -q 2>/dev/null | wc -l)
    if [ "${RUNNING_CONTAINERS}" -eq 0 ]; then
        log_info "All containers are down."
        break
    fi
    log_info "Still waiting... (${RETRY_COUNT}/${MAX_RETRIES}) Running containers: ${RUNNING_CONTAINERS}"
    sleep ${WAIT_INTERVAL}
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]; then
    log_error "Timeout waiting for containers to stop. Current status:"
    "${DOCKER_BIN}" compose ps 2>&1 | tee -a "${LOG_FILE}"
fi

# ===== ログ終了 =====
log_info "===== Finished ${SCRIPT_NAME} (PID: $$) ====="
