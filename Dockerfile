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

ADD scripts/run.sh /scripts/run.sh

RUN apk -U --no-cache upgrade &&\
    apk add --no-cache mariadb mariadb-server-utils mariadb-client pwgen &&\
    sed -i '/skip-networking/d' /etc/my.cnf.d/mariadb-server.cnf &&\
    rm -rf /tmp/src /var/cache/apk/* &&\
    mkdir /scripts/pre-exec.d &&\
    mkdir /scripts/pre-init.d &&\
    chmod -R 755 /scripts

# ports and volumes
EXPOSE 3306
VOLUME /var/lib/mysql

ENTRYPOINT ["/scripts/run.sh"]