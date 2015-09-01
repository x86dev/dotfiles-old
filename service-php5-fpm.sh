#!/bin/sh

set -eu
set -x

/usr/sbin/php5-fpm >> /var/log/service-php5-fpm.log 2>&1
