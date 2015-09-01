#!/bin/sh

set -eu
set -x

exec /sbin/setuser www-data /usr/bin/php /var/www/ttrss/update_daemon2.php >> /var/log/service-ttrss-update.log 2>&1
