#!/bin/sh
BASENAME=basename
ECHO=echo
MKDIR=mkdir
MV=mv
RM=rm
SCP=scp
SED=sed
SSH=ssh
TEE=tee

SCRIPT_PATH=$(readlink -f $0 | xargs dirname)
SCRIPT_EXITCODE=0

set -e

set -x

# See: http://www.cyberciti.biz/faq/duplicity-installation-configuration-on-debian-ubuntu-linux/
#      http://linux-audit.com/gpg-key-generation-not-enough-random-bytes-available/

backup_log()
{
    ${ECHO} "$1"
}

backup_create_dir()
{
    if [ "${BACKUP_TO_REMOTE}" = "1" ]; then
        backup_log "Creating remote directory: '${2}'"
        ${SSH} ${BACKUP_SSH_OPTS} ${BACKUP_DEST_HOST} "mkdir -p ${2}"
    else
        backup_log "Creating local directory: '${2}'"
        ${MKDIR} -p "${2}"
    fi
}

backup_move_file()
{
    if [ "${BACKUP_TO_REMOTE}" = "1" ]; then
        LOCAL_FILE=${BACKUP_DEST_HOST}:${2}/$($BASENAME ${1})
        backup_log "Moving file '${1}' to remote '${LOCAL_FILE}'"
        ${SCP} ${BACKUP_SCP_OPTS} "${1}" "${LOCAL_FILE}" && ${RM} "${1}"
    else
        backup_log "Moving file '${1}' to '${2}'"
        ${MV} "${1}" "${2}"
    fi
}

backup_duplicity_run()
{
    LOCAL_DUPLICITY_BIN=duplicity
    LOCAL_DUPLICITY_BACKUP_TYPE=incremental

    LOCAL_DUPLICITY_OPTS="\
        ${LOCAL_DUPLICITY_OPTS}
        --progress \
        --verbosity=2 \
        --full-if-older-than 30D \
        --volsize=4096 \
        --num-retries=3 \
        --encrypt-key=${PROFILE_GPG_KEY} \
        --exclude-device-files \
        --exclude-other-filesystems"

    LOCAL_HOST=$1
    LOCAL_SOURCES=$2
    LOCAL_DEST_DIR=$3

    for CUR_SOURCE in ${LOCAL_SOURCES}; do
        CUR_SOURCE_SUFFIX=$($ECHO ${CUR_SOURCE} | ${SED} 's_/_-_g')
        CUR_TARGET_DIR=${LOCAL_DEST_DIR}/${PROFILE_NAME}${CUR_SOURCE_SUFFIX}
        CUR_LOG_FILE_SUFFIX=$($ECHO ${CUR_SOURCE}.log | ${SED} 's_/_-_g')
        CUR_LOG_FILE=${BACKUP_PATH_TMP}/${BACKUP_LOG_PREFIX}-${PROFILE_NAME}${CUR_LOG_FILE_SUFFIX}
        ${ECHO} "Backing up: ${CUR_SOURCE}"
        ${ECHO} "    Target: ${CUR_TARGET_DIR}"
        ${ECHO} "    Log   : ${CUR_LOG_FILE}"
        backup_create_dir "${LOCAL_HOST}" "${CUR_TARGET_DIR}"
        ${LOCAL_DUPLICITY_BIN} ${LOCAL_DUPLICITY_BACKUP_TYPE} ${LOCAL_DUPLICITY_OPTS} ${CUR_SOURCE} ${BACKUP_PATH_PREFIX}/${CUR_TARGET_DIR} \
            2>&1 | ${TEE} ${CUR_LOG_FILE}
        backup_move_file "${CUR_LOG_FILE}" "${CUR_TARGET_DIR}"
    done
}

while [ $# != 0 ]; do
    CUR_PARM="$1"
    shift
    case "$CUR_PARM" in
        backup)
            SCRIPT_CMD="backup"
            ;;
        --profile)
            SCRIPT_PROFILE_FILE="$1"
            ;;
        *)
            ;;
    esac
done

if [ -z "${SCRIPT_CMD}" ]; then
    ${ECHO} "Must specify a (valid) command to execute, exiting"
    exit 1
fi

if [ -z "${SCRIPT_PROFILE_FILE}" ]; then
    ${ECHO} "Must specify a profile name using --profile (e.g. --profile foo.conf), exiting"
    exit 1
fi

SCRIPT_PROFILE_FILE=${SCRIPT_PATH}/${SCRIPT_PROFILE_FILE}
if [ ! -f "${SCRIPT_PROFILE_FILE}" ]; then
    CUR_PROFILE=${SCRIPT_PROFILE_FILE}
    if [ ! -f "${SCRIPT_PROFILE_FILE}" ]; then
        ${ECHO} "Profile \"${SCRIPT_PROFILE_FILE}\" not found, exiting"
        exit 1
    fi
fi

${ECHO} "Using profile: ${SCRIPT_PROFILE_FILE}"
. ${SCRIPT_PROFILE_FILE}

if [ "${PROFILE_DEST_HOST}" = "localhost" ]; then
    BACKUP_TO_REMOTE=0
else
    BACKUP_TO_REMOTE=1
fi

if [ -n "${PROFILE_DEST_SSH_PORT}" ]; then
    BACKUP_SCP_OPTS="-q -P ${PROFILE_DEST_SSH_PORT}"
    BACKUP_SSH_OPTS="-p ${PROFILE_DEST_SSH_PORT}"
fi

BACKUP_PATH_TMP=/tmp
${ECHO} "Using temp dir: ${BACKUP_PATH_TMP}"

if [ "${BACKUP_TO_REMOTE}" = "1" ]; then
    if [ -n "${PROFILE_DEST_USERNAME}" ]; then
        BACKUP_DEST_HOST=${PROFILE_DEST_USERNAME}@${PROFILE_DEST_HOST}
    else
        BACKUP_DEST_HOST=${PROFILE_DEST_HOST}
    fi
    if [ -n "${PROFILE_DEST_SSH_PORT}" ]; then
        BACKUP_PATH_PREFIX=scp://${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}
    else
        BACKUP_PATH_PREFIX=scp://${BACKUP_DEST_HOST}
    fi
else
    BACKUP_DEST_HOST=localhost
    BACKUP_PATH_PREFIX=file://
fi
BACKUP_DEST_DIR=${PROFILE_DEST_DIR}

BACKUP_DEST_DIR_MONTHLY="${BACKUP_DEST_DIR}/backup_$(date +%y%m)"

BACKUP_TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
BACKUP_LOG_PREFIX="backup-${BACKUP_TIMESTAMP}"

case "$SCRIPT_CMD" in
    backup)
        backup_create_dir "${BACKUP_DEST_HOST}" "${BACKUP_DEST_DIR}"
        backup_create_dir "${BACKUP_DEST_HOST}" "${BACKUP_DEST_DIR_MONTHLY}"
        backup_duplicity_run "${BACKUP_DEST_HOST}" "${PROFILE_SOURCES_ONCE}" "${BACKUP_DEST_DIR}"
        backup_duplicity_run "${BACKUP_DEST_HOST}" "${PROFILE_SOURCES_MONTHLY}" "${BACKUP_DEST_DIR_MONTHLY}"
        ;;
    test)
        ## @todo Implement this.
        ;;
    *)
        ${ECHO} "Unknown command \"$SCRIPT_CMD\", exiting"
        SCRIPT_EXITCODE=1
        ;;
esac

exit ${SCRIPT_EXITCODE}
