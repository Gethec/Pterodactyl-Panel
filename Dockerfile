FROM alpine AS base

# Update and prepare base image
RUN apk --no-cache --update upgrade && \
    apk add \
        bash \
        curl \
        nginx \
        php8 \
        php8-bcmath \
        php8-common \
        php8-ctype \
        php8-dom \
        php8-fileinfo \
        php8-fpm \
        php8-gd \
        php8-mbstring \
        php8-pecl-memcached \
        php8-openssl \
        php8-pdo \
        php8-pdo_mysql \
        php8-phar \
        php8-json \
        php8-session \
        php8-simplexml \
        php8-sodium \
        php8-tokenizer \
        php8-xmlwriter \
        php8-zip \
        php8-zlib && \
    mkdir -p \
        /var/www/pterodactyl \
        /run/nginx \
        /run/php-fpm

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
    curl -sS https://getcomposer.org/installer | php8 -- --install-dir=/usr/local/bin --filename=composer && \
    cp .env.example .env && \
    composer install --ansi --no-dev --optimize-autoloader && \
    chown -R nginx:nginx * && \
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
ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /usr/local/bin/wait-for-it

# Download common tools
ADD https://raw.githubusercontent.com/Gethec/ProjectTools/main/DockerUtilities/ContainerTools /usr/bin/ContainerTools

# Install S6-Overlay and Wait-For-It
RUN chmod u+x /usr/local/bin/wait-for-it && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    # Remove preinstalled conf files
    rm -rf \
        /tmp/* \
        /etc/nginx/http.d/default.conf \
        /etc/php8/php-fpm.d/www.conf && \
    # Symlink storage and conf file
    ln -s /config/storage storage && \
    ln -s /config/pterodactyl.conf .env

# Expose HTTP port
EXPOSE 80

# Persistent storage directory
VOLUME [ "/config" ]

# Set entrypoint to S6-Overlay
ENTRYPOINT [ "/init" ]