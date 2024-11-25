#!/bin/bash

# 설정
BACKUP_FILE="/data/mariadb-db-mariadb/_data/testVM/latest.sql" # 복구할 백업 파일 경로
CONTAINER_NAME="db-mariadb" # MariaDB 컨테이너 이름

# 복구 실행
if [ -f "$BACKUP_FILE" ]; then
    docker exec -i $CONTAINER_NAME mysql -u root -p'rootsecretpassword' appwrite < $BACKUP_FILE
    if [ $? -eq 0 ]; then
        echo "Restore completed from $BACKUP_FILE"
    else
        echo "Restore failed!"
        exit 1
    fi
else
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

