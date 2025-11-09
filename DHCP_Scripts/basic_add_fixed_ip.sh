#!/bin/bash

FICHERO_CSV="$1" # varible que almacena el fichero
SERVER_RED="192.168.10" # variable que almacena el rango IP de Sala Servidores
DESKTOP_RED="192.168.20" # variable que almacena el rango IP de Puestos de Trabajo
WIRELESS_RED="192.168.30" # variable que almacena el rango IP de Redes Inalámbricas

# funcion para el inio del log
mostrar_log_inicio() {
    echo "================================================"
    echo "INICIO DEL SCRIPT DHCP"
    echo "================================================"
    echo "Hora de inicio: $(date)"
}

#funcion para el final del log
mostrar_log_final() {
    echo "================================================"
    echo "FIN DEL SCRIPT"
    echo "================================================"
}

# funciones para validar los campos que almacena
limpiar_nombre() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '/' '-'
}
limpar_mac() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' '
}
limpiar_ambito() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# funcion para definir que rango IP es para cada ambito
obtener_red_por_ambito() {
    case "$1" in
        "Server")
            echo "$SERVER_RED"
            ;;
        "Desktop")
            echo "$DESKTOP_RED"
            ;;
        "Wireless")
            echo "$WIRELESS_RED"
            ;;
        *)
            echo ""
            ;;
    esac
}

# funcion que encuentra las IPs ya asignadas y asigna la siguiente
encontrar_ip_disponible() {
    local net="$1"
    local ips_usadas=()
    
    while read -r ip; do
        ips_usadas+=( "$(echo "$ip" | awk -F. '{print $4}')" )
    done < <(grep -o "${net}\.[0-9]*" /etc/dhcp/dhcpd.conf) # process substition (pasa la salida de un comando al while read)
    
    for i in {2..250}; do
        if [[ ! " ${ips_usadas[*]} " =~ " $i " ]]; then # comprueba si el patron está dentro del array con las ips usadas
            echo "${net}.${i}"
            return
        fi
    done
}

# funcion para crear el bloque que se va a añadir en el .conf
insertar_host_en_ambito() {
    local nombre="$1" # primer parámetro es el nombre
    local ip="$2" # segundo parámetro la IP
    local mac="$3" # tercer parámetro que se le pase la MAC
    local net="$4" # cuarto parámetro el rango de red
    local ambito="$5" # quinto parámetro el ambito donde está

    local marcador_fin=$(obtener_marcador_fin "$ambito")

    local bloque_host="
host $nombre {
    hardware ethernet $mac;
    fixed-address $ip;
}
# ÚLTIMA_IP_${net}: ${ip}
"

    local temp_file=$(mktemp)
    while IFS= read -r linea; do
        if echo "$linea" | grep -q "$marcador_fin"; then
            echo "$bloque_host" >> "$temp_file"
        fi
        echo "$linea" >> "$temp_file"
    done < /etc/dhcp/dhcpd.conf

    mv "$temp_file" /etc/dhcp/dhcpd.conf
}

# funcion que comprueba si la mac existe
existe_mac() {
    grep -qi "hardware ethernet.*$1" /etc/dhcp/dhcpd.conf
}

# funcion que, si tiene un nombre igual, le añade un _num
encontrar_hostname_unico() {
    local nombre="$1"
    local contador=1
    local nuevo="$nombre"
    while grep -q "host $nuevo" /etc/dhcp/dhcpd.conf; do
        nuevo="${nombre}_${contador}"
        contador=$((contador + 1))
    done
    echo "$nuevo"
}

#------Inicio del script------
mostrar_log_inicio

# comprueba que se ha pasado un parámetro
if [ $# -ne 1 ]; then
    echo "Uso: $0 <fichero.csv>"
    exit 1
fi

# comprueba que lo que se ha pasado es un fichero
if [ ! -f "$FICHERO_CSV" ]; then
    echo "Error: el fichero $FICHERO_CSV no existe"
    exit 1
fi

# Crea una copia de seguridad
if [ -f "$FICHERO_CONF" ]; then
    cp "$FICHERO_CONF" "$FICHERO_BACKUP"
    echo "Copia de seguridad creada: $FICHERO_BACKUP"
    sleep 2
else
    echo "Error: El archivo de configuración $FICHERO_CONF no existe"
    exit 1
fi

# lee el csv saltando la primera línea
linea_num=0
while IFS=";" read -r nombre mac ambito; do
    linea_num=$((linea_num + 1))
    if [ "$linea_num" -eq 1 ]; then
        continue
    fi
    # limpia los nombres usando las funciones
    nombre_limpio=$(limpiar_nombre "$nombre")
    mac_limpia=$(limpar_mac "$mac")
    ambito_limpio=$(limpiar_ambito "$ambito")
    # verifica que los campos no estén vacíos
    if [ -z "$nombre_limpio" ] || [ -z "$mac_limpia" ] || [ -z "$ambito_limpio" ]; then 
        echo "Error: Campos vacíos en línea $linea_num. Saltando..." 
        continue 
    fi
    # verifica si la MAC existe
    if existe_mac "$mac_limpia"; then 
        echo "El host con MAC $mac_limpia ya existe. Saltando $nombre_base" 
        sleep 1 
        continue 
    fi
    # comprueba si el nombre existe, si sí, le da uno único
    nombre_unico=$(encontrar_hostname_unico "$nombre_limpio")
    if [ "$nombre_limpio" != "$nombre_unico" ]; then
        echo "Nota: El nombre '$nombre_limpio' ya existe, usando '$nombre_unico' en su lugar"
    fi
    # obtiene la red buscando por ambito
    net=$(obtener_red_por_ambito "$ambito_limpio")
    # comprueba que tenga ámbito mirando si está vacío
    if [ -z "$net" ]; then
        echo "Ámbito desconocido '$ambito_limpio'. Saltando $nombre_unico"
        sleep 1
        continue
    fi
    # busca la siguiente IP a asignar
    siguiente_ip=$(encontrar_ip_disponible "$net") # Se pasa el valor del ámbito encontrado y extrae últimos octetos
    # si no encuentra IP, lo salta
    if [ -z "$siguiente_ip" ]; then
        echo "No hay IPs disponibles en la subred $net. Saltando $nombre_limpio."
        sleep 1
        continue
    fi
    # si ha encontrado IP, inserta el host en el fichero y añade un registro al contador
    if insertar_host_en_ambito "$nombre_limpio" "$siguiente_ip" "$mac_limpia" "$net" "$ambito_limpio"; then
        echo "Añadido $nombre_limpio → $siguiente_ip en ámbito $ambito_limpio"
        REGISTROS_INSERTADOS=$((REGISTROS_INSERTADOS + 1))
    else
        echo "Error al añadir $nombre_limpio en ámbito $ambito_limpio"
    fi
# termina de leer el fichero
done < "$FICHERO_CSV"

# Muestra el LOG final
mostrar_log_final