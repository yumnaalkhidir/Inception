FROM debian:bookworm

RUN apt update -y && apt upgrade -y \
     apt install nginx -y \
     apt install openssl

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

