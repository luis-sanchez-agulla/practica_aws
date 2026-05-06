#!/bin/bash
# Configuracion de Route Tables y Security Groups para Alumno D
# Ejecutar en CloudShell de AWS

REGION="eu-south-2"
RTB_WS1="rtb-0e10b1e6f2c9d51be"
RTB_WS2="rtb-0ebc97d828f5cf2bd"
SG_ID="sg-09258a12a3a95dbcd"
PEERING_A="pcx-0af2bf937b279dac3"
PEERING_B="pcx-0b11057a74e5f1b46"
IGW_ID="igw-0ae20c16007137c2d"

echo "=== Route Table WS1 ==="
aws ec2 create-route --route-table-id $RTB_WS1 --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id $PEERING_A --region $REGION 2>/dev/null || echo "Ya existe"
aws ec2 create-route --route-table-id $RTB_WS1 --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id $PEERING_B --region $REGION 2>/dev/null || echo "Ya existe"

echo "=== Route Table WS2 ==="
aws ec2 create-route --route-table-id $RTB_WS2 --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id $PEERING_A --region $REGION 2>/dev/null || echo "Ya existe"
aws ec2 create-route --route-table-id $RTB_WS2 --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id $PEERING_B --region $REGION 2>/dev/null || echo "Ya existe"
aws ec2 create-route --route-table-id $RTB_WS2 --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION 2>/dev/null || echo "Ya existe"

echo "=== Security Group ==="
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 10.20.1.153/32 --region $REGION 2>/dev/null || echo "Ya existe"
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION 2>/dev/null || echo "Ya existe"
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol udp --port 123 --cidr 10.10.0.0/16 --region $REGION 2>/dev/null || echo "Ya existe"
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol icmp --port -1 --cidr 10.0.0.0/8 --region $REGION 2>/dev/null || echo "Ya existe"

echo "=== Configuracion completada ==="
