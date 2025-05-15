#!/bin/bash

set -euo pipefail

# Get current timestamp
timestamp=$(date +%Y-%m-%d)
backup_dir="${timestamp}-service-backups"
mkdir -p "$backup_dir"

# Define services and their container names
declare -a services=(
  "wiki wiki-db"
  "online online-db"
  "danger danger-db"
  "click click-db"
)

# Define root directory for services
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_ROOT="$(realpath "$SCRIPT_DIR/../prod/services")"

# Utility: Load a single variable from an .env file dynamically
load_var_from_env() {
  local file="$1"
  local key="$2"
  grep -E "^${key}=" "$file" | cut -d '=' -f2- | tr -d '"' | tr -d "'"
}

# Generate random passwords for services dynamically (from `init-services.sh`)
export_secrets() {
  export ENV_TAG="stage"

  if [[ ${#SERVICE_ITEMS[@]} -eq 0 ]]; then
    count_dir
  fi

  for item in "${SERVICE_ITEMS[@]}"; do
    local service_name
    service_name="${item//-/_}"

    local root_password
    root_password=$(generate_random_pass)
    local password
    password=$(generate_random_pass)

    export "${service_name^^}_MARIADB_ROOT_PASSWORD"="$root_password"
    export "${service_name^^}_MARIADB_PASSWORD"="$password"
  done

  export DB_PASSWORD
  DB_PASSWORD=$(generate_random_pass)
  export LOGIN_PASSWORD
  LOGIN_PASSWORD=$(generate_random_pass)
  export ADMIN_PASSWORD
  ADMIN_PASSWORD=$(generate_random_pass)
  export BAN_PASSWORD
  BAN_PASSWORD=$(generate_random_pass)
  export ALLOWED_EMBEDS="/^.*\.wetfish.net$/i"
}

# Unpacking loop for services
for entry in "${services[@]}"; do
  IFS=' ' read -r service_name container <<< "$entry"

  env_file="${SERVICES_ROOT}/${service_name}/mariadb.env"

  if [[ ! -f "$env_file" ]]; then
    echo "⚠️  Warning: Env file for $service_name not found at $env_file. Skipping..."
    continue
  fi

  echo "🔍 Reading secrets for $service_name..."

  # Load database name and root password dynamically from the mariadb.env file
  db_name=$(load_var_from_env "$env_file" "MARIADB_DATABASE")
  root_password=$(load_var_from_env "$env_file" "MARIADB_ROOT_PASSWORD")

  if [[ -z "$db_name" || -z "$root_password" ]]; then
    echo "❌ Error: Missing database name or root password in $env_file. Skipping..."
    continue
  fi

  # Construct backup filename
  backup_filename="${service_name}-backup-${timestamp}.sql"

  # Check if the backup file exists for restoration
  backup_file="${SCRIPT_DIR}/${backup_filename}"
  if [[ ! -f "$backup_file" ]]; then
    echo "⚠️  Warning: Backup file for $service_name not found at $backup_file. Skipping..."
    continue
  fi

  echo "📦 Restoring $db_name to $container from backup file $backup_filename..."

  # Restore the database from the backup file
  docker exec "$container" mysql -u root --password="$root_password" "$db_name" < "$backup_file"

  # Cleanup sensitive vars
  unset db_name
  unset root_password
done

echo "✅ All backups restored successfully!"
