#!/bin/bash

# ------------------------------------------------------------------
# - Filename: main_postgresql_restore.sh
# - Author : ottomatic
# - Dependency : logs.sh, utils.sh, postgresql_restore.sh
# - Description : script that restore a postgresql database.
# - Creation date : 2024-12-20
# - Bash version : 5.2.15(1)-release
# ------------------------------------------------------------------

set -euo pipefail

####################################################
#                    Parameters
####################################################
MANDATORY_VAR_LIST=("POSTGRES_DB_LIST" "POSTGRES_HOST" "POSTGRES_PORT" "POSTGRES_USERNAME" "POSTGRES_PASS" "RESTIC_REPOSITORY" "RESTIC_PASSWORD" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")

## temp restore var list :
# RESTIC_REPOSITORY
# RESTIC_PASSWORD

### utils parameters
WORKDIR=${WORKDIR:-/srv}
START_TIME=$(date +%s)
DATE=$(date '+%Y-%m-%d')
USERNAME=$(id -un)

### database parameters
POSTGRES_DB_LIST=${POSTGRES_DB_LIST}
POSTGRES_USERNAME=${POSTGRES_USERNAME}
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_PORT=${POSTGRES_PORT}
PGPASSFILE=${PGPASSFILE:-/$(id -un)/.pgpass}

### logs parameters
LOG_STD_OUTPUT=${LOG_STD_OUTPUT:-false}
LOG_DIR=${LOG_DIR:-/var/log}
SCRIPT_NAME="${SCRIPT_NAME:-cron}.log"
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}

### pg_ready parameters
PG_READY_RETRY_THRESHOLD=${PG_READY_RETRY_THRESHOLD:-3}
PG_READY_RETRY_THRESHOLD_INITIAL=${PG_READY_RETRY_THRESHOLD}
PG_READY_RETRY_WAIT_TIME=${PG_READY_RETRY_WAIT_TIME:-120}

### restic parameters
RESTIC_PATH=${RESTIC_PATH:-restic}
RESTIC_TAG=${RESTIC_TAG:-postgresql_backup}
RESTIC_REPOSITORY=${RESTIC_REPOSITORY}
RESTIC_PASSWORD=${RESTIC_PASSWORD:-}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-fr-par}
AWS_REGION=${AWS_DEFAULT_REGION}

## backup and restore parameters
BACKUP_POSTGRES_DIR_MOUNT_POINT=${BACKUP_POSTGRES_DIR_MOUNT_POINT:-/}
RESTORE_RESTIC_TARGET_DIR=${RESTORE_RESTIC_TARGET_DIR:-/restore}

####################################################
#                    Dependencies
####################################################

. ${WORKDIR}/shell_modules/logs.sh
. ${WORKDIR}/shell_modules/utils.sh
. ${WORKDIR}/shell_modules/postgresql_restore.sh

####################################################
#              Main function
####################################################

RESTORE_START_TIME=$(date +%s)

validate_log_path || error_exit "$?"

checkMandatoryVariable
if [ $? -ne 0 ]; then
    error_exit "mandatory variables above not set, see previous logs to see which, exiting"
fi

log " ==> new postgresql restore process started <=="

## Get snapshot_id from user input or set it to latest by default
if [ -z "$RESTIC_SNAPSHOT_ID" ]; then
    RESTIC_SNAPSHOT_ID=$(restic snapshots --json | jq -r '.[0].id')
    if [ -z "$RESTIC_SNAPSHOT_ID" ]; then
        error "No snapshots found in restic repository : $RESTIC_REPOSITORY"
        restore_failure_message
    fi
fi

# test space availility for the restore process 
if ${FEATURE_SIZE_CHECK} ; then
    check_restore_size || restore_failure_message
fi

restore_restic_backup || restore_failure_message

## @TODO restore the content into the postgresql database 
postgresql_restore || restore_failure_message

## @TODO check database working using pgready
if ${PG_RESTORE_SUCCESS} ; then
    postgresql_check_readiness || error_exit "$?"
fi

## @TODO remove backup content 
#

ELAPSED_TIME=$(( $(date +%s)-${START_TIME} ))
log "postgresql restore process finished in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
log " ==> postgresql restore process ended <=="


