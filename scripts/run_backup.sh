#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==== $(date '+%Y-%m-%d %H:%M:%S') START ===="

echo "[1/2] db_backup.sh 実行開始"
"$BASE_DIR/db_backup.sh"
echo "[1/2] db_backup.sh 完了"

echo "[2/2] docker_project_backup.sh 実行開始"
sudo "$BASE_DIR/docker_project_backup.sh"
echo "[2/2] docker_project_backup.sh 完了"

echo "==== $(date '+%Y-%m-%d %H:%M:%S') END ===="

