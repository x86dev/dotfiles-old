#!/bin/sh
CUR_PATH=$(readlink -f $0 | xargs dirname)
CUR_EXITCODE=0

#set -x

while [ $# != 0 ]; do
    CUR_PARM="$1"
    shift
    case "$CUR_PARM" in
        backup)
            SCRIPT_CMD="backup"
            ;;
        mount)
            SCRIPT_CMD="mount"
            ;;
        --profile)
            SCRIPT_PROFILE_FILE="$1"
            ;;
        *)
            ;;
    esac
done

if [ -z "${SCRIPT_CMD}" ]; then
    echo "Must specify a (valid) command to execute, exiting"
    exit 1
fi

if [ -z "${SCRIPT_PROFILE_FILE}" ]; then
    echo "Must specify a profile name using --profile (e.g. --profile foo.conf), exiting"
    exit 1
fi

CUR_PROFILE=${CUR_PATH}/${SCRIPT_PROFILE_FILE}
if [ ! -f "${CUR_PROFILE}" ]; then
    CUR_PROFILE=${SCRIPT_PROFILE_FILE}
    if [ ! -f "${CUR_PROFILE}" ]; then
        echo "Profile \"${CUR_PROFILE}\" not found, exiting"
        exit 1
    fi
fi

echo "Using profile: ${CUR_PROFILE}"
. ${CUR_PROFILE}

OBNAM_BIN=$(which obnam)
if [ -z ${OBNAM_BIN} ]; then
    OBNAM_BIN="/opt/local/bin/obnam"
fi
if [ ! -f "${OBNAM_BIN}" ]; then
    echo "Obnam seems not to be installed, exiting"
    exit 1
fi
echo "Obnam binary found at: $OBNAM_BIN"

## @todo Detect installed notification system (use Growl and friends?).
## @todo Check for / install python-fuse (for "mount" command)?
NOTIFY_CMD=$(which notify-send)
if [ -n "$NOTIFY_CMD" ]; then
    NOTIFY_PARMS_ERROR="-u critical"
    NOTIFY_PARMS_INFO="-u low"
else
    # Fall back to plain echo.
    NOTIFY_CMD=$(which echo)
fi

case "$SCRIPT_CMD" in
    backup)
        OBNAM_PATH_DEST=${OBNAM_PROFILE_DEST_HOST}${OBNAM_PROFILE_DEST_PATH}

        OBNAM_CMD_REPO="--repository ${OBNAM_PATH_DEST}"
        OBNAM_CMD_ROOT="--root ${OBNAM_PROFILE_SRC_PATH}"
        OBNAM_CMD_CLIENTNAME="--client-name=${OBNAM_PROFILE_CLIENT_NAME}"

        OBNAM_LOG_SUFFIX=$(date +%y%m%d_%H%M%S).log
        ## @todo Properly retrieve tmp directory.
        OBNAM_LOG_FILE="/tmp/backup_${OBNAM_LOG_SUFFIX}"

        # If $OBNAM_PROFILE_DEST_HOST is empty, assume this is a local backup.
        if [ -z "$OBNAM_PROFILE_DEST_HOST" ]; then
            mkdir -p "$OBNAM_PROFILE_DEST_PATH"
        fi      
        
        echo "Started at: $(date --rfc-3339=seconds)"
        echo "Logging to: $OBNAM_LOG_FILE"
        echo "Backing up client \"${OBNAM_PROFILE_CLIENT_NAME}\" to: $OBNAM_PATH_DEST"
        ${OBNAM_BIN} force-lock ${OBNAM_CMD_REPO} ${OBNAM_CMD_CLIENTNAME} && \
        ${OBNAM_BIN} backup --log=${OBNAM_LOG_FILE} --log-level info ${OBNAM_CMD_REPO} ${OBNAM_CMD_ROOT} ${OBNAM_CMD_CLIENTNAME} --exclude-caches ${OBNAM_PROFILE_EXCLUDES}
        if [ "$?" -ne 0 ]; then
            echo "Error performing backup!"
            ${NOTIFY_CMD} ${NOTIFY_PARMS_ERROR} "Error performing backup!"
            CUR_EXITCODE=1
        else
            echo "Backup successfully finished"
            ${OBNAM_BIN} generations ${OBNAM_CMD_CLIENTNAME} ${OBNAM_CMD_REPO}
            ${NOTIFY_CMD} ${NOTIFY_PARMS_INFO} "Backup successfully finished"
        fi
        echo "Ended at: $(date --rfc-3339=seconds)"
        
        # Move over log to backup destination.
        install --mode=644 "$OBNAM_LOG_FILE" "$OBNAM_PATH_DEST"
        ;;
    mount)
        echo "Mounting ..."
        mkdir -p ${OBNAM_PROFILE_REPO_PATH_MOUNTED} || exit 1
        ${OBNAM_BIN} mount --repository ${OBNAM_PROFILE_REPO_PATH_LOCAL} ${OBNAM_CMD_CLIENTNAME} --viewmode=multiple / --to=${OBNAM_PROFILE_REPO_PATH_MOUNTED}
        if [ "$?" -ne 0 ]; then
            ${NOTIFY_CMD} ${NOTIFY_PARMS_ERROR} "Error mounting backup!"
            CUR_EXITCODE=1
        else
            ${NOTIFY_CMD} ${NOTIFY_PARMS_INFO} "Backup successfully mounted to ${OBNAM_PROFILE_REPO_PATH_MOUNTED}"
            echo "Mounted to: ${OBNAM_PROFILE_REPO_PATH_MOUNTED}"
        fi
        ;;
    *)
        echo "Unknown command \"$SCRIPT_CMD\", exiting"
        CUR_EXITCODE=1
        ;;        
esac

exit $CUR_EXITCODE
