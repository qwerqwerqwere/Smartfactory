#!/bin/bash

# 설정
REMOTE_USER="root"                                 # 원격 서버 사용자
REMOTE_HOST="121.189.56.244"                       # 원격 서버 IP
REMOTE_PORT="3022"                                 # SSH 포트
REMOTE_DIR="~/projects/mariadb_backup"             # 원격 서버 백업 디렉토리
LOCAL_BACKUP_DIR="/data/mariadb_db-mariadb/_data/testVM" # 로컬 백업 디렉토리
DB_CONTAINER="db-mariadb"                          # MariaDB 컨테이너 이름
DB_PASSWORD="rootsecretpassword"                  # MariaDB root 비밀번호

# 이메일 설정
EMAIL_TO="hyunwoo50@cbnu.ac.kr"
EMAIL_SUBJECT_SUCCESS="MariaDB Restore Successful"
EMAIL_SUBJECT_FAIL="MariaDB Restore Failed"
EMAIL_BODY_SUCCESS="MariaDB restore completed successfully from the latest backup."
EMAIL_BODY_FAIL="MariaDB restore failed. Please check the logs for more details."

# 로컬 백업 디렉토리 생성 (없으면 생성)
mkdir -p "$LOCAL_BACKUP_DIR"

# 244 서버에서 최신 압축된 백업 파일 찾기
echo "Fetching latest backup from $REMOTE_HOST:$REMOTE_DIR..."
LATEST_REMOTE_BACKUP=$(ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST "ls -t $REMOTE_DIR/*.tar.gz 2>/dev/null | head -n 1")
if [ -z "$LATEST_REMOTE_BACKUP" ]; then
    echo "No backup file found on remote server in $REMOTE_DIR"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi

# 최신 압축 파일을 로컬로 복사
echo "Copying $LATEST_REMOTE_BACKUP to $LOCAL_BACKUP_DIR..."
sshpass -p "bigdatalab!234" scp -P $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST:"$LATEST_REMOTE_BACKUP" "$LOCAL_BACKUP_DIR"
if [ $? -ne 0 ]; then
    echo "Failed to fetch backup file from remote server!"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi

# 로컬에 복사된 압축 백업 파일 경로 설정
LATEST_LOCAL_BACKUP=$(ls -t "$LOCAL_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)

# 압축 해제
if [ -z "$LATEST_LOCAL_BACKUP" ]; then
    echo "No backup file found in $LOCAL_BACKUP_DIR after fetching from remote server"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi

echo "Extracting backup file: $LATEST_LOCAL_BACKUP"
tar -xzf "$LATEST_LOCAL_BACKUP" -C "$LOCAL_BACKUP_DIR"
if [ $? -ne 0 ]; then
    echo "Failed to extract backup file!"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi

# 압축 해제된 SQL 파일 경로 설정
EXTRACTED_SQL_FILE=$(ls -t "$LOCAL_BACKUP_DIR"/*.sql 2>/dev/null | head -n 1)

# 복원 실행
if [ -z "$EXTRACTED_SQL_FILE" ]; then
    echo "No extracted SQL file found in $LOCAL_BACKUP_DIR"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi

echo "Restoring from backup: $EXTRACTED_SQL_FILE"
docker exec -i "$DB_CONTAINER" mariadb -u root -p"$DB_PASSWORD" < "$EXTRACTED_SQL_FILE"

# 결과 확인
if [ $? -eq 0 ]; then
    echo "Restore completed successfully!"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_SUCCESS\" | mail -s \"$EMAIL_SUBJECT_SUCCESS\" $EMAIL_TO"

    # 복원이 완료되면 로컬 파일 삭제
    echo "Deleting local backup files: $LATEST_LOCAL_BACKUP and $EXTRACTED_SQL_FILE"
    rm -f "$LATEST_LOCAL_BACKUP" "$EXTRACTED_SQL_FILE"
    if [ $? -eq 0 ]; then
        echo "Local backup files deleted successfully."
    else
        echo "Failed to delete local backup files!"
    fi
else
    echo "Restore failed!"
    docker exec "$DB_CONTAINER" sh -c "echo \"$EMAIL_BODY_FAIL\" | mail -s \"$EMAIL_SUBJECT_FAIL\" $EMAIL_TO"
    exit 1
fi

