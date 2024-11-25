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

####################################################
#                    Dependencies
####################################################

. ${WORKDIR}/shell_modules/logs.sh

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

echo "${CRON_SCHEDULE} ${CRON_JOB}  &> /var/log/cron.log" >> /etc/crontabs/root

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

## Add logrotate scheduled task to crontab
echo "0 * * * * /usr/sbin/logrotate /etc/logrotate.d/cron_logs" >> /etc/crontabs/root

## Start cron and keep it running in the foreground, while outputting logs
cron

## Continuously output all log files
exec tail -f /var/log/cron.log