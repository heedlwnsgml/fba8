#!/usr/bin/env bash
set -euo pipefail
umask 077
here=$(cd "$(dirname "$0")" && pwd)
base=${TP_K8S_ROOT:-/opt/travelplanner/k8s}
export KUBECONFIG="$base/kubeconfig"
mkdir -p "$base/shared" "$base/rendered"
if kind get clusters 2>/dev/null | grep -qx travelplanner; then
  kubectl --request-timeout=10s cluster-info >/dev/null
  echo CLUSTER_CHANGED=0
else
  kind create cluster --name travelplanner --config "$here/kind-config.yml" --kubeconfig "$KUBECONFIG" --wait 240s
  docker update --memory=5g --memory-swap=6g --cpus=4 travelplanner-control-plane >/dev/null
  echo CLUSTER_CHANGED=1
fi
if [[ $(docker inspect travelplanner-control-plane --format '{{.HostConfig.RestartPolicy.Name}}') != unless-stopped ]]; then
  docker update --restart=unless-stopped travelplanner-control-plane >/dev/null
fi
kubectl config set-context kind-travelplanner --namespace=travelplanner >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=180s
