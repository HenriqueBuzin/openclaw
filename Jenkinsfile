pipeline {
    agent none

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        PROJECT_NAME = 'openclaw'
        PROJECT_DIR = '/root/projects/openclaw'
        ENV_FILE = '/root/projects/envs/openclaw.env'
        OPENCLAW_DATA_ROOT = '/root/projects/openclaw/openclaw'
        OLLAMA_DATA_ROOT = '/root/projects/openclaw/ollama'
    }

    stages {
        stage('Deploy VPS') {
            when {
                beforeAgent true
                branch 'vps'
            }

            agent any

            stages {
                stage('Atualizar código') {
                    steps {
                        sh '''
                            set -eu

                            echo "📁 Preparando diretório do projeto..."
                            mkdir -p "$PROJECT_DIR"

                            echo "🧹 Removendo arquivos antigos sem apagar volumes e .env..."
                            find "$PROJECT_DIR" \
                                -mindepth 1 \
                                -maxdepth 1 \
                                ! -name 'openclaw' \
                                ! -name 'ollama' \
                                ! -name '.env' \
                                -exec rm -rf -- {} +

                            echo "📦 Copiando checkout do Jenkins para o projeto..."
                            cp -a "$WORKSPACE"/. "$PROJECT_DIR"/

                            echo "✅ Código atualizado em $PROJECT_DIR"
                        '''
                    }
                }

                stage('Preparar ambiente') {
                    steps {
                        dir(env.PROJECT_DIR) {
                            sh '''
                                set -eu

                                mkdir -p \
                                    "$OPENCLAW_DATA_ROOT/workspace" \
                                    "$OLLAMA_DATA_ROOT"

                                chown -R 1000:1000 "$OPENCLAW_DATA_ROOT"

                                if [ ! -f "$ENV_FILE" ]; then
                                    echo "❌ Arquivo de ambiente não encontrado: $ENV_FILE"
                                    exit 1
                                fi

                                chmod 600 "$ENV_FILE"
                                ln -sfn "$ENV_FILE" "$PROJECT_DIR/.env"

                                docker network inspect proxy-network >/dev/null 2>&1 \
                                    || docker network create proxy-network
                            '''
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

                                python3 -m json.tool openclaw.json >/dev/null
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

                                tentativas=0
                                limite=30

                                while [ "$tentativas" -lt "$limite" ]; do
                                    container_id="$(docker compose ps -q --all openclaw)"

                                    if [ -z "$container_id" ]; then
                                        status="indisponível"
                                    else
                                        status="$(docker inspect \
                                            --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}' \
                                            "$container_id" 2>/dev/null || true)"
                                    fi

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

                                resposta="$(docker compose exec -T ollama \
                                    ollama run "${OLLAMA_MODEL:-qwen3:4b}" \
                                    'Responda somente com: OK')"

                                echo "$resposta"
                                echo "$resposta" | grep -q 'OK'

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
                            if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
                                docker compose ps || true
                                docker compose logs --tail=200 openclaw ollama || true
                            else
                                echo "⚠️ Docker Compose ainda não está disponível em $PROJECT_DIR."
                            fi
                        '''
                    }
                }

                cleanup {
                    sh '''
                        docker image prune -f >/dev/null 2>&1 || true
                    '''
                }
            }
        }
    }
}