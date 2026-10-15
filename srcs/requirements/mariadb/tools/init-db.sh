#!/bin/sh
set -eu

: "${MYSQL_DATABASE:?Missing MYSQL_DATABASE}"
: "${MYSQL_USER:?Missing MYSQL_USER}"
: "${MYSQL_PASSWORD_FILE:?Missing MYSQL_PASSWORD_FILE}"
: "${MYSQL_ROOT_PASSWORD_FILE:?Missing MYSQL_ROOT_PASSWORD_FILE}"

case "${MYSQL_DATABASE}${MYSQL_USER}" in
    *[!a-zA-Z0-9_]*)
        echo "Use only letters, numbers and underscores for database/user names"
        exit 1
        ;;
esac

MYSQL_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")

if [ ! -f /var/lib/mysql/.inception_initialized ]; then
    if [ ! -d /var/lib/mysql/mysql ]; then
        chown -R mysql:mysql /var/lib/mysql
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    fi

    mariadbd --user=mysql --skip-networking &
    DB_PID=$!

    i=0
    until mariadb-admin ping --silent >/dev/null 2>&1; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "MariaDB failed to initialize"
            kill "$DB_PID" 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done

    mariadb -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

    mariadb-admin -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait "$DB_PID" || true

    touch /var/lib/mysql/.inception_initialized
    chown mysql:mysql /var/lib/mysql/.inception_initialized
fi

exec mariadbd --user=mysql --console