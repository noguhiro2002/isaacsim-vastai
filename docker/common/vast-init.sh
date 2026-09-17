#!/usr/bin/env bash
set -Eeuo pipefail

persist_root="${VAST_PERSIST_ROOT:-/workspace}"

mkdir -p \
  "${persist_root}/cache/ov" \
  "${persist_root}/cache/pip" \
  "${persist_root}/cache/nvidia/GLCache" \
  "${persist_root}/cache/nvidia/ComputeCache" \
  "${persist_root}/logs" \
  "${persist_root}/output" \
  "${persist_root}/user"

chmod 1777 "${persist_root}" 2>/dev/null || true

link_persistent_dir() {
  local target_path="$1"
  local link_path="$2"

  mkdir -p "${target_path}" "$(dirname "${link_path}")"
  if [[ -L "${link_path}" ]]; then
    ln -sfn "${target_path}" "${link_path}"
  elif [[ -d "${link_path}" && -z "$(ls -A "${link_path}" 2>/dev/null)" ]]; then
    rmdir "${link_path}"
    ln -s "${target_path}" "${link_path}"
  elif [[ ! -e "${link_path}" ]]; then
    ln -s "${target_path}" "${link_path}"
  else
    echo "[vast-init] keeping non-empty path: ${link_path}" >&2
  fi
}

link_persistent_dir "${persist_root}/cache/ov" /root/.cache/ov
link_persistent_dir "${persist_root}/cache/isaac-main" /isaac-sim/.cache
link_persistent_dir "${persist_root}/cache/nvidia/ComputeCache" /root/.nv/ComputeCache
link_persistent_dir "${persist_root}/cache/nvidia/ComputeCache" /isaac-sim/.nv/ComputeCache
link_persistent_dir "${persist_root}/cache/kit" /isaac-sim/kit/cache
link_persistent_dir "${persist_root}/logs/omniverse" /root/.nvidia-omniverse/logs
link_persistent_dir "${persist_root}/logs/omniverse" /isaac-sim/.nvidia-omniverse/logs
link_persistent_dir "${persist_root}/config" /root/.nvidia-omniverse/config
link_persistent_dir "${persist_root}/config" /isaac-sim/.nvidia-omniverse/config
link_persistent_dir "${persist_root}/data" /root/.local/share/ov/data
link_persistent_dir "${persist_root}/data" /isaac-sim/.local/share/ov/data
link_persistent_dir "${persist_root}/pkg" /root/.local/share/ov/pkg
link_persistent_dir "${persist_root}/pkg" /isaac-sim/.local/share/ov/pkg
link_persistent_dir "${persist_root}/cache/ov/hub" /var/cache/hub

echo "[vast-init] persistent root: ${persist_root}"
echo "[vast-init] output directory: ${persist_root}/output"

