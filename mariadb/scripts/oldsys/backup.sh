#!/bin/bash

# 설정
BACKUP_DIR="/data/mariadb_db-mariadb/_data/testVM" # 백업 파일 저장 디렉토리
CONTAINER_NAME="db-mariadb" # MariaDB 컨테이너 이름
DATE=$(date +"%Y%m%d_%H%M%S") # 날짜/시간 포맷
BACKUP_FILE="$BACKUP_DIR/mariadb_backup_$DATE.sql" # 생성될 백업 파일 경로

# 디렉토리 생성 (없으면 생성)
mkdir -p $BACKUP_DIR

# 백업 실행
docker exec $CONTAINER_NAME mariadb-dump -u root -p'rootsecretpassword' --databases appwrite > $BACKUP_FILE

# 성공 메시지 출력
if [ $? -eq 0 ]; then
    echo "Backup completed: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi

