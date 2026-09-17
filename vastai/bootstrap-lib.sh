#!/usr/bin/env bash

bootstrap_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
persist_root="${VAST_PERSIST_ROOT:-/workspace}"

bootstrap_log() {
  printf '[bootstrap] %s\n' "$*"
}

bootstrap_require_root_and_isaac() {
  if [[ "${EUID}" -ne 0 ]]; then
    bootstrap_log "run as root inside the official Isaac Sim container"
    return 77
  fi
  if [[ ! -x /isaac-sim/python.sh ]]; then
    bootstrap_log "/isaac-sim/python.sh was not found; use the documented NVIDIA image"
    return 66
  fi
}

bootstrap_apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends "$@"
  rm -rf /var/lib/apt/lists/*
}

bootstrap_checkout() {
  local repository="$1"
  local revision="$2"
  local destination="$3"

  mkdir -p "${destination}"
  if [[ ! -d "${destination}/.git" ]]; then
    git -C "${destination}" init
    git -C "${destination}" remote add origin "${repository}"
  fi

  for attempt in 1 2 3; do
    if GIT_LFS_SKIP_SMUDGE=1 git -C "${destination}" -c http.version=HTTP/1.1 \
      fetch --depth 1 origin "${revision}"; then
      break
    fi
    if [[ "${attempt}" == 3 ]]; then
      bootstrap_log "failed to fetch ${repository}@${revision}"
      return 69
    fi
    sleep $((attempt * 10))
  done

  git -C "${destination}" checkout --detach --force FETCH_HEAD
}

bootstrap_install_helpers() {
  local project="$1"

  mkdir -p /opt/vast-isaac
  install -m 0644 "${bootstrap_repo_root}/docker/common/isaac-usd-smoke.py" \
    /opt/vast-isaac/isaac-usd-smoke.py
  install -m 0644 "${bootstrap_repo_root}/LICENSE" /opt/vast-isaac/LICENSE
  install -m 0644 "${bootstrap_repo_root}/THIRD_PARTY_NOTICES.md" \
    /opt/vast-isaac/THIRD_PARTY_NOTICES.md

  install -m 0755 "${bootstrap_repo_root}/docker/common/vast-init.sh" /usr/local/bin/vast-init
  install -m 0755 "${bootstrap_repo_root}/docker/common/isaac-python.sh" /usr/local/bin/isaac-python
  install -m 0755 "${bootstrap_repo_root}/docker/common/isaacsim-headless.sh" /usr/local/bin/isaacsim-headless
  install -m 0755 "${bootstrap_repo_root}/docker/common/isaacsim-webrtc.sh" /usr/local/bin/isaacsim-webrtc
  install -m 0755 "${bootstrap_repo_root}/docker/common/isaac-usd-smoke.sh" /usr/local/bin/isaac-usd-smoke
  install -m 0755 "${bootstrap_repo_root}/docker/common/verify-gpu.sh" /usr/local/bin/verify-gpu

  if [[ "${project}" == "labutopia" ]]; then
    install -m 0755 "${bootstrap_repo_root}/docker/labutopia/labutopia-run.sh" \
      /usr/local/bin/labutopia-run
  fi

  cat > /etc/profile.d/vast-isaac.sh <<EOF
export OMNI_KIT_ALLOW_ROOT=1
export ISAACSIM_PATH=/isaac-sim
export VAST_PERSIST_ROOT=${persist_root}
export MATTERIX_PATH=/opt/matterix
export ISAACLAB_PATH=/opt/matterix
export LABUTOPIA_PATH=/opt/labutopia
export PATH=/usr/local/bin:\$PATH
EOF

  /usr/local/bin/vast-init
}

bootstrap_write_marker() {
  local project="$1"
  local revision="$2"
  mkdir -p "${persist_root}/.setup"
  printf '%s\n' "${revision}" > "${persist_root}/.setup/${project}.ready"
}

bootstrap_marker_matches() {
  local project="$1"
  local revision="$2"
  [[ -f "${persist_root}/.setup/${project}.ready" ]] && \
    [[ "$(cat "${persist_root}/.setup/${project}.ready")" == "${revision}" ]]
}
