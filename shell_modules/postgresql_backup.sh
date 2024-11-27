#!/bin/bash

# ------------------------------------------------------------------
# - Filename: postgresql_backup.sh
# - Author: ottomatic
# - Dependency: None
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
#         Postgresql credential configuration
####################################################

set_pg_credential() {
    # create the PGPASSFILE path and validate the rights
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

####################################################
#              Backup function
####################################################

check_database_estimated_size() {
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

check_disk_space_availiability(){
    ## make sure that backup dir path mount is created
    mkdir -p ${BACKUP_POSTGRES_DIR_MOUNT_POINT}
    log "checking disk space availability"
    # check if BACKUP_POSTGRES_DIR_MOUNT_POINT exist
    SPACE_AVAILABLE=$(df -h | grep -i ${BACKUP_POSTGRES_DIR_MOUNT_POINT} | awk '{print $4}')
    # strip any non numeric character in SPACE_AVAILABLE
    SPACE_AVAILABLE=$(echo ${SPACE_AVAILABLE} | sed 's/[^0-9]*//g')
    if [ "${SPACE_AVAILABLE}" != "" ] ;then
        log "database size: ${PG_SIZE_TMP_INITIAL}GB and space available : ${SPACE_AVAILABLE}GB"
        if [ ${PG_SIZE_TMP_INITIAL} -gt ${SPACE_AVAILABLE} ];then
            error_exit "not enough disk available for the backup, aborting"
        fi
    else
        warn "cannot found the mount point : ${BACKUP_POSTGRES_DIR_MOUNT_POINT}, the disk space check is skipped"
    fi
}

resticprofile_configuration() {
### configure restic parameters using restic profile ###
    log "checking if resticprofile is installed"
    if [ ! -f "/usr/local/bin/resticprofile" ] ; then
        log "resticprofile not found in '/usr/local/bin/resticprofile' "
        log "installing restic profile from githubusercontent"
        CURL_RESULT_CODE=$(curl -s -LO https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh -w %{http_code} --output-dir /tmp)
        if [ "${CURL_RESULT_CODE}" = "200" ]; then
            log "launching install script for restic profile"
            chmod +x /tmp/install.sh
            /tmp/install.sh -b /usr/local/bin 2>&1 >/dev/null
        else
            ELAPSED_TIME=$(( $(date +%s)-${START_TIME} ))
            error "backup failure, caused by resticprofile installation fail in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
            error_exit "$?"
        fi
    else
        log "resticprofile already installed"
    fi

    log "updating resticprofile"
    resticprofile self-update >/dev/null

    log "setting resticprofile configuration"
    mkdir -p ${RESTICPROFILE_CONFIG_PATH}
    ( [ -e "${RESTICPROFILE_CONFIG_PATH}/profile.yml" ] || cp ${WORKDIR}/resticprofile/profile.yml ${RESTICPROFILE_CONFIG_PATH}/profile.yml )
    chmod 0700 ${RESTICPROFILE_CONFIG_PATH}/profile.yml
    if [ -z ${RESTIC_PASSWORD+x} ] ; then
        log "restic password not set by user, generate random key"
        resticprofile generate --random-key ${RESTICPROFILE_PASSWORD_LENGTH} > ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}
    else
        log "setting user defined restic password to file ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}"
        echo ${RESTIC_PASSWORD} > ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}
    fi
    chmod 0600 ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}
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

        PG_DUMP_RESULT=$(pg_dump -h ${POSTGRES_HOST} -U ${POSTGRES_USERNAME} -d ${DB} -j ${BACKUP_PARALELL_THREAD} -F ${BACKUP_FORMAT} --no-owner -f ${FILENAME} 2>&1)
        if [ $? -eq 0 ];then
            PG_DUMP_ELAPSED_TIME=$(( $(date +%s)-${PG_DUMP_START_TIME} ))
            log "postgresql dump process ended (in success) for Database : ${DB} in in $(($PG_DUMP_ELAPSED_TIME/60)) min $(($PG_DUMP_ELAPSED_TIME%60)) sec"
            PG_DUMP_SUCCESS=true
        else
            ELAPSED_TIME=$(( $(date +%s)-${PG_DUMP_START_TIME} ))
            error "postgresql backup process ended (in error) for Database : ${DB} in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
            error "backup failure on ${POSTGRES_HOST} for database: ${DB}"
            error_exit "${PG_DUMP_RESULT}"

        fi

        if ${PG_DUMP_SUCCESS};then
            RESTIC_START_TIME=$(date +%s)
            RESTIC_RESULT=$(resticprofile -c "${RESTICPROFILE_CONFIG_PATH}/profile.yml" backup ${FILENAME} 2>&1)
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