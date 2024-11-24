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

MANDATORY_VAR_LIST=("CRON_SCHEDULE" "CRON_JOB")

### utils parameters
WORKDIR=${WORKDIR:-/srv}

### logs parameters
LOG_STD_OUTPUT=${LOG_STD_OUTPUT:-false}
LOG_DIR=${LOG_DIR:-/var/log}
SCRIPT_NAME="${SCRIPT_NAME:-cron}.log"
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}

## cron parameters
CRON_BASE_DIR=${CRON_BASE_DIR:-/etc/cron.d/}


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

createCronJob() {
### create cron jon
###    arg 1 : cron schedule
###    arg 2 : cron job action
###    arg 3 : cron job name
###
    TEMP_CRON_SCHEDULE=$(echo "$1" | tr -d '"')
    TEMP_CRON_JOB=$(echo "$2" | tr -d '"')
    CRON_CREATION_OC=$(echo "${TEMP_CRON_SCHEDULE} ${TEMP_CRON_JOB}" >> ${CRON_BASE_DIR}/$3)
    if [ $? -ne 0 ]; then
        error_exit "error while creating job $3 : ${CRON_CREATION_OC}"
    else
        log "successfully creating job named : $3"
    fi
}

####################################################
#              Main function
####################################################

checkMandatoryVariable
if [ $? -ne 0 ]; then
    error_exit "mandatory variables above not set, see previous logs to see which, exiting"
fi

createCronJob "${CRON_SCHEDULE}" "${CRON_JOB}" backup_job

## Create logrotate configuration file
cat << EOF > /etc/logrotate.d/cron_logs
/var/log/cron.log {
    size 10M
    rotate 5
    missingok
    notifempty
    compress
    delaycompress
    create 0644 root root
    postrotate
        /usr/bin/killall -HUP cron
    endscript
}
EOF

createCronJob "0 12 * * 1" "/usr/sbin/logrotate /etc/logrotate.d/cron_logs >> /var/log/cron.log 2>&1" logrotate_job

## Start cron and keep it running in the foreground, while outputting logs
cron && tail -f /var/log/cron.log