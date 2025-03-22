#!/usr/bin/env bash

set -eu

# Function to dynamically get the service directories
count_dir() {
    SERVICE_ITEMS=($(find ./services/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
}

# Generate random SHA-512 hash for passwords
generate_random_pass() {
  pwgen -s 32 1
}

# Create environment variables for services
export_secrets() {
  export ENV_TAG="prod"

  # Use count_dir to get the service directories
  count_dir

  # Iterate through all service items
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

  # Export other secrets
  export DB_PASSWORD_WIKI
  DB_PASSWORD_WIKI=$(generate_random_pass)
  export LOGIN_PASSWORD_WIKI
  LOGIN_PASSWORD_WIKI=$(generate_random_pass)
  export ADMIN_PASSWORD_WIKI
  ADMIN_PASSWORD_WIKI=$(generate_random_pass)
  export BAN_PASSWORD_WIKI
  BAN_PASSWORD_WIKI=$(generate_random_pass)
  export SITE_URL="prod-wiki.wetfish.net"
  export ALLOWED_EMBEDS="/^.*\.wetfish.net$/i"
}

# Generate configuration files from templates
generate_configs() {
  # Use count_dir to get the service directories
  count_dir

  # Loop over the service directories to find the .env.example files
  for dir in "${SERVICE_ITEMS[@]}"; do
    local php_example="./services/$dir/php.env.example"
    local mariadb_example="./services/$dir/mariadb.env.example"

    # Check if php.env.example exists and process it
    if [[ -f "$php_example" ]]; then
      local output="${php_example%.example}"
      mkdir -p "$(dirname "$output")"
      envsubst < "$php_example" > "$output" && echo "Generated: $output"
    else
      echo "Warning: Template file $php_example not found."
    fi

    # Check if mariadb.env.example exists and process it
    if [[ -f "$mariadb_example" ]]; then
      local output="${mariadb_example%.example}"
      mkdir -p "$(dirname "$output")"
      envsubst < "$mariadb_example" > "$output" && echo "Generated: $output"
    else
      echo "Warning: Template file $mariadb_example not found."
    fi
  done
}

# Replace variables directly in .env files
update_env_files() {
  # Use count_dir to get the service directories
  count_dir

  # Loop through all service directories
  for dir in "${SERVICE_ITEMS[@]}"; do
    local php_example="./services/$dir/php.env.example"
    local mariadb_example="./services/$dir/mariadb.env.example"

    # Check if the php.env.example file exists
    if [[ -f "$php_example" ]]; then
      echo "Updating variables in: $php_example"

      # Backup the original file
      cp "$php_example" "${php_example}.bak"

      # Substitute service-specific secrets into php.env.example
      for item in "${SERVICE_ITEMS[@]}"; do
        local service_name
        service_name="${item//-/_}"

        local mariadb_root_password
        mariadb_root_password="${!service_name^^_MARIADB_ROOT_PASSWORD}"
        local mariadb_password
        mariadb_password="${!service_name^^_MARIADB_PASSWORD}"

        # Perform in-place substitution
        sed -i "s|${service_name^^}_MARIADB_ROOT_PASSWORD=.*|${service_name^^}_MARIADB_ROOT_PASSWORD=$mariadb_root_password|" "$php_example"
        sed -i "s|${service_name^^}_MARIADB_PASSWORD=.*|${service_name^^}_MARIADB_PASSWORD=$mariadb_password|" "$php_example"
      done

      # Substitute global secrets
      sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD_WIKI|" "$php_example"
      sed -i "s|LOGIN_PASSWORD=.*|LOGIN_PASSWORD=$LOGIN_PASSWORD_WIKI|" "$php_example"
      sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$ADMIN_PASSWORD_WIKI|" "$php_example"
      sed -i "s|BAN_PASSWORD=.*|BAN_PASSWORD=$BAN_PASSWORD_WIKI|" "$php_example"
      sed -i "s|SITE_URL=.*|SITE_URL=$SITE_URL|" "$php_example"
      sed -i "s|ALLOWED_EMBEDS=.*|ALLOWED_EMBEDS=$ALLOWED_EMBEDS|" "$php_example"

      echo "Successfully updated $php_example"
    else
      echo "Warning: .env file $php_example not found."
    fi

    # Check if the mariadb.env.example file exists
    if [[ -f "$mariadb_example" ]]; then
      echo "Updating variables in: $mariadb_example"

      # Backup the original file
      cp "$mariadb_example" "${mariadb_example}.bak"

      # Perform in-place substitution for mariadb.env.example
      for item in "${SERVICE_ITEMS[@]}"; do
        local service_name
        service_name="${item//-/_}"

        local mariadb_root_password
        mariadb_root_password="${!service_name^^_MARIADB_ROOT_PASSWORD}"
        local mariadb_password
        mariadb_password="${!service_name^^_MARIADB_PASSWORD}"

        # Perform in-place substitution
        sed -i "s|${service_name^^}_MARIADB_ROOT_PASSWORD=.*|${service_name^^}_MARIADB_ROOT_PASSWORD=$mariadb_root_password|" "$mariadb_example"
        sed -i "s|${service_name^^}_MARIADB_PASSWORD=.*|${service_name^^}_MARIADB_PASSWORD=$mariadb_password|" "$mariadb_example"
      done

      # Substitute global secrets
      sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD_WIKI|" "$mariadb_example"
      sed -i "s|LOGIN_PASSWORD=.*|LOGIN_PASSWORD=$LOGIN_PASSWORD_WIKI|" "$mariadb_example"
      sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$ADMIN_PASSWORD_WIKI|" "$mariadb_example"
      sed -i "s|BAN_PASSWORD=.*|BAN_PASSWORD=$BAN_PASSWORD_WIKI|" "$mariadb_example"
      sed -i "s|SITE_URL=.*|SITE_URL=$SITE_URL|" "$mariadb_example"
      sed -i "s|ALLOWED_EMBEDS=.*|ALLOWED_EMBEDS=$ALLOWED_EMBEDS|" "$mariadb_example"

      echo "Successfully updated $mariadb_example"
    else
      echo "Warning: .env file $mariadb_example not found."
    fi
  done
}

# Configure Traefik environment file
config_traefik() {
  cp ./traefik/traefik.env.example ./traefik/traefik.env
}

# Run Docker Compose commands
run_docker_compose() {
  local action="$1"

  # Use count_dir to get the service directories
  count_dir

  case "$action" in
    "down")
      for dir in "${SERVICE_ITEMS[@]}"; do
        echo "Running \"docker compose down\" in services/$dir"
        if [ -d "${SCRIPT_DIR}/services/$dir" ]; then
          cd "${SCRIPT_DIR}/services/$dir" && docker compose down || {
            echo "Failed to bring down the service in $dir. Continuing..."
          }
        else
          echo "Directory for service $dir not found. Skipping..."
        fi
      done
      ;;
    "up")
      for dir in "${SERVICE_ITEMS[@]}"; do
        echo "Running \"docker compose up -d --force-recreate\" in services/$dir"
        if [ -d "${SCRIPT_DIR}/services/$dir" ]; then
          cd "${SCRIPT_DIR}/services/$dir" && docker compose up -d --force-recreate || {
            echo "Failed to start the service in $dir. Continuing..."
          }
        else
          echo "Directory for service $dir not found. Skipping..."
        fi
      done
      ;;
    "dev-build")
      for dir in "${SERVICE_ITEMS[@]}"; do
        echo "Running \"docker compose up -d --force-recreate --build --no-deps\" in services/$dir"
        if [ -d "${SCRIPT_DIR}/services/$dir" ]; then
          cd "${SCRIPT_DIR}/services/$dir" && docker compose up -d --force-recreate --build --no-deps || {
            echo "Failed to set the service in $dir. Continuing..."
          }
        else
          echo "Directory for service $dir not found. Skipping..."
        fi
      done
      ;;
    *)
      echo "Error: Invalid action '$action'. Allowed values are 'up', 'down', or 'dev-build'."
      echo "Usage: $0 [up | down | dev-build]"
      exit 1
      ;;
  esac
}

# Main script execution
main() {
  if [[ $# -eq 0 ]]; then
    echo "Error: No action specified. Please
