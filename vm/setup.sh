#!/usr/bin/env bash
set -Eeuo pipefail

target="${1:-}"
case "${target}" in
  matterix|labutopia) ;;
  *)
    echo "usage: sudo NVIDIA_ACCEPT_EULA=Y bash vm/setup.sh <matterix|labutopia>" >&2
    exit 64
    ;;
esac

if [[ "${EUID}" -ne 0 ]]; then
  echo "[vm-setup] run this script as root (normally with sudo)" >&2
  exit 77
fi

if [[ "${NVIDIA_ACCEPT_EULA:-}" != "Y" ]]; then
  cat >&2 <<'EOF'
[vm-setup] Review the NVIDIA Isaac Sim and Omniverse license terms first.
[vm-setup] Re-run with NVIDIA_ACCEPT_EULA=Y only after accepting them.
EOF
  exit 78
fi

if [[ "${target}" == "labutopia" ]] && \
  [[ "${LABUTOPIA_ACCEPT_CC_BY_NC_4_0:-}" != "Y" ]]; then
  cat >&2 <<'EOF'
[vm-setup] LabUtopia data assets are CC BY-NC 4.0.
[vm-setup] For accepted non-commercial research/education use, re-run with
[vm-setup] LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y.
EOF
  exit 78
fi

if [[ ! -r /etc/os-release ]]; then
  echo "[vm-setup] /etc/os-release was not found" >&2
  exit 69
fi

source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]] || \
  [[ "${VERSION_ID:-}" != "22.04" && "${VERSION_ID:-}" != "24.04" ]]; then
  echo "[vm-setup] supported host OS: Ubuntu 22.04 or 24.04; found ${PRETTY_NAME:-unknown}" >&2
  exit 69
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "[vm-setup] only x86_64 Vast.ai VMs are currently supported" >&2
  exit 69
fi

log() {
  printf '[vm-setup] %s\n' "$*"
}

on_error() {
  local exit_code="$?"
  log "failed at line ${BASH_LINENO[0]} (exit ${exit_code})"
  exit "${exit_code}"
}
trap on_error ERR

vm_root="${ISAAC_VM_ROOT:-/srv/isaacsim-vastai}"
source_root="${ISAAC_VM_SOURCE_ROOT:-/opt/isaacsim-vastai-source}"
repository="${ISAACSIM_VASTAI_REPOSITORY:-https://github.com/noguhiro2002/isaacsim-vastai.git}"
repository_ref="${ISAACSIM_VASTAI_REF:-main}"
container_name="${ISAAC_VM_CONTAINER_NAME:-isaacsim-vm-${target}}"
enable_webrtc="${ENABLE_WEBRTC:-Y}"
firewall_tailscale_only="${FIREWALL_TAILSCALE_ONLY:-Y}"
force_recreate="${FORCE_RECREATE:-N}"
setup_timeout="${SETUP_TIMEOUT_SECONDS:-7200}"
stream_timeout="${STREAM_TIMEOUT_SECONDS:-1800}"

case "${enable_webrtc}" in Y|N) ;; *) echo "[vm-setup] ENABLE_WEBRTC must be Y or N" >&2; exit 64 ;; esac
case "${firewall_tailscale_only}" in Y|N) ;; *) echo "[vm-setup] FIREWALL_TAILSCALE_ONLY must be Y or N" >&2; exit 64 ;; esac
case "${force_recreate}" in Y|N) ;; *) echo "[vm-setup] FORCE_RECREATE must be Y or N" >&2; exit 64 ;; esac
if [[ ! "${setup_timeout}" =~ ^[1-9][0-9]*$ ]] || \
  [[ ! "${stream_timeout}" =~ ^[1-9][0-9]*$ ]]; then
  echo "[vm-setup] timeout values must be positive integers" >&2
  exit 64
fi

case "${target}" in
  matterix)
    isaac_image="${ISAAC_SIM_IMAGE:-nvcr.io/nvidia/isaac-sim:6.0.1}"
    ;;
  labutopia)
    isaac_image="${ISAAC_SIM_IMAGE:-nvcr.io/nvidia/isaac-sim:5.1.0}"
    ;;
esac

log "checking NVIDIA GPU passthrough"
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "[vm-setup] nvidia-smi is missing; use a Vast.ai GPU VM with its NVIDIA driver installed" >&2
  exit 66
fi
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

log "installing host prerequisites"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git gnupg iproute2 iptables

if ! command -v docker >/dev/null 2>&1; then
  log "installing Docker from Ubuntu"
  apt-get install -y --no-install-recommends docker.io
fi
systemctl enable --now docker

if ! command -v nvidia-ctk >/dev/null 2>&1; then
  log "installing NVIDIA Container Toolkit"
  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update
  apt-get install -y --no-install-recommends nvidia-container-toolkit
fi
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

if ! command -v tailscale >/dev/null 2>&1; then
  log "installing Tailscale"
  tailscale_installer="$(mktemp)"
  curl -fsSL https://tailscale.com/install.sh -o "${tailscale_installer}"
  bash "${tailscale_installer}"
  rm -f "${tailscale_installer}"
fi
systemctl enable --now tailscaled

default_tailscale_hostname="vast-isaac-$(hostname | tr -cs '[:alnum:]-' '-' | sed 's/-$//')"
tailscale_hostname="${TAILSCALE_HOSTNAME:-${default_tailscale_hostname}}"
if ! tailscale ip -4 >/dev/null 2>&1; then
  tailscale_args=(up --hostname="${tailscale_hostname}" --accept-dns=false)
  if [[ "${TAILSCALE_SSH:-N}" == "Y" ]]; then
    tailscale_args+=(--ssh)
  fi
  if [[ -n "${TS_AUTHKEY:-}" ]]; then
    log "joining the tailnet with the supplied one-time auth key"
    tailscale_args+=(--auth-key="${TS_AUTHKEY}")
  else
    log "Tailscale authentication is required; open the URL printed below"
  fi
  tailscale "${tailscale_args[@]}"
fi
unset TS_AUTHKEY || true

tailscale_ip="$(tailscale ip -4 | head -n 1)"
if [[ -z "${tailscale_ip}" ]]; then
  echo "[vm-setup] Tailscale did not provide an IPv4 address" >&2
  exit 69
fi
log "Tailscale IPv4: ${tailscale_ip}"

log "checking out ${repository}@${repository_ref}"
if [[ -e "${source_root}" && ! -d "${source_root}/.git" ]]; then
  echo "[vm-setup] ${source_root} exists but is not a git checkout; move it and retry" >&2
  exit 73
fi
if [[ ! -d "${source_root}/.git" ]]; then
  git clone --filter=blob:none --no-checkout "${repository}" "${source_root}"
fi
git -C "${source_root}" -c http.version=HTTP/1.1 fetch --depth 1 origin "${repository_ref}"
git -C "${source_root}" checkout --detach --force FETCH_HEAD

install -m 0755 "${source_root}/vm/isaac-vm" /usr/local/bin/isaac-vm
install -m 0755 "${source_root}/vm/tailscale-firewall.sh" \
  /usr/local/sbin/isaac-tailscale-firewall

{
  printf 'ISAAC_VM_CONTAINER_NAME=%q\n' "${container_name}"
  printf 'ISAAC_VM_TARGET=%q\n' "${target}"
  printf 'ISAAC_VM_ROOT=%q\n' "${vm_root}"
  printf 'ISAAC_VM_TAILSCALE_IP=%q\n' "${tailscale_ip}"
  printf 'ISAAC_VM_IMAGE=%q\n' "${isaac_image}"
  printf 'ISAAC_VM_WEBRTC=%q\n' "${enable_webrtc}"
} > /etc/isaacsim-vm.conf
chmod 0644 /etc/isaacsim-vm.conf

cat > /etc/systemd/system/isaac-tailscale-firewall.service <<'EOF'
[Unit]
Description=Restrict Isaac Sim WebRTC ports to Tailscale
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service
Before=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/isaac-tailscale-firewall apply
ExecStop=/usr/local/sbin/isaac-tailscale-firewall remove
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
if [[ "${firewall_tailscale_only}" == "Y" ]]; then
  systemctl enable --now isaac-tailscale-firewall.service
else
  systemctl disable --now isaac-tailscale-firewall.service 2>/dev/null || true
  /usr/local/sbin/isaac-tailscale-firewall remove
fi

workspace_root="${vm_root}/${target}/workspace"
mkdir -p \
  "${workspace_root}/cache" \
  "${workspace_root}/config" \
  "${workspace_root}/data" \
  "${workspace_root}/logs" \
  "${workspace_root}/output" \
  "${workspace_root}/pkg"
chmod 1777 "${workspace_root}"

log "pulling ${isaac_image}; this is the longest download"
docker pull "${isaac_image}"
docker run --rm --gpus all --entrypoint nvidia-smi "${isaac_image}" \
  --query-gpu=name,driver_version,memory.total --format=csv,noheader
if [[ "${enable_webrtc}" == "Y" ]]; then
  log "checking that NVENC is visible inside the container"
  docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    --entrypoint /bin/bash "${isaac_image}" \
    -lc 'ldconfig -p | grep -q libnvidia-encode'
fi

container_exists=N
if docker container inspect "${container_name}" >/dev/null 2>&1; then
  container_exists=Y
fi

if [[ "${container_exists}" == "Y" && "${force_recreate}" == "Y" ]]; then
  log "removing the existing ${container_name} container because FORCE_RECREATE=Y"
  docker rm -f "${container_name}"
  container_exists=N
fi

if [[ "${container_exists}" == "Y" ]]; then
  existing_target="$(docker inspect --format '{{ index .Config.Labels "io.isaacsim-vastai.target" }}' "${container_name}")"
  existing_mode="$(docker inspect --format '{{ index .Config.Labels "io.isaacsim-vastai.webrtc" }}' "${container_name}")"
  existing_image="$(docker inspect --format '{{.Config.Image}}' "${container_name}")"
  existing_network="$(docker inspect --format '{{.HostConfig.NetworkMode}}' "${container_name}")"
  existing_user="$(docker inspect --format '{{.Config.User}}' "${container_name}")"
  existing_public_ip="$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${container_name}" \
    | sed -n 's/^ISAACSIM_PUBLIC_IP=//p' | head -n 1)"
  if [[ "${existing_target}" != "${target}" ]]; then
    echo "[vm-setup] ${container_name} belongs to target ${existing_target}; choose another name" >&2
    exit 73
  fi
  if [[ "${existing_mode}" != "${enable_webrtc}" || \
    "${existing_image}" != "${isaac_image}" || \
    "${existing_network}" != "host" || \
    "${existing_user}" != "root" || \
    "${existing_public_ip}" != "${tailscale_ip}" ]]; then
    cat >&2 <<EOF
[vm-setup] the existing container has different settings.
[vm-setup] existing: image=${existing_image}, ENABLE_WEBRTC=${existing_mode:-unknown}, network=${existing_network}, user=${existing_user:-image-default}, IP=${existing_public_ip:-unknown}
[vm-setup] requested: image=${isaac_image}, ENABLE_WEBRTC=${enable_webrtc}, network=host, user=root, IP=${tailscale_ip}
[vm-setup] re-run with FORCE_RECREATE=Y; persistent /workspace data is retained.
EOF
    exit 73
  fi
  log "reusing existing container ${container_name}"
  docker start "${container_name}" >/dev/null
else
  container_command='exec > >(tee -a /workspace/logs/vm-container.log) 2>&1; '
  container_command+="bash /opt/isaacsim-vastai/vastai/install-${target}.sh; "
  if [[ "${enable_webrtc}" == "Y" ]]; then
    container_command+='exec /usr/local/bin/isaacsim-webrtc'
  else
    container_command+='exec tail -f /dev/null'
  fi

  docker_args=(
    run -d
    --name "${container_name}"
    --hostname "${container_name}"
    --restart unless-stopped
    --network host
    --user root
    --gpus all
    --shm-size 8g
    --ulimit memlock=-1
    --ulimit stack=67108864
    --label "io.isaacsim-vastai.target=${target}"
    --label "io.isaacsim-vastai.webrtc=${enable_webrtc}"
    -e ACCEPT_EULA=Y
    -e OMNI_KIT_ALLOW_ROOT=1
    -e NVIDIA_VISIBLE_DEVICES=all
    -e NVIDIA_DRIVER_CAPABILITIES=all
    -e VAST_PERSIST_ROOT=/workspace
    -e "ISAACSIM_PUBLIC_IP=${tailscale_ip}"
    -e ISAACSIM_SIGNAL_PORT=49100
    -e ISAACSIM_STREAM_PORT=47998
    -v "${workspace_root}:/workspace"
    -v "${source_root}:/opt/isaacsim-vastai:ro"
    --entrypoint /bin/bash
  )
  if [[ "${PRIVACY_CONSENT:-N}" == "Y" ]]; then
    docker_args+=(-e PRIVACY_CONSENT=Y)
  fi
  if [[ "${target}" == "labutopia" ]]; then
    docker_args+=(-e LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y)
  fi
  docker_args+=("${isaac_image}" -lc "${container_command}")

  log "creating ${container_name} with host networking"
  docker "${docker_args[@]}" >/dev/null
fi

marker="${workspace_root}/.setup/${target}.ready"
deadline=$((SECONDS + setup_timeout))
last_notice=0
while [[ ! -s "${marker}" ]]; do
  if [[ "$(docker inspect --format '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" != "true" ]]; then
    echo "[vm-setup] container stopped during setup; recent log follows" >&2
    docker logs --tail 150 "${container_name}" >&2 || true
    exit 70
  fi
  if (( SECONDS >= deadline )); then
    echo "[vm-setup] timed out waiting for ${target} setup" >&2
    docker logs --tail 150 "${container_name}" >&2 || true
    exit 70
  fi
  if (( SECONDS - last_notice >= 30 )); then
    log "project installation is still running; use: isaac-vm logs"
    last_notice="${SECONDS}"
  fi
  sleep 10
done
log "${target} installation completed"

if [[ "${enable_webrtc}" == "Y" ]]; then
  deadline=$((SECONDS + stream_timeout))
  while ! grep -Fq 'Isaac Sim Full Streaming App is loaded.' \
    "${workspace_root}/logs/vm-container.log" 2>/dev/null; do
    if [[ "$(docker inspect --format '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" != "true" ]]; then
      echo "[vm-setup] container stopped while starting WebRTC" >&2
      docker logs --tail 150 "${container_name}" >&2 || true
      exit 70
    fi
    if (( SECONDS >= deadline )); then
      log "WebRTC is still warming up; inspect it with: isaac-vm logs"
      break
    fi
    sleep 10
  done
fi

cat <<EOF

Vast.ai VM setup completed.

  Target:        ${target}
  Container:     ${container_name}
  Tailscale IP:  ${tailscale_ip}
  Persistent:    ${workspace_root}

Mac/Windows/Linux Isaac Sim WebRTC Streaming Client:
  Server: ${tailscale_ip}

Useful commands:
  isaac-vm status
  isaac-vm verify
  isaac-vm logs
  isaac-vm shell
EOF
if [[ "${enable_webrtc}" == "N" ]]; then
  echo "  isaac-vm smoke"
fi
cat <<'EOF'

Keep the client machine connected to the same tailnet. The streaming ports are
restricted to tailscale0 and localhost when FIREWALL_TAILSCALE_ONLY=Y.
EOF
