#!/bin/bash
set -eu

# ===== 固定パス定義 =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
LOG_DIR="$(cd "${SCRIPT_DIR}/logs" && pwd)"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.*}.log"

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

# ===== 自己署名証明書作成 =====
OUT_DIR="$(cd "${BASE_DIR}/nginx/certs" && pwd)"
CERT_NAME="dummy"
mkdir -p "${OUT_DIR}"

openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 \
  -keyout "${OUT_DIR}/${CERT_NAME}.key" \
  -out "${OUT_DIR}/${CERT_NAME}.crt" \
  -subj "/C=JP/ST=Dummy/L=Dummy/O=Dummy/OU=Dummy/CN=dummy"

chmod 600 "${OUT_DIR}/${CERT_NAME}.key"
chmod 644 "${OUT_DIR}/${CERT_NAME}.crt"

# ===== ログ終了 =====
log_info "===== Finished ${SCRIPT_NAME} (PID: $$) ====="
