#!/bin/bash

#title           :logs.sh
#description     :Shell module for logging
#author		     :ottomatic
#creation date   :2024-11-18
#bash_version    :5.2.15(1)-release
#==============================================================================


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

warn() {
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${ORANGE}WARN : $@ ${NC}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${ORANGE}WARN : $@ ${NC}" >> ${LOG_FILE}
    fi
}

error() {
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $@ ${NC}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $@ ${NC}" >> ${LOG_FILE}
    fi
}

log() {
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO : $@ ${NC}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO : $@ ${NC}" >> ${LOG_FILE}
    fi
}

error_exit() {
    if ${LOG_STD_OUTPUT}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $1 ${NC}"
        exit 1
    else
        echo "Error: $1"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR : $1 ${NC}" >> ${LOG_FILE}
        exit 1
    fi
}
