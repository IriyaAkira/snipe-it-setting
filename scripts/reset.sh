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
log_info "Execute the stop script"
if bash "${SCRIPT_DIR}/stop.sh"; then
    log_info "Stop script completed successfully."
else
    log_error "Stop script failed."
    exit 1
fi

# ===== docker ボリューム、イメージ、コンテナの削除 =====
log_info "Delete Docker volumes, images, and containers"
cd "${BASE_DIR}"
if "${DOCKER_BIN}" compose down -v --rmi all 2>&1 | tee -a "${LOG_FILE}"; then
    log_info "Docker resources deleted successfully."
else
    log_error "Failed to delete Docker resources."
    exit 1
fi

# ===== 再スタート処理 =====
log_info "Execute the start script"
if bash "${SCRIPT_DIR}/start.sh"; then
    log_info "Start script completed successfully."
else
    log_error "Start script failed."
    exit 1
fi

# ===== ログ終了 =====
log_info "===== Finished ${SCRIPT_NAME} (PID: $$) ====="
