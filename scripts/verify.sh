#!/bin/sh
set -eu

export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-ci-token}"

python3 -m json.tool openclaw.json >/dev/null

for file in docker-compose.yml docker-compose-prod.yml; do
  ! grep -Eq '^[[:space:]]*version:' "$file"
  ! grep -Eq '^[[:space:]]*profiles:' "$file"
  ! grep -Eqi 'nginx' "$file"
  docker compose --env-file .env.example -f "$file" config --quiet
done

grep -q '^name: openclaw-dev$' docker-compose.yml
grep -q '^name: openclaw$' docker-compose-prod.yml

for service in backend web model model-init config-init; do
  grep -Eq "^  ${service}:$" docker-compose.yml
  grep -Eq "^  ${service}:$" docker-compose-prod.yml
done
