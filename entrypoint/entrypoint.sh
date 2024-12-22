#!/bin/bash

# ------------------------------------------------------------------
# - Filename: cron_entrypoint.sh
# - Author : ottomatic
# - Dependency : logs.sh
# - Description : container cron entrypoint
# - Creation date : 2024-11-25
# - Bash version : 5.2.15(1)-release
# ------------------------------------------------------------------

set -euo pipefail

####################################################
#                    Parameters
####################################################

MANDATORY_VAR_LIST=("SLEEP_SEC_DURATION")

### utils parameters
WORKDIR=${WORKDIR:-/srv}

### logs parameters
LOG_STD_OUTPUT=${LOG_STD_OUTPUT:-false}
LOG_DIR=${LOG_DIR:-/var/log}
SCRIPT_NAME="${SCRIPT_NAME:-cron}.log"
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}

## cron parameters
SLEEP_SEC_DURATION=${SLEEP_SEC_DURATION:-86400}


####################################################
#                    Dependencies
####################################################

. ${WORKDIR}/shell_modules/logs.sh

####################################################
#                    Utils function
####################################################

checkMandatoryVariable() {
### valid that all variables tagged as mandatory are defined ###
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

if [ "$#" -eq 0 ]; then
    # No arguments passed, run the default script
    while true; do
        ${WORKDIR}/main_postgresql_backup.sh
        sleep ${SLEEP_SEC_DURATION}
    done
else
    case "$1" in
        backup)
            ${WORKDIR}/main_postgresql_backup.sh
            ;;
        restore)
            if [ $# -ge 2 ]; then
                RESTIC_SNAPSHOT_ID=$2
            fi
            ${WORKDIR}/shell_modules/main_postgresql_restore.sh
            ;;
        *)
            error "Error: Unrecognized command '$1'."
            warn "Available command : "
            warn "backup"
            warn "restore <restic_snapshot_id>"
    esac

fi

