#!/usr/bin/env bash
set -euo pipefail
umask 077
source_dir=$(realpath "${1:?Usage: import-migration.sh BACKUP_DIRECTORY RELEASE_ID}")
release=${2:?Specify a new release ID}
[[ "$release" =~ ^[a-zA-Z0-9._-]+$ ]] || exit 2
base=${TP_DEPLOY_ROOT:-/opt/travelplanner}
target="$base/releases/$release"
# Require empty destination. Never replace a running or existing DB/config.
[[ ! -e "$base/shared" && ! -e "$target" ]] || { echo 'Destination already contains data; import refused' >&2; exit 3; }
(cd "$source_dir"; sha256sum -c SHA256SUMS >/dev/null)
mkdir -p "$target" "$base/shared"
cp -a "$source_dir/runtime/". "$base/shared/"
cp -a "$source_dir/database-init" "$base/shared/"
mkdir "$base/shared/mariadb"
# MariaDB entrypoint runs initialization as mysql, so readonly init files must be readable there.
chmod 0755 "$base/shared/database-init"
find "$base/shared/database-init" -type f -exec chmod 0444 {} +
cp -a "$source_dir/deploy" "$target/"
cp "$source_dir/images.lock.env" "$target/"
# Pin the exact image digests and keep host-specific paths out of imported config.
sed '/^TP_SHARED_DIR=/d; /^BACKEND_IMAGE=/d; /^FRONTEND_IMAGE=/d; /^DATABASE_IMAGE=/d' "$source_dir/release.env" > "$target/release.env"
cat "$target/images.lock.env" >> "$target/release.env"
printf '\nTP_SHARED_DIR=%s/shared\n' "$base" >> "$target/release.env"
chmod 700 "$base/shared/secrets"
chmod 0444 "$base/shared/secrets/"*
# Parent 0700 protects host access; readonly bind secrets are readable by service UIDs.
chown -R 10001:10001 "$base/shared/data"
chmod -R u+rwX,go-rwx "$base/shared/config"
# The backend UID must be able to read its configuration, but no other user may.
chown -R 10001:10001 "$base/shared/config"
bash "$target/deploy/scripts/pull-images.sh"
bash "$target/deploy/scripts/deploy.sh" "$release"
