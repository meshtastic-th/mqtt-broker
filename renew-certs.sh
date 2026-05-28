#!/bin/bash

# This script renews Let's Encrypt certificates and updates the broker.

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo "Usage: ./renew-certs.sh <your-domain>"
  echo "Example: ./renew-certs.sh mqtt.meshgw.com"
  exit 1
fi

echo "--- $(date): Starting certificate renewal for $DOMAIN ---"

# 1. Run Certbot renewal
# Note: This assumes certbot is installed on the host system.
# Using --quiet to reduce output in logs
sudo certbot renew --quiet

# 2. Update certificates in the project directory
# We reuse the use-certbot.sh script to handle copying and permissions.
./use-certbot.sh "$DOMAIN"

# 3. Restart the MQTT broker to pick up new certificates
echo "--- Restarting MQTT broker ---"
docker-compose restart mqtt-broker

echo "--- $(date): Renewal process completed ---"
