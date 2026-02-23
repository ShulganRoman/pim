#!/usr/bin/env bash
set -e

echo "Running OpenPIM init.sql on DB '${PIM_DB}'..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$PIM_DB" \
  -f /docker-entrypoint-initdb.d/init.sql
echo "OpenPIM schema initialized."
