#!/bin/bash

# ------------------------------------------------------------------
# - Filename: utils.sh
# - Author: ottomatic
# - Dependency: None
# - Description: Shell module for utilitaries function
# - Creation date: 2024-12-20
# - Bash version: 5.2.15(1)-release
# ------------------------------------------------------------------

####################################################
#                    Parameters
####################################################

### postgresql database parameters
POSTGRESQL_DEFAULT_DB=("postgres")

####################################################
#                 Common utils function
####################################################

checkMandatoryVariable() {
### valid that all variables tagged as mandatory are defined ###
    MANDATORY_VAR_LIST_TMP=$1
    for var in "${MANDATORY_VAR_LIST_TMP[@]}"; do
        if [[ -z "${var+x}" ]]; then
            error "$var is not defined or is empty."
            return 1
        fi
    done
}

convert_kib_to_gb() {
    kib=$1
    gb_value=$(echo "scale=6; $kib / (1024 * 1024)" | bc)
    echo $gb_value
}

####################################################
#                 Disk utils function
####################################################

check_disk_space_availiability(){
### check disk space available ###
    log "checking disk space availability"
    SPACE_AVAILABLE=$(df -BG ${BACKUP_POSTGRES_DIR_MOUNT_POINT} | awk 'NR==2 {print $2}' | tr -d 'G')
    if [ "${SPACE_AVAILABLE}" != "" ] ;then
        log "database size: ${PG_SIZE_TMP_INITIAL}GB and space available : ${SPACE_AVAILABLE}GB"
        if [ ${PG_SIZE_TMP_INITIAL} -gt ${SPACE_AVAILABLE} ];then
            error_exit "not enough disk available for the backup, aborting"
        fi
    else
        warn "cannot found the mount point : ${BACKUP_POSTGRES_DIR_MOUNT_POINT}, the disk space check is skipped"
    fi
}

####################################################
#                 Restic utils function
####################################################

show_latest_snapshot() {
### show latest restic snapshot ###
    RESTIC_SNAPSHOT_ID=$(restic snapshots --json | jq -r '.[-1].id')
    RESTIC_SNAPSHOT_DATA=$(restic snapshots --json |  jq --arg id "$RESTIC_SNAPSHOT_ID" '.[] | select(.id == $id)')
        if [ $? -eq 0 ];then
            log "${RESTIC_SNAPSHOT_DATA}"
        else 
            error "Cannot show backup snapshot"
        fi
    
}

check_recent_backup() {
### check if backup was made recently ###
    LATEST_BACKUP_SEC_DELAY=$1
    RESTIC_SNAPSHOT_TIME=$(restic snapshots --json | jq --arg id "$RESTIC_SNAPSHOT_ID" '.[] | select(.id == $id) | .time')

    ## convert str time to epoch time
    DATE_TMP=$(echo "${RESTIC_SNAPSHOT_TIME:0:19}" | sed 's/T/ /')
    LATEST_BACKUP_DATE=$(date -d "$DATE_TMP" +%s)
    CURRENT_DATE=$(date +%s)
    EXPECTED_BACKUP_DATE=$((CURRENT_DATE + LATEST_BACKUP_SEC_DELAY))
    if [ "$LATEST_BACKUP_DATE" -lt "$EXPECTED_BACKUP_DATE" ]; then
        warn "previous backup was made before the backup interval, to prevent unwanted new backup creation, this backup is skipped"
        return 1
    fi
}

####################################################
#                 Postgresql utils function
####################################################

set_pg_credential() {
### create the PGPASSFILE path and validate the rights ###
    log "creating postgresql client config file at : ${PGPASSFILE}"
    mkdir -p $(dirname "${PGPASSFILE}")
    ( [ -e "${PGPASSFILE}" ] || touch "${PGPASSFILE}" ) && [ ! -w "${PGPASSFILE}" ] && error_exit "cannot write to ${PGPASSFILE}"
    chmod 0600 ${PGPASSFILE}
    chown $(id -un) ${PGPASSFILE}
    set PGPASSFILE=$PGPASSFILE

    ## add default line for postgres DB
    for DB in ${POSTGRESQL_DEFAULT_DB}; do
        CREDENTIAL_LINE="${POSTGRES_HOST}:${POSTGRES_PORT}:${DB}:${POSTGRES_USERNAME}:${POSTGRES_PASS}"
        if ! grep -q "$CREDENTIAL_LINE" "$PGPASSFILE" ; then
            echo ${CREDENTIAL_LINE} >> ${PGPASSFILE}
        fi
    done

    ## add line for each DB
    for DB in ${POSTGRES_DB_LIST}; do
        CREDENTIAL_LINE="${POSTGRES_HOST}:${POSTGRES_PORT}:${DB}:${POSTGRES_USERNAME}:${POSTGRES_PASS}"
        if ! grep -q "$CREDENTIAL_LINE" "$PGPASSFILE" ; then
            echo ${CREDENTIAL_LINE} >> ${PGPASSFILE}
        fi
    done
}

check_database_estimated_size() {
### Get the estimated postgresql database size using pg_database_size ###
    for DB in ${POSTGRES_DB_LIST}; do
        PG_SIZE_TMP_INITIAL=0
        PG_SIZE_TMP=$(psql -t -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -c "SELECT pg_database_size('${DB}');")
        if [ $? -eq 0 ];then
            # strip any non numeric charachter in PG_SIZE_TMP
            PG_SIZE_TMP=$(echo ${PG_SIZE_TMP} | sed 's/[^0-9]*//g')
            # convert bytes into GB for logs
            PG_SIZE_TMP=$((PG_SIZE_TMP/1024/1024/1024))
            PG_SIZE_TMP_INITIAL=$((PG_SIZE_TMP_INITIAL + PG_SIZE_TMP))
        else
            error "Error on estimating database size : ${PG_SIZE_TMP}"
            return 1
            break
        fi
    done;
}

postgresql_check_readiness() {
### check if postgresql database is ready using pg_isready ###
    until pg_isready -q -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB}
    do
        if [ ${PG_READY_RETRY_THRESHOLD} -gt 0 ]; then
            warn "database not ready, waiting ${PG_READY_RETRY_WAIT_TIME}s"
            PG_READY_RETRY_THRESHOLD=$((PG_READY_RETRY_THRESHOLD-1))
            sleep ${PG_READY_RETRY_WAIT_TIME}
        else
            warn "threshold reached for pg_ready test, database is not available after ${PG_READY_RETRY_THRESHOLD_INITIAL} try"
            break
        fi
    done

    if pg_isready -q -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB}  ; then
        log "database is ready to receive any connection (pg_ready success)"
    else
        warn "database left unavailable for connection (pg_ready failure)"
    fi

}

postgresql_multiple_user_database_mode() {
### set postgresql database access parameter datallowconn to true to enable new conn ###
    ALLOWCONN_COUNTER=0
    SLEEP_INIT_VALUE=5
    until psql -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -c "UPDATE pg_database SET datallowconn = 'true' WHERE datname = '${DB}';"
    do
        ALLOWCONN_COUNTER=$((ALLOWCONN_COUNTER+1))
        SLEEP_VALUE=$((ALLOWCONN_COUNTER*SLEEP_INIT_VALUE))
        warn "Error while trying to set database allowconn parameter to 'true'. Database cannot accept new connection ..."
        warn "Trying to set datallowconn parameter again (attemp number : $ALLOWCONN_COUNTER)"
        sleep ${SLEEP_VALUE}
    done
    log "Database ${DB} parameter datallowconn successfully set to true. Database now allow new connection"
}

remove_pg_dump_output() {
### remove pg_dump after backup export ###
    if [ -f ${FILENAME} ]; then
        rm -rf ${FILENAME}
        if [ $? -eq 0 ];then
            log "temp pg_dump data successfully deleted"
        else
            warn "error while deleting pg_dump file : ${FILENAME}."
        fi
    fi

}