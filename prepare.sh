#!/bin/bash
# prepare.sh — provision runtime directories and sync repo files to /opt/infra.
#
# Run once before the first `./rossini-runner.sh up`, and again after any
# git pull or changes to compose/nginx/php/scripts files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_GROUP="$(id -gn "$USER")"

RUNTIME_ROOT="${RUNTIME_ROOT:-/opt/infra}"
DATA_ROOT="${DATA_ROOT:-/srv/docker-data}"

# ─── directory layout ─────────────────────────────────────────────────────────
sudo mkdir -p \
    "${RUNTIME_ROOT}/apps" \
    "${RUNTIME_ROOT}/shared/lib" \
    "${RUNTIME_ROOT}/shared/scripts/postgres-init" \
    "${RUNTIME_ROOT}/reverse-proxy/conf.d" \
    "${RUNTIME_ROOT}/reverse-proxy/certs" \
    "${RUNTIME_ROOT}/reverse-proxy/templates" \
    "${RUNTIME_ROOT}/apps/glpi/certs" \
    "${RUNTIME_ROOT}/apps/n8n/certs"

sudo mkdir -p \
    "${DATA_ROOT}/postgres" \
    "${DATA_ROOT}/postgres/backups" \
    "${DATA_ROOT}/glpi/mysql" \
    "${DATA_ROOT}/glpi/files" \
    "${DATA_ROOT}/glpi/plugins" \
    "${DATA_ROOT}/glpi/marketplace" \
    "${DATA_ROOT}/glpi/config" \
    "${DATA_ROOT}/glpi/backups" \
    "${DATA_ROOT}/n8n/data" \
    "${DATA_ROOT}/n8n/files" \
    "${DATA_ROOT}/evolution/instances"

# ─── sync helper ──────────────────────────────────────────────────────────────
sync_dir() {
    local src="$1" dst="$2"
    shift 2
    sudo mkdir -p "${dst}"
    if command -v rsync >/dev/null 2>&1; then
        sudo rsync -a --delete "$@" "${src}/" "${dst}/"
    else
        echo "WARNING: rsync not found, falling back to cp (no delete sync)"
        sudo cp -a "${src}/." "${dst}/"
    fi
}

# ─── bootstrap .env from example if missing ───────────────────────────────────
for envdir in \
    "${SCRIPT_DIR}/infra/shared" \
    "${SCRIPT_DIR}/infra/apps/glpi" \
    "${SCRIPT_DIR}/infra/apps/n8n" \
    "${SCRIPT_DIR}/infra/apps/chatwoot"; do
    if [ ! -f "${envdir}/.env" ] && [ -f "${envdir}/.env.example" ]; then
        cp "${envdir}/.env.example" "${envdir}/.env"
        echo "Created ${envdir}/.env from example. Fill in secrets before running up."
    fi
done

# ─── sync repo files to runtime ───────────────────────────────────────────────
echo "Syncing repository files to ${RUNTIME_ROOT}..."

sync_dir "${SCRIPT_DIR}/infra/shared"        "${RUNTIME_ROOT}/shared"        --exclude ".env"
sync_dir "${SCRIPT_DIR}/infra/reverse-proxy" "${RUNTIME_ROOT}/reverse-proxy" --exclude "certs/*" --exclude "conf.d/*"
sync_dir "${SCRIPT_DIR}/infra/apps/glpi"     "${RUNTIME_ROOT}/apps/glpi"     --exclude "certs/*"
sync_dir "${SCRIPT_DIR}/infra/apps/n8n"      "${RUNTIME_ROOT}/apps/n8n"      --exclude "certs/*" --exclude "plan/*" --exclude ".claude/*"
sync_dir "${SCRIPT_DIR}/infra/apps/chatwoot" "${RUNTIME_ROOT}/apps/chatwoot" --exclude ".env"

# Copy compose.yml (top-level include manifest)
sudo cp "${SCRIPT_DIR}/infra/compose.yml" "${RUNTIME_ROOT}/compose.yml"

# Copy .env files (secrets stay on disk; not in git)
for envfile in \
    "${SCRIPT_DIR}/infra/shared/.env" \
    "${SCRIPT_DIR}/infra/apps/glpi/.env" \
    "${SCRIPT_DIR}/infra/apps/n8n/.env" \
    "${SCRIPT_DIR}/infra/apps/chatwoot/.env"; do
    if [ -f "${envfile}" ]; then
        rel="${envfile#"${SCRIPT_DIR}/infra/"}"
        sudo cp "${envfile}" "${RUNTIME_ROOT}/${rel}"
    fi
done

# ─── permissions ──────────────────────────────────────────────────────────────
sudo chown -R "$USER":"${USER_GROUP}" "${RUNTIME_ROOT}" "${DATA_ROOT}"

# ─── make scripts executable ──────────────────────────────────────────────────
find "${RUNTIME_ROOT}" -name "*.sh" -exec sudo chmod +x {} +

echo "Runtime sync complete at ${RUNTIME_ROOT}."
