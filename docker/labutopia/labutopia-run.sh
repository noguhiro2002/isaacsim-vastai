#!/usr/bin/env bash
set -Eeuo pipefail
cd "${LABUTOPIA_PATH:-/opt/labutopia}"
exec /usr/local/bin/isaac-python main.py "$@"

