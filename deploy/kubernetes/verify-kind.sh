#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${TP_K8S_ROOT:-/opt/travelplanner/k8s}/kubeconfig"
kubectl -n travelplanner rollout status statefulset/database --timeout=300s
kubectl -n travelplanner rollout status deployment/backend --timeout=300s
kubectl -n travelplanner rollout status deployment/frontend --timeout=180s
curl --fail --silent --show-error --max-time 5 --retry 60 --retry-delay 2 --retry-max-time 180 --retry-connrefused --retry-all-errors http://127.0.0.1:18080/api/v1/auth/health/ready >/dev/null
curl --fail --silent --show-error --max-time 5 --retry 60 --retry-delay 2 --retry-max-time 180 --retry-connrefused --retry-all-errors http://127.0.0.1:18081/healthz >/dev/null
curl --fail --silent --show-error --max-time 5 --retry 60 --retry-delay 2 --retry-max-time 180 --retry-connrefused --retry-all-errors http://127.0.0.1:18081/api/v1/auth/health/ready >/dev/null
kubectl -n travelplanner get pods -o wide
echo K8S_HEALTH_OK
