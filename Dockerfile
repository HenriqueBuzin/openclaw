# syntax=docker/dockerfile:1.7

ARG OPENCLAW_BASE_IMAGE=ghcr.io/openclaw/openclaw:2026.7.1

FROM node:24.18.1-bookworm-slim AS verify

WORKDIR /workspace

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . ./

RUN npm run test:e2e:list

FROM node:24.18.1-bookworm-slim AS node-runtime

FROM ${OPENCLAW_BASE_IMAGE} AS runtime

ARG BUILD_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_NUMBER=""

LABEL org.opencontainers.image.title="OpenClaw com Ollama" \
      org.opencontainers.image.description="OpenClaw usando modelo local pelo Ollama" \
      org.opencontainers.image.revision="${BUILD_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      dev.jenkins.build-number="${BUILD_NUMBER}"

USER root
COPY --from=node-runtime /usr/local/ /usr/local/
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -f /usr/local/bin/pnpm /usr/local/bin/pnpx \
    && rm -rf /usr/local/share/corepack \
    && npm install --global npm@12.0.2 \
    && npm install --prefix /tmp/runtime-patches \
        @opentelemetry/propagator-jaeger@2.9.0 \
        brace-expansion@5.0.8 \
        fast-uri@3.1.4 \
    && rm -rf \
        /app/node_modules/@opentelemetry/propagator-jaeger \
        /app/node_modules/brace-expansion \
        /app/node_modules/fast-uri \
    && cp -a /tmp/runtime-patches/node_modules/@opentelemetry/propagator-jaeger /app/node_modules/@opentelemetry/ \
    && cp -a /tmp/runtime-patches/node_modules/brace-expansion /app/node_modules/ \
    && cp -a /tmp/runtime-patches/node_modules/fast-uri /app/node_modules/ \
    && rm -rf \
        /app/node_modules/@vitest/browser \
        /app/node_modules/postcss \
        /tmp/runtime-patches \
    && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/pnpm \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/pnpm /usr/local/bin/pnpx \
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
CMD ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
