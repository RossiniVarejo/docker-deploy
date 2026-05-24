# Rossini Docker Infra (GLPI)

Este repositório sobe a stack completa do GLPI com:

- PostgreSQL compartilhado (infra comum)
- GLPI (app + cron)
- Nginx reverse proxy
- Certbot (Let's Encrypt)

## 1. Pre-requisitos

- macOS ou Linux
- Docker + Docker Compose plugin (`docker compose`)
- DNS do seu dominio apontando para o servidor (para Let's Encrypt)
- Portas liberadas:
  - `80` (obrigatoria para desafio HTTP-01 do Let's Encrypt)
  - `443` (HTTPS)

Verifique:

```bash
docker --version
docker compose version
```

## 2. Estrutura principal

- `prepare.sh`: cria diretorios, gera `.env` inicial e sincroniza arquivos para `/opt/infra`
- `rossini-runner.sh`: comando unico para operar toda a stack
- `infra/shared/.env`: configuracoes centrais
- `infra/apps/glpi/docker-compose.yml`: servicos GLPI + Nginx + Certbot

## 2.1 Como funciona o sync

Mesmo com o repositorio clonado em `~/seu-repo`, o runtime e executado a partir de `/opt/infra`.

O `prepare.sh` sincroniza:

- `infra/shared/*` -> `/opt/infra/shared/`
- `infra/apps/glpi/*` -> `/opt/infra/apps/glpi/`

E tambem copia:

- `infra/shared/.env` -> `/opt/infra/shared/.env`

## 3. Preparacao inicial

Na raiz do projeto:

```bash
chmod +x prepare.sh rossini-runner.sh
./prepare.sh
```

Isso cria os caminhos de dados persistentes e copia `infra/shared/.env.example` para `infra/shared/.env` (se ainda nao existir).
Tambem sincroniza os arquivos do projeto para `/opt/infra`, que e o caminho usado pelo runner.

Depois de qualquer alteracao em compose/nginx/php/scripts (ou apos `git pull`), rode novamente:

```bash
./rossini-runner.sh sync
```

## 4. Configuracao do ambiente

Edite `infra/shared/.env` e ajuste no minimo:

```env
# Banco GLPI
MYSQL_ROOT_PASSWORD=troque
MYSQL_PASSWORD=troque

# Dominio e email para Let's Encrypt
LETSENCRYPT_DOMAIN=seu-dominio.com.br
LETSENCRYPT_EMAIL=voce@seu-dominio.com.br
LETSENCRYPT_STAGING=0

# Portas publicas (obrigatorio para cert valido)
GLPI_HTTP_PORT=80
GLPI_HTTPS_PORT=443

# Caminho dos certificados usado pelo Nginx
GLPI_CERTS_PATH=/opt/infra/apps/glpi/certs
```

Observacoes:

- Em homologacao, use `LETSENCRYPT_STAGING=1` para evitar limite de emissao.
- Para producao, mantenha `LETSENCRYPT_STAGING=0`.

## 5. Subir tudo

```bash
./rossini-runner.sh up
```

O `rossini-runner.sh` usa por padrao os arquivos sincronizados em `/opt/infra`.

Ver status:

```bash
./rossini-runner.sh status
```

Ver logs:

```bash
./rossini-runner.sh logs
```

## 6. Gerar certificado Let's Encrypt

Com a stack no ar e DNS correto:

```bash
./rossini-runner.sh letsencrypt
```

Na primeira execucao, se `glpi.crt` e `glpi.key` ainda nao existirem, o runner sobe o Nginx em modo HTTP (`glpi-dev.conf`) para permitir o desafio ACME. Apos gerar os certificados, ele recria o Nginx automaticamente com configuracao SSL (`glpi.conf`).

Esse comando:

- garante o Nginx em execucao
- solicita o certificado via Certbot (webroot)
- copia para:
  - `glpi.crt`
  - `glpi.key`
- recarrega o Nginx

## 7. Renovacao de certificado

Renovacao manual:

```bash
./rossini-runner.sh letsencrypt-renew
```

Sugestao de cron (host), 1x por dia as 03:17:

```cron
17 3 * * * cd /caminho/para/rossini-docker-infra && ./rossini-runner.sh letsencrypt-renew >> /tmp/rossini-letsencrypt.log 2>&1
```

## 8. Backup e restore do GLPI

Backup:

```bash
bash /opt/infra/apps/glpi/scripts/backup.sh
```

Restore (exemplo):

```bash
bash /opt/infra/apps/glpi/scripts/restore.sh 20260425_030000
```

Arquivos de backup usam `GLPI_BACKUP_PATH` definido no `.env`.

## 9. Comandos uteis do runner

```bash
./rossini-runner.sh up
./rossini-runner.sh sync
./rossini-runner.sh down
./rossini-runner.sh restart
./rossini-runner.sh status
./rossini-runner.sh logs
./rossini-runner.sh pull
./rossini-runner.sh config
./rossini-runner.sh letsencrypt [glpi|n8n]
./rossini-runner.sh letsencrypt-renew [glpi|n8n]
```

O argumento de app para `letsencrypt` e `letsencrypt-renew` e opcional; o padrao e `glpi` para retrocompatibilidade.

## 10. Troubleshooting rapido

- Erro de `.env` ausente:
  - rode `./rossini-runner.sh sync`
- Erro `mounts denied` no macOS (Docker Desktop):
  - o runner remapeia automaticamente caminhos `/srv/docker-data/...` para `${HOME}/docker-data/...`
  - opcional: defina `MAC_DATA_ROOT` para outro caminho dentro da sua home
- Certificado nao emite:
  - confirme DNS para o servidor
  - confirme porta 80 aberta externamente
  - teste com `LETSENCRYPT_STAGING=1`
- Nginx nao sobe com SSL:
  - verifique se `GLPI_CERTS_PATH` esta correto e gravavel
  - sem certificado inicial, rode `./rossini-runner.sh up` (HTTP) e depois `./rossini-runner.sh letsencrypt`
- Validar compose final:

```bash
./rossini-runner.sh config
```

## 11. Primeira verificacao funcional

Depois de `up` + `letsencrypt`:

1. Acesse `https://SEU_DOMINIO`
2. Finalize o wizard do GLPI
3. Ajuste credenciais padrao no primeiro login

## 12. n8n

### Configuracao

Edite `infra/shared/.env` e ajuste:

```env
# Dominio publico do n8n
N8N_DOMAIN=n8n.exemplo.com.br
N8N_LETSENCRYPT_DOMAIN=n8n.exemplo.com.br
N8N_LETSENCRYPT_EMAIL=voce@exemplo.com.br

# Portas publicas
N8N_HTTP_PORT=8081
N8N_HTTPS_PORT=8444

# Banco de dados (Postgres compartilhado)
N8N_DB_NAME=n8n
N8N_DB_USER=n8n
N8N_DB_PASSWORD=senha-segura

# Chave de criptografia: minimo 32 caracteres aleatorios
# IMPORTANTE: nao altere apos o primeiro start ou as credenciais armazenadas serao perdidas
N8N_ENCRYPTION_KEY=gere-uma-chave-aleatoria-de-32-chars
```

O `TZ` (timezone) e compartilhado com os demais servicos via `infra/shared/.env`.

### Subir e gerar certificado

```bash
./rossini-runner.sh up
./rossini-runner.sh letsencrypt n8n
```

### Renovacao de certificado

```bash
./rossini-runner.sh letsencrypt-renew n8n
```

### Banco de dados Postgres (primeiro boot)

Na primeira execucao com um volume de dados vazio, o script `infra/shared/scripts/postgres-init/10-create-n8n.sh` cria automaticamente o role e o banco `n8n`.

**Se o volume de dados do Postgres ja existir**, execute manualmente:

```sql
-- Conecte ao container postgres:
docker exec -it <container-postgres> psql -U $POSTGRES_USER

CREATE ROLE n8n WITH LOGIN PASSWORD 'sua-senha';
CREATE DATABASE n8n OWNER n8n;
```

### Dados persistentes

| Variavel | Caminho padrao | Conteudo |
|---|---|---|
| `N8N_DATA_PATH` | `/srv/docker-data/n8n/data` | Configuracoes, workflows, credenciais |
| `N8N_FILES_PATH` | `/srv/docker-data/n8n/files` | Arquivos de upload/download dos workflows |
