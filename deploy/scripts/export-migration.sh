#!/usr/bin/env bash
# A protected private backup, NOT a Docker image and NOT suitable for GitHub.
set -euo pipefail
umask 077
base=${TP_DEPLOY_ROOT:-/opt/travelplanner}
release=$(readlink -f "$base/current")
out=${1:?Usage: export-migration.sh NEW_OUTPUT_DIRECTORY}
[[ ! -e "$out" ]] || { echo 'Output must not already exist' >&2; exit 2; }
test -s "$release/images.lock.env"
shared=$(sed -n 's/^TP_SHARED_DIR=//p' "$release/release.env")
shared=${shared:-$base/shared}
mkdir -p "$out/database-init" "$out/runtime"
compose() { docker compose --project-name "${TP_COMPOSE_PROJECT:-travelplanner}" --env-file "$release/release.env" --env-file "$release/images.lock.env" -f "$release/deploy/compose.yaml" "$@"; }
# Stop writers before exporting SQL and SQLite files; resume even if export fails.
compose stop backend
trap 'compose start backend >/dev/null' EXIT
compose exec -T database sh -ec 'export MYSQL_PWD=$(cat /run/secrets/db_root_password); exec mariadb-dump -uroot --single-transaction --routines --events --triggers --hex-blob --databases test_planner_20261019_update test_planner_app_metadata test_planner_collected_passes_20261012' | gzip > "$out/database-init/10-application.sql.gz"
cp -a "$shared/data" "$shared/config" "$shared/secrets" "$out/runtime/"
# Never copy MariaDB physical files: logical dump is portable across host filesystems.
cp -a "$release/deploy" "$out/"
cp "$release/release.env" "$release/images.lock.env" "$out/"
cp "$release/deploy/database/90-create-app-user.sh" "$out/database-init/90-create-app-user.sh"
(cd "$out"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
echo 'Private migration directory created. Transfer through an encrypted channel/storage.'
