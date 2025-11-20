#!/bin/bash

# Parámetros que debe tener:
# -o nombre del fichero que debe generar.
# -d sólo muestra el tamaño (en formato humano) de cada directorio dentro del directorio
# /home/usuario.
# -a muestra para cada directorio dentro de /home/usuario, el tamaño de todos los archivos
# que tiene,
# -t genera el espacio total que ocupan los archivos en %, el tamaño total máximo será
# especificado en la opción s.
# -s define el tamaño máximo de disco que debe ocupar como mucho el espacio de usuario
# en /home/usuario, si no se especifica esta opción el tamaño será 900KBytes.
# Para crear el conjunto de parámetros usa “getopt”, para obtener el tamaño en disco usa
# “du”.
HTML_START="<html><head><title>Lista de archivos</title></head><body>"
HTML_END="</body></html>"
FILE="/var/www/html/pagina.html"
ACTION=""
SPECIFIED_SIZE=""
SIZE="900"
contador=0
suma=0

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

echo $HTML_START > $FILE

if [ "$ACTION" == "directories" ]; then
    CMD=$(du -d 1 -h /home/usuario)
    print_cmd
elif [ "$ACTION" == "all_files" ]; then
    CMD=$(du -ah /home/usuario/*)
    print_cmd
elif [ "$ACTION" == "total_space" ]; then
    suma=$(du -cb | tail -1 | cut -f1) # me da el tamaño total en bytes
    SIZE=$(echo "$SIZE*1024" | bc) # pasa el tamaño a bytes para que todo esté igual
    SPACE_OCCUPIED=$(echo "($suma*100)/$SIZE" | bc) # se calcula el espacio que ocupa
    echo "<p> El espacio ocupado por el usuario es del $SPACE_OCCUPIED % de los $SIZE disponibles </p>" >> $FILE
elif [ "$ACTION" == "total_specified" ]
    suma=$(du -cb | tail -1 | cut -f1) # me da el tamaño total en bytes
    SIZE=$SPECIFIED_SIZE
    SIZE=$(echo "$SIZE*1024" | bc) # pasa el tamaño a bytes para que todo esté igual
    SPACE_OCCUPIED=$(echo "($suma*100)/$SIZE" | bc)
    echo "<p> El espacio ocupado por el usuario es del $SPACE_OCCUPIED % de los $SIZE disponibles </p>" >> $FILE
else
    echo "Error"
fi

echo $HTML_END >> $FILE