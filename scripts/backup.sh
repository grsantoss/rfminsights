#!/bin/bash
# RFM Insights - Database Backup Script

# Set variables from environment or use defaults
PG_HOST=${POSTGRES_HOST:-postgres}
PG_USER=${POSTGRES_USER:-rfminsights}
PG_PASSWORD=${POSTGRES_PASSWORD:-rfminsights_password}
PG_DB=${POSTGRES_DB:-rfminsights}
BACKUP_DIR=${BACKUP_DIR:-/backups}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Set timestamp for backup file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${PG_DB}_${TIMESTAMP}.sql.gz"

# Log start of backup
echo "[$(date)] Starting backup of database $PG_DB to $BACKUP_FILE"

# Perform backup
PGPASSWORD=$PG_PASSWORD pg_dump -h $PG_HOST -U $PG_USER $PG_DB | gzip > $BACKUP_FILE

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "[$(date)] Backup completed successfully: $BACKUP_FILE"
    echo "[$(date)] Backup size: $(du -h $BACKUP_FILE | cut -f1)"
    
    # Create a symlink to the latest backup
    ln -sf $BACKUP_FILE ${BACKUP_DIR}/latest.sql.gz
    
    # Delete old backups
    echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days"
    find $BACKUP_DIR -name "${PG_DB}_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    # List remaining backups
    BACKUP_COUNT=$(find $BACKUP_DIR -name "${PG_DB}_*.sql.gz" | wc -l)
    echo "[$(date)] Current backup count: $BACKUP_COUNT"
    
    # Create backup report
    echo "Backup Report - $(date)" > ${BACKUP_DIR}/backup_report.txt
    echo "Database: $PG_DB" >> ${BACKUP_DIR}/backup_report.txt
    echo "Latest Backup: $BACKUP_FILE" >> ${BACKUP_DIR}/backup_report.txt
    echo "Backup Size: $(du -h $BACKUP_FILE | cut -f1)" >> ${BACKUP_DIR}/backup_report.txt
    echo "Total Backups: $BACKUP_COUNT" >> ${BACKUP_DIR}/backup_report.txt
    
    exit 0
else
    echo "[$(date)] Backup failed with error code $?"
    exit 1
fi