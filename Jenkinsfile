pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    stages {

        stage('Deploy') {
            steps {
                script {

                    def branch = env.BRANCH_NAME
                    def project = "openclaw"

                    echo "🚀 Branch: ${branch}"

                    if (branch == 'main') {
                        sh """
                        set -e

                        cd /root/projects/${project}

                        echo "🔄 Atualizando código..."
                        git fetch origin
                        git reset --hard origin/main
                        git clean -fd

                        echo "🔗 Aplicando .env..."
                        ln -sf /root/projects/envs/${project}.env .env

                        echo "📁 Preparando volumes persistentes..."
                        mkdir -p \
                          /root/projects/volumes/${project}/workspace \
                          /root/projects/volumes/ollama

                        chown -R 1000:1000 \
                          /root/projects/volumes/${project}

                        echo "🌐 Verificando rede do proxy..."
                        docker network inspect proxy-network >/dev/null 2>&1 \
                          || docker network create proxy-network

                        echo "🛑 Derrubando containers antigos..."
                        docker compose down --remove-orphans || true

                        echo "🐳 Construindo e subindo serviços..."
                        docker compose up -d --build

                        echo "🤖 Verificando modelo do Ollama..."
                        if docker compose exec -T ollama \
                            ollama show "\${OLLAMA_MODEL:-qwen3:8b}" \
                            >/dev/null 2>&1
                        then
                            echo "✅ Modelo já está instalado."
                        else
                            echo "⬇️ Baixando modelo \${OLLAMA_MODEL:-qwen3:8b}..."

                            docker compose run \
                              --rm \
                              ollama-model-init
                        fi

                        echo "🔄 Recriando OpenClaw após validar o modelo..."
                        docker compose up \
                          -d \
                          --build \
                          --force-recreate \
                          openclaw

                        echo "📋 Status dos containers..."
                        docker compose ps

                        echo "✅ Deploy concluído."
                        """
                    }

                    else {
                        echo "⚠️ Branch ignorada: ${branch}"
                    }
                }
            }
        }

    }
}