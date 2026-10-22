FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl tar \
        php-cli php-fpm php-mysql php-curl \
        php-gd php-mbstring php-xml php-zip && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html && \
    curl -fsSL https://wordpress.org/wordpress-7.1.3.tar.gz \
        -o /tmp/wordpress.tar.gz && \
    tar -xzf /tmp/wordpress.tar.gz \
        --strip-components=1 -C /var/www/html && \
    rm /tmp/wordpress.tar.gz && \
    chown -R www-data:www-data /var/www/html

COPY tools/entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

RUN chmod +x /usr/local/bin/wordpress-entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]