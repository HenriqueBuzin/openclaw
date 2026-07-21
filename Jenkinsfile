pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        PROJECT_NAME = 'openclaw'
        PROJECT_DIR = '/root/projects/openclaw'
        ENV_FILE = '/root/projects/envs/openclaw.env'
        OPENCLAW_DATA_ROOT = '/root/projects/volumes/openclaw'
        OLLAMA_DATA_ROOT = '/root/projects/volumes/ollama'
    }

    stages {

        stage('Atualizar código') {
            steps {
                dir(env.PROJECT_DIR) {
                    sh '''
                        set -eu

                        echo "🔄 Atualizando código..."
                        git fetch --prune origin
                        git reset --hard origin/main
                        git clean -fd
                    '''
                }
            }
        }

        stage('Preparar ambiente') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'openclaw-gateway-token',
                        variable: 'OPENCLAW_GATEWAY_TOKEN_SECRET'
                    )
                ]) {
                    dir(env.PROJECT_DIR) {
                        sh '''
                            set -eu
                            umask 077

                            echo "📁 Preparando diretórios persistentes..."
                            mkdir -p \
                                "$OPENCLAW_DATA_ROOT/workspace" \
                                "$OLLAMA_DATA_ROOT" \
                                "$(dirname "$ENV_FILE")"

                            chown -R 1000:1000 "$OPENCLAW_DATA_ROOT"

                            echo "📝 Criando arquivo de ambiente..."
                            cat > "$ENV_FILE" <<ENVEOF
COMPOSE_PROJECT_NAME=openclaw

OPENCLAW_BASE_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_IMAGE_NAME=openclaw-local
OPENCLAW_IMAGE_TAG=latest

OPENCLAW_DATA_ROOT=$OPENCLAW_DATA_ROOT
OLLAMA_DATA_ROOT=$OLLAMA_DATA_ROOT

OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN_SECRET

OLLAMA_IMAGE=ollama/ollama:latest
OLLAMA_MODEL=qwen3:8b
OLLAMA_CONTEXT_LENGTH=16384
OLLAMA_KEEP_ALIVE=10m
ENVEOF

                            chmod 600 "$ENV_FILE"

                            echo "🔗 Aplicando link simbólico do .env..."
                            ln -sfn "$ENV_FILE" .env

                            echo "🌐 Verificando rede do proxy..."
                            docker network inspect proxy-network >/dev/null 2>&1 \
                                || docker network create proxy-network
                        '''
                    }
                }
            }
        }

        stage('Validar configuração') {
            steps {
                dir(env.PROJECT_DIR) {
                    sh '''
                        set -eu

                        test -f Dockerfile
                        test -f docker-compose.yml
                        test -f openclaw.json
                        test -L .env

                        echo "🔎 Validando JSON..."
                        jq empty openclaw.json

                        echo "🔎 Validando Docker Compose..."
                        docker compose config --quiet
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                dir(env.PROJECT_DIR) {
                    sh '''
                        set -eu

                        export BUILD_COMMIT="$(git rev-parse HEAD)"
                        export BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                        export BUILD_NUMBER="${BUILD_NUMBER:-local}"

                        echo "🐳 Construindo imagem do OpenClaw..."
                        docker compose build --pull openclaw
                    '''
                }
            }
        }

        stage('Inicializar dependências') {
            steps {
                dir(env.PROJECT_DIR) {
                    sh '''
                        set -eu

                        echo "🦙 Iniciando Ollama..."
                        docker compose up -d ollama
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                dir(env.PROJECT_DIR) {
                    sh '''
                        set -eu

                        echo "🚀 Instalando dependências e subindo OpenClaw..."
                        docker compose up -d --remove-orphans openclaw
                    '''
                }
            }
        }

        stage('Verificar saúde') {
            steps {
                dir(env.PROJECT_DIR) {
                    sh '''
                        set -eu

                        echo "⏳ Aguardando healthcheck do OpenClaw..."

                        tentativas=0
                        limite=30

                        while [ "$tentativas" -lt "$limite" ]; do
                            status="$(docker inspect \
                                --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}' \
                                openclaw 2>/dev/null || true)"

                            echo "Status: ${status:-indisponível}"

                            if [ "$status" = "healthy" ]; then
                                break
                            fi

                            if [ "$status" = "unhealthy" ]; then
                                docker compose logs --tail=200 openclaw
                                exit 1
                            fi

                            tentativas=$((tentativas + 1))
                            sleep 10
                        done

                        if [ "$tentativas" -ge "$limite" ]; then
                            echo "❌ Tempo limite aguardando o OpenClaw."
                            docker compose ps
                            docker compose logs --tail=200 openclaw
                            exit 1
                        fi

                        echo "🧪 Testando modelo no Ollama..."
                        resposta="$(docker compose exec -T ollama \
                            ollama run "${OLLAMA_MODEL:-qwen3:8b}" \
                            'Responda somente com: OK')"

                        echo "$resposta"
                        echo "$resposta" | grep -q 'OK'

                        echo "📋 Status final..."
                        docker compose ps
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Deploy do OpenClaw concluído com sucesso.'
        }

        failure {
            echo '❌ O deploy do OpenClaw falhou.'

            dir(env.PROJECT_DIR) {
                sh '''
                    docker compose ps || true
                    docker compose logs --tail=200 openclaw ollama || true
                '''
            }
        }

        cleanup {
            dir(env.PROJECT_DIR) {
                sh '''
                    docker image prune -f >/dev/null 2>&1 || true
                '''
            }
        }
    }
}
