#!/usr/bin/env bash
# backup-postgres.sh — pg_dump all configured databases from the shared cluster.
#
# Invoke directly or via: ./rossini-runner.sh backup postgres
#
# Each database is dumped in custom format (-Fc), compressed.
# Backups older than BACKUP_RETAIN_DAYS are rotated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Load shared env, then per-app envs if available
_load_env() {
    local f="$1"
    if [ -f "${f}" ]; then
        set -a
        # shellcheck disable=SC1090
        source "${f}"
        set +a
    fi
}
_load_env "${ROOT_DIR}/infra/shared/.env"
_load_env "${ROOT_DIR}/infra/apps/n8n/.env"
_load_env "${ROOT_DIR}/infra/apps/glpi/.env"

BACKUP_DIR="${POSTGRES_BACKUP_PATH:-/srv/docker-data/postgres/backups}"
DATE="$(date +%Y%m%d_%H%M%S)"
RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-30}"
PG_CONTAINER="postgres"
PG_USER="${POSTGRES_USER:-postgres}"

# List of databases to dump.
# Add a new line here for every additional app that stores data in shared PG.
DATABASES=(
    "${N8N_DB_NAME:-n8n}"
)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "${BACKUP_DIR}"

log "Starting Postgres backup (date: ${DATE}, retain: ${RETAIN_DAYS} days)..."

for db in "${DATABASES[@]}"; do
    dump_file="${BACKUP_DIR}/pg_${db}_${DATE}.dump"
    log "Dumping database '${db}' -> ${dump_file}"

    # PGPASSWORD avoids the password appearing in ps output
    docker exec \
        -e PGPASSWORD="${POSTGRES_PASS:?POSTGRES_PASS not set}" \
        "${PG_CONTAINER}" \
        pg_dump \
            -U "${PG_USER}" \
            --format=custom \
            --no-password \
            "${db}" > "${dump_file}"

    log "  -> $(du -sh "${dump_file}" | cut -f1)"
done

log "Rotating backups older than ${RETAIN_DAYS} days..."
find "${BACKUP_DIR}" -name "pg_*.dump" -mtime "+${RETAIN_DAYS}" -delete

log "Postgres backup finished."
