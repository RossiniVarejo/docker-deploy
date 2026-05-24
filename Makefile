.PHONY: check check-compose check-shell help

SHELL_SCRIPTS := rossini-runner.sh prepare.sh push-remote.sh \
    $(wildcard infra/shared/scripts/*.sh) \
    $(wildcard infra/apps/*/scripts/*.sh)

help:
	@echo "Usage:"
	@echo "  make check          Run all checks (compose config + shellcheck)"
	@echo "  make check-compose  Validate docker compose config"
	@echo "  make check-shell    Shellcheck all shell scripts"

check: check-compose check-shell
	@echo "All checks passed."

check-compose:
	@echo "==> Validating compose config..."
	@if [ ! -f infra/shared/.env ]; then \
		cp infra/shared/.env.example infra/shared/.env; \
	fi
	@if [ ! -f infra/apps/glpi/.env ]; then \
		cp infra/apps/glpi/.env.example infra/apps/glpi/.env; \
	fi
	@if [ ! -f infra/apps/n8n/.env ]; then \
		cp infra/apps/n8n/.env.example infra/apps/n8n/.env; \
	fi
	@if [ ! -f infra/apps/chatwoot/.env ]; then \
		cp infra/apps/chatwoot/.env.example infra/apps/chatwoot/.env; \
	fi
	@touch infra/reverse-proxy/conf.d/00-limits.conf
	docker compose \
		--env-file infra/shared/.env \
		--env-file infra/apps/glpi/.env \
		--env-file infra/apps/n8n/.env \
		-f infra/compose.yml \
		--project-directory infra \
		config -q
	@echo "   compose config OK"

check-shell:
	@echo "==> Running shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck --severity=warning $(SHELL_SCRIPTS); \
		echo "   shellcheck OK"; \
	else \
		echo "   WARNING: shellcheck not found; skipping (install: brew install shellcheck)"; \
	fi
