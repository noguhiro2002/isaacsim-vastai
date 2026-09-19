# Third-party notices and distribution boundaries

This repository's original helper scripts, templates, documentation, and
Docker build recipes are licensed under the MIT License in `LICENSE`. That
license does not replace or broaden the terms of any third-party component.

## NVIDIA Isaac Sim

The repository does not distribute an NVIDIA Isaac Sim image or NVIDIA
Omniverse Kit binaries. The Vast.ai templates pull NVIDIA's official images
directly from `nvcr.io/nvidia/isaac-sim`.

Isaac Sim source and the additional NVIDIA-owned components have different
terms. The additional components are governed by the NVIDIA Isaac Sim
Additional Software and Materials License. Users must review and accept that
license before setting `ACCEPT_EULA=Y` or running the software. Redistribution
of Isaac Sim with Omniverse Kit to third parties may require an NVIDIA AI
Enterprise license.

- License: https://www.nvidia.com/en-us/agreements/enterprise-software/isaac-sim-additional-software-and-materials-license/
- FAQ: https://docs.isaacsim.omniverse.nvidia.com/6.0.0/common/license-faq.html

## Matterix

The runtime installer fetches Matterix commit
`5d86bd6e4fc7dd6ea83dead1d076c0176440be9e` directly from its upstream
repository. Matterix is licensed under BSD-3-Clause. The upstream copyright
and license file remain in `/opt/matterix/LICENSE.txt`.

- Source: https://github.com/AccelerationConsortium/Matterix
- License: https://github.com/AccelerationConsortium/Matterix/blob/5d86bd6e4fc7dd6ea83dead1d076c0176440be9e/LICENSE.txt

### Matterix_assets is intentionally excluded

Matterix pins `Matterix_assets` commit
`0d856a0572d3e0823204264fd3d2700e15a43f4b` as a Git submodule. At the time
of review, that commit contains no `LICENSE`, `COPYING`, or `NOTICE` file.
The installers and local Dockerfile therefore do not initialize or copy the
submodule. Asset-dependent Matterix environments remain unavailable until the
rights holder publishes suitable terms or gives the user explicit permission.
The README records a runtime procedure for users who have independently
obtained the necessary rights and supplied the assets themselves. That
procedure does not download, redistribute, or grant any rights to
`Matterix_assets`.

- Source reviewed: https://github.com/AccelerationConsortium/Matterix_assets/tree/0d856a0572d3e0823204264fd3d2700e15a43f4b

## LabUtopia

The runtime installer fetches LabUtopia commit
`8df72784265c375a327ffa3f0a0cf8c676f229a7` directly from its upstream
repository. Its code is licensed under MIT. Its data assets are licensed under
CC BY-NC 4.0 and are limited to non-commercial research and education. The
installer downloads Git LFS assets only when the user explicitly sets
`LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y`. The upstream license and README remain in
`/opt/labutopia`.

- Source: https://github.com/Rui-li023/LabUtopia
- Code license: https://github.com/Rui-li023/LabUtopia/blob/8df72784265c375a327ffa3f0a0cf8c676f229a7/LICENSE
- Asset terms: https://github.com/Rui-li023/LabUtopia/blob/8df72784265c375a327ffa3f0a0cf8c676f229a7/README.md#-license

## Python and system dependencies

The installers obtain Python packages and Ubuntu packages from their original
registries. Each package keeps its own license and metadata. This repository
does not relicense those dependencies.
