ARG BASE_IMAGE_PREFIX

FROM multiarch/qemu-user-static as qemu

FROM ${BASE_IMAGE_PREFIX}alpine

COPY --from=qemu /usr/bin/qemu-*-static /usr/bin/

ENV PUID=0
ENV PGID=0

COPY scripts/start.sh /

RUN apk -U --no-cache upgrade
RUN apk add --no-cache mariadb mariadb-server-utils mariadb-client pwgen
RUN sed -i '/skip-networking/d' /etc/my.cnf.d/mariadb-server.cnf
RUN mkdir -p /scripts/pre-exec.d /scripts/pre-init.d
RUN chmod -R 777 /scripts /start.sh

RUN rm -rf /tmp/* /var/cache/apk/* /usr/bin/qemu-*-static

# ports and volumes
EXPOSE 3306
VOLUME /var/lib/mysql

ENTRYPOINT ["/start.sh"]