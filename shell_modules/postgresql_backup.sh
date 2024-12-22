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
#              Backup function
####################################################

# resticprofile_configuration() {
# ### configure restic parameters using restic profile ###
#     log "checking if resticprofile is installed"
#     if [ ! -f "/usr/local/bin/resticprofile" ] ; then
#         log "resticprofile not found in '/usr/local/bin/resticprofile' "
#         log "installing restic profile from githubusercontent"
#         CURL_RESULT_CODE=$(curl -s -LO https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh -w %{http_code} --output-dir /tmp)
#         if [ "${CURL_RESULT_CODE}" = "200" ]; then
#             log "launching install script for restic profile"
#             chmod +x /tmp/install.sh
#             /tmp/install.sh -b /usr/local/bin 2>&1 >/dev/null
#         else
#             ELAPSED_TIME=$(( $(date +%s)-${START_TIME} ))
#             error "backup failure, caused by resticprofile installation fail in $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
#             error_exit "$?"
#         fi
#     else
#         log "resticprofile already installed"
#     fi

#     log "updating resticprofile"
#     resticprofile self-update >/dev/null

#     log "setting resticprofile configuration"
#     mkdir -p ${RESTICPROFILE_CONFIG_PATH}
#     ( [ -e "${RESTICPROFILE_CONFIG_PATH}/profile.yml" ] || cp ${WORKDIR}/resticprofile/profile.yml ${RESTICPROFILE_CONFIG_PATH}/profile.yml )
#     chmod 0700 ${RESTICPROFILE_CONFIG_PATH}/profile.yml
#     if [ -z ${RESTIC_PASSWORD+x} ] ; then
#         log "restic password not set by user, generate random key"
#         resticprofile generate --random-key ${RESTICPROFILE_PASSWORD_LENGTH} > ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}
#     else
#         log "setting user defined restic password to file ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}"
#         ## debug try to create pass file before updating content
#         touch ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}
#         echo ${RESTIC_PASSWORD} > ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}*
#         ## more debug
#         if [ $? -eq 0 ];then
#             log "touch and echo pass in file in success"
#         else
#             warn "touch and echo pass in file failure"
#         fi

#     fi
#     chmod 0600 ${RESTICPROFILE_CONFIG_PATH}/${RESTICPROFILE_PASSWORD_FILENAME}
# }

restic_configuration() {
### apply restic fonfiguration using restic init ###
    if [ ! -d "$RESTIC_REPOSITORY" ]; then
        restic init --repo $RESTIC_REPOSITORY
    fi
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
            log "postgresql dump process ended (in success) for Database : ${DB} in $(($PG_DUMP_ELAPSED_TIME/60)) min $(($PG_DUMP_ELAPSED_TIME%60)) sec"
            PG_DUMP_SUCCESS=true
        else
            ELAPSED_TIME=$(( $(date +%s)-${PG_DUMP_START_TIME} ))
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