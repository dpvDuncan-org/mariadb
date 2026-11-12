#!/bin/sh
set -e

PUID=${PUID:-1000}
PGID=${PGID:-1000}

GROUPNAME=$(getent group "$PGID" | cut -d: -f1 || true)
if [ -z "$GROUPNAME" ]; then
    addgroup -g "$PGID" mariadb
    GROUPNAME="mariadb"
fi

USERNAME=$(getent passwd "$PUID" | cut -d: -f1 || true)
if [ -z "$USERNAME" ]; then
    adduser -G "$GROUPNAME" -u "$PUID" -D mariadb
    USERNAME="mariadb"
fi

# Exécution des scripts de pré-initialisation
for i in /scripts/pre-init.d/*.sh; do
    if [ -e "${i}" ]; then
        echo "[i] pre-init.d - processing $i"
        . "${i}"
    fi
done

mkdir -p /run/mysqld
chown -R "${USERNAME}:${GROUPNAME}" /var/lib/mysql /run/mysqld

if [ -d /var/lib/mysql/mysql ]; then
    echo "[i] MySQL directory already present, skipping creation"
else
    echo "[i] MySQL data directory not found, creating initial DBs"

    mariadb-install-db --user="${USERNAME}" --datadir='/var/lib/mysql' --auth-root-authentication-method=normal > /dev/null

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        MYSQL_ROOT_PASSWORD=$(pwgen 16 1)
        echo "[i] MySQL root Password: $MYSQL_ROOT_PASSWORD"
    fi

    # Échappement des apostrophes dans le mot de passe root
    SAFE_ROOT_PWD=$(printf '%s' "$MYSQL_ROOT_PASSWORD" | sed "s/'/''/g")

    tfile=$(mktemp)

    cat << EOF > "$tfile"
USE mysql;
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.user WHERE User='';
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${SAFE_ROOT_PWD}' WITH GRANT OPTION;
EOF

    if [ -n "${MYSQL_DATABASE}" ]; then
        echo "[i] Creating database: ${MYSQL_DATABASE}"
        echo "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> "$tfile"

        if [ -n "${MYSQL_USER}" ]; then
            SAFE_USER_PWD=$(printf '%s' "$MYSQL_PASSWORD" | sed "s/'/''/g")
            echo "[i] Creating user: ${MYSQL_USER}"
            echo "GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' IDENTIFIED BY '${SAFE_USER_PWD}';" >> "$tfile"
        fi
    fi

    echo "FLUSH PRIVILEGES;" >> "$tfile"

    /usr/bin/mysqld --user="${USERNAME}" --bootstrap --datadir='/var/lib/mysql' < "$tfile"
    rm -f "$tfile"
fi

# Remplacement du shell par mysqld pour la gestion propre de SIGTERM
exec /usr/bin/mysqld --user="${USERNAME}" --datadir='/var/lib/mysql' --console
