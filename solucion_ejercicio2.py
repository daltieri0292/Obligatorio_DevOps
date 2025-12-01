###################################################
#  OBLIGATORIO Programación para DEVOPS AGOSTO/25 #
#      EJERCICIO 2 - PABLO DELUCCHI (315123)      #
###################################################

import boto3
import botocore.exceptions as ClientError  # Para manejar excepciones
import os  # Para manipular variables de entorno
import time  # Para hacer pausas

ec2 = boto3.client('ec2')
rds = boto3.client('rds')

# Obtengo el ID de la VPC por defecto. en vpcs queda un listado (un arreglo) de todas las vpc, tomo la principal, es decir la que tiene indice 0
# por defecto yo se que no hay otras creadas asi que puede parecer redundante, pero podría darse el caso de que haya mas vpcs. a parte voy a aplicarle un SG y a poner las instancias allí.
vpcs = ec2.describe_vpcs()
vpc_id = vpcs['Vpcs'][0]['VpcId']

# Defino un nombre para el SG
sg_name = 'AplicacionWeb'

try:
    response = ec2.create_security_group(
        GroupName=sg_name,
        Description='Control del trafico interno y externo',
        VpcId=vpc_id
    )
    sg_id = response['GroupId']
    print(f"Security Group creado: {sg_id}")

    # Permitir tráfico HTTP desde Internet
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 80,
                'ToPort': 80,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            }
        ]
    )

    # Permitir tráfico MySQL SOLO entre instancias que usan este mismo SG
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 3306,
                'ToPort': 3306,
                'UserIdGroupPairs': [{'GroupId': sg_id}]
            }
        ]
    )

#Si el SG ya existe, falla.
except ClientError as e:
    if 'InvalidGroup.Duplicate' in str(e):
        sg_id = ec2.describe_security_groups(GroupNames=[sg_name])['SecurityGroups'][0]['GroupId']
        print(f"Security Group ya existe: {sg_id}")
    else:
        raise

# Parámetros
DB_INSTANCE_ID = 'app-mysql'
DB_NAME = 'demo_db'
DB_USER = 'admin'

# Almaceno en DB_PASS la variable almacenada por el usuario
DB_PASS = os.environ.get('RDS_ADMIN_PASSWORD')

# Si el usuario no pasó la contraseña de la DB por variable (export) previamente, falla.
if not DB_PASS:
    raise Exception('Debes definir la variable de entorno RDS_ADMIN_PASSWORD con la contraseña del admin.')

# Intento crear la instancia de rds, si falla salto al bloque "except"
try:
    rds.create_db_instance(
        DBInstanceIdentifier=DB_INSTANCE_ID,
        AllocatedStorage=20,
        DBInstanceClass='db.t3.micro',
        Engine='mysql',
        MasterUsername=DB_USER,
        MasterUserPassword=DB_PASS,
        DBName=DB_NAME,
        VpcSecurityGroupIds=[sg_id], # Asigno el SG con id "sg_id"
        PubliclyAccessible=True,
        BackupRetentionPeriod=0
    )
    print(f'Instancia RDS {DB_INSTANCE_ID} creada correctamente.')

# Si la instancia RDS ya existe, lo indico
# Por si quiero usar una instancia que tenía anteriormente y no crear una nueva
except rds.exceptions.DBInstanceAlreadyExistsFault:
    print(f'La instancia {DB_INSTANCE_ID} ya existe, No hace falta esperar.')

# Espero a que la instancia de RDS esté disponible si no existía y se tuvo que crear.
print("Esperando que la instancia de RDS esté disponible...")
while True:
    info_rds = rds.describe_db_instances(DBInstanceIdentifier=DB_INSTANCE_ID)
    status = info_rds['DBInstances'][0]['DBInstanceStatus']
    print(f"Estado actual de la DB: {status}")
    if status == 'available':
        break
    time.sleep(10)

# Obtengo el endpoint de RDS
info_rds = rds.describe_db_instances(DBInstanceIdentifier=DB_INSTANCE_ID)
endpoint = info_rds["DBInstances"][0]["Endpoint"]["Address"]
print(f"El endpoint de la insntancia RDS es {endpoint}.")

# User data con f-srings para que se referencie correctamente el endpoint y la password de la DB
user_data = f'''#!/bin/bash
dnf clean all
dnf makecache
dnf -y install httpd git php-fpm php php-cli php-common php-mysqlnd mariadb105 mariadb105-server
systemctl start httpd
systemctl enable httpd

mkdir -p /tmp/obligatorio
cd /tmp/obligatorio
git clone https://github.com/daltieri0292/Obligatorio_DevOps.git

cp Obligatorio_DevOps/obligatorio-main/* /var/www/html

echo '<FilesMatch \\.php$>
  SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost/"
</FilesMatch>' | sudo tee /etc/httpd/conf.d/php-fpm.conf

echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

sudo systemctl restart httpd php-fpm
chown -R apache:apache /var/www/html
systemctl restart httpd

mv /var/www/html/README.md /var/www
mv /var/www/html/init_db.sql /var/www

mysql -h {endpoint} -u admin -padmin123 < /var/www/init_db.sql

echo "DB_HOST={endpoint}" > /var/www/.env
echo "DB_NAME=demo_db" >> /var/www/.env
echo "DB_USER=admin" >> /var/www/.env
echo "DB_PASS={DB_PASS}" >> /var/www/.env
echo "APP_USER=admin" >> /var/www/.env
echo "APP_PASS=admin123" >> /var/www/.env

chown apache:apache /var/www/.env
chmod 600 /var/www/.env

systemctl restart httpd
'''

# Crear instancia EC2
image_id = 'ami-06b21ccaeff8cd686'
response = ec2.run_instances(
    ImageId=image_id,
    MinCount=1,
    MaxCount=1,
    InstanceType='t3.micro',
    SecurityGroupIds=[sg_id], #Asigno el SG con id "sg_id"
    UserData=user_data
)

instance_id = response['Instances'][0]['InstanceId']
print(f"Instancia creada con ID: {instance_id}")

ec2.create_tags(
    Resources=[instance_id],
    Tags=[{'Key': 'Name', 'Value': 'AplicacionWeb'}]
)

# Buscar la instancia recién creada
instances = ec2.describe_instances(Filters=[{'Name': 'tag:Name', 'Values': ['AplicacionWeb']}])
instance_id = None

for reservation in instances['Reservations']:
    for instance in reservation['Instances']:
        instance_id = instance['InstanceId']
        break
    if instance_id:
        break

if not instance_id:
    raise Exception("No se encontró ninguna instancia con el tag 'AplicacionWeb'.")

print(f"SG {sg_id} asociado a la instancia {instance_id}")
print("La aplicación está desplegada y lista. Espere unos minutos y navegue a la IP pública de la instancia para verificar el acceso web.")
	
