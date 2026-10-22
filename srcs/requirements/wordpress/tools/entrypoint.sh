#!/bin/sh
set -eu
: "${WP_TITLE:?Missing WP_TITLE}"
: "${WP_ADMIN_USER:?Missing WP_ADMIN_USER}"
: "${WP_ADMIN_EMAIL:?Missing WP_ADMIN_EMAIL}"
: "${WP_ADMIN_PASSWORD_FILE:?Missing WP_ADMIN_PASSWORD_FILE}"
: "${WP_USER:?Missing WP_USER}"
: "${WP_USER_EMAIL:?Missing WP_USER_EMAIL}"
: "${WP_USER_PASSWORD_FILE:?Missing WP_USER_PASSWORD_FILE}"


: "${DOMAIN_NAME:?Missing DOMAIN_NAME}"
: "${MYSQL_DATABASE:?Missing MYSQL_DATABASE}"
: "${MYSQL_USER:?Missing MYSQL_USER}"
: "${MYSQL_PASSWORD_FILE:?Missing MYSQL_PASSWORD_FILE}"

WP_DB_HOST="${WP_DB_HOST:-mariadb}"
DB_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")

# Wait for MariaDB to accept connections (maximum 60 seconds).
i=0
until MYSQL_PASSWORD="$DB_PASSWORD" php -r '
    $db = @new mysqli(
        getenv("WP_DB_HOST"),
        getenv("MYSQL_USER"),
        getenv("MYSQL_PASSWORD"),
        getenv("MYSQL_DATABASE")
    );
    exit($db->connect_errno ? 1 : 0);
' >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "MariaDB connection failed"
        exit 1
    fi
    sleep 1
done

# Generate wp-config.php only on the first run.
if [ ! -f /var/www/html/wp-config.php ]; then
    AUTH_KEY=$(php -r 'echo bin2hex(random_bytes(32));')
    SECURE_AUTH_KEY=$(php -r 'echo bin2hex(random_bytes(32));')
    LOGGED_IN_KEY=$(php -r 'echo bin2hex(random_bytes(32));')
    NONCE_KEY=$(php -r 'echo bin2hex(random_bytes(32));')

    cat > /var/www/html/wp-config.php <<EOF
<?php
define('DB_NAME', '${MYSQL_DATABASE}');
define('DB_USER', '${MYSQL_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${WP_DB_HOST}:3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('AUTH_KEY', '${AUTH_KEY}');
define('SECURE_AUTH_KEY', '${SECURE_AUTH_KEY}');
define('LOGGED_IN_KEY', '${LOGGED_IN_KEY}');
define('NONCE_KEY', '${NONCE_KEY}');

define('WP_HOME', 'https://${DOMAIN_NAME}');
define('WP_SITEURL', 'https://${DOMAIN_NAME}');

\$table_prefix = 'wp_';

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
EOF

    chown www-data:www-data /var/www/html/wp-config.php
    chmod 640 /var/www/html/wp-config.php
fi

WP_ADMIN_PASSWORD=$(cat "$WP_ADMIN_PASSWORD_FILE")
WP_USER_PASSWORD=$(cat "$WP_USER_PASSWORD_FILE")

if ! wp core is-installed --path=/var/www/html --allow-root >/dev/null 2>&1; then
    wp core install --path=/var/www/html --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
fi

if ! wp user get "$WP_USER" --path=/var/www/html --allow-root >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --role=author \
        --user_pass="$WP_USER_PASSWORD" \
        --path=/var/www/html --allow-root
fi

chown -R www-data:www-data /var/www/html

exec php-fpm8.2 -F