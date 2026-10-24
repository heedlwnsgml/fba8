#!/usr/bin/env bash
set -euo pipefail
serial=${1:?Specify the Android device serial}
while true; do
    if adb -s "$serial" get-state >/dev/null 2>&1; then
        if ! adb -s "$serial" reverse --list 2>/dev/null | grep -Eq 'tcp:8080[[:space:]]+tcp:8080$'; then
            adb -s "$serial" reverse tcp:8080 tcp:8080
        fi
    fi
    sleep 3
done
