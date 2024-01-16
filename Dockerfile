# syntax=docker/dockerfile:1

FROM alpine

ENV PUID=0
ENV PGID=0

COPY scripts/start.sh /

RUN apk -U --no-cache upgrade
RUN apk add --no-cache mariadb mariadb-server-utils mariadb-client pwgen
RUN sed -i '/skip-networking/d' /etc/my.cnf.d/mariadb-server.cnf
RUN mkdir -p /scripts/pre-exec.d /scripts/pre-init.d
RUN chmod -R 777 /scripts /start.sh

RUN rm -rf /tmp/* /var/cache/apk/*

# ports and volumes
EXPOSE 3306
VOLUME /var/lib/mysql

ENTRYPOINT ["/start.sh"]