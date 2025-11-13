#!/bin/bash

# Run this command once manually (outside the script) to create and set log file ownership:
# sudo touch /var/log/backupSZPV.log && sudo chown netrika_ka /var/log/backupSZPV.log

# For Server ClickHouse
## sudo mkdir /data/Backups_db_szpv && sudo chown -R netrika_ka /data/Backups_db_szpv && ln -s /data/Backups_db_szpv ~/Backups_db_szpv

# Create SSH key
## ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "netrika_ka" && chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub && ssh-copy-id -i ~/.ssh/id_ed25519.pub netrika_ka@172.16.8.56

# Create file for logs
sudo touch /var/log/backupSZPV.log && sudo chown netrika_ka /var/log/backupSZPV.log

# Directories for backup files and script storage
BACKUP_DIR="/data/backupDB"
SCRIPT_DIR="/data/backupDB"
SCRIPT_NAME="backupDB.sh"
REMOTE_USER="netrika_ka"
REMOTE_HOST="10.0.10.168"
REMOTE_DIR="Backups_db_szpv"
SSH_KEY="/home/netrika_ka/.ssh/id_ed25519"
DATE=$(date +'%Y-%m-%d')
LOG_FILE="/var/log/backupSZPV.log"

# Full paths for current script and where to copy
CURRENT_SCRIPT_PATH=$(readlink -f "$0")
DEST_SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"

# Create backup and script directories if they don't exist (should be owned by netrika_ka)
sudo mkdir -p "$BACKUP_DIR"
sudo mkdir -p "$SCRIPT_DIR"
sudo chown -R netrika_ka:netrika_ka $BACKUP_DIR
sudo chmod 755 $BACKUP_DIR

# Create log file if it doesn't exist and set permissions (if not done manually)
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Remove backups older than 3 days
find "$BACKUP_DIR" -name '*.backup' -type f -mtime +3 -exec rm -f {} \;

# Copy current script to script directory and set execute permission
cp -f "$CURRENT_SCRIPT_PATH" "$DEST_SCRIPT_PATH"
chmod +x "$DEST_SCRIPT_PATH"

# Add cron job if it doesn't exist
CRON_COMMENT="# Daily backup script $SCRIPT_NAME"
CRON_JOB="0 2 * * * $DEST_SCRIPT_PATH"

if ! crontab -l 2>/dev/null | grep -Fq "$CRON_JOB"; then
  (crontab -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$CRON_JOB") | crontab -
else
  echo "Cron job already exists, not adding."
fi

# Get all non-template PostgreSQL databases
DBS=$(psql -U postgres -Atc "SELECT datname FROM pg_database WHERE datistemplate = false;")

# Patterns of databases to backup
patterns=("hub_" "routing_" "newhub" "book" "ah" "prostore")

# Backup matching databases and copy backups to remote server using the SSH key
for db in $DBS; do
  for pattern in "${patterns[@]}"; do
    if [[ $db == $pattern* ]]; then
      echo "Backing up $db"
      backup_file="$BACKUP_DIR/${db}_${DATE}.backup"
      rm -f "$backup_file"
      /usr/bin/pg_dump -U postgres -F c -f "$backup_file" "$db" >> "$LOG_FILE" 2>&1
      if [ $? -eq 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Backup of $db successful: $backup_file" >> "$LOG_FILE"
        echo "Backup of $db successful, attempting to copy to remote server..."
        scp -i "$SSH_KEY" "$backup_file" "$REMOTE_USER@$REMOTE_HOST:/home/netrika_ka/$REMOTE_DIR/$(basename "$backup_file")" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
          echo "$(date +'%Y-%m-%d %H:%M:%S') - Successfully copied $backup_file to remote server." >> "$LOG_FILE"
        else
          echo "$(date +'%Y-%m-%d %H:%M:%S') - Warning: Failed to copy backup $backup_file to remote server." >> "$LOG_FILE"
          echo "Warning: Failed to copy backup $backup_file to remote server. Local backup retained."
        fi
      else
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Error: Backup of $db failed, skipping copy. See above for pg_dump error." >> "$LOG_FILE"
        echo "Error: Backup of $db failed, skipping copy."
        rm -f "$backup_file"
      fi
    fi
  done
done

ls -l $BACKUP_DIR/
cat /var/log/backupSZPV.log
