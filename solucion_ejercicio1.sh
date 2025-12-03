###################################################
#  OBLIGATORIO Programación para DEVOPS AGOSTO/25 #
#      EJERCICIO 1 - PABLO DELUCCHI (315123)      #
###################################################

#!/bin/bash

#Inicializo las variables iniciales necesarias

Posicion=1           # Contador para indicar en qué posición del listado voy
PosI=0               # Posición del parámetro -i
PosC=0               # Posición del parámetro -c
PosClave=0           # Posición de la clave
PosArchivo=0         # Posición del archivo de entrada con usuarios
MostrarInfo=0        # Indica si se debe mostrar mostrar información en pantalla o no (para no tener que verificar si uno de los parámetros es -i. Si se le pasó durante el llamado al script, durante toda la ejecución MostrarInfo=1 y uso eso que es mas rápido y cómodo


# Códigos de error / indicativo
# 1 -> Arhivo de entrada mal formateado, sin permisos de lectura o inexitente
# 2 -> Error de parámetros en el llamado al script

# Recorro el listado de parámetros que se le pasaron al script, el cual está representado por la variable interna $@
# A medida que voy encontrando "-i" o "-c" voy colocando sus posiciones en las variables correspondientes.
# Si alguna no existe al salir del ciclo, entonces su valor va a ser 0.
# Si encuentro "-c" entonces SUPONGO que en PosC+1 debería estar la clave. Después lo tendré que corroborar.
# Recorrer el listado de parámetros tiene la ventaja de que yo no debo saber de atemano el órden de los mismos (y entiendo en la letra no queda del todo claro que lo tenga)
# No se indica por ejemplo que "script.sh -i -c clave archivo" o "script.sh -c clave -i archivo" tengan que estar mal alguno de ellos.
# porque cumplen que luego de -c se pasa una clave y a priori hay un nombre de archivo válido.

for parametro in "$@"; do
    if [ "$parametro" = "-i" ]; then
        MostrarInfo=1  # Debo mostrar info en pantalla
    elif [ "$parametro" = "-c" ]; then
        PosC=$Posicion #Encontré el parámetro "-c" en la posición $Posicion
        PosClave=$((PosC+1))  # El siguiente parámetro asumo que es la clave
    elif [[ "$parametro" != "-i" && "$parametro" != "-c" && $PosArchivo -eq 0 ]]; then
        # El usuario pudo haber escrito una clave o un nombre de archivo luego de -c, distingo entre ambos.
		# Si encontre "-c" y la posición en la que estoy coincide con la que deberia estar la clave (o dicho de otro modo hay un argumento mas luego de -c), entonces ese es la clave y no el archivo 
        if [ $PosC -ne 0 ] && [ $PosClave -eq $Posicion ]; then
            Clave="$parametro"
        else # De lo contrario cualquier otro argumento que no sea ni -i ni -c ni la clave se considera es el nombre del archivo
            PosArchivo=$Posicion
            Archivo="$parametro"
        fi
    fi
    Posicion=$((Posicion+1)) # Avanzo en la lista de parametros
done

# Ahora debo validar el archivo de entrada que contiene los usuarios
# Se da por hecho que el órden de los parámetros es siempre el correcto, es decir, que no debo verificar que el usuario se pase primero, etc.
# Leo el archivo de entrada ($Archivo) linea a linea utilizando el delimitador base de read, el salto de linea (\n) por ello IFS="nada"

while IFS= read -r linea; do
    # Cuento cuántos ":" hay en la línea, debe haber 4, de lo contrario el usuario escribio de mas
    cantidad_campos=$(echo "$linea" | grep -o ":" | wc -l) #Le paso la linea "$Linea a grep quien con su modificador -o y el delimitador ":" me muestra solo la linea que coincide con dicho patrón (o sea, me deuelve literalmente ":")y finalmente wc -l la cuenta
    if [ "$cantidad_campos" -ne 4 ]; then #No estan los 5 campos, entonces aviso del error y lo tiro por la salida estándar de errores.
        echo "Error. El archivo de entrada esta mal formateado. Formato esperado: usuario:comentario:home:crear_home:shell.">&2
        exit 1
    fi
done < "$Archivo"


# Validación de que argumento es cada cual 

# Si la posición de "-c" no es 0 pero no se definió (quedo vacío). entonces el usuario especificó el parámetro -c sin una clave
if [ $PosC -ne 0 ] && [ -z "$Clave" ]; then
    echo "Error de parametros. Se especificó -c pero falta la clave. El script no puede continuar">&2
    exit 2
fi

# Si la variable $Archivo quedó sin definir, es decir no se encontró un nombre de archivo, entonces falla el script.
if [ -z "$Archivo" ]; then
    echo "Error: No se especificó archivo de entrada. El Script no puede continuar">&2
    exit 1
fi

# Si se llama al script con mas de cuatro argumentos entonces el mismo debe fallar y abortar su ejecución.
# No es necesario espeficiar un minimo de argumentos aceptables ya que al ejecutarse y no poder obtener un nombre de archivo entonces falla indicando eso.

if [ $# -gt 4 ]; then
    echo "Error de parametros. Se especificaron demasiados argumentos. El script no puede continuar">&2
    exit 2
fi

# Si el archivo de entrada no existe o no se tienen permisos para su lectura. se indica con un error 
if [ ! -e "$Archivo" ] || [ ! -r "$Archivo" ]; then
    echo "Error: el archivo '$Archivo' no existe o no se puede leer. El script no puede continuar">&2
    exit 1
fi

# Contador de usuarios creados
UsuariosCreados=0

# Nuevamente, abro el archivo de entrada pero esta vez utilizo como delimitador ":". lo "tokenizo" y pongo cada uno de ellos en cada una de las variables indicadas, el primer string entre ":" en nombre_usuario, el segundo en "comentario" y asi sucesivamente
while IFS=: read -r nombre_usuario comentario directorio_home crear_directorio shell_por_defecto; do

    Error=0  # Para cada usuario (linea) reinicio el contador que me indica si hubo o no un error. Si vale 1 entonces el usuario no se crea y si vale 0, lo hace

    # Guardo los valores reales de cada elemento. el valor real es el que obtiene del archivo, en caso de que no estén definidos, tomarán como valor la cadena "<Valor por defeco>"
    comentario_real="$comentario"
    directorio_home_real="$directorio_home"
    shell_real="$shell_por_defecto"
    crear_directorio_real="$crear_directorio"

    # $Variable_mostrar es lo que se ve en pantalla si el usuario especificó el parámetro -i
    comentario_mostrar="${comentario:-<Valor por defecto>}"
    directorio_home_mostrar="${directorio_home:-<Valor por defecto>}"
    shell_mostrar="${shell_por_defecto:-<Valor por defecto>}"
    if [[ -z "$crear_directorio" ]]; then
        crear_directorio_mostrar="<Valor por defecto>"
    else
        crear_directorio_mostrar="$crear_directorio"
    fi

# Ahora debo verificar el usuario previo a su creación. resulta que por mas que estén todos los parámetros bien especificados, useradd no siempre puede crear el usuario, esto ocurre por las siguientes razones:
# 1- El usuario especificado si bien es correcto, ya existe.

# Para verificar esto lo que hago es pasarle al comando id (que me devuelve datos del usuario como sus grupos, etc) el nombre del usuario y derivar su salida al archivo especial vacio /dev/null
# esto provoca que el comando se ejecute y se genere su exitcode (que es lo que quiero evaluar después) pero que no me muestre nada en pantalla.
# finalmente, si el id = 1 eso significa (implícito en "if id" es decir que no necesito escribir if id = 1) que el comando se ejecutó con exito y mostró la info del usuario, osea que existe
# el caso de que dé 0 no me interesa, porque entonces se puede continuar. no necesito evaluarlo.

    if id "$nombre_usuario" &>/dev/null; then
        Error=1
    fi

# 2- El nombre de usuario especificado es inválido.

# useradd no permite pasarle cualquier nombre de usuario sino solo aquellos que comiencen con letras a-Z o guion bajo y que en medio tengan letras, números o guiones
# en caso de que no se cumpla esto, el usuario no se crea y falla asi que es importante manejar este tipo de error.
# para ello hago uso de la expresión regular ^[a-z_][a-z0-9_-]*$

    if [[ ! "$nombre_usuario" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        Error=1
    fi

# 3- El directorio padre debe existir y tener permisos de escritura

# useradd no permite la creación de usuarios en directorios en donde no se tenga permisos del padre
# esto quiere decir que si por ejemplo yo quisiera crear mi home dentro de la carpeta de otro usuario, no debería poder porque por defecto no soy el propietrio y no tengo permisos para escribir alli
# además se debe cumplir también que la ruta que se la pasa sea absoluta. useradd falla si por ejemplo le paso la ruta "home" en vez de "/home"

    #Si se definió un directorio home en el archivo de entrada.
    if [[ -n "$directorio_home_real" ]]; then
        # El directorio debe ser ruta absoluta. Si es distinta a /"cualquier cosa" falla.
        if [[ "$directorio_home_real" != /* ]]; then Error=1; fi
        # El directorio padre debe existir. El directorio padre se obtiene mediante el comando "dirname". dirname /home/pdelucchi devuelve /home. seria el opuesto a basename
        DirectorioPadre="$(dirname "$directorio_home_real")"
        if [[ ! -d "$DirectorioPadre" ]]; then Error=1; fi
        # Además debo tener permisos para esribir en el
        if [[ ! -w "$DirectorioPadre" ]]; then Error=1; fi
    fi

# 4 - CASO ESPECIAL "forzado": home definido, crear home=NO, y el home no existe. esto es lo que le ocurre al usuario papanatas del ejemplo mostrado en la letra.

# Este caso especial se "forzó" para que el usuario "papanatas" y algun otro en las mismas condiciones que se pueda probar de el mismo resultado.
# en la letra del obligatorio no queda muy claro porqué falla la creación de dicho usuario, debería proceder y crear el usuario.

# papanatas:Este es un usuario trucho:/trucho:NO:/bin/sh

# El nombre de usuario es correcto, cumple con las condiciones de no existencia previa, permisos, etc. el comentario tambien es correcto. El directorio del usuario se decide crear en la raíz, en el subdirectorio trucho.
# se especifica que si ya existe no se cree y finalmente su shell por defecto
# A priori no hay ningún problema en que se cree "/trucho". De hecho, el usuario que debe correr el script es root sino ningún usuario se crea porque useradd no lo permite.
# y justamente root si tiene permisos para escribir en "/" (de hecho "mkdir /prueba" funciona como root).
# está especificado que NO se cree si ya existe, en este caso NO, asi que no debería crear "/trucho", pero useradd no falla, porque permite crear usuarios sin carpeta home.
# así que "papanatas" debería poder crearse en esas condiciones.


    if [[ -n "$directorio_home_real" && "$crear_directorio_real" != "SI" && ! -d "$directorio_home_real" ]]; then
        Error=1
    fi

    # Si el directorio home del usuario no se especifica, y está seteado para que no se cree, entonces el usuario no se crea.
	if [[ -z "$directorio_home_real" ]] && [[ "$crear_directorio_real" = "NO" ]]; then
        Error=1
    fi

 #Si no se especificó un nombre de usuario o se encontró algun error anterior entonces el usuario no se puede crear. de lo contrario continúa
    if [[ -z "$nombre_usuario" ]] || [[ "$Error" -eq 1 ]]; then
        # Solo mostrar info en pantalla si se pasó -i
        if [[ $MostrarInfo -eq 1 ]]; then
            echo "ATENCIÓN: El usuario '$nombre_usuario' no pudo ser creado."
        fi
        continue
    fi

# Ahora voy construyendo el comando useradd concatenando una lista denominada opciones inicialmente vacía
# a esta lista le voy a ir adicionando los parámetros para llamar a useradd.

# Si comentario_real está definido entonces voy a agregar a la lista "-c $comentario_real""
# Si directorio_home_real lo está agrego "-d $directorio_home_real", si estuvieran las dos, opciones quedaría parcialmente como: "-c $comentario_real -d $directorio_home_real" 
# lo mismo con el resto. una salvedad importante es que por defecto si no se especifica un home, useradd lo crea en forma automática con el nombre del usuario
# este comportamiento se debe al archivo etc/login.defs que indica por defecto que el HOME del usuario debe crearse si no se especifica ($CREATE_HOME = yes)
# esto se puede contener mediante el uso de -M en vez de -m asi que cuando esté seteado para no crear HOME se utilizará -M para que useradd no vaya a leer este archivo y lo cree igual

    opciones=()
    if [ -n "$comentario_real" ]; then
        opciones+=("-c" "$comentario_real")
    fi
    if [ -n "$directorio_home_real" ]; then
        opciones+=("-d" "$directorio_home_real")
    fi
    if [[ "$crear_directorio_real" = "SI" ]]; then
        opciones+=("-m")  # Crear home
    else
        opciones+=("-M")  # No crear home, ignora CREATE_HOME
    fi
    if [ -n "$shell_real" ]; then
        opciones+=("-s" "$shell_real")
    fi
    if [ -n "$Clave" ]; then
        hash=$(openssl passwd -6 "$Clave")  # Useradd no acepta claves en texto plano asi que hay que hashearla previamente utilizando el comando "openssl"
        opciones+=("-p" "$hash")
    fi

    # Crear usuario concatenando useradd con la lista de opciones generadas anteriormente. Aqui se procede igual que con el comando ID. si useradd devuelve un exitcode de 1 el usuario se creo y sumo uno al contador
    if useradd "${opciones[@]}" "$nombre_usuario" 2>/dev/null; then
        UsuariosCreados=$((UsuariosCreados+1))
        # Mostrar info sólo si se pasó -i
        if [ $MostrarInfo -eq 1 ]; then
            echo "Usuario '$nombre_usuario' creado con éxito con los datos indicados."
            echo " 	Comentario: $comentario_mostrar"
            echo " 	Dir home: $directorio_home_mostrar"
            echo " 	Asegurado existencia de directorio home: $crear_directorio_mostrar"
            echo " 	Shell por defecto: $shell_mostrar"
        fi
    else
        # Mostrar error solo si se pasó -i
        if [ $MostrarInfo -eq 1 ]; then
            echo "ATENCIÓN: El usuario '$nombre_usuario' no pudo ser creado."
        fi
    fi

done < "$Archivo"

if [ $MostrarInfo -eq 1 ]; then

    echo "Se han creado $UsuariosCreados usuarios con éxito."
            
fi