#!/usr/bin/env bash
set -e

echo "Creating role '${PIM_ADMIN}'..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${PIM_ADMIN}') THEN
      CREATE ROLE ${PIM_ADMIN} LOGIN PASSWORD '${PIM_ADMIN_PASSWORD}';
    ELSE
      ALTER ROLE ${PIM_ADMIN} WITH PASSWORD '${PIM_ADMIN_PASSWORD}';
    END IF;
  END
  \$\$;
EOSQL

echo "Creating database '${PIM_DB}' (owner: ${PIM_ADMIN}) if not exists..."

# CREATE DATABASE должен быть вне транзакции, поэтому делаем через shell-проверку
DB_EXISTS="$(psql -tA --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "SELECT 1 FROM pg_database WHERE datname='${PIM_DB}'")"
if [ "$DB_EXISTS" != "1" ]; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE DATABASE ${PIM_DB} OWNER ${PIM_ADMIN};"
else
  echo "Database '${PIM_DB}' already exists."
fi

echo "Role/DB ready."
