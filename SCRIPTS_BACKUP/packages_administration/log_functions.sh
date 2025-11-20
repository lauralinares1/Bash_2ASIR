#!/bin/bash
#-------------------------------------------
# Archivo: /lib/myfunctions/log_functions.sh
#   Autor: Laura Linares
# Descripción: Librería de funciones de log personalizadas
#-------------------------------------------

# Declaracion de variables
LOGFILE="/var/log/scripts_laura.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NC='\033[0m'

# Funcion que cambia el .log donde se almacenarán los logs
set_logfile() {
    LOGFILE="$1"
}

# Función para que salga el mensaje por pantalla y que se escriba en el .log
_log() {
    local type="$1"
    local color="$2"
    local message="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H:%M:%S')

    # Salida por pantalla
    echo "${color}[$timestamp] [$type] $message${NC}"

    # Escritura en .log
    echo "[$timestamp] [$type] $message" >> "$LOGFILE"
}

# Funciones con los distintos logs posibles
log_success() {
    _log "OK" "$GREEN" "$1";
}
log_error() {
    _log "ERROR" "$RED" "$1";
}
log_info() {
    _log "INFO" "$BLUE" "$1";
}