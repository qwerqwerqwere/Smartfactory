#!/bin/bash

# 설정
REMOTE_USER="root"                                 # 원격 서버 사용자
REMOTE_HOST="121.189.56.244"                       # 원격 서버 IP
REMOTE_PORT="3022"                                 # SSH 포트
REMOTE_DIR="~/projects/mariadb_backup"             # 원격 서버 백업 디렉토리
LOCAL_BACKUP_DIR="/data/mariadb_db-mariadb/_data/testVM" # 로컬 백업 디렉토리
DB_CONTAINER="db-mariadb"                          # MariaDB 컨테이너 이름

# 로컬 백업 디렉토리 생성 (없으면 생성)
mkdir -p "$LOCAL_BACKUP_DIR"

# 244 서버에서 최신 백업 파일 찾기
echo "Fetching latest backup from $REMOTE_HOST:$REMOTE_DIR..."
LATEST_REMOTE_BACKUP=$(ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "ls -t $REMOTE_DIR/*.sql 2>/dev/null | head -n 1")
if [ -z "$LATEST_REMOTE_BACKUP" ]; then
    echo "No backup file found on remote server in $REMOTE_DIR"
    exit 1
fi

# 최신 파일을 로컬로 복사
echo "Copying $LATEST_REMOTE_BACKUP to $LOCAL_BACKUP_DIR..."
sshpass -p "bigdatalab!234" scp -P $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST:"$LATEST_REMOTE_BACKUP" "$LOCAL_BACKUP_DIR"
if [ $? -ne 0 ]; then
    echo "Failed to fetch backup file from remote server!"
    exit 1
fi

# 로컬에 복사된 백업 파일 경로 설정
LATEST_LOCAL_BACKUP=$(ls -t "$LOCAL_BACKUP_DIR"/*.sql 2>/dev/null | head -n 1)

# 복원 실행
if [ -z "$LATEST_LOCAL_BACKUP" ]; then
    echo "No backup file found in $LOCAL_BACKUP_DIR after fetching from remote server"
    exit 1
fi

echo "Restoring from backup: $LATEST_LOCAL_BACKUP"
docker exec -i "$DB_CONTAINER" mariadb -u root -p'rootsecretpassword' < "$LATEST_LOCAL_BACKUP"

# 결과 확인
if [ $? -eq 0 ]; then
    echo "Restore completed successfully!"

    # 복원이 완료되면 로컬 파일 삭제
    echo "Deleting local backup file: $LATEST_LOCAL_BACKUP"
    rm -f "$LATEST_LOCAL_BACKUP"
    if [ $? -eq 0 ]; then
        echo "Local backup file deleted successfully."
    else
        echo "Failed to delete local backup file!"
    fi
else
    echo "Restore failed!"
    exit 1
fi