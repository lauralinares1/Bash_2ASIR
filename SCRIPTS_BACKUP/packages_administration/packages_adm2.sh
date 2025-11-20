#! /bin/bash
#---------------------------------
# Archivo: packages_adm.sh
# Autor: Laura Linares
# Version: 3.1
#---------------------------------
# Uso: crea directorios, descarga y descomprime ficheros pasados mediante enlace,
# comprime una carpeta de trabajo para crear una copia de seguridad y recupera
# copias de segurdad realizadas previamente en el directorio de trabajo especificado
#---------------------------------

# Carga funciones personalizadas para log
. /lib/myfunctions/log_functions.sh

# Declaración de funciones
usage() {
    cat << EOF
$0: $0 [opción] [argumento]

    Crea directorios de trabajo en /opt.
    Descarga y descomprime archivos pasados mediante enlace.
    Cierra un directorio de trabajo creando una copia de seguridad en /usr/local/lib
    Recupera y descomprime un directorio de trabajo previamente cerrado

    Opciones:
        [obligatorio]   -a | --accion       indica la acción que debe realizar este script entre las disponibles

        [obligatorio]   -d | --directorio   indica el directorio con el que se va a trabajar

                        -e | --enlace       enlace desde el que se descargará el fichero comprimido

                        -h | --help         proporciona este mensaje de ayuda
    
    Los log se guardarán en un fichero ubicado en /var/log/scripts_laura.sh
EOF
    exit 1
}

last_error_control() {
    #Controla que el último proceso haya sido exitoso
    if [ $? -eq 0 ]; then
        log_success "La acción se ha completado sin fallos"
    else
        log_error "Ha ocurrido un error durante la ejecución de esta acción"
        exit 1
    fi
}

check_accion() {
    if [ -z "$accion" ]; then
        log_info "Debe especificarse una acción con -a o --accion" >&2
        usage
    fi
}

check_directorio() {
    if [ -z "$directorio" ]; then
        log_info "Para esta acción debe especificarse el nombre de un directorio con -d o --directorio" >&2
        usage
    fi
}

check_enlace() {
    if [ -z "$enlace" ]; then
        log_info "Para esta acción debe especificarse un enlace para la descarga con -e o --enlace" >&2
        usage
    fi
}

# Declaración de variables
accion=""
enlace=""
directorio=""

#----------------------Inicio del script----------------------
    # Analiza opciones de línea de comandos
OPTS=$(getopt -o a:e:d:h --long accion:,enlace:,directorio:,help -- "$@")

if [ $? -ne 0 ]; then
    log_info "No se han podido analizar las opciones proporcionadas" >&2
    usage
fi

eval set -- "$OPTS"

    # Procesa las opciones
while true; do
    case "$1" in
        -a | --accion)
            accion="$2"
            shift 2
            ;;
        -e | --enlace)
            enlace="$2"
            shift 2
            ;;
        -d | --directorio)
            directorio="$2"
            shift 2
            ;;
        -h | --help)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Se ha producido un error interno"
            exit 1
            ;;
    esac
done

    # Controla que se pasen las opciones obligatorias
check_accion
check_directorio

    # Manejo de las distintas opciones
case "$accion" in
    nueva | nuevaconfig | nuevaconfiguracion)
            # Comprueba si el directorio existe
        if [ -d "/opt/$directorio" ]; then
            log_error "El directorio que está intentando crear ya existe"
            exit 1
        fi
            # Crea el directorio
        sudo mkdir /opt/$directorio
            # Comprueba errores en la ejecución
        last_error_control
        ;;
    descargar)
            # Comprueba que se ha pasado un enlace
        check_enlace
            # Comprueba si existe el directorio donde desea descargar
        if [ -d "/opt/$directorio" ]; then
            # Comprueba que los paquetes necesarios estén instalados
            for i in wget gzip bzip2; do
                if ! command -V "$i" &>/dev/null; then
                    log_info "Instalando $i"
                    sudo apt-get update -qq &>/dev/null
                    sudo apt-get install -y -qq "$i" &>/dev/null
                fi
            done
                # Obtiene el nombre del fichero desde la URL
            fichero=$(basename "$enlace")
                # Almacena en una variable la ruta que tendría el fichero
            ruta_fichero="/opt/$directorio/$fichero"
                # Comprueba si el fichero ya existe
            if [ -f "$ruta_fichero" ]; then
                log_error "El fichero que intenta descargar ya existe en ese directorio"
                exit 1
            fi
                # Descarga el archivo en el directorio
            sudo wget -q -P "/opt/$directorio" "$enlace"
                # Comprueba que el archivo descargado existe
            if [ ! -f "$ruta_fichero" ]; then
                log_error "No se ha encontrado el archivo descargado"
                exit 1
            fi
                # Lo descomprime
            if [[ "$fichero" == *.tar.gz ]]; then
                sudo tar -xzf "$ruta_fichero" -C "/opt/$directorio"
            elif [[ "$fichero" == *.tar.bz2 ]]; then
                sudo tar -xjf "$ruta_fichero" -C "/opt/$directorio"
            else
                log_error "Archivo descargado, pero no es .tar.gz ni .tar.bz2 -- No se ha podido descomprimir"
                exit 1
            fi
                # Comprueba errores en la ejecución
            last_error_control
        else
            log_error "El directorio indicado no existe. Debe crearlo primero para poder descargar contenido en él"
            exit 1
        fi
        ;;
    cerrar)
        if [ -d "/opt/$directorio" ]; then
                # Crea el nombre que tendrá el archivo con la fecha del momento en que se ejecuta la acción
            nombre_archivo="${directorio}_$(date +%Y_%m_%d).tar.gz"
            dir_destino="/usr/local/lib"
                # Comprime el archivo en el directorio de destino
            sudo tar -czf "$dir_destino/$nombre_archivo" -C "/opt" "$directorio"
                # Comprueba errores en la ejecución
            last_error_control
        else
            log_error "El directorio indicado no existe"
            exit 1
        fi
        ;;
    recuperar)
            # Busca la o las copias que haya con el nombre especificado
        copias=$(find /usr/local/lib -maxdepth 1 -type f -name "$directorio*")
            # Controla la existencia de alguna copia de seguridad
        if [ -z "$copias" ]; then
            log_error "No existe ninguna copia de seguridad de esa configuración"
            exit 1
        else
                # Comprueba si existe el directorio donde se va a recuperar
            if [ ! -d "/opt/$directorio" ]; then
                log_info "No existe el directorio de destino. Se va a crear para poder continuar"
                sudo mkdir "/opt/$directorio"
            fi
                # Ordena las copias y coge solo la última
            archivo=$(echo $copias | tr " " "\n" | sort -nr | head -1)
                # Borra el contenido del directorio de destino
            destino="/opt/$directorio"
            sudo rm -r $destino/*
                # Extrae el contenido en el directorio de destino
            sudo tar -xzf "$archivo" -C "/opt/$directorio"
                # Comprueba errores en la ejecución
            last_error_control
        fi
        ;;
    *)
        log_error "La acción que ha introducido no ha sido encontrada"
        ;;
esac