#!/bin/bash

# 1. Definir variables
FECHA=$(date +%Y%m%d_%H%M%S)
ARCHIVO="/home/bitnami/backups/universidad_$FECHA.sql"
BUCKET="buclet-practica-ufv-config"

# 2. Hacer el volcado de la base de datos
export PGPASSWORD="A:U=+8.Mz=,+"
pg_dump -U postgres -h localhost universidad > $ARCHIVO

# 3. Subir el archivo a S3 usando el Rol IAM de la máquina
aws s3 cp $ARCHIVO s3://bucket-practica-ufv-spain/alumno-b/backup_alumno_b/ --region eu-south-2

# 4. Borrar el archivo local para que no se llene el disco duro con el tiempo
rm $ARCHIVO

echo "Backup de $FECHA completado y subido a S3."