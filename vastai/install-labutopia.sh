#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap-lib.sh"

bootstrap_require_root_and_isaac

if [[ "${LABUTOPIA_ACCEPT_CC_BY_NC_4_0:-}" != "Y" ]]; then
  cat >&2 <<'EOF'
[bootstrap] LabUtopia data assets are licensed under CC BY-NC 4.0.
[bootstrap] Set LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y only for a non-commercial
[bootstrap] research or educational use after reviewing the upstream terms.
EOF
  exit 78
fi

labutopia_repository="${LABUTOPIA_REPOSITORY:-https://github.com/Rui-li023/LabUtopia.git}"
labutopia_ref="${LABUTOPIA_REF:-8df72784265c375a327ffa3f0a0cf8c676f229a7}"
labutopia_path="${LABUTOPIA_PATH:-/opt/labutopia}"
labutopia_integration_revision="${labutopia_ref}:webrtc-v2"

bootstrap_install_helpers labutopia

if bootstrap_marker_matches labutopia "${labutopia_integration_revision}" && \
  [[ -d "${labutopia_path}/.git" ]]; then
  bootstrap_log "LabUtopia ${labutopia_ref} is already installed"
  exit 0
fi

bootstrap_apt_install \
  build-essential ca-certificates curl ffmpeg git git-lfs libglib2.0-0

bootstrap_checkout "${labutopia_repository}" "${labutopia_ref}" "${labutopia_path}"
git -C "${labutopia_path}" lfs install --local
git -C "${labutopia_path}" lfs pull
# The pinned upstream main.py uses CRLF and trailing spaces. Normalize both so
# the maintained patch applies deterministically in Docker and runtime paths.
sed -i 's/[[:space:]]\+$//' "${labutopia_path}/main.py"

patch_file="${bootstrap_repo_root}/docker/labutopia/labutopia-headless.patch"
patch_options=(--ignore-space-change --ignore-whitespace)
if git -C "${labutopia_path}" apply "${patch_options[@]}" --check "${patch_file}"; then
  git -C "${labutopia_path}" apply "${patch_options[@]}" "${patch_file}"
elif ! git -C "${labutopia_path}" apply "${patch_options[@]}" --reverse --check "${patch_file}"; then
  bootstrap_log "LabUtopia patch does not apply to ${labutopia_ref}"
  exit 65
fi

/isaac-sim/python.sh -m pip install --upgrade pip
/isaac-sim/python.sh -m pip install \
  torch==2.9.0 torchvision==0.24.0 torchaudio==2.9.0 \
  --index-url https://download.pytorch.org/whl/cu126
/isaac-sim/python.sh -m pip install -r "${labutopia_path}/requirements.txt"
/isaac-sim/python.sh -m pip install \
  "PyJWT[crypto]>=1,<3" \
  "docstring-parser==0.16" \
  "lxml>=4.9.2,<5"

bootstrap_write_marker labutopia "${labutopia_integration_revision}"
bootstrap_log "LabUtopia installed from upstream for an accepted CC BY-NC 4.0 use"
