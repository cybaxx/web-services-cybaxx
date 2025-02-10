#!/usr/bin/env bash

set -eu

trapdoor(){
  # Define a file that will act as a lock to check if the script has run before
  LOCK_FILE="/tmp/web-services-init.lock"

  # Check if the lock file exists
  if [ -f "$LOCK_FILE" ]; then
      echo "This script has already been run on this machine. Exiting."
      exit 1
  else
    # If the lock file doesn't exist, create it
    touch "$LOCK_FILE"
    echo "This is the first time the script is being run on this machine."
  fi
}

# Generate a random SHA-512 hash
generate_random_pass() {
  pwgen -s 32 1
}

count_dir() {
    SERVICE_ITEMS=($(ls ./services/))
}

# Create env var for services as needed
export_secrets() {
  export ENV_TAG="staging"

  # Iterate through all service items
  for item in "${SERVICE_ITEMS[@]}"; do
    # Replace hyphens with underscores in the service name
    local service_name="${item//-/_}"

    # Generate random passwords and declare service-specific variables
    declare -g "${service_name^^}_MARIADB_ROOT_PASSWORD=$(generate_random_pass)"
    declare -g "${service_name^^}_MARIADB_PASSWORD=$(generate_random_pass)"
  done

  # Dynamically set the shared global variables for all services
  for item in "${SERVICE_ITEMS[@]}"; do
    # Replace hyphens with underscores in the service name for the global variable name
    local service_name="${item//-/_}"

    # Export global variables dynamically for each service
    export "${service_name^^}_MARIADB_ROOT_PASSWORD"
    export "${service_name^^}_MARIADB_PASSWORD"
  done

  # Export other secrets as needed
  export DB_PASSWORD_WIKI=$(generate_random_pass)
  export LOGIN_PASSWORD_WIKI=$(generate_random_pass)
  export ADMIN_PASSWORD_WIKI=$(generate_random_pass)
  export BAN_PASSWORD_WIKI=$(generate_random_pass)
  export SITE_URL="staging-wiki.wetfish.net"
  export ALLOWED_EMBEDS="/^.*\.wetfish.net$/i"
}

# Generate configuration files from templates
generate_configs() {
  local files=(
    './services/wiki-staging/php.env.example'
    './services/wiki-staging/mariadb.env.example'
    './services/online-staging/php.env.example'
    './services/online-staging/mariadb.env.example'
  )

  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      local output="${file%.example}"  # Remove .example extension
      envsubst < "$file" > "$output" && echo "Generated: $output"
    else
      echo "Warning: Template file $file not found."
    fi
  done
}

# Replace variables directly in .env files
update_env_files() {
  local files=(
    './services/wiki-staging/php.env'
    './services/wiki-staging/mariadb.env'
    './services/online-staging/php.env'
    './services/online-staging/mariadb.env'
  )

  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      echo "Updating variables in: $file"

      # Create a backup before making any changes
      cp "$file" "${file}.bak"

      # Substitute service-specific secrets
      for item in "${SERVICE_ITEMS[@]}"; do
        local service_name="${item//-/_}"
        local root_password_var="${service_name^^}_MARIADB_ROOT_PASSWORD"
        local password_var="${service_name^^}_MARIADB_PASSWORD"

        # Get the values for passwords from the environment variables
        local mariadb_root_password="${!root_password_var}"
        local mariadb_password="${!password_var}"

        # Perform in-place substitution
        sed -i "s|${service_name^^}_MARIADB_ROOT_PASSWORD=.*|${service_name^^}_MARIADB_ROOT_PASSWORD=$mariadb_root_password|" "$file"
        sed -i "s|${service_name^^}_MARIADB_PASSWORD=.*|${service_name^^}_MARIADB_PASSWORD=$mariadb_password|" "$file"
      done

      # Substitute the global secrets
      sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD_WIKI|" "$file"
      sed -i "s|LOGIN_PASSWORD=.*|LOGIN_PASSWORD=$LOGIN_PASSWORD_WIKI|" "$file"
      sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$ADMIN_PASSWORD_WIKI|" "$file"
      sed -i "s|BAN_PASSWORD=.*|BAN_PASSWORD=$BAN_PASSWORD_WIKI|" "$file"
      sed -i "s|SITE_URL=.*|SITE_URL=$SITE_URL|" "$file"
      sed -i "s|ALLOWED_EMBEDS=.*|ALLOWED_EMBEDS=$ALLOWED_EMBEDS|" "$file"

      echo "Successfully updated $file"
    else
      echo "Warning: .env file $file not found."
    fi
  done
}

# Configure Traefik environment file
config_traefik() {
  cp ./traefik/traefik.env.example ./traefik/traefik.env
}

# Change to the script's directory
set_script_dir() {
  local dirname
  dirname=$(dirname "$0")
  SCRIPT_DIR=$(cd "$dirname" || exit; pwd)
  cd "$SCRIPT_DIR" || exit
}

# Check Docker Compose version
check_docker_compose() {
  if ! docker compose version &>/dev/null; then
    echo "Error: Docker Compose is not installed or not found."
    exit 2
  fi
}

# Run Docker Compose commands
run_docker_compose() {
  local action="$1"
  local project_dirs=("traefik" "services/home-staging" "services/online-staging" "services/wiki-staging")

  case "$action" in
    "down")
      for dir in "${project_dirs[@]}"; do
        echo "Running \"docker compose down\" in ${dir}"
        cd "${SCRIPT_DIR}/${dir}" && docker compose down || {
          echo "Failed to bring down the service in $dir. Continuing..."
        }
      done
      ;;
    "up")
      for dir in "${project_dirs[@]}"; do
        echo "Running \"docker compose up -d --force-recreate\" in ${dir}"
        cd "${SCRIPT_DIR}/${dir}" && docker compose -f docker-compose.yml up -d --force-recreate || {
          echo "Failed to start the service in $dir. Continuing..."
        }
      done
      ;;
    "dev-build")
      for dir in "${project_dirs[@]}"; do
        echo "Running \"docker compose up -d --force-recreate --build --no-deps\" in ${dir}"
        cd "${SCRIPT_DIR}/${dir}" && docker compose up -d --force-recreate --build --no-deps || {
          echo "Failed to set the service in $dir. Continuing..."
        }
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
  # Ensure an action argument is passed
  if [[ $# -eq 0 ]]; then
    echo "Error: No action specified. Please provide 'up', 'down', or 'dev-build'."
    echo "Usage: $0 [up | down | dev-build]"
    exit 1
  fi

  # Validate the action argument
  local action="$1"
  if [[ "$action" != "up" && "$action" != "down" && "$action" != "dev-build" ]]; then
    echo "Error: Invalid action '$action'. Allowed values are 'up', 'down', or 'dev-build'."
    echo "Usage: $0 [up | down | dev-build]"
    exit 1
  fi

  # Proceed with the script tasks
  trapdoor
  count_dir
  export_secrets
  generate_configs
  update_env_files
  config_traefik
  set_script_dir
  check_docker_compose
  run_docker_compose "$action"
}

main "$@"
