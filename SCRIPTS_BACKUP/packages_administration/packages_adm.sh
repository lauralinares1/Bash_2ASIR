#! /bin/bash

#----Author:LauraLinares-----
#---------Version:4.2--------
#---Script:packages_adm.sh---
#--Uso 1. script.sh nuevaconfiguracion nombre_de_la_nueva_configuracion
#---------por defecto usará el directorio /opt
#---------creará un directorio dentro del directorio por defecto

#--Uso 2. script.sh descargar directorio_donde_descargar enlace
#---------descargará y descomprimirá el enlace en el directorio

#--Uso 3. script.sh cerrar nombre_de_la_configuracion
#---------comprimirá lo existente en el directorio especificado y
#---------guadará dicho paquete comprimido en /opt/lib haciendo una
#---------copia de seguridad en /usr/local/lib

#--Uso 4. script.sh recuperar nombre_de_la_configuracion
#---------desempaquetará la copia de seguridad especificada y la
#---------copiará en el directorio /opt, eliminando lo que hubiese

#------Inicio del script-----

    #Controla que se pase mínimo 1 parámetro
if [ $# -eq 0 ]; then
    echo "Error, no se ha pasado ningún parámetro"
    echo "Uso de $0: <script><acción><opciones>"
    exit 1
fi

#--Uso 1. script.sh nuevaconfiguracion nombre_de_la_nueva_configuracion--
if [ "$1" = "nuevaconfiguracion" ]; then
        #Controla que se hayan pasado los parámetros necesarios
    if [ $# -ne 2 ]; then
        echo "Error, no se han pasado los parámetros correctos"
        echo "Uso 1 de $0: <script> <nuevaconfiguracion> <nombre_de_la_nueva_configuracion>"
        exit 1
    fi
    directorio="$2"

        

#--Uso 2. script.sh descargar directorio_donde_descargar enlace--
elif [ "$1" = "descargar" ]; then
        #Controla que se hayan pasado los parámetros necesarios
    if [ $# -ne 3 ]; then
        echo "Error, no se han pasado los parámetros determinados"
        echo "Uso 2 de $0: <script> <descargar> <directorio_donde_descargar> <enlace>"
        exit 1
    fi
    directorio="$2"
    enlace="$3"

        #Comprueba si existe el directorio donde desea descargar
    if [ -d "/opt/$directorio" ]; then
            #Comprueba que los paquetes necesarios estén instalados
        for i in wget gzip bzip2; do
            if ! command -V "$i" >/dev/null 2>&1; then
                echo "Instalando $i"
                sudo apt-get update -qq
                sudo apt-get install -y -qq "$i"
            fi
        done

            #Obtiene el nombre del archivo desde la URL
        archivo=$(basename "$enlace")
        

            #Descarga el archivo en el directorio
        sudo wget -q -P "/opt/$directorio" "$enlace"

            #Controla que el último proceso haya sido exitoso
        if [ $? -eq 0 ]; then
            echo "El archivo ha sido descargado con éxito"
        else
            echo "Error en la descarga"
            exit 1
        fi

        ruta_archivo="/opt/$directorio/$archivo"

            #Comprueba que el archivo descargado existe
        if [ ! -f "$ruta_archivo" ]; then
            echo "Error, no se ha encontrado el archivo descargado $archivo"
            exit 1
        fi

            #Lo descomprime
        if [[ "$archivo" == *.tar.gz ]]; then
            sudo tar -xzf "$ruta_archivo" -C "/opt/$directorio"
        elif [[ "$archivo" == *.tar.bz2 ]]; then
            sudo tar -xjf "$ruta_archivo" -C "/opt/$directorio"
        else
            echo "Archivo descargado, pero no es .tar.gz ni .tar.bz2"
            echo "No se ha podido descomprimir"
            exit 1
        fi

            #Controla que el último proceso haya sido exitoso
        if [ $? -eq 0 ]; then
            echo "El archivo ha sido descomprimido con éxito"
        else
            echo "Error durante la descompresión"
            exit 1
        fi

    else
        echo "Error, el directorio no existe. Créelo primero"
        echo "Para crearlo puede usar el USO 1 de este script"
        exit 1
    fi

#--Uso 3. script.sh cerrar nombre_de_la_configuracion--
elif [ "$1" = "cerrar" ]; then
        #Controla que se hayan pasado los parámetros necesarios
    if [ $# -ne 2 ]; then
        echo "Error, no se han pasado los parámetros determinados"
        echo "Uso 3 de $0: <script> <cerrar> <nombre_de_la_configuracion>"
        exit 1
    fi
    directorio="$2"

        #Comprueba si existe el directorio donde desea descargar
    if [ -d "/opt/$directorio" ]; then
        nombre_archivo="${destino}_$(date +%Y_%m_%d).tar.gz"
        dir_destino="/usr/local/lib"

            #Crea el archivo en el directorio de destino
        sudo tar -czf "$dir_destino/$nombre_archivo" -C "/opt" "$directorio"

        if [ $? -eq 0 ]; then
            echo "La compresión y copia de seguridad se han realizado con éxito"
            echo "Esta se encuentra en $dir_destino y su nombre es: $nombre_archivo"
        else
            echo "Error. Ha fallado la creación de la copia de seguridad"
            exit 1
        fi

    else
        echo "Error, el directorio $directorio no existe"
        exit 1
    fi

#--Uso 4. script.sh recuperar nombre_de_la_configuracion--
elif [ "$1" = "recuperar" ]; then
        #Controla que se hayan pasado los parámetros necesarios
    if [ $# -ne 2 ]; then
        echo "Error, no se han pasado los parámetros determinados"
        echo "Uso 4 de $0: <script> <recuperar> <nombre_de_la_configuracion>"
        exit 1
    fi

    nombre_conf=$2

        #Busca la o las copias que haya con ese nombre
    copias=$(find /usr/local/lib -maxdepth 1 -type f -name "$nombre_conf*")

        #Controla la existencia de alguna copia de seguridad
    if [ -z "$copias" ]; then
        echo "Error, no existe ninguna copia de seguridad sobre esa configuración"
        exit 1
    else
            #Comprueba si existe el directorio donde se va a recuperar
        if [ ! -d "/opt/$nombre_conf" ]; then
            echo "Error, no existe el directorio $nombre_conf y no se podrá guardar la copia de seguridad allí"
            echo "Creelo usando el USO 1 de este script"
            exit 1
        fi

            #Ordena las copias y coge solo la última
        archivo=$(echo $copias | tr " " "\n" | sort -nr | head -1)

            #Borra el contenido del directorio de destino
        destino="/opt/$nombre_conf"
        sudo rm -r $destino/*

            #Extrae el contenido en el directorio de destino
        sudo tar -xzf "$archivo" -C "/opt/$nombre_conf"

            ##Controla que el último proceso haya sido exitoso
        if [ $? -eq 0 ]; then
            echo "La copia de seguridad ha sido recuperada con éxito"
        else
            echo "Error durante la recuperación"
            exit 1
        fi
    fi
fi