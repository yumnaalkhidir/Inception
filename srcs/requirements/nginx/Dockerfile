FROM debian:bookworm

RUN apt update && \
    apt install -y nginx openssl && \
    rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf.template /etc/nginx/nginx.conf.template

RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/private.key \
    -out /etc/nginx/ssl/certificate.crt \
    -subj "/CN=yalkhidi.42.fr"

# No EXPOSE: the listen port is a runtime variable now, so a fixed number here
# would be a lie. EXPOSE is metadata only and opens nothing.
# Render the template at start, then become nginx (PID 1).
# sed, not envsubst: envsubst needs gettext-base, and with no variable list it
# also eats $uri, $args, $document_root and $fastcgi_script_name.
CMD ["sh", "-c", "sed -e \"s/{{NGINX_PORT}}/${NGINX_PORT:-443}/\" -e \"s/{{WP_FPM_PORT}}/${WP_FPM_PORT:-9000}/\" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && exec nginx -g 'daemon off;'"]
