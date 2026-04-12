#!/bin/bash

# Configuration
DAYS=365
COUNTRY="TH"
STATE="Bangkok"
CITY="Bangkok"
ORG="Meshtastic Thailand Community"
OU="Community"
CN="${1:-localhost}"

# Check if certs directory exists
mkdir -p certs

# 1. Generate CA key and certificate
openssl req -new -x509 -days $DAYS -extensions v3_ca -keyout certs/ca.key -out certs/ca.crt -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=MyCA" -nodes

# 2. Generate server key
openssl genrsa -out certs/server.key 2048

# 3. Generate server certificate request (CSR)
openssl req -new -out certs/server.csr -key certs/server.key -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$CN"

# 4. Sign the server certificate with the CA
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days $DAYS

# Set permissions for Mosquitto (UID 1883)
chmod 644 certs/ca.crt certs/server.crt
chmod 600 certs/server.key
# Note: If running on Linux, you might need to chown to 1883:1883
# chown 1883:1883 certs/*

echo "Certificates generated in certs/ directory."
