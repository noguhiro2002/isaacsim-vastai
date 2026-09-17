#!/usr/bin/env bash
set -Eeuo pipefail

target="${1:-}"
case "${target}" in
  matterix|labutopia) ;;
  *)
    echo "usage: bootstrap.sh <matterix|labutopia>" >&2
    exit 64
    ;;
esac

if [[ "${EUID}" -ne 0 ]]; then
  echo "[bootstrap] run as root inside the official Isaac Sim container" >&2
  exit 77
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates git
rm -rf /var/lib/apt/lists/*

repo_url="${VAST_ISAAC_BOOTSTRAP_REPOSITORY:-https://github.com/noguhiro2002/isaacsim-vastai.git}"
repo_ref="${VAST_ISAAC_BOOTSTRAP_REF:-main}"
repo_root="${VAST_ISAAC_BOOTSTRAP_PATH:-/opt/isaacsim-vastai}"

mkdir -p "${repo_root}"
if [[ ! -d "${repo_root}/.git" ]]; then
  git -C "${repo_root}" init
  git -C "${repo_root}" remote add origin "${repo_url}"
fi

for attempt in 1 2 3; do
  if git -C "${repo_root}" -c http.version=HTTP/1.1 fetch --depth 1 origin "${repo_ref}"; then
    break
  fi
  if [[ "${attempt}" == 3 ]]; then
    echo "[bootstrap] failed to fetch ${repo_url}@${repo_ref}" >&2
    exit 69
  fi
  sleep $((attempt * 10))
done

git -C "${repo_root}" checkout --detach --force FETCH_HEAD
exec bash "${repo_root}/vastai/install-${target}.sh"
