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
    FULL_RESTORE_SIZE=$(restic stats --mode json | jq -r --arg SNAPSHOT_ID "${RESTIC_SNAPSHOT_ID}" '.snapshots[] | select(.id == ${RESTIC_SNAPSHOT_ID}) | .total_size')
    if [ -n "$FULL_RESTORE_SIZE" ]; then
        log "Full restore size of snapshot ${RESTIC_SNAPSHOT_ID}: $FULL_RESTORE_SIZE bytes"
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
        log "restic snapshot size: ${FULL_RESTORE_SIZE}GB and space available : ${SPACE_AVAILABLE}GB"
        if [ ${FULL_RESTORE_SIZE} -gt ${SPACE_AVAILABLE} ];then
            error "Not enough disk available for the backup, aborting"
            return 1
        fi
    else
        error "cannot found the mount point : ${RESTORE_RESTIC_TARGET_DIR}, the disk space check is skipped"
        return 1
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
    for DB in ${POSTGRES_DB_RESTORE_LIST}; do

        ## create database if not exist 
        ## (not using "pg_restore -C --clean" in order to separate steps and errors)
        PG_CREATE_DB_START_TIME=$(date +%s)
        log "postgresql create DB process started on host : ${POSTGRES_HOST} for Database : ${DB}"
        CREATE_DB_RESULT=$(psql -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -c "CREATE DATABASE ${DB} IF NOT EXISTS;")
        if [ $? -ne 0 ]; then
            PG_CREATE_DB_ELAPSED_TIME=$(( $(date +%s)-${PG_CREATE_DB_START_TIME} ))
            error "postgresql create DB (${DB}) process ended (in error) in $(($PG_CREATE_DB_ELAPSED_TIME/60)) min $(($PG_CREATE_DB_ELAPSED_TIME%60)) sec"
            error $CREATE_DB_RESULT
            PG_RESTORE_SUCCESS=false
            return 1
            break
        fi

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

        ## restore database from restic restore
        PG_RESTORE_DB_START_TIME=$(date +%s)
        log "postgresql restore process started on host : ${POSTGRES_HOST} for Database : ${DB}"
        PG_RESTORE_RESULT=$(pg_restore -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} $BACKUP_DMP_FILENAME)
        if [ $? -ne 0 ]; then
            PG_RESTORE_ELAPSED_TIME=$(( $(date +%s)-${PG_RESTORE_DB_START_TIME} ))
            error "postgresql restore process ended (in error) in $(($PG_RESTORE_ELAPSED_TIME/60)) min $(($PG_RESTORE_ELAPSED_TIME%60)) sec"
            error $PG_RESTORE_RESULT
            PG_RESTORE_SUCCESS=false
            return 1
            break
        fi
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
    error "backup failure on ${POSTGRES_HOST}."
}