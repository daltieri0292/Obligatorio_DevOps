# Obligatorio DevOps #
Repositorio de código para el obligatorio de la materia "Programación para DevOps" Agosto/25


Alumno: Pablo Delucchi - 315123


## 1-Script Bash para creación automatizada de usuarios ##
-Crea una serie de usuarios especificados en un archivo externo, de acuerdo a una serie de parámetros.

- Consideraciones previas:
  
> El script debe tener permisos de ejecución: chmod +x solucion_ejercicio1.sh (o utilizando la ruta absoluta si no se está posicionado en el mismo directorio donde este se encuentra)

> Debe ejecutarse con privilegios de administrador (por ejemplo, usando sudo su -), ya que utiliza el comando useradd.


- Sintaxis de uso:
   
> ./solucion_ejercicio1.sh -i -c "Clave" [Archivo de entrada] (o utilizando la ruta absoluta si no se está posicionado en el mismo directorio donde este se encuentra)

Parámetros:

-i → (Opcional) Muestra información al usuario.

-c "Clave" → (Opcional) Especifica una contraseña. Si se usa, debe incluir una clave entre comillas.

[Archivo de entrada] → Obligatorio, contiene los datos para crear los usuarios. Debe ser el último parámetro indicado.



- Formato del archivo de entrada:
Debe contener 5 campos separados por “:” en el siguiente orden:

>Nombre de usuario:Comentario:Directorio home:Crear directorio home si no existe (SI/NO):Shell por defecto

En una misma linea para cada usuario.Si contiene más o menos campos, el script fallará.


## 2-Script python para Despliegue Automatizado de Aplicación Web en AWS##
-Despliega en forma automatizada una instancia de Amazon EC2 y una de RDS y despliega una aplicación web mediante el uso de una pila LAMP.


- Consideraciones previas:

>Ejecutar como usuario con privilegios de administrador.

>Tener instalados y configurados Python y AWS CLI.

> Por seguridad, la contraseña del administrador de la base RDS no está incluida en el código.
Debe declararse como variable de entorno previo a ejecutar el script:

> por ej: export RDS_ADMIN_PASSWORD="admin123"

- Sintaxis de uso
>python solucion_ejercicio2.py (o utilizando la ruta absoluta si no se está posicionado en el mismo directorio donde este se encuentra)

- Importante:
La instancia de RDS demora en inicializarse y estar lista, por lo que el script espera que esto ocurra antes de proceder a inicializar la instancia de EC2.
esto se debe a que si la instancia de EC2 se crea cuando la de base de datos no está lista, la misma aun no tiene disponible un endpoint para permitir la conexión, por lo que la instancia de EC2 no puede conectarse a esta para operar y por tanto el script falla. la instancia de EC2 se genera una vez que el motor de base de datos está listo.
