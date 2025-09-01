FROM node:22-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG USERNAME=codex
ARG UID=1000
ARG GID=1000
ARG CODEX_CLI_VERSION=latest

RUN sed -i "/^[^:]*:x:${GID}:/d" /etc/group \
    && sed -i "/^[^:]*:x:${UID}:/d" /etc/passwd \
    && echo "${USERNAME}:x:${UID}:${GID}::/home/${USERNAME}:/sbin/nologin" >> /etc/passwd \
    && echo "${USERNAME}:x:${GID}:" >> /etc/group \
    && mkdir -p /home/${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    git-lfs \
    curl \
    gnupg \
    jq \
    ripgrep \
    tzdata \
    wget \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@openai/codex@${CODEX_CLI_VERSION}"

USER ${USERNAME}
WORKDIR /work

ENTRYPOINT ["codex"]
