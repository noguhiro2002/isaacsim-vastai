#!/usr/bin/env bash
set -Eeuo pipefail

/usr/local/bin/vast-init

if [[ $# -gt 0 ]]; then
  exec "$@"
fi

case "${AUTO_START:-idle}" in
  idle)
    echo "[entrypoint] Ready. AUTO_START=idle; keeping the container alive."
    exec tail -f /dev/null
    ;;
  headless)
    exec /usr/local/bin/isaacsim-headless
    ;;
  webrtc)
    exec /usr/local/bin/isaacsim-webrtc
    ;;
  usd-smoke)
    exec /usr/local/bin/isaac-usd-smoke
    ;;
  *)
    echo "[entrypoint] Unknown AUTO_START=${AUTO_START}" >&2
    exit 64
    ;;
esac

