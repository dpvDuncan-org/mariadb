#!/bin/sh

GROUPNAME=$(getent group $PGID | cut -d: -f1)
USERNAME=$(getent passwd $PUID | cut -d: -f1)

if [ ! $GROUPNAME ]
then
        addgroup -g $PGID mariadb
        GROUPNAME=mariadb
fi

if [ ! $USERNAME ]
then
        adduser -G $GROUPNAME -u $PUID -D mariadb
        USERNAME=mariadb
fi

# execute any pre-init scripts, useful for images
# based on this image
for i in /scripts/pre-init.d/*sh
do
        if [ -e "${i}" ]; then
                echo "[i] pre-init.d - processing $i"
                . "${i}"
        fi
done

if [ ! -d "/run/mysqld" ]; then
        mkdir -p /run/mysqld
fi

chown -R ${USERNAME}:${GROUPNAME} /var/lib/mysql /run/mysqld

if [ -d /var/lib/mysql/mysql ]; then
        echo "[i] MySQL directory already present, skipping creation"
else
        echo "[i] MySQL data directory not found, creating initial DBs"

        mysql_install_db --user=${USERNAME} --datadir='/var/lib/mysql' > /dev/null

        if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
                MYSQL_ROOT_PASSWORD=`pwgen 16 1`
                echo "[i] MySQL root Password: $MYSQL_ROOT_PASSWORD"
        fi

        MYSQL_DATABASE=${MYSQL_DATABASE:-""}
        MYSQL_USER=${MYSQL_USER:-""}
        MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

        tfile='/tmp/init.sql'

        cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
DROP DATABASE test;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '' WITH GRANT OPTION;
EOF

        if [ "${MYSQL_DATABASE}" != "" ]; then
            echo "[i] Creating database: ${MYSQL_DATABASE}"
            echo "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

            if [ "${MYSQL_USER}" != "" ]; then
                echo "[i] Creating user: ${MYSQL_USER} with password ${MYSQL_PASSWORD}"
                echo "GRANT ALL ON \`${MYSQL_DATABASE}\`.* to '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" >> $tfile
            fi
        fi

        /usr/bin/mysqld --user=${USERNAME} --bootstrap --datadir='/var/lib/mysql' < $tfile
        rm -f $tfile
fi

/usr/bin/mysqld --user=${USERNAME} --datadir='/var/lib/mysql' --console