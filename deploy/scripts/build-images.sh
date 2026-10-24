#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test -f release.env
set -a; source release.env; set +a
: "${BACKEND_IMAGE:?}" "${FRONTEND_IMAGE:?}"
test -f A5front/build/web/index.html
DOCKER_BUILDKIT=1 docker build --pull -t "$BACKEND_IMAGE" TravelPlanner_Backend
DOCKER_BUILDKIT=1 docker build --pull -t "$FRONTEND_IMAGE" A5front
docker image inspect "$BACKEND_IMAGE" "$FRONTEND_IMAGE" --format '{{.Id}} {{.Size}} {{json .RepoTags}}'
