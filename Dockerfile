# see hooks/build and hooks/.config
ARG BASE_IMAGE_PREFIX
FROM ${BASE_IMAGE_PREFIX}alpine

# see hooks/post_checkout
ARG ARCH
COPY .gitignore qemu-${ARCH}-static* /usr/bin/

# see hooks/build and hooks/.config
ARG BASE_IMAGE_PREFIX
FROM ${BASE_IMAGE_PREFIX}alpine

# see hooks/post_checkout
ARG ARCH
COPY qemu-${ARCH}-static /usr/bin

RUN apk update && apk upgrade

ADD scripts/start.sh /start.sh

RUN apk -U --no-cache upgrade
RUN apk add --no-cache mariadb mariadb-server-utils mariadb-client pwgen
RUN sed -i '/skip-networking/d' /etc/my.cnf.d/mariadb-server.cnf
RUN mkdir /scripts/pre-exec.d /scripts/pre-init.d
RUN chmod -R 755 /scripts /start.sh

RUN rm -rf /tmp/* /var/cache/apk/* /usr/bin/qemu-*-static

# ports and volumes
EXPOSE 3306
VOLUME /var/lib/mysql

ENTRYPOINT ["/start.sh"]