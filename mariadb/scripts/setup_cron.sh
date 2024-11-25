#!/bin/bash

# 백업 스크립트 경로
SCRIPT_PATH="/root/projects/Rabbitmq-Grafana/mariadb/scripts/mariadb_backup.sh"

# 크론탭 작업 설정
CRON_JOB="0 0 * * * $SCRIPT_PATH >> /root/projects/Rabbitmq-Grafana/mariadb/scripts/backup.log 2>&1"

# 크론탭에 추가 (중복되지 않도록 설정)
(crontab -l 2>/dev/null | grep -F "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Crontab job added successfully."
