#!/bin/sh
set -eu

: "${WP_TITLE:?}" "${WP_ADMIN_USER:?}" "${WP_ADMIN_EMAIL:?}" "${WP_ADMIN_PASSWORD_FILE:?}"
: "${WP_USER:?}" "${WP_USER_EMAIL:?}" "${WP_USER_PASSWORD_FILE:?}"
: "${DOMAIN_NAME:?}" "${MYSQL_DATABASE:?}" "${MYSQL_USER:?}" "${MYSQL_PASSWORD_FILE:?}"
: "${MYSQL_HOST:?}" "${MYSQL_PORT:?}" "${WP_FPM_PORT:?}"

# One source of truth: .env holds host and port apart, WordPress wants them joined.
export WP_DB_HOST="${MYSQL_HOST}:${MYSQL_PORT}"
export MYSQL_PASSWORD="$(cat "$MYSQL_PASSWORD_FILE")"
WP="wp --path=/var/www/html --allow-root"

# Wait for MariaDB (max 60s)
i=0
until php -r 'exit(@(new mysqli(getenv("MYSQL_HOST"), getenv("MYSQL_USER"), getenv("MYSQL_PASSWORD"), getenv("MYSQL_DATABASE"), (int)getenv("MYSQL_PORT")))->connect_errno ? 1 : 0);' >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -ge 60 ] && { echo "MariaDB connection failed"; exit 1; }
    sleep 1
done

# Download, configure and install WordPress (each step runs only if needed)
[ -f /var/www/html/wp-load.php ]   || $WP core download
[ -f /var/www/html/wp-config.php ] || $WP config create \
    --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" \
    --dbpass="$MYSQL_PASSWORD" --dbhost="$WP_DB_HOST" --skip-check

$WP core is-installed 2>/dev/null || $WP core install \
    --url="https://${DOMAIN_NAME}" --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" --admin_password="$(cat "$WP_ADMIN_PASSWORD_FILE")" \
    --admin_email="$WP_ADMIN_EMAIL" --skip-email

$WP user get "$WP_USER" >/dev/null 2>&1 || $WP user create "$WP_USER" "$WP_USER_EMAIL" \
    --role=author --user_pass="$(cat "$WP_USER_PASSWORD_FILE")"

chown -R www-data:www-data /var/www/html
mkdir -p /run/php

# php-fpm has no command line flag for the pool listen port. Rewrite the line.
# Idempotent: the pattern also matches the line a previous start wrote.
sed -i "s/^listen = .*/listen = ${WP_FPM_PORT}/" /etc/php/8.2/fpm/pool.d/www.conf

exec php-fpm8.2 -F