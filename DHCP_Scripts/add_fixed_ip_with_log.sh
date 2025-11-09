#!/bin/bash
#---------------------------Autor:LauraLinares--------------------------
#------------------------------Version:V4.2-----------------------------
#--------------------Script:add_fixed_ip_with_log.sh--------------------
#
#--Uso: Script para añadir hosts con IP fija a dhcpd.conf desde un .CSV-
#--con el siguiente formato: nombre;mac;ámbito que mostrará por pantalla
#--un mensaje log con toda la información recolectada sobre lo que se ha
#--hecho durante la ejecución del mismo y esta información se guardará--
#--en un fichero .log ubicado en la misma carpeta que el script---------

#------Declaraciones-------
FICHERO_CONF="/etc/dhcp/dhcpd.conf"
FICHERO_BACKUP="${FICHERO_CONF}_$(date +%Y%m%d_%H%M%S).bak"
FICHERO_CSV="$1"

#----Variables para el LOG----
HORA_INICIO=$(date +"%Y-%m-%d %H:%M:%S")
REGISTROS_INSERTADOS=0 # Contador que irá almacenando todos los registros que se inserten para el mensaje final

# Redes por ámbito definidos en variables cuyo valor es la parte base de la red según cada ámbito
SERVER_RED="192.168.10"
DESKTOP_RED="192.168.20"
WIRELESS_RED="192.168.30"

#------Funciones de LOG------
mostrar_log_inicio() {
    echo "================================================"
    echo "           INICIO DEL SCRIPT DHCP"
    echo "================================================"
    echo "Hora de inicio: $HORA_INICIO"
    echo "Archivo CSV: $FICHERO_CSV"
    echo "Archivo configuración: $FICHERO_CONF"
    echo "================================================"
    echo ""
}

mostrar_log_final() {
    local hora_fin=$(date +"%Y-%m-%d %H:%M:%S")
    local inicio_segundos=$(date -d "$HORA_INICIO" +%s) # Se pasa el inicio a seg para la posterior comparación
    local fin_segundos=$(date +%s) # Se pasa el fin a seg para la posterior comparación
    local duracion=$((fin_segundos - inicio_segundos)) # Comparación para ver cuánto a durado el script
    
    echo ""
    echo "================================================"
    echo "                 RESUMEN FINAL                  "
    echo "================================================"
    echo "Hora de inicio: $HORA_INICIO"
    echo "Hora de finalización: $hora_fin"
    echo "Duración total: ${duracion} segundos"
    echo "Registros insertados: $REGISTROS_INSERTADOS"
    echo ""
    echo "================================================"
    
    # Version breve para añadirla a un .log
    echo "$(date '+%Y-%m-%d %H:%M:%S') -- El script ha finalizado -- Registros insertados: $REGISTROS_INSERTADOS -- Duración: ${duracion}s" >> dhcp_script_add_fixed_ip.log
}

#------Otras funciones------
obtener_red_por_ambito() {
    local ambito="$1" # Se asigna el valor del parámetro pasado junto con la función
    case "$ambito" in
        "Server") echo "$SERVER_RED" ;;
        "Desktop") echo "$DESKTOP_RED" ;;
        "Wireless") echo "$WIRELESS_RED" ;;
        *) echo "" ;;
    esac
}
# Función para encontrar la linea de end segun el ámbito
obtener_marcador_fin() {
    local ambito="$1"
    case "$ambito" in
        "Server") echo "#ENDSERVER" ;;
        "Desktop") echo "#ENDDESKTOP" ;;
        "Wireless") echo "#ENDWIRELESS" ;;
        *) echo "" ;;
    esac
}

#------Funciones principales------
encontrar_hostname_unico() {
    local nombre_original="$1"
    local nombre_prueba="$nombre_original"
    local contador=1
    local temp_file=$(mktemp)
    
    # Buscar hosts existentes
    grep "host[[:space:]].*{" "$FICHERO_CONF" | sed 's/.*host[[:space:]]*\([^[:space:]{]*\).*/\1/' > "$temp_file"
    
    # Verificar si el nombre existe
    while IFS= read -r host_existente; do
        if [ "$host_existente" = "$nombre_prueba" ]; then # Verifica si existe el nombre en el fichero conforme lo va leyendo
            nombre_prueba="${nombre_original}_${contador}"
            contador=$((contador + 1))
            continue
        fi
    done < "$temp_file"
    
    rm -f "$temp_file" # Borra el archivo temporal
    echo "$nombre_prueba"
}

# Función para extraer el último octeto de la IP
extraer_ultimo_octeto() {
    local ip="$1"
    echo "$ip" | awk -F. '{print $4}' # Se divide la IP por puntos y se imprime solo el cuarto campo
}

# Función para encontrar la última IP disponible
encontrar_ip_disponible() {
    local net="$1"
    local temp_file=$(mktemp)
    local ips_usadas=""
    
    # Buscar IPs en linea fixed-address
    grep "fixed-address.*${net}\." "$FICHERO_CONF" | while IFS= read -r line; do
        # Extraer IP
        local ip=$(echo "$line" | grep -o "${net}\.[0-9]*" | head -1)
        if [ -n "$ip" ]; then
            local octeto=$(extraer_ultimo_octeto "$ip")
            echo "$octeto" >> "$temp_file"
        fi
    done
    
    # Buscar IPs en comentarios
    grep "ÚLTIMA_IP_.*${net}\." "$FICHERO_CONF" | while IFS= read -r line; do
        local ip=$(echo "$line" | grep -o "${net}\.[0-9]*" | head -1)
        if [ -n "$ip" ]; then
            local octeto=$(extraer_ultimo_octeto "$ip")
            echo "$octeto" >> "$temp_file"
        fi
    done
    
    # Buscar la primera IP disponible
    for i in $(seq 2 250); do
        if ! grep -q "^$i$" "$temp_file" 2>/dev/null; then # -q modo Quiet y con 2>/dev/null se suprimen posibles errores
            rm -f "$temp_file"
            echo "${net}.${i}"
            return
        fi
    done
    
    rm -f "$temp_file"
    echo ""
}

# Función para comprobar si ya existe la MAC
existe_mac() {
    local mac="$1"
    local mac_minusculas=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
    
    if grep -q "hardware ethernet.*$mac_minusculas" "$FICHERO_CONF"; then
        return 0
    else
        return 1
    fi
}

# Función para introducir host en el .conf
insertar_host_en_ambito() {
    local nombre="$1"
    local ip="$2"
    local mac="$3"
    local net="$4"
    local ambito="$5"
    
    local marcador_fin=$(obtener_marcador_fin "$ambito")
    
    if [ -z "$marcador_fin" ]; then
        echo "Error: Ámbito desconocido '$ambito'"
        return 1
    fi
    
    if ! grep -q "$marcador_fin" "$FICHERO_CONF"; then
        echo "Error: No se encontró el marcador $marcador_fin"
        return 1
    fi
    
    # Crear archivo temporal
    local temp_file=$(mktemp)
    local bloque_host="
host $nombre {
    hardware ethernet $mac;
    fixed-address $ip;
}
# ÚLTIMA_IP_${net}: ${ip}
"
    
    # Insertar antes del marcador de fin
    local encontrado=0
    while IFS= read -r linea; do
        if [ "$encontrado" -eq 0 ] && echo "$linea" | grep -q "$marcador_fin"; then
            echo "$bloque_host" >> "$temp_file" # Escribe el host en un archivo temporal
            encontrado=1
        fi
        echo "$linea" >> "$temp_file" # Tras el host, escribe de nuevo la línea #END[AMBITO]
    done < "$FICHERO_CONF"
    
    # Reemplazar archivo original
    mv "$temp_file" "$FICHERO_CONF"
    return 0
}

# Función para limpiar el nombre de caracteres raros
limpiar_nombre() {
    local nombre="$1"
    # Convertir a minúsculas
    nombre=$(echo "$nombre" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '/' '-')
    local nombre_limpio="$nombre"
    
    echo "$nombre_limpio"
}

# Función para limpiar la MAC
limpiar_mac() {
    local mac="$1"
    # Convertir a minúsculas y quitar espacios
    echo "$mac" | tr '[:upper:]' '[:lower:]' | tr -d ' '
}

# Función para limpiar el ámbito
limpiar_ambito() {
    local ambito="$1"
    # Solo quitar espacios al principio y final
    echo "$ambito" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

#------Inicio del script------
mostrar_log_inicio

# Comprueba el número de argumentos
if [ $# -ne 1 ]; then
    echo "Uso: $0 <fichero.csv>"
    echo "El fichero .csv deberá tener el siguiente formato: nombre;mac;ámbito"
    sleep 2
    exit 1
fi

# Comprueba que el fichero existe
if [ ! -f "$FICHERO_CSV" ]; then
    echo "Error. El archivo $FICHERO_CSV no existe."
    echo "Saliendo..."
    sleep 2
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

# Procesar el CSV (saltando la primera línea)
linea_num=0
while IFS=';' read -r nombre mac ambito; do
    linea_num=$((linea_num + 1))
    
    # Salta la cabecera
    if [ "$linea_num" -eq 1 ]; then
        continue
    fi
    
    # Limpia y normalizar campos
    nombre_base=$(limpiar_nombre "$nombre")
    mac_limpia=$(limpiar_mac "$mac")
    ambito_limpio=$(limpiar_ambito "$ambito")
    
    # Verifica que los campos no estén vacíos
    if [ -z "$nombre_base" ] || [ -z "$mac_limpia" ] || [ -z "$ambito_limpio" ]; then
        echo "Error: Campos vacíos en línea $linea_num. Saltando..."
        continue
    fi
    
    # Verifica si ya existe la MAC en el fichero
    if existe_mac "$mac_limpia"; then
        echo "El host con MAC $mac_limpia ya existe. Saltando $nombre_base"
        sleep 1
        continue
    fi
    
    # Obtiene un nombre único si ya existe en el fichero
    nombre_limpio=$(encontrar_hostname_unico "$nombre_base")
    if [ "$nombre_base" != "$nombre_limpio" ]; then
        echo "Nota: El nombre '$nombre_base' ya existe, usando '$nombre_limpio' en su lugar"
    fi
    
    # Obtiene la red según ámbito
    net=$(obtener_red_por_ambito "$ambito_limpio") # Llama a la función y esta va a devolver el valor de uno de los ámbitos ej. 192.168.10 si encuentra
    if [ -z "$net" ]; then
        echo "Ámbito desconocido '$ambito_limpio'. Saltando $nombre_limpio"
        sleep 1
        continue
    fi
    
    # Busca una IP disponible
    siguiente_ip=$(encontrar_ip_disponible "$net") # Se pasa el valor del ámbito encontrado y extrae últimos octetos
    if [ -z "$siguiente_ip" ]; then
        echo "No hay IPs disponibles en la subred $net. Saltando $nombre_limpio."
        sleep 1
        continue
    fi
    
    # Añade el host al archivo
    if insertar_host_en_ambito "$nombre_limpio" "$siguiente_ip" "$mac_limpia" "$net" "$ambito_limpio"; then
        echo "Añadido $nombre_limpio → $siguiente_ip en ámbito $ambito_limpio"
        REGISTROS_INSERTADOS=$((REGISTROS_INSERTADOS + 1))
    else
        echo "Error al añadir $nombre_limpio en ámbito $ambito_limpio"
    fi
    
done < "$FICHERO_CSV"

echo ""

# Da un recordatorio de reiniciar servicio
echo "================================================"
echo "IMPORTANTE: Debe reiniciar el servicio DHCP para"
echo "            que los cambios sean efectivos      "
echo "Comando: sudo systemctl restart isc-dhcp-server "
echo "================================================"

# Muestra el LOG final
mostrar_log_final
