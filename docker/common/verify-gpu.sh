#!/usr/bin/env bash
set -Eeuo pipefail

nvidia-smi

if ! ldconfig -p 2>/dev/null | grep -q 'libnvidia-encode'; then
  echo "[verify-gpu] libnvidia-encode is not visible. Headless compute may work, but WebRTC/NVENC will not." >&2
  exit 0
fi

echo "[verify-gpu] GPU and NVENC runtime are visible."

