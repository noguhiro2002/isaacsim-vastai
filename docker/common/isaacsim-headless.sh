#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -x /isaac-sim/isaac-sim.sh ]]; then
  exec /isaac-sim/isaac-sim.sh \
    --no-window \
    --/app/window/enabled=false \
    --/app/livestream/enabled=false \
    "$@"
fi

exec python3 -m isaacsim isaacsim.exp.full \
  --no-window \
  --/app/window/enabled=false \
  --/app/livestream/enabled=false \
  "$@"

