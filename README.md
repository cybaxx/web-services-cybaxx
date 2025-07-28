# production-manifests
contains traefik config and submodules for docker compose based deployments

This branch of the repo is for the 2023 new prod server deployment, \
however it also contains the traefik configuration for the staging deployments \
of wiki and fourms. These are attached to the same traefik-backend network.

## How do I get started?

```bash
# install docker and docker-compose-plugin
# https://docs.docker.com/engine/install/debian/

# create traefik backend network
docker network create traefik-backend

# clone the repo (recursively)
cd /opt

export REPO_DIR="$(cd "/opt" || exit 1; pwd)/production-manifests"

git clone \
  --branch prod-2023 \
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
services/blog/config.js

# danger: database
services/danger/db

# wetfishonline: database, fish/equpipment
services/online/db
services/online/storage

# wiki: database, user uploads
services/wiki/db
services/wiki/upload # mounted over nfs to storage server
```
