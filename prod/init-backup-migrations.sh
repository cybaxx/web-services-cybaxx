#!/usr/bin/env bash

set -euo pipefail

# Default Values
SERVICE_DIR="./services"
DUMP_DIR="/opt/wetfish-data-dumps/in"
OUT_DIR="/opt/wetfish-data-dumps/out"
PROD_SERVER="old-prod"
ZFS_POOL="your_zfs_pool"
ZFS_SNAPSHOT_DIR="/web-services-cybaxx"
SRC_DIR="./services"
DEST_DIR="$OUT_DIR"
LOG_FILE="/var/log/script.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Logging function
log_message() {
  echo "$TIMESTAMP: $1" | tee -a "$LOG_FILE"
}

# Function to request user permission
ask_permission() {
  log_message "Asking for permission to proceed."
  read -p "Did you get permission to run the prod service? (yes/no): " user_response
  if [[ "$user_response" != "yes" ]]; then
    log_message "Permission denied by user. Exiting."
    exit 1
  fi
}

# Function to close outgoing ports 443 and 80
close_outgoing_ports() {
  log_message "Closing outgoing ports 443 and 80."
  sudo ufw deny out 443/tcp
  sudo ufw deny out 80/tcp
}

# Function to create ZFS snapshot
create_zfs_snapshot() {
  local snapshot_name="web-services-cybaxx@snapshot-$(date "+%Y-%m-%d_%H-%M-%S")"
  log_message "Creating ZFS snapshot: $snapshot_name."
  zfs snapshot "$ZFS_POOL$ZFS_SNAPSHOT_DIR@$snapshot_name" || { log_message "Error creating ZFS snapshot."; exit 1; }
}

# Function to backup MariaDB databases
backup_databases() {
  log_message "Starting database backup process."

  for service_dir in "$SRC_DIR"/*; do
    if [ -d "$service_dir" ]; then
      local service_name=$(basename "$service_dir")
      local env_file="$service_dir/mariadb.env"

      if [ -f "$env_file" ]; then
        local mariadb_password=$(grep -E '^MARIADB_ROOT_PASSWORD=' "$env_file" | cut -d '=' -f2)
        if [ -z "$mariadb_password" ]; then
          log_message "No MariaDB root password found for $service_name. Skipping backup."
          continue
        fi

        local container_name="${service_name}-db"
        if docker ps -q -f name="$container_name" >/dev/null; then
          local dump_filename="$DUMP_DIR/${service_name}-backup-$(date +%Y-%m-%d).sql"
          log_message "Backing up database for $service_name to $dump_filename."
          docker exec "$container_name" mysqldump -u root --password="$mariadb_password" "$service_name" > "$dump_filename" || { log_message "Failed to back up database for $service_name."; continue; }
          log_message "Backup for $service_name completed."
        else
          log_message "Container for $service_name is not running. Skipping backup."
        fi
      else
        log_message "No mariadb.env file found for $service_name. Skipping backup."
      fi
    fi
  done
}

# Function to apply backup on production server
apply_backup_on_prod() {
  log_message "Starting restore process on $PROD_SERVER."

  for dump_file in "$DUMP_DIR"/*.sql; do
    if [ -f "$dump_file" ]; then
      local service_name=$(basename "$dump_file" | cut -d '-' -f1)
      local container_name="${service_name}-db"
      log_message "Restoring database for $service_name from $dump_file."

      if ssh "$PROD_SERVER" "docker ps -q -f name=$container_name" >/dev/null; then
        ssh "$PROD_SERVER" "docker exec -i $container_name mysql -u root --password=<your_root_password> $service_name < $dump_file" || { log_message "Failed to restore $service_name on $PROD_SERVER."; continue; }
        log_message "Backup restored for $service_name on $PROD_SERVER."
      else
        log_message "Container for $service_name is not running on $PROD_SERVER. Skipping restore."
      fi
    fi
  done
}

# Function to fetch SSH keys from old-prod to new-prod
fetch_ssh_keys() {
  log_message "Fetching SSH keys from $PROD_SERVER."
  ssh-copy-id -i ~/.ssh/id_rsa.pub "$PROD_SERVER" || { log_message "Failed to fetch SSH keys."; exit 1; }
  log_message "SSH keys successfully copied to $PROD_SERVER."
}

# Function to parse command line arguments
parse_args() {
  while getopts "s:d:p:" opt; do
    case "$opt" in
      s) SRC_DIR="$OPTARG" ;;
      d) DEST_DIR="$OPTARG" ;;
      p) PROD_SERVER="$OPTARG" ;;
      *) echo "Usage: $0 [-s src_directory] [-d dest_directory] [-p prod_server]"; exit 1 ;;
    esac
  done
}

# Main script execution
main() {
  ask_permission
  parse_args "$@"
  close_outgoing_ports

  if [ ! -d "$DUMP_DIR" ]; then
    log_message "Error: Directory $DUMP_DIR does not exist. Exiting."
    exit 1
  fi

  fetch_ssh_keys
  create_zfs_snapshot
  backup_databases

  log_message "Rsyncing backups to $PROD_SERVER:$DEST_DIR."
  rsync -avz "$DUMP_DIR/" "$PROD_SERVER:$DEST_DIR/" || { log_message "Error during rsync."; exit 1; }

  apply_backup_on_prod
  log_message "Backup process completed successfully."
}

main "$@"
