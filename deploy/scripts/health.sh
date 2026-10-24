#!/usr/bin/env bash
set -euo pipefail
api=${TP_HEALTH_API_URL:-http://127.0.0.1:8080}
web=${TP_HEALTH_WEB_URL:-http://127.0.0.1:8081}
curl --fail --silent --show-error --max-time 8 "$api/api/v1/auth/health/ready" >/dev/null
curl --fail --silent --show-error --max-time 8 "$web/healthz" >/dev/null
echo 'HEALTH_OK=1'
