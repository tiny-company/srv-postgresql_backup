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
MANDATORY_VAR_LIST=$("POSTGRES_DB_LIST" "POSTGRES_HOST" "POSTGRES_PORT" "POSTGRES_USERNAME" "POSTGRES_PASS" "RESTIC_REPOSITORY" "RESTIC_PASSWORD" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")

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
BACKUP_POSTGRES_DIR_MOUNT_POINT=${BACKUP_POSTGRES_DIR_MOUNT_POINT:-/backup}

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
LOG_STD_OUTPUT=${LOG_STD_OUTPUT:-true}
LOG_DIR=${LOG_DIR:-/var/log/tinycompany/postgresql_backup}
SCRIPT_NAME="${SCRIPT_NAME:-postgresql_backup_script}.log"
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}

### pg_ready parameters
PG_READY_RETRY_THRESHOLD=${PG_READY_RETRY_THRESHOLD:-3}
PG_READY_RETRY_THRESHOLD_INITIAL=${PG_READY_RETRY_THRESHOLD}
PG_READY_RETRY_WAIT_TIME=${PG_READY_RETRY_WAIT_TIME:-120}

### restic parameters
RESTIC_PATH=${RESTIC_PATH:-restic}
RESTIC_TAG=${RESTIC_TAG:-postgresql_backup}
RESTIC_REPOSITORY=${RESTIC_REPOSITORY}
RESTIC_PASSWORD=${RESTIC_PASSWORD}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-fr-par}
AWS_REGION=${AWS_DEFAULT_REGION}

### resticprofile parameters
RESTICPROFILE_CONFIG_PATH=${RESTICPROFILE_CONFIG_PATH:-/root/resticprofile}
RESTICPROFILE_PASSWORD_LENGTH=${RESTICPROFILE_PASSWORD_LENGTH:-2048}
RESTICPROFILE_PASSWORD_FILENAME=${RESTICPROFILE_PASSWORD_FILENAME:-password.key}
PROMETHEUS_URL=${PROMETHEUS_URL}

####################################################
#                    Dependencies
####################################################

. ${WORKDIR}/shell_modules/logs.sh
. ${WORKDIR}/shell_modules/postgresql_backup.sh

####################################################
#                    Utils function
####################################################

checkMandatoryVariable() {
### valid that all variables tagged as mandatory are defined ###
    log "checking mandatory variables existence"
    for var in "${MANDATORY_VAR_LIST[@]}"; do
        if [[ -z "${var+x}" ]]; then
            error "$var is not defined or is empty."
            return 1
        fi
    done
}

####################################################
#              Main function
####################################################

checkMandatoryVariable
if [ $? -ne 0 ]; then
    error_exit "mandatory variables above not set, see previous logs to see which, exiting"
fi

validate_log_path || error_exit "$?"

log " ==> new postgresql backup process started <=="
create_backup_path || error_exit "$?"
set_pg_credential || error_exit "$?"

if ${FEATURE_SIZE_CHECK} ; then
    check_database_estimated_size || exit 1
    check_disk_space_availiability || error_exit "$?"
fi

resticprofile_configuration || error_exit "$?"
postgresql_backup_restic || error_exit "$?"

if ${PG_DUMP_SUCCESS} ; then
    postgresql_check_readiness || error_exit "$?"
fi

ELAPSED_TIME=$(( $(date +%s)-${START_TIME} ))
log "postgresql backup process finished in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
log " ==> postgresql backup process ended <=="