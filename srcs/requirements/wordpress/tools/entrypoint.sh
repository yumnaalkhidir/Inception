#!/bin/sh
set -eu

: "${DOMAIN_NAME:?Missing DOMAIN_NAME}"
: "${MYSQL_DATABASE:?Missing MYSQL_DATABASE}"
: "${MYSQL_USER:?Missing MYSQL_USER}"
: "${MYSQL_PASSWORD_FILE:?Missing MYSQL_PASSWORD_FILE}"

MYSQL_HOST="${MYSQL_HOST:-mariadb}"
DB_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")

# Wait for MariaDB to accept connections (maximum 60 seconds).
i=0
until MYSQL_PASSWORD="$DB_PASSWORD" php -r '
    $db = @new mysqli(
        getenv("MYSQL_HOST"),
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
define('DB_HOST', '${MYSQL_HOST}:3306');
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

exec php-fpm8.2 -F