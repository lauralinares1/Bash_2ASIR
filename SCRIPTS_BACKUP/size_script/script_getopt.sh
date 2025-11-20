#!/bin/bash

# Declaración de variables
HTML_START="<html><head><title>Lista de archivos</title></head><body>"
HTML_END="</body></html>"
FILE="/var/www/html/pagina.html"
ACTION=""
SIZE="900"
T_DIR_SIZE="" # variable para el tamaño total en b
T_DIR_SIZE_KB="" # variable para el tamaño total en kb
contador=0

# Declaración de funciones
show_help(){
    cat << EOF
Uso: $0 [opciones]

Opciones:
  -o, --output <archivo>      Nombre del fichero HTML que se generará.
  -d, --directories           Mostrar el tamaño de cada directorio dentro de /home/usuario (formato humano).
  -a, --all-files             Mostrar el tamaño de todos los archivos dentro de /home/usuario.
  -t, --total                 Mostrar el espacio total ocupado en porcentaje.
  -s, --size <tamaño>         Tamaño máximo en KB para calcular porcentaje (por defecto 900 KB).
  -h, --help                  Mostrar ayuda del script.
EOF
    exit 0
}

print_cmd(){
    echo "<ul>" >> $FILE
    for elemento in $CMD
    do
        modulo=$(echo "$contador%2" | bc)
        if [ $modulo -eq 0 ]; then
            echo "<li> $elemento" >> $FILE
        else
            echo "$elemento </li>" >> $FILE
        fi
        contador=$(echo "$contador+1" | bc)
    done
    echo "</ul>" >> $FILE
}

# Parseo de opciones con getopt
OPTIONS=$(getopt -o ho:dats: --long help,output:,directories,all-files,total,size: -n 'script' -- "$@")
if [ $? -ne 0 ]; then
  echo "Error al analizar opciones" >&2
  exit 1
fi
eval set -- "$OPTIONS"

while true; do
    case "$1" in
        -h | --help)
            show_help
            ;;
        -o | --output)
            FILE="$2"
            shift 2
            ;;
        -d | --directories)
            ACTION="directories"
            shift
            ;;
        -a | --all-files)
            ACTION="all_files"
            shift
            ;;
        -t | --total)
            ACTION="total_space"
            shift
            ;;
        -s | --size)
            SIZE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error interno"
            exit 1
            ;;
    esac
done

# Creación del HTML
echo "$HTML_START" > "$FILE"

if [ "$ACTION" == "directories" ]; then
    CMD=$(du -d 1 -h /home/usuario)
    print_cmd
elif [ "$ACTION" == "all_files" ]; then
    CMD=$(du -ah /home/usuario/*)
    print_cmd
elif [ "$ACTION" == "total_space" ]; then
    T_DIR_SIZE=$(du -cb /home/usuario | tail -1 | cut -f1) # me da el tamaño total del dir en bytes
    T_DIR_SIZE_KB=$(echo "$T_DIR_SIZE/1024" | bc) # transforma el tamaño total del dir a kb
    SIZE_OCCUPIED=$(echo "($T_DIR_SIZE_KB*100)/$SIZE" | bc) # se calcula el espacio que ocupa en comparación con el SIZE
    echo "<p> El espacio ocupado por el usuario es del $SIZE_OCCUPIED % ($T_DIR_SIZE_KB KB) de los $SIZE KB disponibles </p>" >> $FILE
fi

echo "$HTML_END" >> "$FILE"