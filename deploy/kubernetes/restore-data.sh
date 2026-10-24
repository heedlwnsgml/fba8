#!/usr/bin/env bash
# Restore a private portable backup into a NEW Kubernetes data directory.
set -euo pipefail
umask 077
source_dir=${1:-/import}
shared=${TP_K8S_ROOT:-/opt/travelplanner/k8s}/shared
[[ -s "$source_dir/SHA256SUMS" ]] || exit 2
(cd "$source_dir"; sha256sum -c SHA256SUMS >/dev/null)
mkdir -p "$shared"
[[ -z "$(find "$shared" -mindepth 1 -maxdepth 1 -print -quit)" ]] || { echo 'Existing data found; restore refused' >&2; exit 3; }
cp -a "$source_dir/runtime/". "$shared/"
cp -a "$source_dir/database-init" "$shared/"
mkdir "$shared/mariadb"
chown root:root "$shared/secrets/"*
chmod 0700 "$shared" "$shared/secrets"
chmod 0600 "$shared/secrets/"*
chmod 0755 "$shared/database-init"
find "$shared/database-init" -type f -exec chmod 0444 {} +
chown -R 10001:10001 "$shared/data" "$shared/config"
echo K8S_DATA_RESTORED
