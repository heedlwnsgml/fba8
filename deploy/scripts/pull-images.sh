#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test -s images.lock.env || { echo 'Missing verified registry lock file' >&2; exit 1; }
# Only accept the three image entries, not executable shell input.
while IFS='=' read -r name image; do
 [[ "$name" =~ ^(BACKEND_IMAGE|FRONTEND_IMAGE|DATABASE_IMAGE)$ ]] || exit 2
 [[ "$image" =~ ^[a-zA-Z0-9./:_-]+@sha256:[a-f0-9]{64}$ ]] || exit 2
 docker pull "$image"
done < images.lock.env
# Compose accepts repeated --env-file; this override pins images for deployment.
echo 'Image download complete. deploy.sh automatically uses images.lock.env.'
