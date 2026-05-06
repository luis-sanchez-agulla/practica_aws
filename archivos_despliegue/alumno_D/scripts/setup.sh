#!/bin/bash
# Script de instalacion completa para los Web Servers del Alumno D
# Ejecutar en cada servidor como ec2-user

set -e

echo "=== 1. Instalando dependencias ==="
sudo dnf install -y python3 python3-pip nginx postgresql15

echo "=== 2. Instalando librerias Python ==="
sudo /usr/bin/python3 -m pip install flask psycopg2-binary flask-cors

echo "=== 3. Creando estructura de la app ==="
sudo mkdir -p /opt/app/templates

echo "=== 4. Copiando archivos ==="
sudo cp app.py /opt/app/app.py
sudo cp templates/index.html /opt/app/templates/index.html

echo "=== 5. Configurando systemd ==="
sudo cp flask-app.service /etc/systemd/system/flask-app.service
sudo systemctl daemon-reload
sudo systemctl enable --now flask-app

echo "=== 6. Configurando Nginx ==="
sudo cp profesores.conf /etc/nginx/conf.d/profesores.conf
sudo sed -i 's/listen       80;/#listen       80;/g' /etc/nginx/nginx.conf
sudo sed -i 's/listen       \[::\]:80;/#listen       [::]:80;/g' /etc/nginx/nginx.conf
sudo systemctl enable --now nginx
sudo nginx -t && sudo systemctl reload nginx

echo "=== 7. Verificando ==="
sleep 3
curl http://localhost/health
curl http://localhost/profesores

echo "=== Instalacion completada ==="
