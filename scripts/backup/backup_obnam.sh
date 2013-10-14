#!/bin/sh
CUR_PATH=$(readlink -f $0 | xargs dirname)
CUR_EXITCODE=0

if [ "$#" -le 0 ]; then
    echo "Must specify a profile name (e.g. foo.conf), exiting"
    exit 1
fi

CUR_PROFILE=${CUR_PATH}/${1}
if [ ! -f "${CUR_PROFILE}" ]; then
    echo "Profile \"${CUR_PROFILE}\" not found, exiting"
    exit 1
fi
. ${CUR_PROFILE}

OBNAM_BIN=$(which obnam)
if [ -z ${OBNAM_BIN} ]; then
    OBNAM_BIN="/opt/local/bin/obnam"
fi
if [ ! -f "${OBNAM_BIN}" ]; then
    echo "Obnam seems not to be installed, exiting"
    exit 1
fi

set -x

## @todo Detect installed notification system (use Growl and friends?).
NOTIFY_CMD=$(which notify-send)
NOTIFY_PARMS_ERROR="-u critical"
NOTIFY_PARMS_INFO="-u low"

OBNAM_PATH_DEST=${OBNAM_PROFILE_DEST_HOST}${OBNAM_PROFILE_DEST_PATH}

OBNAM_CMD_REPO="--repository ${OBNAM_PATH_DEST}"
OBNAM_CMD_ROOT="--root ${OBNAM_PROFILE_SRC_PATH}"

OBNAM_LOG_SUFFIX=`date +%y%m%d_%H%M%S`.log
## @todo Properly retrieve tmp directory.
OBNAM_LOG_FILE="/tmp/backup_${OBNAM_LOG_SUFFIX}"

${OBNAM_BIN} force-lock ${OBNAM_CMD_REPO}

${OBNAM_BIN} backup --log=${OBNAM_LOG_FILE} --log-level debug ${OBNAM_CMD_REPO} ${OBNAM_CMD_ROOT} --client-name=${OBNAM_PROFILE_CLIENT_NAME} --exclude-caches ${OBNAM_PROFILE_EXCLUDES}
if [ "$?" -ne 0 ]; then
    ${NOTIFY_CMD} ${NOTIFY_PARMS_ERROR} "Error performing backup!"
    CUR_EXITCODE=1
else
    ${OBNAM_BIN} generations ${OBNAM_CMD_REPO}
    ${NOTIFY_CMD} ${NOTIFY_PARMS_INFO} "Backup successfully finished"
fi

## @todo Move over log to backup destination.
#install -m 644 "${OBNAM_LOG_FILE}" "${OBNAM_PATH_DEST}/backup$_{OBNAM_LOG_SUFFIX}"

exit $CUR_EXITCODE
