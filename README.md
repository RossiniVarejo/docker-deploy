# Rossini Docker Infra

Multi-app Docker Compose stack for the Rossini environment.

**Apps:** GLPI (IT service desk) · n8n (workflow automation) · Chatwoot (customer support)

---

## 1. Prerequisites

- macOS or Linux
- Docker + Docker Compose v2.20+ (`docker compose`)
- DNS records pointing your domains to the server before requesting TLS certs
- Ports `80` and `443` reachable externally (required for Let's Encrypt HTTP-01)

```bash
docker --version
docker compose version
```

---

## 2. Repository structure

```
.
├── prepare.sh               # Provision dirs + sync repo to /opt/infra
├── rossini-runner.sh        # Single operator interface for the stack
├── push-remote.sh           # rsync repo to a remote server + optional apply
├── Makefile                 # make check — validate compose + shellcheck
│
└── infra/
    ├── compose.yml          # Top-level compose include manifest (entire stack)
    │
    ├── shared/              # Cross-cutting infra
    │   ├── .env.example     # Shared vars (TZ, Postgres, networks)
    │   ├── docker-compose.network.yml      # rossini-shared bridge
    │   ├── docker-compose.data-network.yml # rossini-data bridge (Postgres consumers)
    │   ├── docker-compose.postgres.yml     # Shared Postgres cluster
    │   └── scripts/
    │       ├── postgres-init/10-create-n8n.sh  # Bootstrap n8n DB on fresh volume
    │       └── backup-postgres.sh              # pg_dump all configured databases
    │
    ├── reverse-proxy/       # Single shared nginx + certbot (the only :80/:443 publisher)
    │   ├── docker-compose.yml
    │   ├── templates/       # Nginx conf templates (dev = HTTP, ssl = HTTPS)
    │   └── conf.d/          # Runtime active confs (written by runner; gitignored)
    │
    └── apps/
        ├── glpi/            # GLPI + MySQL + cron
        │   ├── .env.example
        │   ├── docker-compose.yml
        │   ├── mysql/my.cnf
        │   ├── nginx/       # glpi.conf, glpi-dev.conf (kept for reference)
        │   ├── php/glpi.ini
        │   └── scripts/     # backup.sh, restore.sh, init-db.sh
        ├── n8n/             # n8n workflow automation
        │   ├── .env.example
        │   └── docker-compose.yml
        ├── chatwoot/        # Chatwoot customer support
        │   ├── .env.example
        │   └── docker-compose.yml
        └── evolution-api-overlay/  # Evolution API rossini overlay
            ├── .env.example
            └── docker-compose.rossini.yml
```

### Network topology

```
Internet
    │
    ▼
proxy-nginx (:80/:443)
    │  rossini-shared
    ├──► glpi (PHP-FPM)  ──► glpi-db (MySQL, rossini-shared only)
    ├──► n8n (:5678)     ──► postgres  (via rossini-data)
    └──► chatwoot-rails  ──► postgres  (via rossini-data)
```

- **rossini-shared** — proxy reaches all app containers
- **rossini-data** — Postgres reachable only by n8n and Chatwoot (not GLPI, not proxy)
- GLPI's MySQL is on rossini-shared but only GLPI services talk to it

---

## 3. First-time setup

### 3.1 Clone and prepare

```bash
git clone <repo-url> rossini-docker-infra
cd rossini-docker-infra
chmod +x prepare.sh rossini-runner.sh push-remote.sh

./prepare.sh
```

`prepare.sh` creates data directories under `/srv/docker-data` (Linux) or
`~/docker-data` (macOS), syncs files to `/opt/infra`, and bootstraps `.env`
files from the `.env.example` templates if they don't exist.

### 3.2 Configure secrets

Edit the three `.env` files — **never commit them**:

```bash
# Shared: TZ, Postgres cluster
vim infra/shared/.env

# GLPI: MySQL credentials, domain, certs path
vim infra/apps/glpi/.env

# n8n: DB credentials, encryption key, basic-auth, domain
vim infra/apps/n8n/.env
```

Minimum values to set before `up`:

| File | Variable | Notes |
|---|---|---|
| `shared/.env` | `POSTGRES_PASS` | Strong random password |
| `glpi/.env` | `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` | Strong random passwords |
| `glpi/.env` | `LETSENCRYPT_DOMAIN`, `LETSENCRYPT_EMAIL` | Your domain + email |
| `n8n/.env` | `N8N_DB_PASSWORD` | Strong random password |
| `n8n/.env` | `N8N_ENCRYPTION_KEY` | `openssl rand -base64 48 \| tr -d '/+=' \| head -c 48` |
| `n8n/.env` | `N8N_BASIC_AUTH_USER`, `N8N_BASIC_AUTH_PASSWORD` | UI access credentials |
| `n8n/.env` | `N8N_DOMAIN`, `N8N_LETSENCRYPT_DOMAIN`, `N8N_LETSENCRYPT_EMAIL` | Your domain + email |

---

## 4. Bring the stack up

```bash
./rossini-runner.sh up
```

Check status:

```bash
./rossini-runner.sh status
./rossini-runner.sh logs
```

---

## 5. TLS certificates (Let's Encrypt)

> DNS must resolve and port 80 must be open before running this.

```bash
# First certificate issuance for each app:
./rossini-runner.sh letsencrypt glpi
./rossini-runner.sh letsencrypt n8n
./rossini-runner.sh letsencrypt chatwoot

# Manual renewal (add to cron for automation):
./rossini-runner.sh letsencrypt-renew glpi
./rossini-runner.sh letsencrypt-renew n8n
```

Suggested cron (runs daily at 03:17):

```cron
17 3 * * * cd /opt/infra && ./rossini-runner.sh letsencrypt-renew glpi >> /tmp/le-glpi.log 2>&1
17 3 * * * cd /opt/infra && ./rossini-runner.sh letsencrypt-renew n8n  >> /tmp/le-n8n.log  2>&1
```

How it works:
1. Copies `templates/<app>-dev.conf` → `reverse-proxy/conf.d/<app>.conf` (HTTP-only, serves ACME challenge)
2. Reloads proxy-nginx
3. Runs certbot via `proxy-certbot` container
4. Copies `fullchain.pem` → `reverse-proxy/certs/<app>.crt` and `privkey.pem` → `<app>.key`
5. Copies `templates/<app>-ssl.conf` → `conf.d/<app>.conf` (HTTPS)
6. Reloads proxy-nginx

---

## 6. Backup and restore

### Postgres (n8n, future apps)

```bash
./rossini-runner.sh backup postgres
```

Dumps are written to `POSTGRES_BACKUP_PATH` (default `/srv/docker-data/postgres/backups`).

Restore example:

```bash
docker exec -i postgres pg_restore \
  -U postgres --clean --if-exists -d n8n \
  < /srv/docker-data/postgres/backups/pg_n8n_20260524_030000.dump
```

### GLPI

```bash
./rossini-runner.sh backup glpi
```

Dumps MySQL + files + plugins + config to `GLPI_BACKUP_PATH`.

Restore example:

```bash
bash /opt/infra/apps/glpi/scripts/restore.sh 20260524_030000
```

### Backup all

```bash
./rossini-runner.sh backup all
```

---

## 7. Full runner reference

```bash
./rossini-runner.sh up [services...]
./rossini-runner.sh down
./rossini-runner.sh restart [services...]
./rossini-runner.sh logs [services...]
./rossini-runner.sh status
./rossini-runner.sh pull
./rossini-runner.sh config          # Print merged compose config (dry-run)
./rossini-runner.sh sync            # Re-run prepare.sh (after git pull)
./rossini-runner.sh letsencrypt <app>
./rossini-runner.sh letsencrypt-renew <app>
./rossini-runner.sh backup [glpi|postgres|all]
```

---

## 8. Sync to a remote server

```bash
# Preview what would be transferred
./push-remote.sh --host my-server.example.com --dry-run

# Push + sync + restart on remote
./push-remote.sh --host my-server.example.com --apply

# Include .env files in push (use with care)
./push-remote.sh --host my-server.example.com --with-env --apply
```

---

## 9. After any git pull

```bash
./rossini-runner.sh sync    # syncs files to /opt/infra
./rossini-runner.sh restart # recreates changed containers
```

---

## 10. Validate before deploy

```bash
make check
# or individually:
make check-compose   # docker compose config -q
make check-shell     # shellcheck on all .sh files
```

---

## 11. Adding a new app

1. **Create the app folder:**
   ```
   infra/apps/<app>/
   ├── .env.example       # app-specific vars
   └── docker-compose.yml # no ports:, no nginx — joins rossini-shared
   ```
   If the app uses shared Postgres, also join `rossini-data` network.

2. **Add nginx templates:**
   ```
   infra/reverse-proxy/templates/<app>-dev.conf   # HTTP + ACME
   infra/reverse-proxy/templates/<app>-ssl.conf   # HTTPS + proxy_pass http://<container>
   ```
   Replace the `APP_DOMAIN` placeholder with the real domain at runtime (the runner does this).

3. **Register in `infra/compose.yml`:**
   ```yaml
   include:
     - path: apps/<app>/docker-compose.yml
   ```

4. **Add to `prepare.sh`:**
   Add `sync_dir` for the new app dir and `_load_env` for its `.env`.

5. **Issue certificate:**
   ```bash
   ./rossini-runner.sh letsencrypt <app>
   ```

---

## 12. Secret rotation

### N8N_ENCRYPTION_KEY

> Only rotate before n8n has stored any credentials. After that, changing
> the key loses all stored credential data.

1. Generate: `openssl rand -base64 48 | tr -d '/+=' | head -c 48`
2. Update `infra/apps/n8n/.env`
3. `./rossini-runner.sh restart n8n`

### Postgres password

1. Update `POSTGRES_PASS` in `infra/shared/.env`
2. Connect and `ALTER ROLE postgres WITH PASSWORD 'new-pass';`
3. `./rossini-runner.sh restart postgres n8n chatwoot`

### MySQL (GLPI)

1. Update `MYSQL_ROOT_PASSWORD`/`MYSQL_PASSWORD` in `infra/apps/glpi/.env`
2. Connect and `ALTER USER 'glpi'@'%' IDENTIFIED BY 'new-pass';`
3. `./rossini-runner.sh restart glpi-db glpi glpi-cron`

---

## 13. Troubleshooting

| Problem | Fix |
|---|---|
| `.env` missing | Run `./rossini-runner.sh sync` |
| `mounts denied` on macOS | Runner auto-remaps `/srv/docker-data` → `~/docker-data`; set `MAC_DATA_ROOT` to override |
| Cert not issuing | Confirm DNS → server, port 80 open, try `LETSENCRYPT_STAGING=1` first |
| nginx won't start (SSL) | Run `letsencrypt <app>` before SSL conf is activated |
| Validate merged config | `./rossini-runner.sh config` |
