#!/bin/bash
RETENTION_DAYS=14 # How many days to keep the backups.
CRON_SCHEDULE="0 2 * * *" #    #"0 2 * * *"  # Example: Run at 02:00 every day.
BACKUP_DIR="/etcd_backup/"
ETCD_ENDPOINTS="https://127.0.0.1:2379"
CA_CERT="/etc/kubernetes/pki/etcd/ca.crt"
SHORT_HOSTNAME=$(hostname)
CERT="/etc/kubernetes/pki/etcd/server.crt"
KEY="/etc/kubernetes/pki/etcd/server.key"
SCRIPT_PATH="$(realpath "$0")"
CRON_JOB="$CRON_SCHEDULE /bin/bash $SCRIPT_PATH"
 
if ! crontab -l | grep -q "$SCRIPT_PATH"; then
   (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cronjob added: $CRON_JOB"
fi
 
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creating directory $BACKUP_DIR."
    mkdir -p "$BACKUP_DIR"
    chown kuberadm: /etcd_backup
    chmod g+s /etcd_backup/
    
fi
 
BACKUP_FILE="$BACKUP_DIR/etcd-backup-$(date +%Y-%m-%d_%I:%M%p).db"
 
ETCDCTL_API=3 /usr/local/bin/etcdctl snapshot save $BACKUP_FILE \
  --endpoints=$ETCD_ENDPOINTS \
  --cacert=$CA_CERT \
  --cert=$CERT \
  --key=$KEY
 
chmod g+r $BACKUP_FILE
gzip $BACKUP_FILE
find $BACKUP_DIR -name "etcd-backup-*.db.gz" -type f -mtime +$RETENTION_DAYS -delete