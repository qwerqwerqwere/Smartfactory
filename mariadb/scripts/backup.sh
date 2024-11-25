#!/bin/bash

# MariaDB 컨테이너 설정
CONTAINER_NAME="db-mariadb"                        # MariaDB 컨테이너 이름
DATE=$(date +"%Y%m%d_%H%M%S")                      # 날짜/시간 포맷
BACKUP_DIR="/data/mariadb_db-mariadb/_data/testVM" # 로컬 백업 파일 저장 디렉토리
BACKUP_FILE="$BACKUP_DIR/mariadb_backup_$DATE.sql" # 생성될 백업 파일 경로
ARCHIVE_FILE="$BACKUP_DIR/mariadb_backup_$DATE.tar.gz" # 압축된 백업 파일 경로

# 원격 서버 설정
REMOTE_USER="root"                                 # 원격 서버 사용자
REMOTE_HOST="121.189.56.244"                       # 원격 서버 IP
REMOTE_PORT="3022"                                 # SSH 포트
REMOTE_DIR="~/projects/mariadb_backup"             # 원격 서버의 저장 디렉토리
REMOTE_PASS="bigdatalab!234"                       # 원격 서버 비밀번호

# 이메일 설정
EMAIL_TO="hyunwoo50@cbnu.ac.kr"
EMAIL_SUBJECT_SUCCESS="MariaDB Backup Successful: $DATE"
EMAIL_SUBJECT_FAIL="MariaDB Backup Failed: $DATE"
EMAIL_BODY_SUCCESS="MariaDB backup completed successfully.\n\nBackup file: $ARCHIVE_FILE\nTransferred to: $REMOTE_HOST:$REMOTE_DIR"
EMAIL_BODY_FAIL="MariaDB backup failed. Please check the logs for more details."

# 백업 디렉토리 생성 (없으면 생성)
mkdir -p $BACKUP_DIR

# MariaDB 백업 실행
docker exec $CONTAINER_NAME mariadb-dump -u root -p'rootsecretpassword' --databases appwrite > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Local backup completed: $BACKUP_FILE"

    # 백업 파일 압축
    echo "Compressing backup file..."
    tar -czf $ARCHIVE_FILE -C $BACKUP_DIR $(basename $BACKUP_FILE)
    if [ $? -eq 0 ]; then
        echo "Backup file compressed: $ARCHIVE_FILE"
    else
        echo "Failed to compress backup file!"
        exit 1
    fi

    # sshpass를 사용하여 압축 파일을 원격 서버로 전송
    sshpass -p "$REMOTE_PASS" scp -P $REMOTE_PORT $ARCHIVE_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR
    if [ $? -eq 0 ]; then
        echo "Compressed backup successfully transferred to $REMOTE_HOST:$REMOTE_DIR"

        # 원격 서버에서 30일 지난 파일 삭제
        echo "Deleting old backups on remote server..."
        sshpass -p "$REMOTE_PASS" ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "find $REMOTE_DIR -type f -name '*.tar.gz' -mtime +30 -exec rm -f {} \;"
        if [ $? -eq 0 ]; then
            echo "Old backups deleted successfully from $REMOTE_HOST:$REMOTE_DIR"
        else
            echo "Failed to delete old backups on remote server!"
        fi

        # 로컬 디렉토리에서 30일 지난 파일 삭제
        echo "Deleting old backups in local directory..."
        find $BACKUP_DIR -type f -name '*.tar.gz' -mtime +30 -exec rm -f {} \;
        if [ $? -eq 0 ]; then
            echo "Old backups deleted successfully from $BACKUP_DIR"
        else
            echo "Failed to delete old backups in local directory!"
        fi

        # 성공 이메일 발송
        docker exec $CONTAINER_NAME sh -c "echo -e \"$EMAIL_BODY_SUCCESS\" | mail -s \"$EMAIL_SUBJECT_SUCCESS\" $EMAIL_TO"
    else
        echo "Failed to transfer compressed backup to remote server!"
        docker exec $CONTAINER_NAME sh -c "echo -e \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
        exit 2
    fi

    # 로컬 원본 및 압축 백업 파일 삭제
    echo "Deleting local backup file: $BACKUP_FILE"
    rm -f $BACKUP_FILE
else
    echo "Backup failed!"
    docker exec $CONTAINER_NAME sh -c "echo -e \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi
