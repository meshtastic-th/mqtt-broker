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

# 3. Generate server certificate request (CSR) with SAN
cat > certs/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORG
OU = $OU
CN = $CN
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = $CN
# Add IP if CN is an IP address
$(if [[ $CN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "IP.1 = $CN"; fi)
EOF

openssl req -new -out certs/server.csr -key certs/server.key -config certs/openssl.cnf

# 4. Sign the server certificate with the CA
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days $DAYS -extensions v3_req -extfile certs/openssl.cnf

# Set permissions for Mosquitto (UID 1883)
chmod 644 certs/ca.crt certs/server.crt
chmod 600 certs/server.key

# Attempt to set ownership if running on Linux/Docker host
if [ "$(id -u)" -eq 0 ]; then
    chown -R 1883:1883 certs/ data/ log/ 2>/dev/null || true
    echo "Ownership set to 1883:1883 for Mosquitto."
else
    echo "Note: If you see permission errors in Docker logs, run: sudo chown -R 1883:1883 certs/ data/ log/"
fi

echo "Certificates generated in certs/ directory."
