#!/usr/bin/env bash
set -euo pipefail
umask 077
here=$(cd "$(dirname "$0")" && pwd)
base=${TP_K8S_ROOT:-/opt/travelplanner/k8s}
export KUBECONFIG="$base/kubeconfig"
lock=${TP_IMAGES_LOCK:-$(cd "$here/../.." && pwd)/images.lock.env}
[[ -s "$lock" && -s "$base/shared/config/application-secret.yml" ]] || { echo 'Provide image lock and private runtime data first' >&2; exit 2; }
python3 "$here/render-kind.py" "$here/application.yml" "$lock" "$base/rendered/application.yml"
kubectl apply -f "$here/namespace.yml"
# Private values never enter a shell argument or log.
kubectl -n travelplanner create secret generic planner-db \
  --from-file=db_password="$base/shared/secrets/db-password" \
  --from-file=db_root_password="$base/shared/secrets/db-root-password" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n travelplanner create secret generic planner-config \
  --from-file=application-secret.yml="$base/shared/config/application-secret.yml" \
  --from-file=application-docker.properties="$base/shared/config/application-docker.properties" --dry-run=client -o yaml | kubectl apply -f -
# Keep an existing successful manifest so a later failed update can restore it.
if [[ -f "$base/last-good.yml" ]]; then cp "$base/last-good.yml" "$base/previous-good.yml"; fi
if ! kubectl apply -f "$base/rendered/application.yml" || ! "$here/verify-kind.sh"; then
  if [[ -f "$base/previous-good.yml" ]]; then
    kubectl apply -f "$base/previous-good.yml"
    "$here/verify-kind.sh"
  fi
  exit 1
fi
cp "$base/rendered/application.yml" "$base/last-good.yml"
echo K8S_DEPLOY_OK
