# OpenClaw

Infraestrutura para executar OpenClaw 2026.7.1 com Ollama 0.32.0, Qwen3 e Caddy 2.11.4.

## Ambientes

- `main`: produção, projeto Compose `openclaw`, arquivo `docker-compose-prod.yml`.
- `dev`: desenvolvimento, projeto Compose `openclaw-dev`, arquivo `docker-compose.yml`.

Os dois ambientes usam os serviços `backend`, `web`, `model`, `model-init` e `config-init`. Caddy é o único proxy HTTP; não há Nginx nem profiles.

## Configuração

Copie `.env.example` para o arquivo externo do ambiente e troque os valores sensíveis. No servidor, o Jenkins cria apenas o link simbólico `.env`:

```text
/root/projects/envs/openclaw.env
/root/projects/envs/openclaw-dev.env
```

Os dados de OpenClaw e Ollama ficam fora do repositório, nos caminhos definidos por `OPENCLAW_DATA_ROOT` e `OLLAMA_DATA_ROOT`.

## Uso local

```bash
cp .env.example .env
docker network inspect proxy-network >/dev/null 2>&1 || docker network create proxy-network
sh scripts/verify.sh
docker compose -f docker-compose.yml up -d --build
```

Produção:

```bash
docker compose -f docker-compose-prod.yml config --quiet
docker compose -f docker-compose-prod.yml up -d --build
```

## Qualidade

```bash
npm ci
sh scripts/verify.sh
npm run test:e2e:list
```

`npm run test:e2e` tenta primeiro `E2E_PLATFORM_COMMAND`; se a plataforma externa não estiver configurada ou falhar, usa Playwright.

Detalhes completos para manutenção e reconstrução estão em `AGENTS.md`.
