#!/bin/sh
set -eu

export MYSQL_PASSWORD="$(cat "$MYSQL_PASSWORD_FILE")"
WP="wp --path=/var/www/html --allow-root"

i=0
until php -r 'exit(@(new mysqli(getenv("WP_DB_HOST"), getenv("MYSQL_USER"), getenv("MYSQL_PASSWORD"), getenv("MYSQL_DATABASE")))->connect_errno ? 1 : 0);' >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -ge 60 ] && { echo "MariaDB connection failed"; exit 1; }
    sleep 1
done

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
exec php-fpm8.2 -F