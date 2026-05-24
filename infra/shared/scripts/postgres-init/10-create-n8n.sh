#!/bin/bash
# Runs once on a fresh Postgres data dir (docker-entrypoint-initdb.d).
# Creates the n8n role and database if they do not already exist.
# For existing data dirs, run the equivalent SQL manually:
#   psql -U $POSTGRES_USER -c "CREATE ROLE n8n WITH LOGIN PASSWORD '...';"
#   psql -U $POSTGRES_USER -c "CREATE DATABASE n8n OWNER n8n;"
set -euo pipefail

N8N_DB="${N8N_DB_NAME:-n8n}"
N8N_USER="${N8N_DB_USER:-n8n}"
N8N_PASS="${N8N_DB_PASSWORD:-}"

if [ -z "${N8N_PASS}" ]; then
  echo "WARNING: N8N_DB_PASSWORD is not set; skipping n8n database creation."
  exit 0
fi

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${N8N_USER}') THEN
      CREATE ROLE "${N8N_USER}" WITH LOGIN PASSWORD '${N8N_PASS}';
    END IF;
  END
  \$\$;

  SELECT 'CREATE DATABASE "${N8N_DB}" OWNER "${N8N_USER}"'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${N8N_DB}') \gexec
EOSQL

echo "Postgres init: n8n role and database ensured."
