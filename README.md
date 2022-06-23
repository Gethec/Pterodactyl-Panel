# Pterodactyl-Panel #

## **NOTICE:**

S6-Overlay released V3 at the start of the year, and with it came fundamental changes to how containers are built and services are handled.  I will, in the near future, be moving this container to the new system, which will require some changes to how the container is configured and run.  To allow users who do not wish to make these changes to continue to use the container, I have created the `s6-v2` branch and tag that will continue to be built with the final release of S6 before the version jump.  For those who want to jump straight into the new, untested, but probably working S6 V3 version, check out the `s6-v3` tag.  If you run into any questions or problems, please open an issue!

## Disclaimer ##
As with anything else, exposing your system to the Internet incurs risks!  This container does its best to be as secure as possible, but makes no guarantees to being completely impenetrable.  Use at your own risk, and feel free to suggest changes that can further increase security.

## About ##
The Pterodactyl project is an impressive one to me, but I wanted a way to make use of it in Unraid without installing it to the system.  Thus, this set of containers was born.  Panel uses uses Alpine's official image to keep the footprint small.

## Configuration ##
The configuration of the Panel container is much less complicated than the Wings container.  Most of the configuration occurs through environment variables.  Simply define them to enable that component.

### Variables ###
This container uses [vishnubob's wait-for-it](https://github.com/vishnubob/wait-for-it) script to allow you to have startup wait for the SQL and Redis servers to become available before continuing.  Simply set the HOST values to the correct hostname or IP address, and specific a port number, if you are not using the services' default option.  You can also set `TESTTIME` to change the wait period from the default 30 seconds to whatever you desire.

It's also worth noting that, since this container is developed for use in Unraid, which has several excelent reverse proxy options, not much attention has been given to making the HTTPS option work.  It should work in theory, but please submit a bug report if you encounter any issues.  To enable, set `HTTPS` to "true", then map the location of your `fullchain.pem` and `privkey.pem` files to `/le-ssl`.

| Variable | Default | Example |
|----------|---------|---------|
| DBHOST | `NULL` | `-e DBHOST="MariaDB"` |
| DBPORT | `3306` | `-e DBPORT=3306` |
| REDISHOST | `NULL` | `-e REDISHOST="Redis"` |
| REDISPORT | `6379` | `-e REDISPORT=6379` |
| TESTTIME | `30` | `-e TESTTIME=30` |
| HTTPS | `NULL` | `-e HTTPS="true"` |

### Volumes ###
| Volume | Note | Example |
|--------|------|---------|
| /config | Required for persistence | `-v "/mnt/user/appdata/panel":"/config"` |
| /le-ssl | Expected location for SSL certs, if HTTPS is enabled | `-v "/letsencrypt/cert/directory":"/le-ssl":ro` |

### Ports ###
| Port | Note | Example |
|------|------|---------|
| 80 | Default port if HTTPS is disabled.  Redirects to 443 otherwise | `-p 80:80` |
| 443 | Web interface if HTTPS is enabled | `- p 443:443` |

## Setup ##
**IMPORTANT:** While this container automates as much as possible, manual setup of the environment is still required to finish installation.  For instructions, complete the Environmental Configuration, Database Setup and Add The First User sections in [Pterodactyl's "Getting Started" guide](https://pterodactyl.io/panel/1.0/getting_started.html#environment-configuration).

Example run command:

    docker run \
        --name="Panel" \
        -e DBHOST="MariaDB" \
        -e DBPORT=3306 \
        -e REDISHOST="Redis" \
        -e REDISPORT=6379 \
        -e TESTTIME=30 \
        -e HTTPS=false \
        -v "/mnt/user/appdata/panel":"/config" \
        -v "/mnt/user/appdata/swag/etc/letsencrypt/live/<example.com>":"/le-ssl":ro \
        -p 80:80 \
        gethec/pterodactyl-panel