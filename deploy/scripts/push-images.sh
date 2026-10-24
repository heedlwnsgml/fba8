#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
set -a; source release.env; set +a
: "${BACKEND_IMAGE:?}" "${FRONTEND_IMAGE:?}"
# Authenticate beforehand using docker login --password-stdin. Never embed credentials.
docker push "$BACKEND_IMAGE"
docker push "$FRONTEND_IMAGE"
# Include the exact DB image too: future machines must use this same version/digest.
database_image=${DATABASE_IMAGE:-mariadb:10.11}
docker pull "$database_image"
lock=$(mktemp)
trap 'rm -f "$lock"' EXIT
for pair in "BACKEND_IMAGE=$BACKEND_IMAGE" "FRONTEND_IMAGE=$FRONTEND_IMAGE" "DATABASE_IMAGE=$database_image"; do
 name=${pair%%=*}; image=${pair#*=}
 digest=$(docker image inspect "$image" --format '{{index .RepoDigests 0}}')
 [[ "$digest" == *@sha256:* ]] || { echo "Missing registry digest: $name" >&2; exit 1; }
 printf '%s=%s\n' "$name" "$digest" >> "$lock"
done
mv "$lock" images.lock.env
printf 'Registry uploads finished; immutable image references: images.lock.env\n'
