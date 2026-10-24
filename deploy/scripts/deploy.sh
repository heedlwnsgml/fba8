#!/usr/bin/env bash
set -euo pipefail
umask 077
base=${TP_DEPLOY_ROOT:-/opt/travelplanner}
release=${1:?Usage: deploy.sh RELEASE_ID}
[[ "$release" =~ ^[a-zA-Z0-9._-]+$ ]] || exit 2
target="$base/releases/$release"
test -f "$target/deploy/compose.yaml"
test -f "$target/release.env"
mkdir -p "$base/state" "$base/backups"
exec 9>"$base/state/deploy.lock"
flock -n 9 || { echo 'Another deployment is running' >&2; exit 3; }
previous=""
if [[ -L "$base/current" ]]; then previous=$(readlink -f "$base/current"); fi
if [[ "$previous" == "$target" ]] && "$target/deploy/scripts/health.sh" >/dev/null 2>&1; then
    echo 'DEPLOY_CHANGED=0'; exit 0
fi
compose() {
    local target_release="$1"; shift
    local args=(--project-name "${TP_COMPOSE_PROJECT:-travelplanner}" --env-file "$target_release/release.env")
    if [[ -s "$target_release/images.lock.env" ]]; then args+=(--env-file "$target_release/images.lock.env"); fi
    docker compose "${args[@]}" -f "$target_release/deploy/compose.yaml" "$@"
}
compose "$target" config --quiet
# Image availability is checked before touching running services.
while IFS= read -r image; do docker image inspect "$image" >/dev/null; done < <(compose "$target" config --images)
if [[ -n "$previous" ]]; then
    test -f "$previous/release.env"
    cp "$previous/release.env" "$base/backups/release-before-$(date +%Y%m%d%H%M%S).env"
fi
restore_previous() {
    echo 'Deployment failed; restoring previous application images' >&2
    if [[ -n "$previous" ]]; then
        compose "$previous" up -d --wait --wait-timeout 240
        "$previous/deploy/scripts/health.sh"
    fi
}
if ! compose "$target" up -d --wait --wait-timeout 240 || ! "$target/deploy/scripts/health.sh"; then
    restore_previous
    exit 1
fi
if [[ -n "$previous" && "$previous" != "$target" ]]; then
    ln -sfn "$previous" "$base/previous"
fi
ln -sfn "$target" "$base/current"
printf '%s\n' "$release" > "$base/state/current-release"
echo 'DEPLOY_CHANGED=1'
