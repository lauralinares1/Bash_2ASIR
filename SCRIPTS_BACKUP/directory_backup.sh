#!/bin/bash
DEBUG=0
SIMULATE="real"

FILE="/dev/null" 
LOG_FILE="/var/log/copia"
OPERATIONS="/opt/copia/operaciones"
DEFAULT_DEST="/opt/copia/listado" # directorio por defecto para operadorescopia y root

USER_TYPE="NO_ADMIN"
ADMIN_GROUP="operadorescopia"
USER_NAME=$(whoami)
USER_HOME="$HOME"

DATE=$(date +%d-%m-%Y)
TAR_NAME=""
ORIGIN_DIR=""
FINAL_DEST=""

function show_help() {
cat <<EOF
Uso: copia [opciones]

Opciones:
  -d, --directorio <ruta>   Directorio a copiar (obligatorio)
  --destino <ruta>          Directorio donde guardar la copia
  -s, --sim                 Modo simulación
  --debug                   Guarda errores en un log
  -h, --help                Muestra esta ayuda
EOF
exit 0
}
function get_group() { 
    if groups | grep -q $ADMIN_GROUP > $FILE 2>$FILE || groups | grep -q root > $FILE 2>$FILE; then
        USER_TYPE=$ADMIN_GROUP
    fi
}
function check_origin() {
    if [ ! -d "$ORIGIN_DIR" ]; then
        echo "ERROR. No existe el directorio de origen"
        exit 1
    fi
    if [ "$USER_TYPE" = "NO_ADMIN" ]; then
        if [[ "$ORIGIN_DIR" != "$USER_HOME" && "$ORIGIN_DIR" != "$USER_HOME"/* ]]; then
            echo "ERROR. Acción no válida"
            exit 1
        fi
    fi
}
function build_tar_name() {
    DIR_OWNER=$(basename "$ORIGIN_DIR")
    TAR_NAME="${DIR_OWNER}_${DATE}.tar.gz"
}
function do_copia() {
    find_cmd=$(eval grep '^$USER_TYPE,copia,$SIMULATE' $OPERATIONS)
    command=$(echo $find_cmd | cut -f4 -d",")
    eval $command
}
OPTS=$(getopt -o d:hs --long directorio:,help,destino:,debug,simulate -n'copia' -- "$@")
if [ $? -ne 0 ]; then
    echo "Error al analizar opciones"
    exit 1
fi
eval set -- "$OPTS"
while true; do
    case "$1" in
        -d|--directorio)
            ORIGIN_DIR="$2"
            shift 2
            ;;
        --destino)
            FINAL_DEST="$2"
            shift 2
            ;;
        -s|--simulate)
            SIMULATE="simulate"
            shift
            ;;
        --debug)
            DEBUG=1
            FILE="$LOG_FILE-$(date +%d-%m-%Y-%H-%M)"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error interno."
            exit 1
            ;;
    esac
done

get_group
check_origin
build_tar_name

if [ "$USER_TYPE" = "$ADMIN_GROUP" ]; then
    if [ -z "$FINAL_DEST" ]; then
        FINAL_DEST=$DEFAULT_DEST
    fi
    FINAL_DEST_NAME="$FINAL_DEST/$TAR_NAME"
    do_copia
else
    FINAL_DEST_NAME="$USER_HOME/listado/$TAR_NAME"
    do_copia
fi