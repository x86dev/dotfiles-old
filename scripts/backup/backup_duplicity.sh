#!/bin/sh
BASENAME=basename
ECHO=echo
GPG=gpg
MKDIR=mkdir
MV=mv
RM=rm
RSYNC=rsync
SCP=scp
SED=sed
SSH=ssh
TEE=tee

## @todo Does not work on OS X -- flag "-f" does not exist there.
SCRIPT_PATH=$(readlink -f $0 | xargs dirname)
SCRIPT_EXITCODE=0

set -e
set -x

# Important: https://bugs.launchpad.net/duplicity/+bug/687295
# Currently the locale *must* be set to en_US.UTF-8 in order to get encryption with a public working!

# See: http://www.cyberciti.biz/faq/duplicity-installation-configuration-on-debian-ubuntu-linux/
#      http://linux-audit.com/gpg-key-generation-not-enough-random-bytes-available/

backup_log()
{
    ${ECHO} "$1"
}

backup_setup()
{
    ${ECHO} "Testing key: ${PROFILE_GPG_KEY}"
    ${ECHO} "1234" | ${GPG} --no-use-agent -o /dev/null --local-user ${PROFILE_GPG_KEY} -as - && echo "The correct passphrase was entered for your key."
}

backup_create_dir()
{
    if [ "$BACKUP_TO_REMOTE" = "1" ]; then
        backup_log "Creating remote directory: '$2'"
        ${SSH} ${BACKUP_SSH_OPTS} ${BACKUP_DEST_HOST} "mkdir -p $2"
    else
        backup_log "Creating local directory: '$2'"
        ${MKDIR} -p "$2"
    fi
}

backup_move_file()
{
    if [ "$BACKUP_TO_REMOTE" = "1" ]; then
        LOCAL_FILE=${BACKUP_DEST_HOST}:${2}/$($BASENAME ${1})
        backup_log "Moving file '$1' to remote '$LOCAL_FILE'"
        ${SCP} ${BACKUP_SCP_OPTS} "$1" "$LOCAL_FILE" && ${RM} "$1"
    else
        backup_log "Moving file '$1' to '$2'"
        ${MV} "$1" "$2"
    fi
}

backup_duplicity_run()
{
    LOCAL_HOST=$1
    LOCAL_SOURCES=$2
    LOCAL_DEST_DIR=$3

    LOCAL_DUPLICITY_BIN=duplicity
    LOCAL_DUPLICITY_BACKUP_TYPE=incr

    LOCAL_DUPLICITY_TEMPDIR=${LOCAL_DEST_DIR}/${PROFILE_NAME}
    backup_create_dir "$LOCAL_HOST" "$LOCAL_DUPLICITY_TEMPDIR"

    LOCAL_DUPLICITY_OPTS="\
        --name $PROFILE_NAME \
        --verbosity=4 \
        --full-if-older-than 30D \
        --volsize=4096 \
        --num-retries=3 \
        --tempdir=$LOCAL_DUPLICITY_TEMPDIR \
        --exclude-device-files \
        --exclude-other-filesystems"

    if [ -n "$PROFILE_GPG_KEY" ]; then
        LOCAL_DUPLICITY_OPTS="\
            $LOCAL_DUPLICITY_OPTS
            --encrypt-key=$PROFILE_GPG_KEY"
    fi

    if [ -n "$PROFILE_GPG_PASSPHRASE" ]; then
        export PASSPHRASE=${PROFILE_GPG_PASSPHRASE}
    fi

    for CUR_SOURCE in ${LOCAL_SOURCES}; do
        CUR_SOURCE_SUFFIX=$($ECHO ${CUR_SOURCE} | ${SED} 's_/_-_g')
        CUR_TARGET_DIR=${LOCAL_DEST_DIR}/${PROFILE_NAME}${CUR_SOURCE_SUFFIX}
        CUR_LOG_FILE_SUFFIX=$($ECHO ${CUR_SOURCE}.log | ${SED} 's_/_-_g')
        CUR_LOG_FILE=${BACKUP_PATH_TMP}/${BACKUP_LOG_PREFIX}-${PROFILE_NAME}${CUR_LOG_FILE_SUFFIX}
        ${ECHO} "Backing up: $CUR_SOURCE"
        ${ECHO} "    Target: $CUR_TARGET_DIR"
        ${ECHO} "      Temp: $LOCAL_DUPLICITY_TEMPDIR"
        ${ECHO} "    Log   : $CUR_LOG_FILE"
        backup_create_dir "$LOCAL_HOST" "$CUR_TARGET_DIR"
        ${LOCAL_DUPLICITY_BIN} ${LOCAL_DUPLICITY_BACKUP_TYPE} ${LOCAL_DUPLICITY_OPTS} ${CUR_SOURCE} ${BACKUP_DUPLICITY_PATH_PREFIX}/${CUR_TARGET_DIR} \
            2>&1 | ${TEE} ${CUR_LOG_FILE}
        backup_move_file "$CUR_LOG_FILE" "$CUR_TARGET_DIR"
    done

    if [ -n "$PROFILE_GPG_PASSPHRASE" ]; then
        unset PASSPHRASE
    fi

    # Taken from: https://lists.gnu.org/archive/html/duplicity-talk/2008-05/msg00061.html
    #
    # ...
    # cases where we do not need to get a passphrase:
    # full: with pubkey enc. doesn't depend on old encrypted info
    # inc and pubkey enc.: need a manifest, which the archive dir has unencrypted
    # with encryption disabled
    # listing files: needs a manifest, but the archive dir has that
    # collection status only looks at a repository
    # ...
    #

    #gpg --armor --export -a 841BFBA2 > duplicitysignpublic.key
    #gpg --armor --export -a F953BE5A > duplicityencryptpublic.key
    #gpg --armor --export-secret-keys -a 841BFBA2 > duplicitysignprivate.key
    #gpg --armor --export-secret-keys -a F953BE5A > duplicityencryptprivate.key

    # ??? gpg -d duplicity-backup-2014-06-10.tar.gpg | tar x
}

backup_rsync_run()
{
    LOCAL_RSYNC_BIN=rsync
    LOCAL_RSYNC_OPTS="\
        --archive \
        --delete \
        --stats"

    LOCAL_HOST=$1
    LOCAL_SOURCES=$2
    LOCAL_DEST_DIR=$3

    for CUR_SOURCE in ${LOCAL_SOURCES}; do
        CUR_SOURCE_SUFFIX=$($ECHO ${CUR_SOURCE} | ${SED} 's_/_-_g')
        CUR_TARGET_DIR=${LOCAL_DEST_DIR}/${PROFILE_NAME}${CUR_SOURCE_SUFFIX}
        CUR_LOG_FILE_SUFFIX=$($ECHO ${CUR_SOURCE}.log | ${SED} 's_/_-_g')
        CUR_LOG_FILE=${BACKUP_PATH_TMP}/${BACKUP_LOG_PREFIX}-${PROFILE_NAME}${CUR_LOG_FILE_SUFFIX}
        ${ECHO} "Mirroring: $CUR_SOURCE"
        ${ECHO} "       To: $CUR_TARGET_DIR"
        ${ECHO} "      Log: $CUR_LOG_FILE"
        backup_create_dir "$LOCAL_HOST" "$CUR_TARGET_DIR"
        ${LOCAL_RSYNC_BIN} ${LOCAL_RSYNC_OPTS} ${CUR_SOURCE} ${BACKUP_RSYNC_PATH_PREFIX}/${CUR_TARGET_DIR} \
            2>&1 | ${TEE} ${CUR_LOG_FILE}
        backup_move_file "$CUR_LOG_FILE" "$CUR_TARGET_DIR"
    done
}

backup_debian()
{
    dpkg --get-selections > dpkg-selections-$(date -I)
    dpkg --set-selections < dpkg-selections-$(date -I)
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

if [ -z "$SCRIPT_CMD" ]; then
    ${ECHO} "Must specify a (valid) command to execute, exiting"
    exit 1
fi

if [ -z "$SCRIPT_PROFILE_FILE" ]; then
    ${ECHO} "Must specify a profile name using --profile (e.g. --profile foo.conf), exiting"
    exit 1
fi

SCRIPT_PROFILE_FILE=${SCRIPT_PATH}/${SCRIPT_PROFILE_FILE}
if [ ! -f "$SCRIPT_PROFILE_FILE" ]; then
    CUR_PROFILE=${SCRIPT_PROFILE_FILE}
    if [ ! -f "$SCRIPT_PROFILE_FILE" ]; then
        ${ECHO} "Profile \"$SCRIPT_PROFILE_FILE\" not found, exiting"
        exit 1
    fi
fi

${ECHO} "Using profile: $SCRIPT_PROFILE_FILE"
. ${SCRIPT_PROFILE_FILE}

#backup_setup

if [ "$PROFILE_DEST_HOST" = "localhost" ]; then
    BACKUP_TO_REMOTE=0
else
    BACKUP_TO_REMOTE=1
fi

if [ -n "$PROFILE_DEST_SSH_PORT" ]; then
    BACKUP_SCP_OPTS="-q -P $PROFILE_DEST_SSH_PORT"
    BACKUP_SSH_OPTS="-p $PROFILE_DEST_SSH_PORT"
fi

BACKUP_PATH_TMP=/tmp
${ECHO} "Using temp dir: $BACKUP_PATH_TMP"

if [ "$BACKUP_TO_REMOTE" = "1" ]; then
    if [ -n "$PROFILE_DEST_USERNAME" ]; then
        BACKUP_DEST_HOST=${PROFILE_DEST_USERNAME}@${PROFILE_DEST_HOST}
    else
        BACKUP_DEST_HOST=${PROFILE_DEST_HOST}
    fi
    if [ -n "$PROFILE_DEST_SSH_PORT" ]; then
        BACKUP_DUPLICITY_PATH_PREFIX=scp://${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}
        BACKUP_RSYNC_PATH_PREFIX=${BACKUP_DEST_HOST}:
    else
        BACKUP_DUPLICITY_PATH_PREFIX=scp://${BACKUP_DEST_HOST}
        BACKUP_RSYNC_PATH_PREFIX=${BACKUP_DEST_HOST}:${PROFILE_DEST_SSH_PORT}
    fi
else
    BACKUP_DEST_HOST=localhost
    BACKUP_DUPLICITY_PATH_PREFIX=file://
    BACKUP_RSYNC_PATH_PREFIX=
fi
BACKUP_DEST_DIR=${PROFILE_DEST_DIR}

BACKUP_DEST_DIR_MONTHLY="${BACKUP_DEST_DIR}/backup_$(date +%y%m)"

BACKUP_TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
BACKUP_LOG_PREFIX="backup-$BACKUP_TIMESTAMP"

case "$SCRIPT_CMD" in
    backup)
        LANG_OLD=${LANG}
        export LANG=en_US.UTF-8
        export PASSPHRASE=notused
        backup_log "Backup started."
        backup_log "Running monthly backups ..."
        backup_create_dir "$BACKUP_DEST_HOST" "$BACKUP_DEST_DIR"
        backup_create_dir "$BACKUP_DEST_HOST" "$BACKUP_DEST_DIR_MONTHLY"
        backup_duplicity_run "$BACKUP_DEST_HOST" "$PROFILE_SOURCES_MONTHLY" "$BACKUP_DEST_DIR_MONTHLY"
        export LANG=${LANG_OLD}
        if [ -n "$PROFILE_SOURCES_ONCE" ]; then
            backup_log "Running only-once backups (mirroring) ..."
            backup_rsync_run "$BACKUP_DEST_HOST" "$PROFILE_SOURCES_ONCE" "$BACKUP_DEST_DIR"
        fi
        backup_log "Backup successfully finished."
        ;;
    test)
        ## @todo Implement this.
        ;;
    setup)
        backup_setup
        ;;
    *)
        ${ECHO} "Unknown command \"$SCRIPT_CMD\", exiting"
        SCRIPT_EXITCODE=1
        ;;
esac

exit ${SCRIPT_EXITCODE}
