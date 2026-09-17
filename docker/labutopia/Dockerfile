# syntax=docker/dockerfile:1.7

# LOCAL/INTERNAL, NON-COMMERCIAL USE ONLY. Do not publish the resulting image
# unless your NVIDIA license expressly permits redistribution of Isaac
# Sim/Omniverse Kit. LabUtopia assets are CC BY-NC 4.0.

ARG ISAAC_SIM_IMAGE=nvcr.io/nvidia/isaac-sim:5.1.0
FROM ${ISAAC_SIM_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG LABUTOPIA_REPOSITORY=https://github.com/Rui-li023/LabUtopia.git
ARG LABUTOPIA_REF=8df72784265c375a327ffa3f0a0cf8c676f229a7
ARG LABUTOPIA_ACCEPT_CC_BY_NC_4_0=N

LABEL org.opencontainers.image.title="LabUtopia on Isaac Sim for Vast.ai" \
      org.opencontainers.image.description="LabUtopia and Isaac Sim 5.1 in a single GPU container" \
      org.opencontainers.image.source="https://github.com/Rui-li023/LabUtopia"

ENV OMNI_KIT_ALLOW_ROOT=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    LABUTOPIA_PATH=/opt/labutopia \
    ISAACSIM_PATH=/isaac-sim \
    VAST_PERSIST_ROOT=/workspace \
    XDG_CACHE_HOME=/workspace/cache \
    PIP_CACHE_DIR=/workspace/cache/pip \
    CUDA_CACHE_PATH=/workspace/cache/nvidia/ComputeCache \
    __GL_SHADER_DISK_CACHE_PATH=/workspace/cache/nvidia/GLCache \
    PYTHONUNBUFFERED=1 \
    AUTO_START=idle

USER root

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      ffmpeg \
      git \
      git-lfs \
      libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

RUN test "${LABUTOPIA_ACCEPT_CC_BY_NC_4_0}" = "Y" || \
      (echo 'Set --build-arg LABUTOPIA_ACCEPT_CC_BY_NC_4_0=Y after accepting the non-commercial asset terms.' >&2; exit 78) && \
    mkdir -p "${LABUTOPIA_PATH}" && \
    git -C "${LABUTOPIA_PATH}" init && \
    git -C "${LABUTOPIA_PATH}" remote add origin "${LABUTOPIA_REPOSITORY}" && \
    for attempt in 1 2 3; do \
      if GIT_LFS_SKIP_SMUDGE=1 git -C "${LABUTOPIA_PATH}" -c http.version=HTTP/1.1 \
        fetch --depth 1 origin "${LABUTOPIA_REF}"; then break; fi; \
      if [[ "${attempt}" == 3 ]]; then exit 1; fi; \
      sleep $((attempt * 10)); \
    done && \
    git -C "${LABUTOPIA_PATH}" checkout --detach FETCH_HEAD && \
    git -C "${LABUTOPIA_PATH}" lfs pull

COPY docker/labutopia/labutopia-headless.patch /tmp/labutopia-headless.patch

RUN git -C "${LABUTOPIA_PATH}" apply --ignore-space-change --ignore-whitespace /tmp/labutopia-headless.patch && \
    rm /tmp/labutopia-headless.patch && \
    /isaac-sim/python.sh -m pip install --upgrade pip && \
    /isaac-sim/python.sh -m pip install \
      torch==2.9.0 torchvision==0.24.0 torchaudio==2.9.0 \
      --index-url https://download.pytorch.org/whl/cu126 && \
    /isaac-sim/python.sh -m pip install -r "${LABUTOPIA_PATH}/requirements.txt"

# Keep NVIDIA SRL metadata dependencies compatible without installing PyPI usd-core,
# which can shadow Isaac Sim Kit's bundled pxr/USD ABI.
RUN /isaac-sim/python.sh -m pip install \
      "PyJWT[crypto]>=1,<3" \
      "docstring-parser==0.16" \
      "lxml>=4.9.2,<5"

COPY docker/common/ /opt/vast-isaac/
COPY docker/labutopia/labutopia-run.sh /opt/vast-isaac/labutopia-run.sh
COPY LICENSE THIRD_PARTY_NOTICES.md /opt/vast-isaac/

RUN install -m 0755 /opt/vast-isaac/vast-init.sh /usr/local/bin/vast-init && \
    install -m 0755 /opt/vast-isaac/entrypoint.sh /usr/local/bin/vast-entrypoint && \
    install -m 0755 /opt/vast-isaac/isaac-python.sh /usr/local/bin/isaac-python && \
    install -m 0755 /opt/vast-isaac/isaacsim-headless.sh /usr/local/bin/isaacsim-headless && \
    install -m 0755 /opt/vast-isaac/isaacsim-webrtc.sh /usr/local/bin/isaacsim-webrtc && \
    install -m 0755 /opt/vast-isaac/isaac-usd-smoke.sh /usr/local/bin/isaac-usd-smoke && \
    install -m 0755 /opt/vast-isaac/verify-gpu.sh /usr/local/bin/verify-gpu && \
    install -m 0755 /opt/vast-isaac/labutopia-run.sh /usr/local/bin/labutopia-run && \
    printf '%s\n' \
      'export LABUTOPIA_PATH=/opt/labutopia' \
      'export ISAACSIM_PATH=/isaac-sim' \
      'export OMNI_KIT_ALLOW_ROOT=1' \
      'export PATH=/usr/local/bin:$PATH' \
      > /etc/profile.d/vast-isaac.sh && \
    mkdir -p /workspace && \
    /usr/local/bin/vast-init

WORKDIR /opt/labutopia
VOLUME ["/workspace"]
ENTRYPOINT ["/usr/local/bin/vast-entrypoint"]
CMD []
