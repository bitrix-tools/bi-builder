#!/usr/bin/env bash
# Generates self-signed SSL certificates for nginx
set -e

SSL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ssl"
mkdir -p "${SSL_DIR}"

if [ -f "${SSL_DIR}/cert.pem" ] && [ -f "${SSL_DIR}/key.pem" ]; then
    echo "SSL certificates already exist in ${SSL_DIR}/"
    echo "Delete them first if you want to regenerate."
    exit 0
fi

echo "Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout "${SSL_DIR}/key.pem" \
    -out "${SSL_DIR}/cert.pem" \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Bitrix24/CN=localhost"

echo "Done. Certificates saved to:"
echo "  ${SSL_DIR}/cert.pem"
echo "  ${SSL_DIR}/key.pem"
