#!/bin/bash

set -euo pipefail

# Get current timestamp
timestamp=$(date +%Y-%m-%d)
backup_dir="${timestamp}-service-backups"
mkdir -p "$backup_dir"

# Determine script directory and service directory root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_ROOT="$(realpath "$SCRIPT_DIR/../prod/services")"

# Utility: Load a single variable from an .env file
load_var_from_env() {
  local file="$1"
  local key="$2"
  grep -E "^${key}=" "$file" | cut -d '=' -f2- | tr -d '"' | tr -d "'"
}

# Define services and their container names
declare -a services=(
  "wiki wiki-db"
  "online online-db"
  "danger danger-db"
  "click click-db"
)

# Backup loop
for entry in "${services[@]}"; do
  IFS=' ' read -r service_name container <<< "$entry"

  env_file="${SERVICES_ROOT}/${service_name}/mariadb.env"

  if [[ ! -f "$env_file" ]]; then
    echo "⚠️  Warning: Env file for $service_name not found at $env_file. Skipping..."
    continue
  fi

  echo "🔍 Reading secrets for $service_name..."

  db_name=$(load_var_from_env "$env_file" "MARIADB_DATABASE")
  root_password=$(load_var_from_env "$env_file" "MARIADB_ROOT_PASSWORD")

  if [[ -z "$db_name" || -z "$root_password" ]]; then
    echo "❌ Error: Missing database name or root password in $env_file. Skipping..."
    continue
  fi

  echo "📦 Backing up $db_name from $container..."

  backup_filename="${service_name}-backup-${timestamp}.sql"

  docker exec "$container" mysqldump -u root --password="$root_password" "$db_name" > "$backup_dir/$backup_filename"

  # Cleanup sensitive vars
  unset db_name
  unset root_password
done

# Archive and transfer
tar -czf "${backup_dir}.tar.gz" "$backup_dir"
scp "${backup_dir}.tar.gz" root@149.28.239.165:/mnt/

echo "✅ All backups completed and archived as ${backup_dir}.tar.gz"
