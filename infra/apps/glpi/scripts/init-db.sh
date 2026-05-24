#!/bin/sh
set -e

echo "[init-db] Starting GLPI database bootstrap..."

mysql -u root --password="${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    DELETE FROM mysql.user
        WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

    DELETE FROM mysql.user WHERE User='';

    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

    FLUSH PRIVILEGES;
EOSQL

echo "[init-db] Root remote access revoked and test DB removed."

mysql -u root --password="${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    GRANT SELECT ON mysql.time_zone_name TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

echo "[init-db] Timezone SELECT granted to '${MYSQL_USER}'."

echo "[init-db] Loading timezone data..."
mysql_tzinfo_to_sql /usr/share/zoneinfo | \
    mysql -u root --password="${MYSQL_ROOT_PASSWORD}" mysql || \
    echo "[init-db] WARNING: Timezone data load failed - run manually if needed."

echo "[init-db] Bootstrap complete."
