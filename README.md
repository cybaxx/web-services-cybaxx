# Web-services production-manifests 
Contains traefik config and submodules for docker compose based deployments using docker watch-tower to run wetfish web-services.

Here's some technical documentation for the tech stack we use:
https://containrrr.dev/watchtower/
https://doc.traefik.io/traefik/
https://labzilla.io/blog/cloudflare-certbot
idk maybe if you don't know docker and compose go learn that 

Services included:
- Online
- Wiki
- Danger
- Click
- Wetfish website

## How do I get started?
Simply paste this curl pipe to bash line in your debian terminal.
```bash
curl -fsSL https://raw.githubusercontent.com/cybaxx/web-services-cybaxx/refs/heads/main/util/wetfish-installer.sh | sudo bash

```

## I don't trust curl pipe to bash
Fine set it up yourself, install docker and the docker compose plugin as a dependency, see script provided above for any additional deps.

```bash
# install docker and docker-compose-plugin
# https://docs.docker.com/engine/install/debian/

# create traefik backend network
docker network create traefik-backend

# clone the repo (recursively)
cd /opt

export REPO_DIR="$(cd "/opt" || exit 1; pwd)/production-manifests"

git clone \
  --branch $BRANCH \
  --single-branch \
  --recursive \
  --recurse-submodules \
  https://github.com/wetfish/production-manifests.git \
  $REPO_DIR

# fix various permissions
cd $REPO_DIR && bash ./fix-subproject-permissions.sh

# recommended: start just traefik, give it a minute to acquire certs (or error out)
cd traefik && docker compose up -d

# start all the stacks at once
cd $REPO_DIR && bash ./init-servivces.sh && ./all-services up
```

## Where is persistent data stored?

```bash
# blog: posts
/opt/web-services/$ENV/services/blog/config.js

# danger: database
/opt/web-services/$ENV/services/danger/db

# wetfishonline: database, fish/equpipment
/opt/web-services/$ENV/services/online/db
services/online/storage

# wiki: database, user uploads
/opt/web-services/$ENV/services/wiki/db
/opt/web-services/$ENV/services/wiki/upload # mounted over nfs to storage server

# Prod Bind Mount
root@wetfish:/mnt/wetfish# ls
backups  wiki
```

## Post install 
To get routers and web services working with SSL certs:
in /opt/web-services/$ENV/treafik find traefik.env and replace the API token with a valid token generated with cloudflair
