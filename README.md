# OpenClaw com Ollama e Qwen3

Projeto para executar o OpenClaw em uma VPS utilizando Docker Compose, Ollama e o modelo local Qwen3.

O deploy é realizado automaticamente pelo Jenkins por meio do `Jenkinsfile` versionado no repositório.

## Arquitetura

```text
Usuário
   │
   ▼
Nginx Proxy Manager
   │
   ▼
OpenClaw
   │
   ▼
Ollama
   │
   ▼
Qwen3 8B
```

### OpenClaw

O OpenClaw funciona como o agente de inteligência artificial. Ele recebe solicitações, conversa com o modelo e pode utilizar ferramentas, integrações e automações configuradas.

### Ollama

O Ollama executa o modelo de inteligência artificial localmente na VPS e disponibiliza uma API interna para o OpenClaw.

### Qwen3

O Qwen3 é o modelo responsável pelo raciocínio e pela geração das respostas.

O modelo padrão deste projeto é:

```text
qwen3:8b
```

## Estrutura do projeto

```text
openclaw/
├── Dockerfile
├── docker-compose.yml
├── Jenkinsfile
├── openclaw.json
├── README.md
├── .env.example
├── .dockerignore
└── .gitignore
```

Os dados persistentes não ficam dentro do repositório.

```text
/root/projects/volumes/openclaw
/root/projects/volumes/ollama
```

O arquivo de ambiente utilizado em produção fica em:

```text
/root/projects/envs/openclaw.env
```

Durante o deploy, o Jenkins cria o seguinte link simbólico:

```text
/root/projects/openclaw/.env
    → /root/projects/envs/openclaw.env
```

## Serviços Docker

### `openclaw`

Executa o gateway principal do OpenClaw.

Porta interna:

```text
18789
```

O serviço não publica a porta diretamente no host. O acesso externo deve ocorrer pelo Nginx Proxy Manager através da rede Docker `proxy-network`.

### `ollama`

Executa o servidor local de modelos.

Porta interna:

```text
11434
```

A porta do Ollama não é publicada na VPS e fica acessível apenas pelos containers conectados à rede do projeto.

### `ollama-model-init`

Serviço temporário responsável por baixar o modelo configurado em `OLLAMA_MODEL`.

O container encerra após concluir o download.

### `openclaw-config-init`

Serviço temporário responsável por copiar o arquivo `openclaw.json` para o volume persistente e ajustar suas permissões.

### `openclaw-cli`

Serviço opcional utilizado para executar comandos administrativos do OpenClaw.

Ele pertence ao profile `cli` e não inicia durante o deploy normal.

## Requisitos

No servidor:

* Ubuntu ou outra distribuição Linux compatível;
* Docker Engine;
* Docker Compose V2;
* Git;
* Jenkins com acesso ao Docker;
* Nginx Proxy Manager conectado à rede `proxy-network`;
* memória suficiente para executar o Qwen3.

Para confirmar os recursos da VPS:

```bash
free -h
nproc
df -h /
```

O modelo `qwen3:8b` exige vários gigabytes de RAM e pode ficar lento quando executado somente por CPU.

Como a VPS também pode executar Jenkins, PostgreSQL, Keycloak e outros serviços, monitore o consumo após o primeiro deploy.

```bash
docker stats openclaw openclaw-ollama
```

## Preparação do Jenkins

O Jenkins precisa ter acesso ao socket Docker e ao diretório de projetos do host.

Exemplo dos volumes no Compose do Jenkins:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - /root/projects:/root/projects
```

A imagem do Jenkins também precisa possuir:

* Docker CLI;
* Docker Compose V2;
* permissões para acessar `/var/run/docker.sock`.

Para consultar o GID do socket Docker no host:

```bash
stat -c '%g' /var/run/docker.sock
```

Esse GID pode ser adicionado ao container Jenkins por meio de `group_add`.

## Credencial do gateway

Gere um token seguro:

```bash
openssl rand -hex 32
```

No Jenkins, acesse:

```text
Manage Jenkins
→ Credentials
→ System
→ Global credentials
→ Add Credentials
```

Crie a credencial:

```text
Kind: Secret text
ID: openclaw-gateway-token
Secret: token gerado
Description: Token do gateway OpenClaw
```

O `Jenkinsfile` utiliza essa credencial para criar o arquivo:

```text
/root/projects/envs/openclaw.env
```

O token não deve ser salvo diretamente no Git.

## Configuração do job

Crie um job do tipo Pipeline.

Configuração recomendada:

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: URL do repositório
Branch Specifier: */main
Script Path: Jenkinsfile
```

Após salvar, execute o primeiro build manualmente.

Os builds seguintes podem ser disparados automaticamente por webhook ou após alterações na branch `main`.

## Fluxo do pipeline

O `Jenkinsfile` executa as seguintes etapas:

```text
Checkout
   ↓
Validação dos arquivos
   ↓
Preparação dos diretórios e variáveis
   ↓
Validação do Docker Compose
   ↓
Build da imagem do OpenClaw
   ↓
Inicialização do Ollama
   ↓
Download do Qwen3
   ↓
Instalação da configuração
   ↓
Deploy do OpenClaw
   ↓
Healthcheck
   ↓
Teste do modelo
```

O pipeline impede builds simultâneos para evitar dois deploys concorrentes alterando os mesmos containers e volumes.

## Variáveis de ambiente

Exemplo:

```dotenv
COMPOSE_PROJECT_NAME=openclaw

OPENCLAW_BASE_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_IMAGE_NAME=openclaw-local
OPENCLAW_IMAGE_TAG=latest

OPENCLAW_DATA_ROOT=/root/projects/volumes/openclaw
OLLAMA_DATA_ROOT=/root/projects/volumes/ollama

OPENCLAW_GATEWAY_TOKEN=gere-um-token-seguro

OLLAMA_IMAGE=ollama/ollama:latest
OLLAMA_MODEL=qwen3:8b
OLLAMA_CONTEXT_LENGTH=16384
OLLAMA_KEEP_ALIVE=10m

BUILD_COMMIT=local
BUILD_DATE=unknown
BUILD_NUMBER=local
```

O arquivo `.env.example` pode ser versionado.

O arquivo `.env` real não deve ser enviado ao Git.

## Modelo utilizado

Modelo padrão:

```text
qwen3:8b
```

Para trocar o modelo, altere no `Jenkinsfile`:

```groovy
OLLAMA_MODEL = 'qwen3:8b'
```

E, quando necessário, ajuste também o `openclaw.json`.

Exemplos de modelos menores:

```text
qwen3:8b
qwen3:1.7b
```

Um modelo menor consome menos memória, mas apresenta menor capacidade de raciocínio e uso de ferramentas.

## Contexto do modelo

O projeto limita inicialmente o contexto para:

```text
16384 tokens
```

Variável:

```dotenv
OLLAMA_CONTEXT_LENGTH=16384
```

Contextos maiores podem melhorar tarefas longas, mas aumentam significativamente o consumo de memória.

## Deploy manual

Embora o fluxo principal seja realizado pelo Jenkins, o projeto também pode ser iniciado manualmente para diagnóstico.

Crie o arquivo `.env`:

```bash
cp .env.example .env
```

Gere um token e ajuste o arquivo:

```bash
openssl rand -hex 32
```

Crie os diretórios persistentes:

```bash
mkdir -p \
  /root/projects/volumes/openclaw/workspace \
  /root/projects/volumes/ollama
```

Ajuste as permissões:

```bash
chown -R 1000:1000 /root/projects/volumes/openclaw
```

Crie a rede do proxy, caso ainda não exista:

```bash
docker network inspect proxy-network >/dev/null 2>&1 \
  || docker network create proxy-network
```

Valide a configuração:

```bash
docker compose config
```

Construa a imagem:

```bash
docker compose build --pull openclaw
```

Suba os serviços:

```bash
docker compose up -d
```

## Verificação

Consultar os containers:

```bash
docker compose ps
```

Consultar os logs:

```bash
docker compose logs -f --tail=200
```

Logs somente do OpenClaw:

```bash
docker compose logs -f --tail=200 openclaw
```

Logs somente do Ollama:

```bash
docker compose logs -f --tail=200 ollama
```

Listar os modelos instalados:

```bash
docker compose exec ollama ollama list
```

Testar o Qwen diretamente:

```bash
docker compose exec ollama \
  ollama run qwen3:8b \
  "Responda somente com: OK"
```

Consultar o healthcheck:

```bash
docker inspect \
  --format='{{.State.Health.Status}}' \
  openclaw
```

## Comandos administrativos

Executar um comando do OpenClaw pelo serviço CLI:

```bash
docker compose --profile cli run --rm openclaw-cli --help
```

Listar modelos reconhecidos:

```bash
docker compose --profile cli run --rm \
  openclaw-cli models list
```

Exibir a configuração:

```bash
docker compose --profile cli run --rm \
  openclaw-cli config get
```

Reiniciar os serviços:

```bash
docker compose restart
```

Reiniciar somente o OpenClaw:

```bash
docker compose restart openclaw
```

Parar o projeto:

```bash
docker compose down
```

Parar sem remover os dados:

```bash
docker compose down
```

Os volumes são bind mounts no host e não são apagados pelo comando `down`.

## Atualização do modelo

Para atualizar o Qwen:

```bash
docker compose exec ollama \
  ollama pull qwen3:8b
```

Depois reinicie o OpenClaw:

```bash
docker compose restart openclaw
```

## Atualização das imagens

```bash
docker compose pull ollama
docker compose build --pull openclaw
docker compose up -d --remove-orphans
```

No ambiente normal, essas etapas são executadas pelo Jenkins após um novo deploy.

## Nginx Proxy Manager

O container `openclaw` participa da rede externa:

```text
proxy-network
```

Crie um Proxy Host com:

```text
Domain Names: ai.henriquebuz.in
Scheme: http
Forward Hostname: openclaw
Forward Port: 18789
WebSocket Support: ativado
Block Common Exploits: ativado
```

Na seção SSL:

```text
Request a new SSL Certificate
Force SSL: ativado
HTTP/2 Support: ativado
```

Acesso:

```text
https://ai.henriquebuz.in
```

## Segurança

Não publique a porta do Ollama diretamente na internet.

Não envie o arquivo `.env` ao Git.

Não salve o token do gateway diretamente no `Jenkinsfile`.

Não monte o socket Docker dentro do OpenClaw sem necessidade.

Não forneça acesso irrestrito ao terminal da VPS antes de configurar regras e permissões adequadas.

Mantenha o OpenClaw protegido por HTTPS, token de gateway e, quando possível, autenticação adicional no proxy reverso.

O OpenClaw pode executar ferramentas e acessar serviços configurados. Portanto, permissões excessivas podem permitir alterações importantes na VPS.

## Persistência

Configurações e workspace:

```text
/root/projects/volumes/openclaw
```

Modelos do Ollama:

```text
/root/projects/volumes/ollama
```

Variáveis de produção:

```text
/root/projects/envs/openclaw.env
```

Esses diretórios devem fazer parte da estratégia de backup da VPS.

## Backup

Exemplo de backup da configuração do OpenClaw:

```bash
tar -czf \
  openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  -C /root/projects/volumes \
  openclaw
```

Os modelos do Ollama podem ser baixados novamente e normalmente não precisam fazer parte do backup.

## Solução de problemas

### OpenClaw fica `unhealthy`

Consulte os logs:

```bash
docker compose logs --tail=300 openclaw
```

Verifique se o Ollama está saudável:

```bash
docker compose ps ollama
```

Teste a comunicação interna:

```bash
docker compose exec openclaw \
  curl -fsS http://ollama:11434/api/tags
```

### Modelo não encontrado

Liste os modelos:

```bash
docker compose exec ollama ollama list
```

Baixe novamente:

```bash
docker compose exec ollama ollama pull qwen3:8b
```

### Erro de permissão

Ajuste o proprietário do volume:

```bash
chown -R 1000:1000 /root/projects/volumes/openclaw
```

Depois recrie o container:

```bash
docker compose up -d --force-recreate openclaw
```

### Jenkins não acessa o Docker

Confirme o socket:

```bash
ls -l /var/run/docker.sock
```

Confirme o GID:

```bash
stat -c '%g' /var/run/docker.sock
```

Verifique se o Docker CLI está instalado no container Jenkins:

```bash
docker exec jenkins docker version
docker exec jenkins docker compose version
```

### Falta de memória

Consulte:

```bash
free -h
docker stats
```

Reduza o contexto:

```dotenv
OLLAMA_CONTEXT_LENGTH=8192
```

Ou troque o modelo:

```text
qwen3:8b
```

### Download do modelo demora demais

O primeiro deploy precisa baixar vários gigabytes.

Consulte o progresso:

```bash
docker compose logs -f ollama-model-init
```

Depois que o modelo estiver armazenado em `/root/projects/volumes/ollama`, os próximos deploys não precisarão baixá-lo novamente.

## Licença

Verifique as licenças individuais dos componentes utilizados:

* OpenClaw;
* Ollama;
* Qwen3;
* imagens Docker e dependências adicionais.

Este repositório contém apenas a configuração de infraestrutura e deploy desses componentes.
