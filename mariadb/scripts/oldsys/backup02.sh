#!/bin/bash

# MariaDB 컨테이너 설정
CONTAINER_NAME="db-mariadb"                        # MariaDB 컨테이너 이름
DATE=$(date +"%Y%m%d_%H%M%S")                      # 날짜/시간 포맷
BACKUP_DIR="/data/mariadb_db-mariadb/_data/testVM" # 로컬 백업 파일 저장 디렉토리
BACKUP_FILE="$BACKUP_DIR/mariadb_backup_$DATE.sql" # 생성될 백업 파일 경로

# 원격 서버 설정
REMOTE_USER="root"                                 # 원격 서버 사용자
REMOTE_HOST="121.189.56.244"                       # 원격 서버 IP
REMOTE_PORT="3022"                                 # SSH 포트
REMOTE_DIR="~/projects/mariadb_backup"             # 원격 서버의 저장 디렉토리
REMOTE_PASS="bigdatalab!234"                       # 원격 서버 비밀번호

# Gmail 설정
#EMAIL_SUBJECT="MariaDB Backup Status"
#EMAIL_TO="hyunwoo50@cbnu.ac.kr"
#EMAIL_BODY="Backup completed successfully: $BACKUP_FILE"

# 백업 디렉토리 생성 (없으면 생성)
mkdir -p $BACKUP_DIR

# MariaDB 백업 실행
docker exec $CONTAINER_NAME mariadb-dump -u root -p'rootsecretpassword' --databases appwrite > $BACKUP_FILE

# 성공 메시지 출력 및 원격 전송
if [ $? -eq 0 ]; then
    echo "Local backup completed: $BACKUP_FILE"

    # sshpass를 사용하여 백업 파일을 원격 서버로 전송
    sshpass -p "$REMOTE_PASS" scp -P $REMOTE_PORT $BACKUP_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR
    if [ $? -eq 0 ]; then
        echo "Backup successfully transferred to $REMOTE_HOST:$REMOTE_DIR"

        # 30일 지난 파일 삭제 (원격 서버)
        sshpass -p "$REMOTE_PASS" ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "find $REMOTE_DIR -type f -name '*.sql' -mtime +3 -exec rm -f {} \;"
        if [ $? -eq 0 ]; then
            echo "Old backups successfully deleted from $REMOTE_HOST:$REMOTE_DIR"
        else
            echo "Failed to delete old backups on remote server!"
        fi
    else
        echo "Failed to transfer backup to remote server!"
        exit 2
    fi

    # 로컬 백업 파일 삭제
    echo "Deleting local backup file: $BACKUP_FILE"
    rm -f $BACKUP_FILE
    if [ $? -eq 0 ]; then
        echo "Local backup file deleted successfully."
    else
        echo "Failed to delete local backup file!"
    fi
else
    echo "Backup failed!"
    exit 1
fi
