#!/usr/bin/env bash
set -Eeuo pipefail

identity_signal_request_port="${VAST_IDENTITY_SIGNAL_REQUEST_PORT:-70000}"
identity_stream_request_port="${VAST_IDENTITY_STREAM_REQUEST_PORT:-70001}"
signal_var="VAST_TCP_PORT_${identity_signal_request_port}"
stream_var="VAST_UDP_PORT_${identity_stream_request_port}"

signal_port="${ISAACSIM_SIGNAL_PORT:-${!signal_var:-49100}}"
stream_port="${ISAACSIM_STREAM_PORT:-${!stream_var:-47998}}"
public_ip="${ISAACSIM_PUBLIC_IP:-${PUBLIC_IPADDR:-}}"

if [[ -z "${public_ip}" ]]; then
  public_ip="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"
fi

if [[ -z "${public_ip}" ]]; then
  echo "[webrtc] Public IP could not be detected. Set ISAACSIM_PUBLIC_IP." >&2
  exit 65
fi

echo "[webrtc] public IP: ${public_ip}"
echo "[webrtc] signaling: ${signal_port}/tcp"
echo "[webrtc] media: ${stream_port}/udp"
echo "[webrtc] This bridge-network path is experimental on Vast.ai; headless mode is the supported fallback."

isaac_version="$(head -n 1 /isaac-sim/VERSION 2>/dev/null || true)"
if [[ "${isaac_version}" == 5.* ]]; then
  if [[ -n "${!stream_var:-}" || "${stream_port}" != "47998" ]]; then
    echo "[webrtc] Isaac Sim 5.1 fixes WebRTC media to UDP 47998; Vast identity-port remapping is unavailable." >&2
    echo "[webrtc] Use headless mode on Vast.ai, or host networking outside Vast.ai." >&2
    exit 78
  fi
  stream_args=(
    "--/app/livestream/publicEndpointAddress=${public_ip}"
    "--/app/livestream/port=${signal_port}"
  )
else
  stream_args=(
    "--/exts/omni.kit.livestream.app/primaryStream/publicIp=${public_ip}"
    "--/exts/omni.kit.livestream.app/primaryStream/signalPort=${signal_port}"
    "--/exts/omni.kit.livestream.app/primaryStream/streamPort=${stream_port}"
  )
fi

if [[ -x /isaac-sim/runheadless.sh ]]; then
  cd /isaac-sim
  exec ./runheadless.sh "${stream_args[@]}" "$@"
fi

exec python3 -m isaacsim isaacsim.exp.full.streaming --no-window \
  "${stream_args[@]}" "$@"

