#!/bin/bash
set -euo pipefail

# ===== 固定パス定義 =====
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SCRIPT="$BASE_DIR/run_backup.sh"
LOG_FILE="$BASE_DIR/logs/run_backup.log"

# ===== cron 設定 =====
CRON_TAG="# snipe-it db backup"
CRON_LINE="0 3 * * * PATH=/usr/bin:/bin $BACKUP_SCRIPT >> $LOG_FILE 2>&1 $CRON_TAG"

# ===== 既存 crontab 取得 =====
CURRENT_CRON="$(crontab -l 2>/dev/null || true)"

# ===== 既存登録があれば削除 =====
FILTERED_CRON="$(printf "%s\n" "$CURRENT_CRON" | grep -v "$CRON_TAG" || true)"

# ===== 新規登録 =====
printf "%s\n%s\n" "$FILTERED_CRON" "$CRON_LINE" | crontab -

echo "cron registered:"
echo "$CRON_LINE"

# ===== ログファイルの容量制限 =====
MAX_LINES=1000
if [[ -f "$LOG_FILE" ]]; then
  tail -n "$MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
  mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
