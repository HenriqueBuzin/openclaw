pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        PROJECT_ROOT = '/root/projects'
        ENV_ROOT = '/root/projects/envs'
    }

    stages {
        stage('Install') {
            when {
                expression { ['main', 'dev'].contains(env.BRANCH_NAME) }
            }
            steps {
                sh '''
                    set -eu
                    command -v docker
                    docker compose version
                    echo 'Dependencias Node/npm sao instaladas no build multi-stage.'
                '''
            }
        }

        stage('Verify') {
            when {
                expression { ['main', 'dev'].contains(env.BRANCH_NAME) }
            }
            steps {
                sh '''
                    set -eu
                    sh scripts/verify.sh
                    docker build --target verify --tag openclaw/infra:verify .
                '''
            }
        }

        stage('Compose') {
            when {
                expression { ['main', 'dev'].contains(env.BRANCH_NAME) }
            }
            steps {
                sh '''
                    set -eu
                    branch="${BRANCH_NAME}"
                    suffix=""
                    compose_file="docker-compose-prod.yml"
                    if [ "$branch" = "dev" ]; then
                      suffix="-dev"
                      compose_file="docker-compose.yml"
                    fi

                    project="openclaw${suffix}"
                    project_dir="${PROJECT_ROOT}/${project}"
                    env_file="${ENV_ROOT}/${project}.env"

                    test -f "$env_file"
                    install -d -m 0755 "$project_dir"
                    find "$project_dir" -mindepth 1 -maxdepth 1 ! -name '.env' -exec rm -rf -- {} +
                    cp -a "$WORKSPACE"/. "$project_dir"/
                    ln -sfn "$env_file" "$project_dir/.env"

                    cd "$project_dir"
                    export COMPOSE_PROJECT_NAME="$project"
                    docker compose --env-file .env -f "$compose_file" config --quiet
                '''
            }
        }

        stage('Container') {
            when {
                expression { ['main', 'dev'].contains(env.BRANCH_NAME) }
            }
            steps {
                sh '''
                    set -eu
                    suffix=""
                    compose_file="docker-compose-prod.yml"
                    if [ "$BRANCH_NAME" = "dev" ]; then
                      suffix="-dev"
                      compose_file="docker-compose.yml"
                    fi

                    project="openclaw${suffix}"
                    cd "${PROJECT_ROOT}/${project}"
                    export COMPOSE_PROJECT_NAME="$project"
                    export BUILD_COMMIT="$(git rev-parse HEAD)"
                    export BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                    docker compose --env-file .env -f "$compose_file" build --pull backend config-init model-init
                '''
            }
        }

        stage('Deploy') {
            when {
                expression { ['main', 'dev'].contains(env.BRANCH_NAME) }
            }
            steps {
                sh '''
                    set -eu
                    suffix=""
                    compose_file="docker-compose-prod.yml"
                    if [ "$BRANCH_NAME" = "dev" ]; then
                      suffix="-dev"
                      compose_file="docker-compose.yml"
                    fi

                    project="openclaw${suffix}"
                    cd "${PROJECT_ROOT}/${project}"
                    export COMPOSE_PROJECT_NAME="$project"
                    docker network inspect proxy-network >/dev/null 2>&1 || docker network create proxy-network
                    docker compose --env-file .env -f "$compose_file" down --timeout 30 || true
                    docker compose --env-file .env -f "$compose_file" up -d --remove-orphans

                    attempts=0
                    until [ "$attempts" -ge 30 ]; do
                      status="$(docker compose --env-file .env -f "$compose_file" ps --format json backend | grep -o '"Health":"[^"]*"' | head -1 || true)"
                      [ "$status" = '"Health":"healthy"' ] && break
                      attempts=$((attempts + 1))
                      sleep 10
                    done

                    [ "$attempts" -lt 30 ] || {
                      docker compose --env-file .env -f "$compose_file" logs --tail=200 backend model web
                      exit 1
                    }

                    docker compose --env-file .env -f "$compose_file" exec -T model \
                      ollama run "${OLLAMA_MODEL:-qwen3:8b}" 'Responda somente com: OK' | grep -q OK
                    docker compose --env-file .env -f "$compose_file" ps
                '''
            }
        }
    }

    post {
        failure {
            sh '''
                suffix=""
                compose_file="docker-compose-prod.yml"
                [ "${BRANCH_NAME:-}" = "dev" ] && suffix="-dev" && compose_file="docker-compose.yml"
                project="openclaw${suffix}"
                if [ -d "${PROJECT_ROOT}/${project}" ]; then
                  cd "${PROJECT_ROOT}/${project}"
                  docker compose --env-file .env -f "$compose_file" logs --tail=200 || true
                fi
            '''
        }
        cleanup {
            sh 'docker image prune -f >/dev/null 2>&1 || true'
        }
    }
}
