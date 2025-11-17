#!/bin/bash
DEBUG=0
SIMULATE="real" 

FILE="/dev/null" 
LOG_FILE="/var/log/copia" # destino de los log
OPERATIONS="/opt/copia/operaciones" # fichero con las operaciones
DEFAULT_DEST="/opt/copia/listado" # directorio por defecto para operadorescopia y root

USER_TYPE="NO_ADMIN" # por defecto, el usuario será NO_ADMIN salvo que cumpla con las condiciones de pertenencia a grupo o root
ADMIN_GROUP="operadorescopia" # grupo con permisos para copiar
USER_NAME=$(whoami) # comando para detectar quién es el usuario que lo ejecuta -- guardado en variable
USER_HOME="$HOME" # comando que dice el directorio HOME del usuario -- guardado en variable

DATE=$(date +%d-%m-%Y) # date para el nombre del tar con la sintaxis deseada
TAR_NAME="" # definicion del nombre tar -- varío
ORIGIN_DIR="" # directorio de origen -- vacío
FINAL_DEST="" # directorio de destino final -- vacío

function show_help() { # función para mostrar ayuda
cat <<EOF
Uso: copia [opciones]

Opciones:
  -d, --directorio <ruta>   Directorio a copiar (obligatorio)
  -D, --destino <ruta>      Directorio donde guardar la copia
  -s, --simulate            Modo simulación
  --debug                   Guarda errores en un log
  -h, --help                Muestra esta ayuda
EOF
exit 0
}
function get_group() { # función para determinar si el usuario que ejecuta es un ADMIN o NO_ADMIN
    if groups | grep -q $ADMIN_GROUP > $FILE 2>$FILE || groups | grep -q root > $FILE 2>$FILE; then
        USER_TYPE=$ADMIN_GROUP
    fi
}
function check_origin() { # función para averiguar si hay un directorio de origen especificado (obligatorio), si existe y si se está cumpliendo la regla de control sobre los directorios a copiar
    if [ -z "$ORIGIN_DIR" ]; then
        echo "ERROR. Debe especificar un directorio de origen con -d"
        exit 1
    fi
    if [ ! -d "$ORIGIN_DIR" ]; then
        echo "ERROR. No existe el directorio de origen: $ORIGIN_DIR"
        exit 1
    fi
    if [ "$USER_TYPE" = "NO_ADMIN" ]; then
        if [[ "$ORIGIN_DIR" != "$USER_HOME" && "$ORIGIN_DIR" != "$USER_HOME"/* ]]; then
            echo "ERROR. Acción no válida. No puede copiar directorios fuera de su home: $USER_HOME"
            exit 1
        fi
    fi
}
function build_tar_name() { # función para construir el nombre del tar
    DIR_OWNER=$(basename "$ORIGIN_DIR")
    TAR_NAME="${DIR_OWNER}_${DATE}.tar.gz"
}
function do_copia() { # función para buscar la operación en el fichero y ejecutarla
    find_cmd=$(eval grep "^$USER_TYPE,copia,$SIMULATE" $OPERATIONS)
    command=$(echo $find_cmd | cut -f4 -d",")
    if [ $SIMULATE == "simulate" ]; then
        eval $command # si está en modo simulacion, muestra la salida
    else
        eval $command > $FILE 2> $FILE # si no, manda la salida a FILE
    fi
}
OPTS=$(getopt -o d:D:sh --long directorio:,destino:,simulate,help,debug -n 'copia' -- "$@")
if [ $? -ne 0 ]; then
    echo "Error al analizar opciones"
    exit 1
fi
eval set -- "$OPTS"
while true; do
    case "$1" in
        -d | --directorio)
            ORIGIN_DIR="$2"
            shift 2
            ;;
        -D | --destino)
            FINAL_DEST="$2"
            shift 2
            ;;
        -s | --simulate)
            SIMULATE="simulate"
            shift
            ;;
        --debug)
            DEBUG=1
            FILE="$LOG_FILE-$(date +%d-%m-%Y-%H-%M)"
            shift
            ;;
        -h | --help)
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
if [ "$DEBUG" -eq 1 ]; then # si está en modo debug, los errores pasan al fichero log con la fecha del dia y hora y min
    FILE="$LOG_FILE-$(date +%d-%m-%Y-%H-%M)"
fi

get_group
check_origin
build_tar_name

if [ "$USER_TYPE" = "$ADMIN_GROUP" ]; then
    if [ -z "$FINAL_DEST" ]; then
        FINAL_DEST=$DEFAULT_DEST # si no ha especificado destino final, es el de por defecto
    fi
    if [ ! -e "$FINAL_DEST" ]; then
        sudo mkdir -p $FINAL_DEST > $FILE 2>$FILE # si no existe el directorio de destino, lo crea
    fi
    FINAL_DEST_NAME="$FINAL_DEST/$TAR_NAME"
    do_copia
else
    FINAL_DEST="$USER_HOME/listado"
    if [ ! -d "$FINAL_DEST" ]; then
        mkdir $FINAL_DEST > $FILE 2>$FILE
        chmod 770 $FINAL_DEST > $FILE 2>$FILE
    fi
    FINAL_DEST_NAME="$USER_HOME/listado/$TAR_NAME"
    do_copia
fi