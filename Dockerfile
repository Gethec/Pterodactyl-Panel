FROM alpine AS base
# FROM alpine

# Update and prepare base image
RUN apk --no-cache --update upgrade && \
    apk add \
        bash \
        curl \
        nginx \
        php81 \
        php81-bcmath \
        php81-common \
        php81-ctype \
        php81-dom \
        php81-fileinfo \
        php81-fpm \
        php81-gd \
        php81-mbstring \
        php81-pecl-memcached \
        php81-openssl \
        php81-pdo \
        php81-pdo_mysql \
        php81-phar \
        php81-json \
        php81-session \
        php81-simplexml \
        php81-sodium \
        php81-tokenizer \
        php81-xmlwriter \
        php81-zip \
        php81-zlib && \
    mkdir -p \
        /var/www/pterodactyl \
        /run/nginx \
        /run/php-fpm && \
        ln -s /usr/bin/php81 /usr/bin/php

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
    chown -R nginx:nginx * && \
    yarn install --production && \
    yarn add cross-env && \
    yarn run build:production && \
    rm -rf node_modules .env ./storage

FROM base AS release
WORKDIR /var/www/pterodactyl
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2"

# Copy built Panel from Build stage
COPY --from=build --chown=nginx:nginx /var/www /var/www
COPY root/ /

# Download latest S6-Overlay build from project repository: https://github.com/just-containers/s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64-installer /tmp/s6-overlay

# Download latest Wait-For-It script from project repository: https://github.com/vishnubob/wait-for-it
ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /usr/local/bin/wait-for-it

# Download common tools
ADD https://bitbucket.org/Gethec/projecttools/raw/master/DockerUtilities/ContainerTools /usr/bin/ContainerTools

# Install S6-Overlay and Wait-For-It
RUN chmod u+x /tmp/s6-overlay /usr/local/bin/wait-for-it && \
    /tmp/s6-overlay / && \
    # Remove preinstalled conf files
    rm -rf \
        /tmp/* \
        /etc/nginx/http.d/default.conf \
        /etc/php81/php-fpm.d/www.conf && \
    # Symlink storage and conf file
    ln -s /config/storage /var/www/pterodactyl/storage && \
    ln -s /config/pterodactyl.conf /var/www/pterodactyl/.env

# Expose HTTP port
EXPOSE 80

# Persistent storage directory
VOLUME [ "/config" ]

# Set entrypoint to S6-Overlay
ENTRYPOINT [ "/init" ]