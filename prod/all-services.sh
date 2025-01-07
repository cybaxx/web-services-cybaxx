#!/usr/bin/env bash

set -eu

# where this .sh file lives
DIRNAME=$(dirname "$0")
SCRIPT_DIR=$(cd "$DIRNAME" || exit; pwd)
cd "$SCRIPT_DIR" || exit

# dir with compose file
# relative to this dir
PROJECT_DIRS=("traefik" "services/home" "services/click" "services/danger" "services/glitch" "services/online" "services/wiki")

# ensure they provided a subcommand
if [ $# -eq 0 ]
  then
    echo "Error: Must specify action to take"
    echo "Error: [up / down ]"
    exit 1
fi

# test for newer style compose
docker compose version
if [ $? -ne 0 ]; then
    echo "Error: Newer type of docker compose plugin not found"
    exit 2
fi

# eval arg and run commands
case $1 in
  "down")
    for DIR in "${PROJECT_DIRS[@]}"; do
      echo "About to run \"docker compose down\" in ${DIR}"
      cd "${SCRIPT_DIR}/${DIR}" && docker compose down || exit
    done
  ;;

  "up")
    for DIR in "${PROJECT_DIRS[@]}"; do
      echo "About to run \"docker compose up -d --force-recreate\" in ${DIR}"
      cd "${SCRIPT_DIR}/${DIR}" && docker compose up -d --force-recreate || exit
    done
  ;;
esac
