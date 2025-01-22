#!/usr/bin/env bash

set -eu

# Generate a random SHA-512 hash
generate_random_sha512() {
  head -c 64 /dev/urandom | sha512sum | awk '{print $1}'
}

# Export secrets as environment variables
export_secrets() {
  export MARIADB_ROOT_PASSWORD=$(generate_random_sha512)
  export MARIADB_PASSWORD=$(generate_random_sha512)
  export DB_PASSWORD_WIKI=$MARIADB_PASSWORD
  export LOGIN_PASSWORD_WIKI=$(generate_random_sha512)
  export ADMIN_PASSWORD_WIKI=$(generate_random_sha512)
  export BAN_PASSWORD_WIKI=$(generate_random_sha512)
  export SITE_URL="wiki.example.com"  # Update with your actual URL
  export ALLOWED_EMBEDS="/^.*\\.example\\.com$/i"
}

# Generate configuration files from templates
generate_configs() {
  local files=(
    './wiki/php.env.example'
    './wiki/mariadb.env.example'
    './online/php.env.example'
    './online/mariadb.env.example'
    './click/php.env.example'
    './click/mariadb.env.example'
    './danger/php.env.example'
    './danger/mariadb.env.example'
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
    './wiki/php.env'
    './wiki/mariadb.env'
    './online/php.env'
    './online/mariadb.env'
    './click/php.env'
    './click/mariadb.env'
    './danger/php.env'
    './danger/mariadb.env'
  )

  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      echo "Updating variables in: $file"
      sed -i.bak \
        -e "s|MARIADB_ROOT_PASSWORD=.*|MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD|" \
        -e "s|MARIADB_PASSWORD=.*|MARIADB_PASSWORD=$MARIADB_PASSWORD|" \
        -e "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD_WIKI|" \
        -e "s|LOGIN_PASSWORD=.*|LOGIN_PASSWORD=$LOGIN_PASSWORD_WIKI|" \
        -e "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$ADMIN_PASSWORD_WIKI|" \
        -e "s|BAN_PASSWORD=.*|BAN_PASSWORD=$BAN_PASSWORD_WIKI|" \
        -e "s|SITE_URL=.*|SITE_URL=$SITE_URL|" \
        -e "s|ALLOWED_EMBEDS=.*|ALLOWED_EMBEDS=$ALLOWED_EMBEDS|" \
        "$file"
      rm -f "$file.bak"
    else
      echo "Warning: .env file $file not found."
    fi
  done
}

# Change to the script's directory
set_script_dir() {
  local dirname=$(dirname "$0")
  SCRIPT_DIR=$(cd "$dirname" || exit; pwd)
  cd "$SCRIPT_DIR" || exit
}

# Check Docker Compose version
check_docker_compose() {
  docker compose version || {
    echo "Error: Newer type of docker compose plugin not found"
    exit 2
  }
}

# Run Docker Compose commands
run_docker_compose() {
  local project_dirs=("traefik" "services/home" "services/click" "services/danger" "services/glitch" "services/online" "services/wiki")

  case $1 in
    "down")
      for dir in "${project_dirs[@]}"; do
        echo "About to run \"docker compose down\" in ${dir}"
        cd "${SCRIPT_DIR}/${dir}" && docker compose down || exit
      done
      ;;

    "up")
      for dir in "${project_dirs[@]}"; do
        echo "About to run \"docker compose up -d --force-recreate\" in ${dir}"
        cd "${SCRIPT_DIR}/${dir}" && docker compose up -d --force-recreate || exit
      done
      ;;

    *)
      echo "Error: Must specify action to take"
      echo "Error: [up / down]"
      exit 1
      ;;
  esac
}

# Main script execution
main() {
  export_secrets
  generate_configs
  update_env_files
  set_script_dir
  check_docker_compose
  run_docker_compose "$1"
}

main "$@"
