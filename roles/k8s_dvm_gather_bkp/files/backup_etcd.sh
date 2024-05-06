#!/bin/bash
SCRIPT_LOG_DIR="/etcd_backups/logs"
MST01_BKP_DIR="/etcd_backups/MST01"
MST02_BKP_DIR="/etcd_backups/MST02"
MST03_BKP_DIR="/etcd_backups/MST03"
RETENTION_DAYS=14 
 
SCRIPT_LOG_FILE="$SCRIPT_LOG_DIR/copy-bkp-files-$(date +%F-%H-%M).log"
 
# check if log folder exist
if [ ! -d "$SCRIPT_LOG_DIR" ]; then
    echo "Creating directory $SCRIPT_LOG_DIR."
    mkdir -p "$SCRIPT_LOG_DIR"
fi
 
# check if mst01_subfolder exist
if [ ! -d "$MST01_BKP_DIR" ]; then
    echo "Creating directory $MST01_BKP_DIR."
    mkdir -p "$MST01_BKP_DIR"
fi
# check if mst02_subfolder exist
if [ ! -d "$MST02_BKP_DIR" ]; then
    echo "Creating directory $MST02_BKP_DIR."
    mkdir -p "$MST02_BKP_DIR"
fi
# check if mst03_subfolder exist
if [ ! -d "$MST03_BKP_DIR" ]; then
    echo "Creating directory $MST03_BKP_DIR."
    mkdir -p "$MST03_BKP_DIR"
fi
 
for h in {MST01,MST02,MST03};
  do
    echo "$(date +%F-%T): starting copy etcd_backup files from $h" >> $SCRIPT_LOG_FILE
    rsync -av $h:/etcd_backup/* /etcd_backups/$h >> $SCRIPT_LOG_FILE 2>&1
    echo "----------------------------------------------------------------------------" >> $SCRIPT_LOG_FILE
    find /etcd_backups/$h -name "etcd-backup-*.db.gz" -type f -mtime +$RETENTION_DAYS -delete
 
done