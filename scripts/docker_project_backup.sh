#!/bin/bash
set -euo pipefail

# root チェック
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: docker_project_backup.sh must be run as root."
  exit 1
fi

set -e

echo "docker_project_backup.sh running as root"

### 設定 ###
WIN_SERVER="192.168.2.6"
WIN_SHARE="densan"
MOUNT_POINT="/mnt/rjserver"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/"
DST_DIR="${MOUNT_POINT}/docker/snipeit/"

CRED_FILE="/root/.smbcredentials"
LOG_FILE="$SRC_DIR/scripts/logs/docker_project_backup.log"

### ログ開始 ###
echo "==== $(date '+%Y-%m-%d %H:%M:%S') START ====" >> "$LOG_FILE"

### .env読み込み ###
ENV_FILE="$SRC_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
	echo "ERROR: .env file not found: $ENV_FILE" >> "$LOG_FILE" 2>&1
	exit 1
fi

set -a
source "$ENV_FILE"
set +a

### マウントポイント作成 ###
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

### マウント ###
if ! mountpoint -q "$MOUNT_POINT"; then
    mount -t cifs "//${WIN_SERVER}/${WIN_SHARE}" "$MOUNT_POINT" \
        -o credentials="$CRED_FILE",iocharset=utf8,vers=3.0 >> "$LOG_FILE" 2>&1
fi

### rsync 実行 ###
rsync -av --delete --exclude='*/.git/'\
    "$SRC_DIR" \
    "$DST_DIR" >> "$LOG_FILE" 2>&1

### アンマウント ###
umount "$MOUNT_POINT"

### ログファイルの容量制限 ###
echo "$(date '+%Y-%m-%d %H:%M:%S'): ログファイルの容量制限開始" >> "$LOG_FILE"
MAX_LINES=10000
if [[ -f "$LOG_FILE" ]]; then
  tail -n "$MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
  mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
echo "$(date '+%Y-%m-%d %H:%M:%S'): ログファイルの容量制限完了" >> "$LOG_FILE"

echo "==== $(date '+%Y-%m-%d %H:%M:%S') END ====" >> "$LOG_FILE"
