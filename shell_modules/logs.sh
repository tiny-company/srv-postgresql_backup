#!/bin/bash

# ------------------------------------------------------------------
# - Filename: log.sh
# - Author: ottomatic
# - Dependency: None
# - Description: Shell module for logging
# - Creation date: 2024-11-18
# - Bash version: 5.2.15(1)-release
# ------------------------------------------------------------------

####################################################
#                    Parameters
####################################################

### color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE="\033[38;5;33m"
ORANGE="\033[38;5;208m"
NC='\033[0m' # No Color

####################################################
#                    Logs configuration
####################################################

validate_log_path() {
### create log path if writing to log file else create link to stdout ###
    if ! ${LOG_STD_OUTPUT} ; then
        mkdir -p ${LOG_DIR}
        ( [ -e "${LOG_FILE}" ] || touch "${LOG_FILE}" ) && [ ! -w "${LOG_FILE}" ] && error_exit "cannot write to ${LOG_FILE}"
        chown $(id -un) ${LOG_FILE}
    fi
}

warn() {
### log as warn level ###
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${ORANGE}WARN : $@ ${NC}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${ORANGE}WARN : $@ ${NC}" >> ${LOG_FILE}
    fi
}

error() {
### log as error level ###
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $@ ${NC}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $@ ${NC}" >> ${LOG_FILE}
    fi
}

log() {
### log as classic log level ###
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO : $@ ${NC}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO : $@ ${NC}" >> ${LOG_FILE}
    fi
}

error_exit() {
### log as error level and exit ###
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $1 ${NC}"
        exit 1
    else
        echo "Error: $1"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $1 ${NC}" >> ${LOG_FILE}
        exit 1
    fi
}
