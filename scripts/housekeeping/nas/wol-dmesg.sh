#!/bin/sh

# Copyright 2016 by Andreas Loeffler (x86dev).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

#
# Simple script to perform a Wake-on-LAN (WOL) request for a given server.
# As most switches / routers do the routing internally without reaching iptable's / netfilter's
# filtering routines, the server to wake up must be in a different (V)LAN.
#
# This script then periodically checks - based on the NAS filtering + logging rules - the dmesg
# log to see if we need to perform a WOL request.
#
# Tested on OpenWrt 15.05 on a Netgear WNDR3700 + WNDR4000.
#
# Note: The script requires the tool 'etherwake' installed to perform the actual WOL request.
#       Everything else should come out-of-the-box.
#

CUR_PATH=$(readlink -f $0 | xargs dirname)
CUR_EXITCODE=0

CFG_FILE=${CUR_PATH}/wol-dmesg.conf

echo "Using config: ${CFG_FILE}"
. ${CFG_FILE}

PING_RETRIES=1

LOG_FILE="/tmp/nas-wol.log"
LOG_TOKEN="<NAS WOL>"

SLEEP_SEC_ALIVE=30
SLEEP_SEC_CHECK=5

WOL=/usr/bin/etherwake
WOL_INTERFACE=eth0.2
WOL_OPTS="-i $WOL_INTERFACE"

# Clear the dmesg log before we begin.
dmesg -c

echo "["`date`"] Script started." > ${LOG_FILE}

LOG_MSG_ID_OLD=""

while true; do

    LOG_DMESG=$(dmesg | grep "$LOG_TOKEN" | tail -n1)
    LOG_MSG_ID_NEW=$(echo $LOG_DMESG | sed -n 's/.*ID=\([0-9]*\).*/\1/p')
    LOG_SRC_IP=$(echo $LOG_DMESG | sed -n 's/.*SRC=\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    LOG_SRC_NAME=$(nslookup $LOG_SRC_IP | tail -1 | sed -n "s/.*$LOG_SRC_IP \(.*\)/\1/p");
    LOG_DST_PORT=$(echo $LOG_DMESG | sed -n 's/.*DPT=\([0-9]*\).*/\1/p')

    if [ "$LOG_MSG_ID_NEW" != "" -a "$LOG_MSG_ID_NEW" != "$LOG_MSG_ID_OLD" ]; then
        if ping -qc ${PING_RETRIES} ${TARGET_IP} > /dev/null; then
            echo "["`date`"] Accessed by $LOG_SRC_NAME ($LOG_SRC_IP) (port $LOG_DST_PORT) and is already alive"
        else
            echo "["`date`"] $LOG_SRC_NAME ($LOG_SRC_IP) causes wake on lan (port $LOG_DST_PORT)." >> ${LOG_FILE}
            ${WOL} ${WOL_OPTS} ${TARGET_MAC} 2>&1 >> ${LOG_FILE}
       fi
       LOG_MSG_ID_OLD=$LOG_MSG_ID_NEW
       echo "["`date`"] Sleeping for $SLEEP_SEC_ALIVE seconds ..."
       sleep ${SLEEP_SEC_ALIVE}
       dmesg -c
    fi
    sleep ${SLEEP_SEC_CHECK}
done
