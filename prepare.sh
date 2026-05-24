#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_GROUP="$(id -gn "$USER")"

RUNTIME_ROOT="${RUNTIME_ROOT:-/opt/infra}"
DATA_ROOT="${DATA_ROOT:-/srv/docker-data}"
REPO_SHARED_DIR="${SCRIPT_DIR}/infra/shared"
REPO_GLPI_DIR="${SCRIPT_DIR}/infra/apps/glpi"
REPO_N8N_DIR="${SCRIPT_DIR}/infra/apps/n8n"
RUNTIME_SHARED_DIR="${RUNTIME_ROOT}/shared"
RUNTIME_GLPI_DIR="${RUNTIME_ROOT}/apps/glpi"
RUNTIME_N8N_DIR="${RUNTIME_ROOT}/apps/n8n"

sync_dir() {
  local src="$1"
  local dst="$2"
  shift 2

  sudo mkdir -p "$dst"

  if command -v rsync >/dev/null 2>&1; then
    sudo rsync -a --delete "$@" "$src/" "$dst/"
  else
    echo "WARNING: rsync not found, using cp fallback without delete sync"
    sudo cp -a "$src/." "$dst/"
  fi
}

sudo mkdir -p "${RUNTIME_ROOT}/apps"
sudo mkdir -p "${RUNTIME_ROOT}/reverse-proxy"
sudo mkdir -p "${RUNTIME_SHARED_DIR}"
sudo mkdir -p "${RUNTIME_GLPI_DIR}/certs"
sudo mkdir -p "${RUNTIME_N8N_DIR}/certs"

sudo mkdir -p "${DATA_ROOT}/postgres"
sudo mkdir -p "${DATA_ROOT}/glpi/mysql"
sudo mkdir -p "${DATA_ROOT}/glpi/files"
sudo mkdir -p "${DATA_ROOT}/glpi/plugins"
sudo mkdir -p "${DATA_ROOT}/glpi/marketplace"
sudo mkdir -p "${DATA_ROOT}/glpi/config"
sudo mkdir -p "${DATA_ROOT}/glpi/backups"
sudo mkdir -p "${DATA_ROOT}/n8n/data"
sudo mkdir -p "${DATA_ROOT}/n8n/files"

if [ ! -f "${REPO_SHARED_DIR}/.env" ] && [ -f "${REPO_SHARED_DIR}/.env.example" ]; then
  cp "${REPO_SHARED_DIR}/.env.example" "${REPO_SHARED_DIR}/.env"
  echo "Created infra/shared/.env from the example file. Update the secrets before exposing the stack."
fi

echo "Syncing repository files to ${RUNTIME_ROOT}..."
sync_dir "${REPO_SHARED_DIR}" "${RUNTIME_SHARED_DIR}" --exclude ".env"
sync_dir "${REPO_GLPI_DIR}" "${RUNTIME_GLPI_DIR}" --exclude "certs/*"
sync_dir "${REPO_N8N_DIR}" "${RUNTIME_N8N_DIR}" --exclude "certs/*" --exclude "plan/*" --exclude ".claude/*"

if [ -f "${REPO_SHARED_DIR}/.env" ]; then
  sudo cp "${REPO_SHARED_DIR}/.env" "${RUNTIME_SHARED_DIR}/.env"
fi

sudo chown -R "$USER":"$USER_GROUP" "${RUNTIME_ROOT}" "${DATA_ROOT}"

if [ -f "${RUNTIME_GLPI_DIR}/scripts/backup.sh" ] && [ -f "${RUNTIME_GLPI_DIR}/scripts/restore.sh" ]; then
  sudo chmod +x "${RUNTIME_GLPI_DIR}/scripts/backup.sh" "${RUNTIME_GLPI_DIR}/scripts/restore.sh"
fi

if [ -f "${RUNTIME_SHARED_DIR}/scripts/postgres-init/10-create-n8n.sh" ]; then
  sudo chmod +x "${RUNTIME_SHARED_DIR}/scripts/postgres-init/10-create-n8n.sh"
fi

echo "Runtime sync complete at ${RUNTIME_ROOT}."