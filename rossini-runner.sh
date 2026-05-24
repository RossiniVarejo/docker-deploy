#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect if we're running from repo (has infra/ subdir) or from /opt/infra
if [ -d "${SCRIPT_DIR}/infra" ]; then
	# Running from repo
	RUNTIME_ROOT="${RUNTIME_ROOT:-${SCRIPT_DIR}}"
	REPO_MODE=true
else
	# Running from /opt/infra (synced)
	RUNTIME_ROOT="${RUNTIME_ROOT:-/opt/infra}"
	REPO_MODE=false
fi

ACTION="${1:-up}"
shift || true

if [ "${ACTION}" = "sync" ]; then
	exec "${SCRIPT_DIR}/prepare.sh"
fi

# Set file paths based on repo mode
if [ "${REPO_MODE}" = "true" ]; then
	ENV_FILE="${ENV_FILE:-${RUNTIME_ROOT}/infra/shared/.env}"
	NETWORK_FILE="${NETWORK_FILE:-${RUNTIME_ROOT}/infra/shared/docker-compose.network.yml}"
	POSTGRES_FILE="${POSTGRES_FILE:-${RUNTIME_ROOT}/infra/shared/docker-compose.postgres.yml}"
	GLPI_FILE="${GLPI_FILE:-${RUNTIME_ROOT}/infra/apps/glpi/docker-compose.yml}"
	N8N_FILE="${N8N_FILE:-${RUNTIME_ROOT}/infra/apps/n8n/docker-compose.yml}"
else
	ENV_FILE="${ENV_FILE:-${RUNTIME_ROOT}/shared/.env}"
	NETWORK_FILE="${NETWORK_FILE:-${RUNTIME_ROOT}/shared/docker-compose.network.yml}"
	POSTGRES_FILE="${POSTGRES_FILE:-${RUNTIME_ROOT}/shared/docker-compose.postgres.yml}"
	GLPI_FILE="${GLPI_FILE:-${RUNTIME_ROOT}/apps/glpi/docker-compose.yml}"
	N8N_FILE="${N8N_FILE:-${RUNTIME_ROOT}/apps/n8n/docker-compose.yml}"
fi

if [ ! -f "${ENV_FILE}" ]; then
	echo "Missing ${ENV_FILE}"
	echo "Run ./rossini-runner.sh sync first to sync files from the repository to ${RUNTIME_ROOT}"
	exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"

# On macOS, Docker Desktop cannot mount /srv/* by default.
# Remap Linux-style data paths to a HOME-based path that is shareable.
if [ "$(uname -s)" = "Darwin" ]; then
	MAC_DATA_ROOT="${MAC_DATA_ROOT:-${HOME}/docker-data}"

	remap_data_path() {
		local var_name="$1"
		local current_value="${!var_name:-}"
		if [ -n "${current_value}" ] && [[ "${current_value}" == /srv/docker-data* ]]; then
			export "${var_name}=${current_value/#\/srv\/docker-data/${MAC_DATA_ROOT}}"
		fi
	}

	remap_data_path "POSTGRES_DATA_PATH"
	remap_data_path "GLPI_MYSQL_DATA_PATH"
	remap_data_path "GLPI_FILES_PATH"
	remap_data_path "GLPI_PLUGINS_PATH"
	remap_data_path "GLPI_MARKETPLACE_PATH"
	remap_data_path "GLPI_CONFIG_PATH"
	remap_data_path "GLPI_BACKUP_PATH"
	remap_data_path "N8N_DATA_PATH"
	remap_data_path "N8N_FILES_PATH"
fi

# Set absolute paths for GLPI nginx config based on RUNTIME_ROOT and mode
if [ "${REPO_MODE}" = "true" ]; then
	export GLPI_NGINX_CONF_PATH="${GLPI_NGINX_CONF_PATH:-${RUNTIME_ROOT}/infra/apps/glpi/nginx/glpi.conf}"
	export GLPI_NGINX_DEV_CONF_PATH="${GLPI_NGINX_DEV_CONF_PATH:-${RUNTIME_ROOT}/infra/apps/glpi/nginx/glpi-dev.conf}"
	export GLPI_CERTS_PATH="${GLPI_CERTS_PATH:-${RUNTIME_ROOT}/infra/apps/glpi/certs}"
else
	export GLPI_NGINX_CONF_PATH="${GLPI_NGINX_CONF_PATH:-${RUNTIME_ROOT}/apps/glpi/nginx/glpi.conf}"
	export GLPI_NGINX_DEV_CONF_PATH="${GLPI_NGINX_DEV_CONF_PATH:-${RUNTIME_ROOT}/apps/glpi/nginx/glpi-dev.conf}"
	export GLPI_CERTS_PATH="${GLPI_CERTS_PATH:-${RUNTIME_ROOT}/apps/glpi/certs}"
fi

GLPI_NGINX_SSL_CONF_PATH="${GLPI_NGINX_CONF_PATH}"
GLPI_CERT_FILE="${GLPI_CERTS_PATH}/glpi.crt"
GLPI_KEY_FILE="${GLPI_CERTS_PATH}/glpi.key"

if [ ! -f "${GLPI_CERT_FILE}" ] || [ ! -f "${GLPI_KEY_FILE}" ]; then
	export GLPI_NGINX_CONF_PATH="${GLPI_NGINX_DEV_CONF_PATH}"
fi

# Set absolute paths for n8n nginx config based on RUNTIME_ROOT and mode
if [ "${REPO_MODE}" = "true" ]; then
	export N8N_NGINX_CONF_PATH="${N8N_NGINX_CONF_PATH:-${RUNTIME_ROOT}/infra/apps/n8n/nginx/n8n.conf}"
	export N8N_NGINX_DEV_CONF_PATH="${N8N_NGINX_DEV_CONF_PATH:-${RUNTIME_ROOT}/infra/apps/n8n/nginx/n8n-dev.conf}"
	export N8N_CERTS_PATH="${N8N_CERTS_PATH:-${RUNTIME_ROOT}/infra/apps/n8n/certs}"
else
	export N8N_NGINX_CONF_PATH="${N8N_NGINX_CONF_PATH:-${RUNTIME_ROOT}/apps/n8n/nginx/n8n.conf}"
	export N8N_NGINX_DEV_CONF_PATH="${N8N_NGINX_DEV_CONF_PATH:-${RUNTIME_ROOT}/apps/n8n/nginx/n8n-dev.conf}"
	export N8N_CERTS_PATH="${N8N_CERTS_PATH:-${RUNTIME_ROOT}/apps/n8n/certs}"
fi

N8N_NGINX_SSL_CONF_PATH="${N8N_NGINX_CONF_PATH}"
N8N_CERT_FILE="${N8N_CERTS_PATH}/n8n.crt"
N8N_KEY_FILE="${N8N_CERTS_PATH}/n8n.key"

if [ ! -f "${N8N_CERT_FILE}" ] || [ ! -f "${N8N_KEY_FILE}" ]; then
	export N8N_NGINX_CONF_PATH="${N8N_NGINX_DEV_CONF_PATH}"
fi

set +a

COMPOSE_ARGS=(
	--env-file "${ENV_FILE}"
	-f "${NETWORK_FILE}"
	-f "${POSTGRES_FILE}"
	-f "${GLPI_FILE}"
	-f "${N8N_FILE}"
)

# Run Let's Encrypt certificate issuance for a given app.
# Usage: _run_letsencrypt <app>   e.g. glpi or n8n
_run_letsencrypt() {
	local app="${1}"
	local APP
	APP="$(echo "${app}" | tr '[:lower:]' '[:upper:]')"

	local domain_var="${APP}_LETSENCRYPT_DOMAIN"
	local email_var="${APP}_LETSENCRYPT_EMAIL"
	local staging_var="${APP}_LETSENCRYPT_STAGING"
	local ssl_conf_var="${APP}_NGINX_SSL_CONF_PATH"
	local dev_conf_var="${APP}_NGINX_DEV_CONF_PATH"

	local domain="${!domain_var:-}"
	local email="${!email_var:-}"
	local staging="${!staging_var:-0}"
	local ssl_conf="${!ssl_conf_var:-}"
	local dev_conf="${!dev_conf_var:-}"

	if [ -z "${domain}" ] || [ -z "${email}" ]; then
		echo "Set ${domain_var} and ${email_var} in infra/shared/.env before running letsencrypt"
		exit 1
	fi

	echo "Starting ${app}-nginx for ACME HTTP challenge..."
	env "${APP}_NGINX_CONF_PATH=${dev_conf}" \
		docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate "${app}-nginx"

	local staging_arg=""
	if [ "${staging}" = "1" ]; then
		staging_arg="--staging"
	fi

	echo "Requesting certificate for ${domain}..."
	docker compose "${COMPOSE_ARGS[@]}" run --rm --no-deps "${app}-certbot" \
		certonly --webroot -w /var/www/certbot \
		-d "${domain}" \
		--email "${email}" --agree-tos --no-eff-email --non-interactive ${staging_arg}

	echo "Copying certificate to nginx mount..."
	docker compose "${COMPOSE_ARGS[@]}" run --rm --no-deps --entrypoint sh "${app}-certbot" -c \
		"cp /etc/letsencrypt/live/${domain}/fullchain.pem /etc/nginx/certs/${app}.crt && \
		cp /etc/letsencrypt/live/${domain}/privkey.pem /etc/nginx/certs/${app}.key && \
		chmod 600 /etc/nginx/certs/${app}.key"

	echo "Switching ${app}-nginx to SSL config..."
	env "${APP}_NGINX_CONF_PATH=${ssl_conf}" \
		docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate "${app}-nginx"
	echo "Let's Encrypt certificate generated successfully for ${app}."
}

# Run Let's Encrypt renewal for a given app.
# Usage: _run_letsencrypt_renew <app>
_run_letsencrypt_renew() {
	local app="${1}"
	local APP
	APP="$(echo "${app}" | tr '[:lower:]' '[:upper:]')"

	local domain_var="${APP}_LETSENCRYPT_DOMAIN"
	local ssl_conf_var="${APP}_NGINX_SSL_CONF_PATH"

	local domain="${!domain_var:-}"
	local ssl_conf="${!ssl_conf_var:-}"

	if [ -z "${domain}" ]; then
		echo "Set ${domain_var} in infra/shared/.env before running letsencrypt-renew"
		exit 1
	fi

	echo "Renewing certificates for ${app}..."
	docker compose "${COMPOSE_ARGS[@]}" run --rm --no-deps "${app}-certbot" \
		renew --webroot -w /var/www/certbot --quiet

	echo "Updating ${app} nginx certificate files..."
	docker compose "${COMPOSE_ARGS[@]}" run --rm --no-deps --entrypoint sh "${app}-certbot" -c \
		"cp /etc/letsencrypt/live/${domain}/fullchain.pem /etc/nginx/certs/${app}.crt && \
		cp /etc/letsencrypt/live/${domain}/privkey.pem /etc/nginx/certs/${app}.key && \
		chmod 600 /etc/nginx/certs/${app}.key"

	env "${APP}_NGINX_CONF_PATH=${ssl_conf}" \
		docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate "${app}-nginx"
	echo "Let's Encrypt certificates renewed and ${app}-nginx reloaded."
}

case "${ACTION}" in
	up)
		docker compose "${COMPOSE_ARGS[@]}" up -d "$@"
		;;
	down)
		docker compose "${COMPOSE_ARGS[@]}" down "$@"
		;;
	restart)
		docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate "$@"
		;;
	logs)
		docker compose "${COMPOSE_ARGS[@]}" logs -f "$@"
		;;
	ps|status)
		docker compose "${COMPOSE_ARGS[@]}" ps "$@"
		;;
	pull)
		docker compose "${COMPOSE_ARGS[@]}" pull "$@"
		;;
	config)
		docker compose "${COMPOSE_ARGS[@]}" config "$@"
		;;
	letsencrypt)
		# Default to glpi for backward-compatibility; pass app as first extra arg.
		APP_ARG="${1:-glpi}"
		shift || true
		_run_letsencrypt "${APP_ARG}"
		;;
	letsencrypt-renew)
		APP_ARG="${1:-glpi}"
		shift || true
		_run_letsencrypt_renew "${APP_ARG}"
		;;
	*)
		docker compose "${COMPOSE_ARGS[@]}" "${ACTION}" "$@"
		;;
esac
