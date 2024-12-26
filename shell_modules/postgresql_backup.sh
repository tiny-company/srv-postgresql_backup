#!/bin/bash

# ------------------------------------------------------------------
# - Filename: postgresql_backup.sh
# - Author: ottomatic
# - Dependency: log.sh, utils.sh
# - Description: Shell module for postgresql backup (with restic)
# - Creation date: 2024-11-18
# - Bash version: 5.2.15(1)-release
# ------------------------------------------------------------------

####################################################
#         Postgresql backup path dest
####################################################

create_backup_path() {
    mkdir -p "${BACKUP_POSTGRES_DIR}/${POSTGRES_HOST}"
}

####################################################
#         backup error
####################################################

backup_failure_message() {
### default backup failure message ###
    ELAPSED_TIME=$(( $(date +%s)-${BACKUP_START_TIME} ))
    error "postgresql restore process ended (in error) in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
    error_exit "backup failure on ${POSTGRES_HOST}."
}

####################################################
#              Backup function
####################################################

restic_repo_init() {
### init restic repository ###
    log "creating restic repository"
    restic init --repo $RESTIC_REPOSITORY 2>&1
}

postgresql_backup_restic() {
### launching postgresql database backup and manage it with restic ###
    PG_DUMP_START_TIME=$(date +%s)
    PG_DUMP_SUCCESS=false
    # execute pg_dump for each database in list
    for DB in ${POSTGRES_DB_LIST}; do
        PG_DUMP_START_TIME=$(date +%s)
        log "postgresql dump process started on host : ${POSTGRES_HOST} for Database : ${DB}"

        FILENAME=${BACKUP_POSTGRES_DIR}/${POSTGRES_HOST}.${DB}.${DATE}.dmp

        PG_DUMP_RESULT=$(pg_dump -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -j ${BACKUP_PARALELL_THREAD} -F ${BACKUP_FORMAT} --no-owner -f ${FILENAME})
        PG_DUMP_ELAPSED_TIME=$(( $(date +%s)-${PG_DUMP_START_TIME} ))
        if [ $? -eq 0 ];then
            log "postgresql dump process ended (in success) for Database : ${DB} in $(($PG_DUMP_ELAPSED_TIME/60)) min $(($PG_DUMP_ELAPSED_TIME%60)) sec"
            PG_DUMP_SUCCESS=true
        else
            error "postgresql backup process ended (in error) for Database : ${DB} in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
            error "backup failure on ${POSTGRES_HOST} for database: ${DB}"
            error_exit "${PG_DUMP_RESULT}"

        fi
        ## backup pg_dump output using restic
        if ${PG_DUMP_SUCCESS};then
            RESTIC_START_TIME=$(date +%s)
            RESTIC_RESULT=$(restic -r ${RESTIC_REPOSITORY} backup ${FILENAME} 2>&1)
            if [ $? -eq 0 ];then
                RESTIC_ELAPSED_TIME=$(( $(date +%s)-${RESTIC_START_TIME} ))
                log "restic process ended (in success) for Database : ${DB} in in $(($RESTIC_ELAPSED_TIME/60)) min $(($RESTIC_ELAPSED_TIME%60)) sec"
            else
                ELAPSED_TIME=$(( $(date +%s)-${RESTIC_START_TIME} ))
                error "restic process ended (in error) for Database : ${DB} in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
                error "backup failure on ${POSTGRES_HOST} for database: ${DB}"
                error_exit "${RESTIC_RESULT}"
            fi

        else
            log "restic process skipped because : postgresql backup failed"
        fi
    done
}