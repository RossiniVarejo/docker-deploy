#!/bin/bash
# rossini-runner.sh — single operator interface for the Rossini stack.
#
# Usage:
#   ./rossini-runner.sh up [services...]
#   ./rossini-runner.sh down
#   ./rossini-runner.sh restart [services...]
#   ./rossini-runner.sh logs [services...]
#   ./rossini-runner.sh status
#   ./rossini-runner.sh pull
#   ./rossini-runner.sh config
#   ./rossini-runner.sh sync
#   ./rossini-runner.sh letsencrypt <app>         (e.g. glpi, n8n, chatwoot)
#   ./rossini-runner.sh letsencrypt-renew <app>
#   ./rossini-runner.sh backup [glpi|postgres|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/infra"

ACTION="${1:-up}"
shift || true

# ─── sync: delegate to prepare.sh ────────────────────────────────────────────
if [ "${ACTION}" = "sync" ]; then
    exec "${SCRIPT_DIR}/prepare.sh"
fi

# ─── env files (shared + per-app) ────────────────────────────────────────────
SHARED_ENV="${SHARED_ENV:-${INFRA_DIR}/shared/.env}"
GLPI_ENV="${GLPI_ENV:-${INFRA_DIR}/apps/glpi/.env}"
N8N_ENV="${N8N_ENV:-${INFRA_DIR}/apps/n8n/.env}"
CHATWOOT_ENV="${CHATWOOT_ENV:-${INFRA_DIR}/apps/chatwoot/.env}"

if [ ! -f "${SHARED_ENV}" ]; then
    echo "ERROR: ${SHARED_ENV} not found."
    echo "  Run ./rossini-runner.sh sync or copy infra/shared/.env.example to infra/shared/.env"
    exit 1
fi

# Build --env-file flags: shared env always; per-app envs when the file exists.
ENV_FLAGS=(--env-file "${SHARED_ENV}")
for appenv in "${GLPI_ENV}" "${N8N_ENV}" "${CHATWOOT_ENV}"; do
    [ -f "${appenv}" ] && ENV_FLAGS+=(--env-file "${appenv}")
done

# Load env for shell-level variable access (letsencrypt, backup, etc.)
set -a
# shellcheck disable=SC1090
source "${SHARED_ENV}"
for appenv in "${GLPI_ENV}" "${N8N_ENV}" "${CHATWOOT_ENV}"; do
    # shellcheck disable=SC1090
    [ -f "${appenv}" ] && source "${appenv}"
done
set +a

# ─── macOS path remap ─────────────────────────────────────────────────────────
# Docker Desktop cannot mount /srv/* by default on macOS.
# Remap Linux-style paths to a HOME-based path that Docker Desktop shares.
if [ "$(uname -s)" = "Darwin" ]; then
    MAC_DATA_ROOT="${MAC_DATA_ROOT:-${HOME}/docker-data}"

    _remap() {
        local var="$1"
        local val="${!var:-}"
        if [ -n "${val}" ] && [[ "${val}" == /srv/docker-data* ]]; then
            export "${var}=${val/#\/srv\/docker-data/${MAC_DATA_ROOT}}"
        fi
    }

    _remap POSTGRES_DATA_PATH
    _remap POSTGRES_BACKUP_PATH
    _remap GLPI_MYSQL_DATA_PATH
    _remap GLPI_FILES_PATH
    _remap GLPI_PLUGINS_PATH
    _remap GLPI_MARKETPLACE_PATH
    _remap GLPI_CONFIG_PATH
    _remap GLPI_BACKUP_PATH
    _remap N8N_DATA_PATH
    _remap N8N_FILES_PATH
fi

# ─── compose invocation ───────────────────────────────────────────────────────
COMPOSE_FILE="${INFRA_DIR}/compose.yml"

_compose() {
    docker compose \
        "${ENV_FLAGS[@]}" \
        -f "${COMPOSE_FILE}" \
        --project-directory "${INFRA_DIR}" \
        "$@"
}

# ─── letsencrypt helpers ──────────────────────────────────────────────────────
# Domains and email vars follow the convention:
#   glpi  → LETSENCRYPT_DOMAIN / LETSENCRYPT_EMAIL / LETSENCRYPT_STAGING
#   n8n   → N8N_LETSENCRYPT_DOMAIN / N8N_LETSENCRYPT_EMAIL / N8N_LETSENCRYPT_STAGING
#   <app> → <APP>_LETSENCRYPT_DOMAIN / <APP>_LETSENCRYPT_EMAIL / <APP>_LETSENCRYPT_STAGING

_resolve_le_var() {
    local app="$1" suffix="$2"
    local APP
    APP="$(echo "${app}" | tr '[:lower:]' '[:upper:]')"
    # glpi uses bare LETSENCRYPT_* for backwards compat; others use <APP>_LETSENCRYPT_*
    if [ "${app}" = "glpi" ]; then
        echo "${!suffix:-}"
    else
        local varname="${APP}_${suffix}"
        echo "${!varname:-}"
    fi
}

_run_letsencrypt() {
    local app="$1"
    local domain email staging
    domain="$(_resolve_le_var "${app}" "LETSENCRYPT_DOMAIN")"
    email="$(_resolve_le_var "${app}"  "LETSENCRYPT_EMAIL")"
    staging="$(_resolve_le_var "${app}" "LETSENCRYPT_STAGING")"

    if [ -z "${domain}" ] || [ -z "${email}" ]; then
        echo "ERROR: domain/email not set for app '${app}'."
        echo "  Set LETSENCRYPT_DOMAIN + LETSENCRYPT_EMAIL (glpi)"
        echo "  or <APP>_LETSENCRYPT_DOMAIN + <APP>_LETSENCRYPT_EMAIL"
        exit 1
    fi

    local proxy_conf_dir="${INFRA_DIR}/reverse-proxy/conf.d"
    local templates_dir="${INFRA_DIR}/reverse-proxy/templates"
    local certs_dir="${INFRA_DIR}/reverse-proxy/certs"

    echo "==> [${app}] Activating HTTP-only nginx config for ACME challenge..."
    cp "${templates_dir}/${app}-dev.conf" "${proxy_conf_dir}/${app}.conf"
    # Substitute the GLPI_DOMAIN / N8N_DOMAIN placeholder in the template
    sed -i.bak "s/GLPI_DOMAIN/${domain}/g; s/N8N_DOMAIN/${domain}/g; \
                s/CHATWOOT_DOMAIN/${domain}/g; s/EVOLUTION_DOMAIN/${domain}/g" \
        "${proxy_conf_dir}/${app}.conf" && rm -f "${proxy_conf_dir}/${app}.conf.bak"

    _compose exec proxy-nginx nginx -s reload 2>/dev/null || \
        _compose up -d proxy-nginx

    local staging_arg=""
    [ "${staging:-0}" = "1" ] && staging_arg="--staging"

    echo "==> [${app}] Requesting certificate for ${domain}..."
    _compose run --rm --no-deps proxy-certbot \
        certonly --webroot -w /var/www/certbot \
        -d "${domain}" \
        --email "${email}" --agree-tos --no-eff-email --non-interactive ${staging_arg}

    echo "==> [${app}] Copying certificate to shared certs dir..."
    _compose run --rm --no-deps --entrypoint sh proxy-certbot -c \
        "cp /etc/letsencrypt/live/${domain}/fullchain.pem /etc/nginx/certs/${app}.crt && \
         cp /etc/letsencrypt/live/${domain}/privkey.pem  /etc/nginx/certs/${app}.key && \
         chmod 600 /etc/nginx/certs/${app}.key"

    echo "==> [${app}] Activating SSL nginx config..."
    cp "${templates_dir}/${app}-ssl.conf" "${proxy_conf_dir}/${app}.conf"
    sed -i.bak "s/GLPI_DOMAIN/${domain}/g; s/N8N_DOMAIN/${domain}/g; \
                s/CHATWOOT_DOMAIN/${domain}/g; s/EVOLUTION_DOMAIN/${domain}/g" \
        "${proxy_conf_dir}/${app}.conf" && rm -f "${proxy_conf_dir}/${app}.conf.bak"

    _compose exec proxy-nginx nginx -s reload
    echo "==> [${app}] Certificate issued and nginx reloaded with SSL config."
}

_run_letsencrypt_renew() {
    local app="$1"
    local domain
    domain="$(_resolve_le_var "${app}" "LETSENCRYPT_DOMAIN")"

    if [ -z "${domain}" ]; then
        echo "ERROR: LETSENCRYPT_DOMAIN not set for app '${app}'."
        exit 1
    fi

    local proxy_conf_dir="${INFRA_DIR}/reverse-proxy/conf.d"
    local templates_dir="${INFRA_DIR}/reverse-proxy/templates"

    echo "==> [${app}] Renewing certificates..."
    _compose run --rm --no-deps proxy-certbot renew --quiet

    echo "==> [${app}] Updating cert files..."
    _compose run --rm --no-deps --entrypoint sh proxy-certbot -c \
        "cp /etc/letsencrypt/live/${domain}/fullchain.pem /etc/nginx/certs/${app}.crt && \
         cp /etc/letsencrypt/live/${domain}/privkey.pem  /etc/nginx/certs/${app}.key && \
         chmod 600 /etc/nginx/certs/${app}.key"

    echo "==> [${app}] Reloading proxy-nginx..."
    _compose exec proxy-nginx nginx -s reload
    echo "==> [${app}] Certificate renewed."
}

# ─── backup helper (delegates to per-script) ─────────────────────────────────
_run_backup() {
    local target="${1:-all}"
    case "${target}" in
        glpi)
            bash "${INFRA_DIR}/apps/glpi/scripts/backup.sh"
            ;;
        postgres)
            bash "${INFRA_DIR}/shared/scripts/backup-postgres.sh"
            ;;
        all)
            bash "${INFRA_DIR}/shared/scripts/backup-postgres.sh"
            bash "${INFRA_DIR}/apps/glpi/scripts/backup.sh"
            ;;
        *)
            echo "Unknown backup target: ${target}. Use glpi, postgres, or all."
            exit 1
            ;;
    esac
}

# ─── dispatch ─────────────────────────────────────────────────────────────────
case "${ACTION}" in
    up)
        # Bootstrap shared nginx conf.d with limits file on first run
        conf_d="${INFRA_DIR}/reverse-proxy/conf.d"
        if [ ! -f "${conf_d}/00-limits.conf" ]; then
            cp "${INFRA_DIR}/reverse-proxy/templates/00-limits.conf" "${conf_d}/00-limits.conf"
        fi
        _compose up -d "$@"
        ;;
    down)
        _compose down "$@"
        ;;
    restart)
        _compose up -d --force-recreate "$@"
        ;;
    logs)
        _compose logs -f "$@"
        ;;
    ps|status)
        _compose ps "$@"
        ;;
    pull)
        _compose pull "$@"
        ;;
    config)
        _compose config "$@"
        ;;
    letsencrypt)
        APP_ARG="${1:?Usage: ./rossini-runner.sh letsencrypt <app>}"
        shift || true
        _run_letsencrypt "${APP_ARG}"
        ;;
    letsencrypt-renew)
        APP_ARG="${1:?Usage: ./rossini-runner.sh letsencrypt-renew <app>}"
        shift || true
        _run_letsencrypt_renew "${APP_ARG}"
        ;;
    backup)
        TARGET="${1:-all}"
        shift || true
        _run_backup "${TARGET}"
        ;;
    *)
        _compose "${ACTION}" "$@"
        ;;
esac
