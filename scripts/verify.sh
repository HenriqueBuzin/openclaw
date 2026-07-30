#!/bin/sh
set -eu

export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-ci-token}"

python3 -m json.tool openclaw.json >/dev/null

for file in docker-compose.yml docker-compose-prod.yml; do
  ! grep -Eq '^[[:space:]]*version:' "$file"
  ! grep -Eq '^[[:space:]]*profiles:' "$file"
  ! grep -Eqi 'nginx' "$file"
  ! grep -Eqi 'caddy' "$file"
  docker compose --env-file .env.example -f "$file" config --quiet
  docker compose --env-file .env.example -f "$file" config --format json |
    python3 -c 'import json,sys
services=json.load(sys.stdin)["services"]
missing=[name for name,service in services.items() if service.get("environment",{}).get("TZ")!="America/Sao_Paulo"]
raise SystemExit("services without America/Sao_Paulo: "+", ".join(missing) if missing else 0)'
done

grep -q '^name: openclaw-dev$' docker-compose.yml
grep -q '^name: openclaw$' docker-compose-prod.yml

for service in backend model model-init config-init; do
  grep -Eq "^  ${service}:$" docker-compose.yml
  grep -Eq "^  ${service}:$" docker-compose-prod.yml
done

! grep -Eq '^  web:$' docker-compose.yml
! grep -Eq '^  web:$' docker-compose-prod.yml
grep -q '127.0.0.1:${OPENCLAW_LOCAL_PORT:-18789}:18789' docker-compose.yml
! grep -Eq '^[[:space:]]*ports:' docker-compose-prod.yml
