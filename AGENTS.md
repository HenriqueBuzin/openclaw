# Reconstrução do projeto

Este repositório é a especificação completa da infraestrutura do OpenClaw. Não contém código-fonte do produto; ele compõe imagens oficiais e configuração.

## Contrato funcional

- OpenClaw 2026.7.1 atende internamente na porta 18789.
- Ollama 0.32.0 atende internamente na porta 11434 e carrega `OLLAMA_MODEL`, por padrão `qwen3:8b`.
- `openclaw.json` configura o provider `ollama` usando o alias de rede `http://ollama:11434`.
- Caddy 2.11.4 é o único proxy. Em dev escuta `:80`; em produção usa `CADDY_DOMAIN` e `CADDY_EMAIL`.
- Nenhuma porta do Ollama é publicada e nenhum serviço usa Nginx.

## Arquivos obrigatórios

- `Dockerfile`: imagem do serviço `backend`; todo comando de inicialização do gateway está no `CMD`.
- `Dockerfile.model-init`: baixa o modelo configurado.
- `Dockerfile.config-init` e `scripts/init-config.sh`: instalam `openclaw.json` no volume persistente.
- `Caddyfile.dev` e `Caddyfile`: proxy de desenvolvimento e produção.
- `docker-compose.yml`: ambiente dev, `name: openclaw-dev`.
- `docker-compose-prod.yml`: ambiente prod, `name: openclaw`.
- `.github/workflows/ci.yml` e `Jenkinsfile`: gates equivalentes.

## Serviços padronizados

- `backend`: gateway OpenClaw.
- `web`: Caddy.
- `model`: Ollama.
- `model-init`: job idempotente de download.
- `config-init`: job idempotente de configuração.

Todos usam labels `infra.project`, `infra.environment` e `infra.version`, rotação de logs, `no-new-privileges` e healthchecks quando são processos longos. Os nomes das imagens de dev terminam em `-dev`; produção não usa `-prod`.

## Ambientes e branches

`main` e `dev` devem ter árvores Git idênticas. A diferença é selecionada somente pelo Compose:

- main: `docker-compose-prod.yml`, projeto `openclaw`, `/root/projects/envs/openclaw.env`.
- dev: `docker-compose.yml`, projeto `openclaw-dev`, `/root/projects/envs/openclaw-dev.env`.

O `.env` nunca é versionado. Jenkins cria um link simbólico para o arquivo externo. Dados também ficam fora do checkout.

## Variáveis

Obrigatórias: `OPENCLAW_GATEWAY_TOKEN`. Produção também exige `CADDY_DOMAIN` e `CADDY_EMAIL`.

Configuráveis: `OPENCLAW_DATA_ROOT`, `OLLAMA_DATA_ROOT`, `OLLAMA_MODEL`, `OLLAMA_CONTEXT_LENGTH`, `OLLAMA_KEEP_ALIVE`, `IMAGE_TAG`, `BUILD_COMMIT`, `BUILD_DATE`, `BUILD_NUMBER`.

## Gates

`scripts/verify.sh` valida JSON, proíbe profiles/Nginx/version no Compose, confirma nomes e serviços e renderiza os dois Compose. O pipeline mantém as etapas `Install`, `Verify`, `Compose`, `Container` e `Deploy`.

O adaptador E2E executa `E2E_PLATFORM_COMMAND` primeiro. Na ausência ou falha da plataforma, Playwright verifica `/healthz` e a interface HTTP usando `E2E_BASE_URL`.

## Reconstrução

Para reconstruir do zero, recrie exatamente os arquivos acima, preserve os nomes de serviços, redes e variáveis, gere um token de gateway, crie a rede externa `proxy-network`, disponibilize os diretórios persistentes e execute o Compose do ambiente. Não adicione banco de dados, Redis, profiles, Nginx ou comandos de aplicação aos Compose.
