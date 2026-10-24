#!/usr/bin/env bash
set -euo pipefail
base=${TP_DEPLOY_ROOT:-/opt/travelplanner}
previous=${1:-$(basename "$(readlink -f "$base/previous" 2>/dev/null || true)")}
[[ -n "$previous" ]] || { echo 'No previous release exists' >&2; exit 1; }
exec "$base/releases/$previous/deploy/scripts/deploy.sh" "$previous"
