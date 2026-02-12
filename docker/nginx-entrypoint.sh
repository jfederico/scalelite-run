#!/bin/sh
set -e

# Fix SSL certificate permissions BEFORE nginx starts
echo "Fixing SSL certificate permissions..."
if [ -d "/etc/letsencrypt" ]; then
	chmod 755 /etc/letsencrypt 2>/dev/null || true
	find /etc/letsencrypt -type d -exec chmod 755 {} \; 2>/dev/null || true
	find /etc/letsencrypt -name 'privkey*.pem' -exec chmod 644 {} \; 2>/dev/null || true
else
	echo "⚠ /etc/letsencrypt not found; skipping permission fixes"
fi
echo "✓ Certificate permissions fixed"

# Wait for upstream DNS to be resolvable to avoid nginx startup failure
UPSTREAM_HOST=${NGINX_UPSTREAM_HOST:-scalelite-api}
UPSTREAM_WAIT_SECONDS=${NGINX_UPSTREAM_WAIT_SECONDS:-60}
echo "Waiting for upstream host: ${UPSTREAM_HOST} (timeout: ${UPSTREAM_WAIT_SECONDS}s)"
elapsed=0
while ! getent hosts "${UPSTREAM_HOST}" >/dev/null 2>&1; do
	if [ "$elapsed" -ge "$UPSTREAM_WAIT_SECONDS" ]; then
		echo "⚠ Upstream host ${UPSTREAM_HOST} not resolvable after ${UPSTREAM_WAIT_SECONDS}s; continuing anyway"
		break
	fi
	sleep 2
	elapsed=$((elapsed + 2))
done
echo "✓ Upstream host check complete"

# Configure nginx with the template
echo "Configuring nginx..."
envsubst '${NGINX_HOSTNAME}' < /etc/nginx/sites.template > /etc/nginx/conf.d/default.conf
echo "✓ Nginx configuration complete"

# Start nginx in foreground
echo "Starting nginx..."
exec nginx -g 'daemon off;'
