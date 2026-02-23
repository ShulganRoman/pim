#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

FRONTEND_PORT="${FRONTEND_PORT:-3000}"
BACKEND_PORT="${BACKEND_PORT:-8080}"
OPENPIM_PORT="${OPENPIM_PORT:-80}"

frontend_url="http://localhost:${FRONTEND_PORT}"
backend_ops_url="http://localhost:${BACKEND_PORT}/api/graphql/operations"
openpim_url="http://localhost:${OPENPIM_PORT}"

echo "[smoke-test] Checking frontend: ${frontend_url}"
curl -fsS "${frontend_url}" >/dev/null

echo "[smoke-test] Checking backend operations endpoint: ${backend_ops_url}"
curl -fsS "${backend_ops_url}" >/dev/null

echo "[smoke-test] Checking OpenPIM UI: ${openpim_url}"
curl -fsS "${openpim_url}" >/dev/null

echo "[smoke-test] All checks passed."
