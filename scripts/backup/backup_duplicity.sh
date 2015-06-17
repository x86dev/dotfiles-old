#!/bin/sh
BASENAME=basename
ECHO=echo
MKDIR=mkdir
MV=mv
SED=sed
TEE=tee

set -e

BACKUP_BIN=duplicity
BACKUP_TYPE=incremental
BACKUP_DIR="/volume1/@backup/ds212"
BACKUP_DIR_MONTHLY="${BACKUP_DIR}/backup_$(date +%y%m)"
BACKUP_GPG_KEY="AC27BDB1" # See: http://www.cyberciti.biz/faq/ssh-passwordless-login-with-keychain-for-scripts/
BACKUP_OPTS="--progress --verbosity=2 --full-if-older-than 30D --volsize=4096 --num-retries=3 --encrypt-key=${BACKUP_GPG_KEY} --exclude-device-files --exclude-other-filesystems"
BACKUP_TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
BACKUP_LOG_PREFIX="backup-${BACKUP_TIMESTAMP}"

# See: http://www.cyberciti.biz/faq/duplicity-installation-configuration-on-debian-ubuntu-linux/ 
#      http://linux-audit.com/gpg-key-generation-not-enough-random-bytes-available/

${MKDIR} -p ${BACKUP_DIR} && \
${MKDIR} -p ${BACKUP_DIR_MONTHLY} && \
${BACKUP_BIN} -V &&

backup_task_run()
{    
    LOCAL_TARGETS=$1
    LOCAL_BACKUP_DIR=$2
    for CUR_TARGET in ${LOCAL_TARGETS}; do
        CUR_TARGET_SUFFIX=$($ECHO ${CUR_TARGET} | ${SED} 's_/_-_g')
        CUR_TARGET_DIR=${LOCAL_BACKUP_DIR}/${BACKUP_TARGET_NAME}${CUR_TARGET_SUFFIX}
        CUR_LOG_FILE_SUFFIX=$($ECHO ${CUR_TARGET}.log | ${SED} 's_/_-_g')
        CUR_LOG_FILE=/tmp/${BACKUP_LOG_PREFIX}-${BACKUP_TARGET_NAME}${CUR_LOG_FILE_SUFFIX}
        ${ECHO} "Backing up: ${CUR_TARGET}"
        ${ECHO} "    Target: ${CUR_TARGET_DIR}"
        ${ECHO} "    Log   : ${CUR_LOG_FILE}"
        ${MKDIR} -p ${CUR_TARGET_DIR}
        ${BACKUP_BIN} ${BACKUP_TYPE} ${BACKUP_OPTS} ${CUR_TARGET} file://${CUR_TARGET_DIR}  2>&1 | ${TEE} ${CUR_LOG_FILE}
        ${MV} ${CUR_LOG_FILE} ${CUR_TARGET_DIR}
    done
}

BACKUP_TARGET_NAME=ds212

BACKUP_TARGETS_ONCE="\
    /etc
    /volume2/com \
    /volume2/comedy \
    /volume2/downloads \
    /volume2/movies \
    /volume2/tv" 

backup_task_run "${BACKUP_TARGETS_ONCE}" "${BACKUP_DIR}"

BACKUP_TARGETS_MONTHLY="\
    /volume2/ebooks \
    /volume2/incoming \
    /volume2/learning \
    /volume2/pictures \
    /volume2/mags \
    /volume2/music" 

backup_task_run "${BACKUP_TARGETS_MONTHLY}" "${BACKUP_DIR_MONTHLY}"
