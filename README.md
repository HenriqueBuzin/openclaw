# OpenClaw

Infraestrutura para executar OpenClaw 2026.7.1 com Ollama 0.32.0 e Qwen3.

## Ambientes

- `main`: produção, projeto Compose `openclaw`, arquivo `docker-compose-prod.yml`.
- `dev`: desenvolvimento, projeto Compose `openclaw-dev`, arquivo `docker-compose.yml`.

Os dois ambientes usam os serviços `backend`, `model`, `model-init` e `config-init`. O backend entra
diretamente na `proxy-network`; não há Caddy interno, Nginx nem profiles. No proxy global da VPS,
use `openclaw:18789` em produção e `openclaw-dev:18789` em desenvolvimento, mantendo WebSocket
habilitado.

Todos os containers usam `TZ=America/Sao_Paulo`.

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

Abra `http://127.0.0.1:18789` no navegador. A porta local pode ser alterada por
`OPENCLAW_LOCAL_PORT`; ela permanece vinculada somente a `127.0.0.1`.

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
