#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ENV_FILE="${ROOT_DIR}/infra/shared/.env"
COMPOSE_FILE="${ROOT_DIR}/infra/apps/glpi/docker-compose.yml"

if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
fi

BACKUP_DIR="${GLPI_BACKUP_PATH:-/srv/docker-data/glpi/backups}"
DATE="$(date +%Y%m%d_%H%M%S)"
RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-30}"
DB_SERVICE="glpi-db"
DB_NAME="${MYSQL_DATABASE:-glpi}"
DB_USER="root"
DB_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"

GLPI_FILES_PATH="${GLPI_FILES_PATH:-/srv/docker-data/glpi/files}"
GLPI_PLUGINS_PATH="${GLPI_PLUGINS_PATH:-/srv/docker-data/glpi/plugins}"
GLPI_CONFIG_PATH="${GLPI_CONFIG_PATH:-/srv/docker-data/glpi/config}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "${BACKUP_DIR}"

if [[ -z "${DB_PASSWORD}" ]]; then
    echo "ERROR: MYSQL_ROOT_PASSWORD is not set. Aborting." >&2
    exit 1
fi

log "Starting GLPI backup (date: ${DATE}, retain: ${RETAIN_DAYS} days)..."

DB_DUMP="${BACKUP_DIR}/glpi_db_${DATE}.sql.gz"
log "Dumping database '${DB_NAME}' -> ${DB_DUMP}"

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" exec -T "${DB_SERVICE}" \
    mysqldump \
        -u "${DB_USER}" \
        --password="${DB_PASSWORD}" \
        --single-transaction \
        --routines \
        --triggers \
        --set-gtid-purged=OFF \
        "${DB_NAME}" \
    | gzip > "${DB_DUMP}"

log "Database dump complete."

FILES_ARCHIVE="${BACKUP_DIR}/glpi_files_${DATE}.tar.gz"
log "Archiving GLPI files -> ${FILES_ARCHIVE}"
tar czf "${FILES_ARCHIVE}" -C "${GLPI_FILES_PATH}" .

PLUGINS_ARCHIVE="${BACKUP_DIR}/glpi_plugins_${DATE}.tar.gz"
log "Archiving GLPI plugins -> ${PLUGINS_ARCHIVE}"
tar czf "${PLUGINS_ARCHIVE}" -C "${GLPI_PLUGINS_PATH}" .

CONFIG_ARCHIVE="${BACKUP_DIR}/glpi_config_${DATE}.tar.gz"
log "Archiving GLPI config -> ${CONFIG_ARCHIVE}"
tar czf "${CONFIG_ARCHIVE}" -C "${GLPI_CONFIG_PATH}" .

log "Rotating backups older than ${RETAIN_DAYS} days..."
find "${BACKUP_DIR}" -name "glpi_*.sql.gz" -mtime "+${RETAIN_DAYS}" -delete
find "${BACKUP_DIR}" -name "glpi_*.tar.gz" -mtime "+${RETAIN_DAYS}" -delete

log "Backup finished successfully."
