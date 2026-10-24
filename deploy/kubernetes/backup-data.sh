#!/usr/bin/env bash
set -euo pipefail
umask 077
base=${TP_K8S_ROOT:-/opt/travelplanner/k8s}
export KUBECONFIG="$base/kubeconfig"
out=${1:?Usage: backup-data.sh NEW_PRIVATE_DIRECTORY}
[[ ! -e "$out" ]] || { echo 'Backup already exists' >&2; exit 2; }
replicas=$(kubectl -n travelplanner get deployment backend -o jsonpath='{.spec.replicas}')
mkdir -p "$out/runtime" "$out/database-init"
trap 'kubectl -n travelplanner scale deployment backend --replicas="$replicas" >/dev/null' EXIT
kubectl -n travelplanner scale deployment backend --replicas=0 >/dev/null
kubectl -n travelplanner wait --for=delete pod -l app=backend --timeout=120s >/dev/null
kubectl -n travelplanner exec database-0 -- sh -ec 'export MYSQL_PWD=$(cat /run/secrets/db_root_password); exec mariadb-dump -uroot --single-transaction --routines --events --triggers --hex-blob --databases test_planner_20261019_update test_planner_app_metadata test_planner_collected_passes_20261012' | gzip > "$out/database-init/10-application.sql.gz"
cp -a "$base/shared/data" "$base/shared/config" "$base/shared/secrets" "$out/runtime/"
cp /opt/travelplanner-deploy/deploy/database/90-create-app-user.sh "$out/database-init/90-create-app-user.sh"
cp /opt/travelplanner-deploy/images.lock.env "$out/"
(cd "$out"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
echo K8S_PRIVATE_BACKUP_OK
