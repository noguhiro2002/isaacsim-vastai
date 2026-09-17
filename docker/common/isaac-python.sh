#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -x /isaac-sim/python.sh ]]; then
  exec /isaac-sim/python.sh "$@"
fi

exec python3 "$@"

