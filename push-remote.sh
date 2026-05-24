#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REMOTE_USER="${REMOTE_USER:-dionizio_ferreira}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_PATH="${REMOTE_PATH:-/home/dionizio_ferreira/rossini-docker-infra}"

DRY_RUN=false
SYNC_ENV=false
APPLY=false

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Push local repository files to the remote server via rsync.

Environment:
  REMOTE_HOST   SSH host (required unless passed with --host)
  REMOTE_USER   SSH user (default: dionizio_ferreira)
  REMOTE_PATH   Remote directory (default: /home/dionizio_ferreira/rossini-docker-infra)

Options:
  --host HOST   Remote SSH host
  --dry-run     Show what would be transferred without copying
  --with-env    Include .env files (excluded by default)
  --apply       After push, run sync + restart on the remote server
  -h, --help    Show this help

Examples:
  REMOTE_HOST=meu-servidor.com ./push-remote.sh
  ./push-remote.sh --host meu-servidor.com --apply
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--host)
			REMOTE_HOST="${2:-}"
			shift 2
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--with-env)
			SYNC_ENV=true
			shift
			;;
		--apply)
			APPLY=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

if [ -z "${REMOTE_HOST}" ]; then
	echo "REMOTE_HOST is required. Set REMOTE_HOST or pass --host." >&2
	exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
	echo "rsync is required but was not found in PATH." >&2
	exit 1
fi

REMOTE="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"

RSYNC_ARGS=(
	-a
	-z
	--delete
	--human-readable
	--progress
)

EXCLUDES=(
	--exclude ".git/"
	--exclude "**/.git/"
	--exclude ".DS_Store"
	--exclude "node_modules/"
	--exclude "infra/apps/glpi/certs/"
	--exclude "infra/apps/n8n/certs/"
	--exclude "infra/apps/n8n/plan/"
	--exclude "infra/apps/n8n/.claude/"
)

if [ "${SYNC_ENV}" = "false" ]; then
	EXCLUDES+=(--exclude ".env")
fi

if [ "${DRY_RUN}" = "true" ]; then
	RSYNC_ARGS+=(--dry-run)
fi

echo "Pushing ${SCRIPT_DIR}/ -> ${REMOTE}"

ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_PATH}'"

rsync "${RSYNC_ARGS[@]}" "${EXCLUDES[@]}" \
	"${SCRIPT_DIR}/" "${REMOTE}"

echo "Remote sync complete at ${REMOTE_PATH}."

if [ "${APPLY}" = "true" ]; then
	if [ "${DRY_RUN}" = "true" ]; then
		echo "Skipping remote apply because --dry-run is enabled."
		exit 0
	fi

	echo "Applying changes on remote server..."
	ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -s <<EOF
set -euo pipefail
cd '${REMOTE_PATH}'
chmod +x prepare.sh rossini-runner.sh
./rossini-runner.sh sync
./rossini-runner.sh restart
EOF
	echo "Remote stack restarted."
fi
