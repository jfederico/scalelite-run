#!/bin/bash
set -e

# Fix SSL certificate permissions BEFORE nginx starts
echo "Fixing SSL certificate permissions..."
find /etc/letsencrypt/live -type d -exec chmod 755 {} \; 2>/dev/null || true
find /etc/letsencrypt/archive -type d -exec chmod 755 {} \; 2>/dev/null || true
find /etc/letsencrypt -name 'privkey*.pem' -exec chmod 644 {} \; 2>/dev/null || true
echo "✓ Certificate permissions fixed"

# Configure nginx with the template
echo "Configuring nginx..."
envsubst '${NGINX_HOSTNAME}' < /etc/nginx/sites.template > /etc/nginx/conf.d/default.conf
echo "✓ Nginx configuration complete"

# Start nginx in foreground
echo "Starting nginx..."
exec nginx -g 'daemon off;'
