#!/bin/bash

# ------------------------------------------------------------------
# - Filename: postgresql_restore.sh
# - Author: ottomatic
# - Dependency: log.sh
# - Description: Shell module for postgresql restore (with restic)
# - Creation date: 2024-12-20
# - Bash version: 5.2.15(1)-release
# ------------------------------------------------------------------

####################################################
#         Restic restore size check
####################################################

check_restore_size() {
### check restic snapshot size ###
    FULL_RESTORE_SIZE=$(restic --json stats ${RESTIC_SNAPSHOT_ID} | jq -r .total_size)
    FULL_RESTORE_SIZE_FOR_LOG=$(convert_kib_to_gb ${FULL_RESTORE_SIZE})
    if [ -n "$FULL_RESTORE_SIZE" ]; then
        log "Full restore size of snapshot ${RESTIC_SNAPSHOT_ID} is : $FULL_RESTORE_SIZE_FOR_LOG GB"
        check_restore_disk_space_available || return 1
    else
        error "Error while getting the snapshot total size : restic stats return empty value"
        return 1
    fi
}

check_restore_disk_space_available() {
### check if space is available for restic restore (compare snapshot size to disk available) ###
    log "checking disk space availability"
    SPACE_AVAILABLE=$(df -h | grep -i ${RESTORE_RESTIC_TARGET_DIR} | awk '{print $4}')
    # strip any non numeric character in SPACE_AVAILABLE
    SPACE_AVAILABLE=$(echo ${SPACE_AVAILABLE} | sed 's/[^0-9]*//g')
    if [ "${SPACE_AVAILABLE}" != "" ] ;then
        log "restic snapshot size: ${FULL_RESTORE_SIZE_FOR_LOG} GB and space available : ${SPACE_AVAILABLE}GB"
        if [ ${FULL_RESTORE_SIZE_FOR_LOG} -gt ${SPACE_AVAILABLE} ];then
            error "Not enough disk available for the backup, aborting"
            return 1
        fi
    else
        error "cannot found the mount point : ${RESTORE_RESTIC_TARGET_DIR}, the disk space check is skipped"
        return 0
    fi
}

####################################################
#         Restic restore
####################################################

restore_restic_backup() {
### get backup from restic repository and restore it to RESTORE_RESTIC_TARGET_DIR ###
    RESTIC_RESTORE_START_TIME=$(date +%s)
    ## Restore the snapshot
    log "Restoring the restic snapshot : ${RESTIC_SNAPSHOT_ID}"
    RESTIC_RESTORE_RESULT=$(restic restore "${RESTIC_SNAPSHOT_ID}" --target "${RESTORE_RESTIC_TARGET_DIR}")
    RESTIC_RESTORE_ELAPSED_TIME=$(( $(date +%s)-${RESTIC_RESTORE_START_TIME} ))
    if [ $? -eq 0 ]; then
        log "restic restore process ended (in success) in $(($RESTIC_RESTORE_ELAPSED_TIME/60)) min $(($RESTIC_RESTORE_ELAPSED_TIME%60)) sec"
    else
        error "restic restore process ended (in error) in $(($RESTIC_RESTORE_ELAPSED_TIME/60)) min $(($RESTIC_RESTORE_ELAPSED_TIME%60)) sec"
        error $RESTIC_RESTORE_RESULT
        return 1
    fi

}

restore_restic_remove_restore_file() {
### remove restore file at RESTORE_RESTIC_TARGET_DIR ###
    RESTIC_REMOVE_FILE_START_TIME=$(date +%s)
    ## Restore the snapshot
    log "Removing the restic snapshot : ${RESTIC_SNAPSHOT_ID} files (cleanup)"
    RESTIC_REMOVE_RESULT=$(rm -rf "${RESTORE_RESTIC_TARGET_DIR}/*")
    RESTIC_REMOVE_ELAPSED_TIME=$(( $(date +%s)-${RESTIC_REMOVE_FILE_START_TIME} ))
    if [ $? -eq 0 ]; then
        log "restic remove process ended (in success) in $(($RESTIC_REMOVE_ELAPSED_TIME/60)) min $(($RESTIC_REMOVE_ELAPSED_TIME%60)) sec"
    else
        error "restic remove process ended (in error) in $(($RESTIC_REMOVE_ELAPSED_TIME/60)) min $(($RESTIC_REMOVE_ELAPSED_TIME%60)) sec"
        error $RESTIC_REMOVE_RESULT
        return 1
    fi

}

####################################################
#         Postgresql restore 
####################################################

postgresql_restore() {
### restore postgresql backup from restic restore at RESTORE_RESTIC_TARGET_DIR ###
    for DB in ${RESTORE_POSTGRES_DB_LIST}; do

        ## get backup dmp file from restic repo
        PG_DMP_FILE_DB_START_TIME=$(date +%s)
        log "postgresql getting dump file process started on host : ${POSTGRES_HOST} for Database : ${DB}"
        BACKUP_DMP_FILENAME=$(find ${RESTORE_RESTIC_TARGET_DIR} -type f -name "*${DB}*.dmp")
        if [ -z "${BACKUP_DMP_FILENAME+x}" ];then 
            PG_DMP_FILE_ELAPSED_TIME=$(( $(date +%s)-${PG_DMP_FILE_DB_START_TIME} ))
            error "postgresql getting dump file process ended (in error) in $(($PG_DMP_FILE_ELAPSED_TIME/60)) min $(($PG_DMP_FILE_ELAPSED_TIME%60)) sec"
            error "Backup file for Database ${DB} not found in restic repository"
            PG_RESTORE_SUCCESS=false
            return 1
            break
        fi
        PG_DMP_FILE_ELAPSED_TIME=$(( $(date +%s)-${PG_DMP_FILE_DB_START_TIME} ))
        log "postgresql (${DB}) getting dump file process ended (in success) in $(($PG_DMP_FILE_ELAPSED_TIME/60)) min $(($PG_DMP_FILE_ELAPSED_TIME%60)) sec"

        ## Get ride of existing database connection
        PG_TERMINATE_CONN_DB_START_TIME=$(date +%s)
        log "postgresql connection termination process started on host : ${POSTGRES_HOST} for Database : ${DB}"
        PG_TERMINATE_CONN_RESULT=$(psql -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = ${DB} AND pid <> pg_backend_pid();")
        if [ $? -ne 0 ]; then
            PG_TERMINATE_CONN_ELAPSED_TIME=$(( $(date +%s)-${PG_TERMINATE_CONN_DB_START_TIME} ))
            error "postgresql (${DB}) connection termination process ended (in error) in $(($PG_TERMINATE_CONN_ELAPSED_TIME/60)) min $(($PG_TERMINATE_CONN_ELAPSED_TIME%60)) sec"
            error $PG_TERMINATE_CONN_RESULT
            PG_RESTORE_SUCCESS=false
            return 1
            break
        fi
        PG_TERMINATE_CONN_ELAPSED_TIME=$(( $(date +%s)-${PG_TERMINATE_CONN_DB_START_TIME} ))
        log "postgresql (${DB}) connection termination process ended (in success) in $(($PG_TERMINATE_CONN_ELAPSED_TIME/60)) min $(($PG_TERMINATE_CONN_ELAPSED_TIME%60)) sec"

        ## restore database from restic restore
        PG_RESTORE_DB_START_TIME=$(date +%s)
        log "postgresql database restore process started on host : ${POSTGRES_HOST} for Database : ${DB}"
        PG_RESTORE_RESULT=$(pg_restore -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -j ${RESTORE_PARALELL_THREAD} --clean --if-exists --create --exit-on-error --format=custom $BACKUP_DMP_FILENAME)
        if [ $? -ne 0 ]; then
            PG_RESTORE_ELAPSED_TIME=$(( $(date +%s)-${PG_RESTORE_DB_START_TIME} ))
            error "postgresql database (${DB}) restore process ended (in error) in $(($PG_RESTORE_ELAPSED_TIME/60)) min $(($PG_RESTORE_ELAPSED_TIME%60)) sec"
            error $PG_RESTORE_RESULT
            PG_RESTORE_SUCCESS=false
            return 1
            break
        fi
        PG_RESTORE_ELAPSED_TIME=$(( $(date +%s)-${PG_RESTORE_DB_START_TIME} ))
        log "postgresql database ${DB} restore process ended (in success) in $(($PG_RESTORE_ELAPSED_TIME/60)) min $(($PG_RESTORE_ELAPSED_TIME%60)) sec"
    done

    PG_RESTORE_SUCCESS=true

}


####################################################
#         backup restore error
####################################################

restore_failure_message() {
### default restore failure message ###
    ELAPSED_TIME=$(( $(date +%s)-${RESTORE_START_TIME} ))
    error "postgresql restore process ended (in error) in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
    error_exit "restore failure on ${POSTGRES_HOST}."
}