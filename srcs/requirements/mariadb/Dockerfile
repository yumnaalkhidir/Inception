FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends mariadb-server && \
    rm -rf /var/lib/apt/lists/*

COPY conf/99-inception.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf
COPY tools/init-db.sh /usr/local/bin/init-db.sh

RUN chmod +x /usr/local/bin/init-db.sh && \
    mkdir -p /run/mysqld && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

ENTRYPOINT ["/usr/local/bin/init-db.sh"]
