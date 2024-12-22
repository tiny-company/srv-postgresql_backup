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
    for DB in ${POSTGRES_DB_LIST}; do
        CREDENTIAL_LINE="${POSTGRES_HOST}:${POSTGRES_PORT}:${DB}:${POSTGRES_USERNAME}:${POSTGRES_PASS}"
        ## if line doesn't already exist in file write it
        if ! grep -q "$CREDENTIAL_LINE" "$PGPASSFILE" ; then
            echo ${CREDENTIAL_LINE} >> ${PGPASSFILE}
        fi
    done
}

check_database_estimated_size() {
### Get the estimated postgresql database size using pg_database_size ###
    for DB in ${POSTGRES_DB_LIST}; do
        PG_SIZE_TMP_INITIAL=0
        PG_SIZE_TMP=$(psql -t -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -c "SELECT pg_database_size('${DB}');" 2>&1)
        if [ $? -eq 0 ];then
            # strip any non numeric charachter in PG_SIZE_TMP
            PG_SIZE_TMP=$(echo ${PG_SIZE_TMP} | sed 's/[^0-9]*//g')
            # convert bytes into GB for logs
            PG_SIZE_TMP=$((PG_SIZE_TMP/1024/1024/1024))
            PG_SIZE_TMP_INITIAL=$((PG_SIZE_TMP_INITIAL + PG_SIZE_TMP))
        else
            error "backup failure on ${POSTGRES_HOST} for database: ${DB}"
            ELAPSED_TIME=$(( $(date +%s)-${START_TIME} ))
            log "postgresql backup process ended (in error) for Database : ${DB} in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec while estimating database size"
            error "${PG_SIZE_TMP}"
            return 1
            break
        fi
    done;
}

postgresql_check_readiness() {
### check if postgresql database is ready using pg_isready ###
    DATABASE_READYNESS=false
    until pg_isready -q -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB}
    do
        if [ ${PG_READY_RETRY_THRESHOLD} -gt 0 ]; then
            warn "database not ready, waiting ${PG_READY_RETRY_WAIT_TIME}s"
            PG_READY_RETRY_THRESHOLD=$((PG_READY_RETRY_THRESHOLD-1))
            sleep ${PG_READY_RETRY_WAIT_TIME};
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