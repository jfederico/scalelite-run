#!/bin/bash

## Script to fix certificate and private key permissions
## Run this after Docker Compose restart or if nginx cannot access the private key
##
## Usage: ./fix-permissions.sh

set -e

echo "=== Fixing certificate and private key permissions ==="

# Ensure certbot config directory exists
if [ ! -d "./data/certbot/conf" ]; then
  echo "Error: ./data/certbot/conf directory does not exist"
  exit 1
fi

# Fix permissions on live certificates
if [ -d "./data/certbot/conf/live" ]; then
  echo "Fixing permissions on live certificates..."
  find ./data/certbot/conf/live -type d -exec chmod 755 {} \; 2>/dev/null || true
  find ./data/certbot/conf/live -name "privkey*.pem" -exec chmod 644 {} \; 2>/dev/null || true
  echo "✓ Live certificates permissions fixed"
else
  echo "⚠ ./data/certbot/conf/live not found (no certificates yet)"
fi

# Fix permissions on archive certificates
if [ -d "./data/certbot/conf/archive" ]; then
  echo "Fixing permissions on archive certificates..."
  find ./data/certbot/conf/archive -type d -exec chmod 755 {} \; 2>/dev/null || true
  find ./data/certbot/conf/archive -name "privkey*.pem" -exec chmod 644 {} \; 2>/dev/null || true
  echo "✓ Archive certificates permissions fixed"
fi

# Fix permissions on renewal directory
if [ -d "./data/certbot/conf/renewal" ]; then
  echo "Fixing permissions on renewal config..."
  find ./data/certbot/conf/renewal -type f -exec chmod 644 {} \; 2>/dev/null || true
  echo "✓ Renewal config permissions fixed"
fi

echo ""
echo "=== Permission fix complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart the nginx container: docker-compose restart scalelite-proxy"
echo "  2. Or restart all services: docker-compose restart"
echo ""
