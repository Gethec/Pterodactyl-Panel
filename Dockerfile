FROM alpine AS base

# Set PHP and PHP-FPM versions
ENV PHP_VER="php81" \
    PHPFPM_VER="php-fpm81" \
    NODE_OPTIONS=--openssl-legacy-provider

# Update and prepare base image
RUN apk --no-cache add \
        bash \
        curl \
        nginx \
        ${PHP_VER} \
        ${PHP_VER}-bcmath \
        ${PHP_VER}-common \
        ${PHP_VER}-ctype \
        ${PHP_VER}-dom \
        ${PHP_VER}-fileinfo \
        ${PHP_VER}-fpm \
        ${PHP_VER}-gd \
        ${PHP_VER}-mbstring \
        ${PHP_VER}-pecl-memcached \
        ${PHP_VER}-openssl \
        ${PHP_VER}-pdo \
        ${PHP_VER}-pdo_mysql \
        ${PHP_VER}-phar \
        ${PHP_VER}-posix \
        ${PHP_VER}-json \
        ${PHP_VER}-session \
        ${PHP_VER}-simplexml \
        ${PHP_VER}-sodium \
        ${PHP_VER}-tokenizer \
        ${PHP_VER}-xmlwriter \
        ${PHP_VER}-zip \
        ${PHP_VER}-zlib && \
    mkdir -p \
        /var/www/pterodactyl \
        /run/nginx \
        /run/php-fpm && \
    ln -s /etc/${PHP_VER} /etc/php && \
    #ln -s /usr/bin/${PHP_VER} /usr/bin/php && \
    ln -s /usr/sbin/${PHPFPM_VER} /usr/sbin/php-fpm && \
    ln -s /var/log/${PHP_VER} /var/log/php

FROM base AS build
WORKDIR /var/www/pterodactyl

# Download latest Panel build from project repository: https://github.com/pterodactyl/panel
ADD https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz ./panel.tar.gz

# Install dependencies, perform Panel installation process
RUN apk add yarn && \
    tar -xf panel.tar.gz && \
    rm panel.tar.gz && \
    chmod -R 755 storage/* bootstrap/cache && \
    find storage -type d > .storage.tmpl && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    cp .env.example .env && \
    composer install --ansi --no-dev --optimize-autoloader && \
    yarn install --production && \
    yarn add cross-env && \
    yarn run build:production && \
    rm -rf node_modules .env ./storage

FROM base AS release
WORKDIR /var/www/pterodactyl
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0"

# Copy built Panel from Build stage
COPY --from=build --chown=nginx:nginx /var/www /var/www
COPY root/ /

# Download latest S6-Overlay components from project repository: https://github.com/just-containers/s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-x86_64.tar.xz /tmp

# Download latest Wait-For-It script from project repository: https://github.com/vishnubob/wait-for-it
ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /usr/local/sbin/wait-for-it

# Download common tools
ADD https://raw.githubusercontent.com/Gethec/ProjectTools/main/DockerUtilities/ContainerTools /usr/local/sbin/ContainerTools

# Install S6-Overlay and Wait-For-It
RUN chmod u+x /usr/local/sbin/wait-for-it && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    # Remove preinstalled conf files
    rm -rf \
        /tmp/* \
        /etc/nginx/http.d/default.conf \
        /etc/${PHP_VER}/php-fpm.d/www.conf && \
    # Symlink storage and conf file
    ln -s /config/storage storage && \
    ln -s /config/pterodactyl.conf .env

# Expose HTTP port
EXPOSE 80

# Persistent storage directory
VOLUME [ "/config" ]

# Set entrypoint to S6-Overlay
ENTRYPOINT [ "/init" ]