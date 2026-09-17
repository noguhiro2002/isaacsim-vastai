#!/usr/bin/env bash
set -Eeuo pipefail
exec /usr/local/bin/isaac-python /opt/vast-isaac/isaac-usd-smoke.py "$@"

