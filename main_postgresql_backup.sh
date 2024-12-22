#!/bin/bash

# ------------------------------------------------------------------
# - Filename: main_postgresql_backup.sh
# - Author : ottomatic
# - Dependency : logs.sh, postgresql_backup.sh
# - Description : script that backup a postgresql database.
# - Creation date : 2024-11-18
# - Bash version : 5.2.15(1)-release
# ------------------------------------------------------------------

set -euo pipefail

####################################################
#                    Parameters
####################################################
MANDATORY_VAR_LIST=("POSTGRES_DB_LIST" "POSTGRES_HOST" "POSTGRES_PORT" "POSTGRES_USERNAME" "POSTGRES_PASS" "RESTIC_REPOSITORY" "RESTIC_PASSWORD" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")

### Feature activation
FEATURE_SIZE_CHECK=${FEATURE_SIZE_CHECK:-true}
FEATURE_BACKUP_ROTATION=${FEATURE_BACKUP_ROTATION:-true}

### utils parameters
WORKDIR=${WORKDIR:-/srv}
START_TIME=$(date +%s)
DATE=$(date '+%Y-%m-%d')
USERNAME=$(id -un)

### backup path
BACKUP_NAME=${BACKUP_NAME:-postgresql}
BACKUP_BASE_DIR=${BACKUP_BASE_DIR:-/backup/tinycompany}
BACKUP_POSTGRES_DIR=${BACKUP_BASE_DIR}/${BACKUP_NAME}
BACKUP_POSTGRES_DIR_MOUNT_POINT=${BACKUP_POSTGRES_DIR_MOUNT_POINT:-/}

### database parameters
POSTGRES_DB_LIST=${POSTGRES_DB_LIST}
POSTGRES_USERNAME=${POSTGRES_USERNAME}
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_PORT=${POSTGRES_PORT}
PGPASSFILE=${PGPASSFILE:-/$(id -un)/.pgpass}

### backup parameters
BACKUP_FORMAT=${BACKUP_FORMAT:-c}
BACKUP_PARALELL_THREAD=${BACKUP_PARALELL_THREAD:-1}
BACKUP_COMPRESSION_LEVEL=${BACKUP_COMPRESSION_LEVEL:-5}
BACKUP_DAILY_COUNT=${BACKUP_DAILY_COUNT:-6}

### logs parameters
LOG_STD_OUTPUT=${LOG_STD_OUTPUT:-false}
LOG_DIR=${LOG_DIR:-/var/log}
SCRIPT_NAME="${SCRIPT_NAME:-cron}.log"
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}
LOG_COLORED=${LOG_COLORED:-false}

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

### resticprofile parameters
RESTICPROFILE_CONFIG_PATH=${RESTICPROFILE_CONFIG_PATH:-/root/resticprofile}
RESTICPROFILE_PASSWORD_LENGTH=${RESTICPROFILE_PASSWORD_LENGTH:-2048}
RESTICPROFILE_PASSWORD_FILENAME=${RESTICPROFILE_PASSWORD_FILENAME:-password.key}
PROMETHEUS_URL=${PROMETHEUS_URL:-}

####################################################
#                    Dependencies
####################################################

. ${WORKDIR}/shell_modules/logs.sh
. ${WORKDIR}/shell_modules/utils.sh
. ${WORKDIR}/shell_modules/postgresql_backup.sh

####################################################
#              Main function
####################################################

BACKUP_START_TIME=$(date +%s)

validate_log_path || error_exit "$?"

checkMandatoryVariable ${MANDATORY_VAR_LIST}
if [ $? -ne 0 ]; then
    error_exit "mandatory variables above not set, see previous logs to see which, exiting"
fi

log " ==> new postgresql backup process started <=="
create_backup_path || error_exit "$?"
set_pg_credential || error_exit "$?"

if ${FEATURE_SIZE_CHECK} ; then
    check_database_estimated_size || backup_failure_message
    check_disk_space_availiability || backup_failure_message
fi

# resticprofile_configuration || error_exit "$?"
restic snapshots > /dev/null || restic_repo_init
postgresql_backup_restic || error_exit "$?"

if ${PG_DUMP_SUCCESS} ; then
    postgresql_check_readiness || error_exit "$?"
fi

ELAPSED_TIME=$(( $(date +%s)-${START_TIME} ))
log "postgresql backup process finished in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
log " ==> postgresql backup process ended <=="