#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap-lib.sh"

bootstrap_require_root_and_isaac

matterix_repository="${MATTERIX_REPOSITORY:-https://github.com/AccelerationConsortium/Matterix.git}"
matterix_ref="${MATTERIX_REF:-5d86bd6e4fc7dd6ea83dead1d076c0176440be9e}"
matterix_path="${MATTERIX_PATH:-/opt/matterix}"
isaaclab_version="${ISAACLAB_VERSION:-3.0.0b2.post1}"

bootstrap_install_helpers matterix

if bootstrap_marker_matches matterix "${matterix_ref}" && \
  [[ -d "${matterix_path}/.git" ]]; then
  bootstrap_log "Matterix ${matterix_ref} is already installed"
  exit 0
fi

bootstrap_apt_install \
  build-essential ca-certificates cmake curl git git-lfs libglib2.0-0 ncurses-term

bootstrap_checkout "${matterix_repository}" "${matterix_ref}" "${matterix_path}"

# Matterix_assets has no explicit license at the pinned submodule commit.
# Do not initialize or download it automatically.
mkdir -p "${matterix_path}/source/matterix_assets/data"
cat > "${matterix_path}/source/matterix_assets/data/ASSETS_NOT_INSTALLED.md" <<'EOF'
Matterix_assets was intentionally not downloaded because the pinned upstream
commit does not contain an explicit redistribution/use license. Obtain written
permission or wait for upstream licensing terms before adding those assets.
EOF

ln -sfn /isaac-sim "${matterix_path}/_isaac_sim"
/isaac-sim/python.sh -m pip install --upgrade pip
/isaac-sim/python.sh -m pip install \
  torch==2.10.0 torchvision==0.25.0 \
  --index-url https://download.pytorch.org/whl/cu128
/isaac-sim/python.sh -m pip install \
  "isaaclab[all]==${isaaclab_version}" \
  --extra-index-url https://pypi.nvidia.com
(
  cd "${matterix_path}"
  /isaac-sim/python.sh -m pip install -r source.txt
)
/isaac-sim/python.sh -m pip install \
  "PyJWT[crypto]>=1,<3" \
  "aiobotocore[boto3]==2.25.1"
/isaac-sim/python.sh -m pip check

bootstrap_write_marker matterix "${matterix_ref}"
bootstrap_log "Matterix installed without the unlicensed Matterix_assets submodule"
