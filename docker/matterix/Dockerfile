# syntax=docker/dockerfile:1.7

ARG ISAAC_SIM_IMAGE=nvcr.io/nvidia/isaac-sim:6.0.1
FROM ${ISAAC_SIM_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG MATTERIX_REPOSITORY=https://github.com/AccelerationConsortium/Matterix.git
ARG MATTERIX_REF=5d86bd6e4fc7dd6ea83dead1d076c0176440be9e
ARG ISAACLAB_VERSION=3.0.0b2.post1

LABEL org.opencontainers.image.title="Matterix on Isaac Sim for Vast.ai" \
      org.opencontainers.image.description="Matterix and Isaac Lab in a single GPU container" \
      org.opencontainers.image.source="https://github.com/AccelerationConsortium/Matterix"

ENV ACCEPT_EULA=Y \
    PRIVACY_CONSENT=Y \
    OMNI_KIT_ALLOW_ROOT=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    MATTERIX_PATH=/opt/matterix \
    ISAACSIM_PATH=/isaac-sim \
    ISAACLAB_PATH=/opt/matterix \
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
      cmake \
      curl \
      git \
      git-lfs \
      libglib2.0-0 \
      ncurses-term && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${MATTERIX_PATH}" && \
    git -C "${MATTERIX_PATH}" init && \
    git -C "${MATTERIX_PATH}" remote add origin "${MATTERIX_REPOSITORY}" && \
    for attempt in 1 2 3; do \
      if GIT_LFS_SKIP_SMUDGE=1 git -C "${MATTERIX_PATH}" -c http.version=HTTP/1.1 \
        fetch --depth 1 origin "${MATTERIX_REF}"; then break; fi; \
      if [[ "${attempt}" == 3 ]]; then exit 1; fi; \
      sleep $((attempt * 10)); \
    done && \
    git -C "${MATTERIX_PATH}" checkout --detach FETCH_HEAD && \
    git -C "${MATTERIX_PATH}" submodule update --init --recursive --depth 1 && \
    git -C "${MATTERIX_PATH}" lfs pull && \
    git -C "${MATTERIX_PATH}" submodule foreach --recursive 'git lfs pull'

RUN ln -sfn /isaac-sim "${MATTERIX_PATH}/_isaac_sim" && \
    /isaac-sim/python.sh -m pip install --upgrade pip && \
    /isaac-sim/python.sh -m pip install \
      torch==2.10.0 torchvision==0.25.0 \
      --index-url https://download.pytorch.org/whl/cu128 && \
    /isaac-sim/python.sh -m pip install \
      "isaaclab[all]==${ISAACLAB_VERSION}" \
      --extra-index-url https://pypi.nvidia.com && \
    cd "${MATTERIX_PATH}" && \
    /isaac-sim/python.sh -m pip install -r source.txt

RUN /isaac-sim/python.sh -m pip install \
      "PyJWT[crypto]>=1,<3" \
      "aiobotocore[boto3]==2.25.1" && \
    /isaac-sim/python.sh -m pip check

COPY docker/common/ /opt/vast-isaac/

RUN install -m 0755 /opt/vast-isaac/vast-init.sh /usr/local/bin/vast-init && \
    install -m 0755 /opt/vast-isaac/entrypoint.sh /usr/local/bin/vast-entrypoint && \
    install -m 0755 /opt/vast-isaac/isaac-python.sh /usr/local/bin/isaac-python && \
    install -m 0755 /opt/vast-isaac/isaacsim-headless.sh /usr/local/bin/isaacsim-headless && \
    install -m 0755 /opt/vast-isaac/isaacsim-webrtc.sh /usr/local/bin/isaacsim-webrtc && \
    install -m 0755 /opt/vast-isaac/isaac-usd-smoke.sh /usr/local/bin/isaac-usd-smoke && \
    install -m 0755 /opt/vast-isaac/verify-gpu.sh /usr/local/bin/verify-gpu && \
    printf '%s\n' \
      'export MATTERIX_PATH=/opt/matterix' \
      'export ISAACSIM_PATH=/isaac-sim' \
      'export ISAACLAB_PATH=/opt/matterix' \
      'export OMNI_KIT_ALLOW_ROOT=1' \
      'export PATH=/usr/local/bin:$PATH' \
      > /etc/profile.d/vast-isaac.sh && \
    mkdir -p /workspace && \
    /usr/local/bin/vast-init

WORKDIR /opt/matterix
VOLUME ["/workspace"]
ENTRYPOINT ["/usr/local/bin/vast-entrypoint"]
CMD []

