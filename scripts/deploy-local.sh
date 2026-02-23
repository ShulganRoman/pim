#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "[deploy-local] .env not found. Create it from .env.example first."
  exit 1
fi

echo "[deploy-local] Validating docker compose config..."
docker compose config >/dev/null

echo "[deploy-local] Building and starting stack..."
docker compose up -d --build

echo "[deploy-local] Current container status:"
docker compose ps

echo "[deploy-local] Running smoke test..."
"$ROOT_DIR/scripts/smoke-test.sh"

echo "[deploy-local] Done."
