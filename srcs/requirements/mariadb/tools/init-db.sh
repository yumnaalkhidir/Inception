#!/bin/sh
set -eu

DATADIR=/var/lib/mysql

if [ ! -f "$DATADIR/.inception_initialized" ]; then
    chown -R mysql:mysql "$DATADIR"
    [ -d "$DATADIR/mysql" ] || mariadb-install-db --user=mysql --datadir="$DATADIR" >/dev/null

     mariadbd --user=mysql --bootstrap <<SQL
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat "$MYSQL_ROOT_PASSWORD_FILE")';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '$(cat "$MYSQL_PASSWORD_FILE")';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

     touch "$DATADIR/.inception_initialized"
fi

# --port wins over any value in the .cnf files, so the port stays in .env only.
exec mariadbd --user=mysql --console --port="${MYSQL_PORT:-3306}"