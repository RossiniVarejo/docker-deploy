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
DB_SERVICE="glpi-db"
DB_NAME="${MYSQL_DATABASE:-glpi}"
DB_USER="root"
DB_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"

GLPI_FILES_PATH="${GLPI_FILES_PATH:-/srv/docker-data/glpi/files}"
GLPI_PLUGINS_PATH="${GLPI_PLUGINS_PATH:-/srv/docker-data/glpi/plugins}"
GLPI_CONFIG_PATH="${GLPI_CONFIG_PATH:-/srv/docker-data/glpi/config}"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <DATE_TAG>"
    echo "Example: $0 20260418_020000"
    exit 1
fi

DATE_TAG="$1"
DB_DUMP="${BACKUP_DIR}/glpi_db_${DATE_TAG}.sql.gz"
FILES_ARCHIVE="${BACKUP_DIR}/glpi_files_${DATE_TAG}.tar.gz"
PLUGINS_ARCHIVE="${BACKUP_DIR}/glpi_plugins_${DATE_TAG}.tar.gz"
CONFIG_ARCHIVE="${BACKUP_DIR}/glpi_config_${DATE_TAG}.tar.gz"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [[ -z "${DB_PASSWORD}" ]]; then
    echo "ERROR: MYSQL_ROOT_PASSWORD is not set." >&2
    exit 1
fi

for f in "${DB_DUMP}" "${FILES_ARCHIVE}"; do
    if [[ ! -f "${f}" ]]; then
        echo "ERROR: Required backup file not found: ${f}" >&2
        exit 1
    fi
done

log "WARNING: This restore will overwrite the current GLPI database and files."
read -rp "Type 'yes' to confirm: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

log "Stopping GLPI application containers..."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" stop glpi glpi-cron glpi-nginx || true

log "Recreating database ${DB_NAME}..."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" exec -T "${DB_SERVICE}" \
    mysql -u "${DB_USER}" --password="${DB_PASSWORD}" \
    -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

log "Importing database dump..."
gunzip -c "${DB_DUMP}" | \
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" exec -T "${DB_SERVICE}" \
    mysql -u "${DB_USER}" --password="${DB_PASSWORD}" "${DB_NAME}"

log "Restoring files..."
rm -rf "${GLPI_FILES_PATH}"/*
tar xzf "${FILES_ARCHIVE}" -C "${GLPI_FILES_PATH}"

if [[ -f "${PLUGINS_ARCHIVE}" ]]; then
    log "Restoring plugins..."
    rm -rf "${GLPI_PLUGINS_PATH}"/*
    tar xzf "${PLUGINS_ARCHIVE}" -C "${GLPI_PLUGINS_PATH}"
fi

if [[ -f "${CONFIG_ARCHIVE}" ]]; then
    log "Restoring config..."
    rm -rf "${GLPI_CONFIG_PATH}"/*
    tar xzf "${CONFIG_ARCHIVE}" -C "${GLPI_CONFIG_PATH}"
fi

log "Starting GLPI stack..."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d

log "Restore finished."
