# syntax=docker/dockerfile:1.7

ARG OPENCLAW_BASE_IMAGE=ghcr.io/openclaw/openclaw:latest
FROM ${OPENCLAW_BASE_IMAGE}

ARG BUILD_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_NUMBER=""

LABEL org.opencontainers.image.title="OpenClaw com Ollama" \
      org.opencontainers.image.description="OpenClaw usando Qwen local pelo Ollama" \
      org.opencontainers.image.revision="${BUILD_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      dev.jenkins.build-number="${BUILD_NUMBER}"

USER root

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        openssh-client \
        procps \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/node/.openclaw/workspace \
    && chown -R node:node /home/node/.openclaw

USER node
WORKDIR /app

ENV HOME=/home/node \
    OPENCLAW_HOME=/home/node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json \
    OPENCLAW_WORKSPACE_DIR=/home/node/.openclaw/workspace \
    OPENCLAW_DISABLE_BONJOUR=1 \
    OLLAMA_API_KEY=ollama-local \
    TZ=America/Sao_Paulo

EXPOSE 18789

# ENTRYPOINT e comportamento-base são herdados da imagem oficial.
# O comando do gateway é definido no docker-compose.yml.
