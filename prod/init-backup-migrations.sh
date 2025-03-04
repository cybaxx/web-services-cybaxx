#!/usr/bin/env bash

set -eu

# Default Values
SERVICE_DIR="./services"
DUMP_DIR="/opt/wetfish-data-dumps/in"
OUT_DIR="/opt/wetfish-data-dumps/out"
PROD_SERVER="new-prod-server"  # Default value for the production server
ZFS_POOL="your_zfs_pool"       # Replace with your ZFS pool name
ZFS_SNAPSHOT_DIR="/web-services-cybaxx"  # Directory to snapshot
SRC_DIR="./services"  # Default source directory for backup
DEST_DIR="$OUT_DIR"  # Default destination for backup

# Function to simulate RSA encryption with public key
rsa_encrypt() {
  local message="$1"
  local e="$2"
  local n="$3"
  local encrypted=""

  # Encrypt each character using RSA formula: c = m^e % n
  for (( i=0; i<${#message}; i++ )); do
    char="${message:$i:1}"
    ascii_value=$(printf "%d" "'$char")
    encrypted_char=$(echo "$ascii_value^$e % $n" | bc)
    encrypted+="$encrypted_char "
  done
  echo "$encrypted"
}

# Function to simulate RSA decryption with private key
rsa_decrypt() {
  local encrypted_message="$1"
  local d="$2"
  local n="$3"
  local decrypted=""

  # Decrypt each number using RSA formula: m = c^d % n
  for encrypted_char in $encrypted_message; do
    decrypted_char=$(echo "$encrypted_char^$d % $n" | bc)
    decrypted+=$(printf "\\$(printf '%03o' "$decrypted_char")")
  done
  echo "$decrypted"
}

# Function to simulate custom RSA shift and base64 encoding (mock)
custom_rsa_base64_shift() {
  local input="$1"

  # Apply RSA encryption to the confirmation phrase (public key: e = 5, n = 91)
  local e=5
  local n=91

  # Encrypt the input using RSA
  local encrypted_message=$(rsa_encrypt "$input" "$e" "$n")

  # Return the encrypted message (this mimics the "shift" in a playful way)
  echo "$encrypted_message"
}

# Function to ask the user for permission to run the prod service
ask_permission() {
  echo "Did you get permission from Rachel to run the prod service, interrupting backups? (yes or no)"
  read -r user_response

  if [[ "$user_response" == "no" ]]; then
    echo "You must get permission from Rachel, the Beaver Queen Monarch of this Momocarcy."
    echo "Please ask Rachel for the server's chastity key first."
    exit 1  # Non-standard error code ID10T (user error)
  elif [[ "$user_response" == "yes" ]]; then
    echo "Rachel is the Beaver Queen Monarch of this Momocarcy."
    echo "Now, please type the exact phrase in all caps to confirm your permission:"
    echo "ISWEARTOGODRACHELTHEBEAVERQUEEENSAIDITWASOKAYTORUNTHISSCRIPTLOOKHERESTHEKEY"

    read -r confirmation

    # Dynamically generate the encrypted confirmation using the RSA mock encryption
    local correct_confirmation=$(custom_rsa_base64_shift "ISWEARTOGODRACHELTHEBEAVERQUEEENSAIDITWASOKAYTORUNTHISSCRIPTLOOKHERESTHEKEY")

    # Apply the custom RSA base64 shift to the input
    local shifted_confirmation=$(custom_rsa_base64_shift "$confirmation")

    # Compare the shifted input with the dynamically generated correct confirmation
    if [[ "$shifted_confirmation" == "$correct_confirmation" ]]; then
      echo "Success Code : B00TY Permission confirmed. You may now run the script."
      echo "4qCA4qCA4qCA4qCA4qKg4qGP4qCA4qCA4qCA4qCA4qCA4qCA4qKA4qGe4qCB4qCA4qG/4qOv4qG34qG04qKm4qOk4qGg4qO24qG24qCA4qK34qCA4qCA4qCA4qCA4qKw4qGH4qCA4qCA4qCA4qCA4qCA4qCA4qG+4qCACuKggOKggOKggOKggOKggOKggOKhnuKggOKggOKggOKggOKggOKggOKggOKjvOKjpeKjpOKjpOKjpOKjpOKjpOKjpOKjpOKjgOKjgOKjgOKjgOKggOKgiOKip+KggOKggOKggOKiuOKhh+KggOKggOKggOKggOKggOKigOKhh+KggArioIDioIDioIDioIDioIDiorjioIHioIDioIDioIDioIDioIDioIDiobzioIHioIDioIDioIDioIDioInioJnioLvior/io7/io7/io7/io7/io7/io7/ioJvioqbioIDioIDiorjioYfioIDioIDioIDioIDioIDiorjioYfioIAK4qCA4qCA4qCA4qCA4qKg4qGP4qCA4qCA4qCA4qCA4qCA4qCA4qG84qCB4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCZ4qK/4qO/4qO/4qO/4qO/4qCz4qCA4qKz4qGA4qK54qGH4qCA4qCA4qCA4qCA4qCA4qG+4qGH4qCACuKggOKggOKggOKggOKhnuKggOKggOKggOKggOKggOKggOKhvOKggeKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKiu+Kjv+Kjv+Khv+KgmOKggOKggOKgueKjvOKhh+KggOKggOKggOKggOKioOKgh+KggOKggArioIDioIDioIDio7DioIPioIDioIDioIDioIDioIDiob7ioIHioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIjio7/iob/ioIHioIDioIDioIDioIDioJjio4fioIDioIDioIDioIDiob7ioIDioIDioIAK4qCA4qCA4qKg4qGP4qCA4qCA4qCA4qCA4qCA4qG84qCB4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qK/4qCB4qCA4qCA4qCA4qCA4qCA4qCA4qC44qGE4qCA4qCA4qK44qCB4qCA4qCA4qCACuKggOKggOKhvuKggOKggOKggOKggOKggOKhvuKggeKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKjvOKggOKggOKggOKggOKggOKggOKggOKggOKiu+KggOKggOKhn+KggOKggOKggOKggArioIDio7TioJPio77io7Pio4DiooDiobzioIHioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDiorvioYfioIDioIDioIDioIDioIDioIDioIDiorjioYfiooDioIfioIDioIDioIDioIAK4qO+4qCD4qCA4qCA4qCA4qCR4qGf4qCB4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qO+4qCD4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCI4qGH4qK44qCA4qCA4qCA4qCA4qCACuKgueKhgOKggOKggOKggOKggOKgueKjhuKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKggOKigOKhj+KggOKggOKggOKggOKggOKggOKggOKggOKggOKhh+KjvuKggOKggOKggOKggOKggArioIDiorPioYTioIDioIDioIDioIDioJjio4TioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDiobzioIDioIDioIDioIDioIDioIDioIDioIDioIDiooDioYfio7/ioIDioIDioIDioIDioIAK4qCA4qCA4qO34qGE4qCA4qCA4qCA4qCA4qCZ4qKm4qGA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qKA4qGe4qCB4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qK44qCD4qGP4qCA4qCA4qCA4qCA4qCACuKggOKigOKhh+KiueKjhOKggOKggOKggOKggOKjgOKgieKgk+KgtuKihOKhgOKggOKggOKggOKggOKggOKigOKjoOKgtOKgi+Kgo+KjhOKggOKggOKggOKggOKggOKggOKggOKggOKioOKgn+KjuOKjp+KggOKggOKggOKggOKggArioIDio7Tio7/ioIvioJjio4bioIDiorDioLbioKTioo3io5vio7bioKTioL/io7fio6bioYDioJLioJrioZ/ioIDioIDioIDioIDioIjioJvioKLioKTioYTioIDioIDiooDiobTioq/ioLTio7PioIfioIDioIDioIDioIDioIAK4qCA4qCA4qCJ4qCA4qCA4qCY4qKm4qGI4qC74qOW4qCk4qOk4qOJ4qOJ4qO54qOv4qOt4qCJ4qCA4qCA4qGH4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qKg4qO+4qCb4qOr4qO84qCD4qCA4qCA4qCA4qCA4qCA4qCACuKggOKggOKggOKggOKggOKggOKggOKgkeKjhOKgieKipuKhgOKggOKggOKgiOKgieKggeKggOKggOKjuOKggeKggOKggOKggOKggOKggOKggOKggOKggOKggOKjtOKiv+Kjt+KimuKhneKggeKggOKggOKggOKggOKggOKggOKggArioIDioIDioIDioIDioIDioIDioIDioIDioIDioLniorbio7fioIfioIDioIDioIDioIDioIDio6DioI/ioIDioIDioIDioIDioIDioIDioIDioIDioIDioIDio7Tio7/ioLfioInioIDioIDioIDioIDioIDioIDioIDioIDioIAK4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qC44qCL4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCA4qCI4qCA" | base64 -decode
    else
      echo "Error: ID10T The phrase does not match exactly. Permission not granted. Exiting."
      exit 1  # Non-standard error code ID10T
    fi
  else
    echo "Invalid response. Please answer with 'yes' or 'no'."
    exit 1  # Non-standard error code ID10T
  fi
}

# Function to close outgoing ports 443 and 80 with ufw
close_outgoing_ports() {
  echo "Closing outgoing ports 443 (HTTPS) and 80 (HTTP)..."

  # Deny outgoing traffic on port 443 (HTTPS)
  sudo ufw deny out 443/tcp

  # Deny outgoing traffic on port 80 (HTTP)
  sudo ufw deny out 80/tcp

  # Confirm the changes
  if [ $? -eq 0 ]; then
    echo "Outgoing ports 443 and 80 have been closed successfully."
  else
    echo "Error: Failed to close outgoing ports 443 and 80."
    exit 1
  fi
}

# Function to create a ZFS snapshot
create_zfs_snapshot() {
  # Get the current timestamp for snapshot naming
  timestamp=$(date +%Y-%m-%d_%H-%M-%S)

  # Create a snapshot of the /web-services-cybaxx directory
  snapshot_name="web-services-cybaxx@snapshot-$timestamp"

  echo "Creating ZFS snapshot: $snapshot_name"
  zfs snapshot "$ZFS_POOL$ZFS_SNAPSHOT_DIR@$snapshot_name"

  if [ $? -eq 0 ]; then
    echo "ZFS snapshot created successfully: $snapshot_name"
  else
    echo "Error: Failed to create ZFS snapshot."
    exit 1
  fi
}

# Function to back up MariaDB databases on old-prod to the local disk (not inside containers)
backup_databases() {
  # Iterate through all services in the service directory
  for service_dir in "$SRC_DIR"/*; do
    if [ -d "$service_dir" ]; then
      service_name=$(basename "$service_dir")

      # Check for mariadb.env file and extract the password if it exists
      env_file="$service_dir/mariadb.env"
      if [ -f "$env_file" ]; then
        echo "Processing $service_name..."

        # Extract the MariaDB password from the .env file
        mariadb_password=$(grep -E '^MARIADB_ROOT_PASSWORD=' "$env_file" | cut -d '=' -f2)

        if [ -z "$mariadb_password" ]; then
          echo "No MariaDB root password found in $env_file. Skipping backup for $service_name."
          continue
        fi

        # Set the Docker container name (assuming the service follows the format of service-db)
        container_name="${service_name}-db"

        # Check if the container is running
        if docker ps -q -f name="$container_name" >/dev/null; then
          echo "Backing up database for $service_name..."

          # Create a dump of the database, directly on the host's filesystem
          dump_filename="$DUMP_DIR/${service_name}-backup-$(date +%Y-%m-%d).sql"
          docker exec "$container_name" mysqldump -u root --password="$mariadb_password" "$service_name" > "$dump_filename"

          echo "Backup for $service_name completed and stored at $dump_filename"

        else
          echo "Container for $service_name not running. Skipping backup."
        fi
      else
        echo "No mariadb.env file found for $service_name. Skipping backup."
      fi
    fi
  done
}

# Function to apply the backup on new-prod server via SSH
apply_backup_on_prod() {
  # SSH into the new-prod server and restore the backups
  for dump_file in "$DUMP_DIR"/*.sql; do
    if [ -f "$dump_file" ]; then
      service_name=$(basename "$dump_file" | cut -d '-' -f1)

      echo "Applying backup for $service_name on $PROD_SERVER..."

      # Assuming the production container follows a similar naming convention
      container_name="${service_name}-db"

      # Check if the container is running on the production server
      if ssh "$PROD_SERVER" "docker ps -q -f name=$container_name" >/dev/null; then
        echo "Restoring database $service_name from $dump_file..."

        # Execute the restore command inside the production container
        ssh "$PROD_SERVER" "docker exec -i $container_name mysql -u root --password=<your_root_password> $service_name < $dump_file"

        echo "Backup restored for $service_name on $PROD_SERVER"
      else
        echo "Container for $service_name not running on $PROD_SERVER. Skipping restore."
      fi
    fi
  done
}

# Function to get SSH keys from old-prod to use for authentication with new-prod
fetch_ssh_keys() {
  echo "Fetching SSH keys from $PROD_SERVER..."

  # Assuming we have access to the old-prod server via SSH
  # Ensure the SSH keys are transferred securely to old-prod
  ssh-copy-id -i ~/.ssh/id_rsa.pub "$PROD_SERVER"

  if [ $? -eq 0 ]; then
    echo "SSH keys successfully copied to $PROD_SERVER."
  else
    echo "Error: Failed to copy SSH keys to $PROD_SERVER."
    exit 1
  fi
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

draw_sines(){
angle=0
step_angle=5
vert_plot=0
horiz_plot=5
centreline=12
amplitude=11
PI=3.14159
clear
# Continuous loop
while true
do
    # Create each floating point value...
    vert_plot=$(awk "BEGIN{ printf \"%.12f\", ((sin($angle*($PI/180))*$amplitude)+$centreline)}")

    # Truncate the floating point value to an integer then invert the plot to suit the x y coordinates inside a terminal...
    vert_plot=$((24-${vert_plot/.*}))

    # Plot the point(s) and print the angle at that point...
    printf "\x1B["$vert_plot";"$horiz_plot"f*"
    printf "\x1B[22;1fAngle is $angle degrees..."

    # Pause for a short time to make the plot visible
    sleep 0.1

    # Increment the angle and ensure it stays within the 0-359 range
    angle=$((angle+step_angle))
    if [ $angle -ge 360 ]; then
        angle=0  # Reset the angle after one full cycle
    fi

    # Increment the horizontal plot position
    horiz_plot=$((horiz_plot+1))

    # Reset horizontal position when it reaches the end of the terminal width (adjust as necessary)
    if [ $horiz_plot -gt 80 ]; then
        horiz_plot=5
    fi
done
}

# Main script execution
main() {
  # Ask for permission before doing anything else
  ask_permission

  # Parse command line arguments
  parse_args "$@"

  # Close outgoing ports 443 and 80 before running the rest of the script
  close_outgoing_ports

  # Ensure that the dump directory exists
  if [ ! -d "$DUMP_DIR" ]; then
    echo "Error: Directory $DUMP_DIR does not exist. Exiting."
    exit 1
  fi

  # Fetch SSH keys from old-prod to new-prod for secure authentication
  fetch_ssh_keys

  # Create a ZFS snapshot before starting the backup
  create_zfs_snapshot

  # Back up the databases from the source to the local disk
  backup_databases

  # Rsync the dumps to new-prod server
  echo "Rsyncing backups from $DUMP_DIR to $PROD_SERVER:$DEST_DIR..."
  rsync -avz "$DUMP_DIR/" "$PROD_SERVER:$DEST_DIR/"
  echo "Backups successfully rsynced to $PROD_SERVER:$DEST_DIR"

  # Apply the backup on the new prod server (if desired)
  apply_backup_on_prod

  #draw_sines
}

main "$@"
