#!/bin/sh

set -eu
set -x

php /root/configure-db.php
php /root/configure-plugin-mobilize.php

# Generate the TLS certificate for our Tiny Tiny RSS server instance.
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=World/L=World/O=ttrss/CN=ttrss" \
    -keyout "/etc/ssl/private/ttrss.key" \
    -out "/etc/ssl/certs/ttrss.cert"
chmod 600 "/etc/ssl/private/ttrss.key"
chmod 600 "/etc/ssl/certs/ttrss.cert"

# Configure Nginx so that is doesn't show its version number in the HTTP headers.
sed -i -e "s/.*server_tokens.*/server_tokens off;/g" /etc/nginx/nginx.conf
