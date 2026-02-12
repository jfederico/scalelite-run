# scalelite-run

A Docker Compose setup for deploying Scalelite as a production-ready BigBlueButton load balancer.

## Overview

[Scalelite](https://github.com/blindsidenetworks/scalelite) is an open-source load balancer designed specifically for [BigBlueButton](https://bigbluebutton.org/), that evenly spreads meeting load over a pool of BigBlueButton servers. It makes the pool appear to external applications (such as Moodle) as a single, highly scalable BigBlueButton server.

**Key Features:**
- Open source under AGPL license (released by Blindside Networks in March 2020)
- Professional-grade load balancing and failover capabilities
- Support for recordings aggregation
- Docker-based deployment with production security

**Architecture:**
Scalelite consists of four main components:
1. **Nginx Proxy** - Custom-built nginx handling BigBlueButton-compatible requests
2. **Scalelite API** - Ruby on Rails application implementing the BigBlueButton API and request routing
3. **Meeting Poller** - Background job monitoring registered BigBlueButton server status
4. **Recording Importer** - Background job aggregating recordings from BigBlueButton servers

This repository provides a complete `docker-compose` configuration for deploying all these components together.

## Quick Start

### Prerequisites

**On your host machine, you need:**
- Ubuntu 22.04 LTS (or other Linux distribution)
- Internet connectivity for the deployment
- Root or sudo access
- Minimum t3.small equivalent resources (2 vCPU, 2GB RAM)

**Software requirements:**
- Git
- Docker
- Docker Compose v2
- OpenSSL (for generating secrets)

### Infrastructure Setup (AWS Example)

If deploying on AWS, set up:
1. **VPC** - Virtual Private Cloud for network isolation
2. **EC2 Instance** - Recommended t3.small or larger with Ubuntu 22.04
3. **Route 53 Hosted Zone** - For DNS management (e.g., `example.com`)
4. **Security Groups** - Allow ports 80, 443 for HTTPS/HTTP, and restrict SSH
5. **Elastic IP** - (Optional) For stable public IP address

### Server Preparation

Before deploying Scalelite, prepare your server:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git docker.io docker-compose curl wget

# Enable Docker daemon and current user
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker

# (Optional) Add swap memory for systems with limited RAM
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

### Deployment Steps

#### 1. Clone the Repository

```bash
git clone https://github.com/jfederico/scalelite-run
cd scalelite-run
```

#### 2. Configure Environment Variables

```bash
# Copy the template
cp dotenv .env

# Edit the .env file with your settings
nano .env
```

Required variables:

```bash
# Generated secrets (use openssl commands below)
SECRET_KEY_BASE=                          # Generated: openssl rand -hex 64
LOADBALANCER_SECRET=                      # Generated: openssl rand -hex 24

# Your deployment details
SL_HOST=sl                                # Subdomain (e.g., 'sl' for sl.example.com)
DOMAIN_NAME=example.com                   # Your domain

# Email for Let's Encrypt certificates
LETSENCRYPT_EMAIL=admin@example.com       # Certificate notifications

# (Optional) BigBlueButton recordings directory
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton
```

Generate required secrets:

```bash
# Generate SECRET_KEY_BASE (64 hex characters)
openssl rand -hex 64

# Generate LOADBALANCER_SECRET (24 hex characters)
openssl rand -hex 24
```

Update your .env file:

```bash
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" .env
sed -i "s/LOADBALANCER_SECRET=.*/LOADBALANCER_SECRET=$(openssl rand -hex 24)/" .env
sed -i "s/SL_HOST=.*/SL_HOST=sl/" .env
sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=example.com/" .env
sed -i "s/LETSENCRYPT_EMAIL=.*/LETSENCRYPT_EMAIL=admin@example.com/" .env
```

#### 3. Set Up SSL Certificates

For **production deployments** with publicly accessible domains, use HTTP challenge:

```bash
# Generate Let's Encrypt certificates (HTTP validation)
./init-letsencrypt.sh
```

This script uses certbot to create valid HTTPS certificates and will:
- Create certificate directories
- Generate certificates for your domain via HTTP challenge
- Configure automatic renewal

**For development or DNS-based validation**, use DNS challenge instead:

```bash
# Method 1: Interactive DNS challenge (manual for testing)
docker run --rm -it \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  certbot/certbot certonly \
    --manual \
    --preferred-challenges dns \
    -d sl.example.com

# Follow the prompts to add TXT records to your DNS provider
```

**For AWS Route53 (Automated DNS Challenge):**

```bash
# Option A: Using environment variables for credentials
docker run --rm \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  -e AWS_ACCESS_KEY_ID=your_access_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret_key \
  certbot/dns-route53 certonly \
    --dns-route53 \
    --dns-route53-propagation-seconds 30 \
    -d sl.example.com \
    -d "*.sl.example.com"

# Option B: Using AWS credentials file
docker run --rm \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  -v ~/.aws/credentials:/root/.aws/credentials:ro \
  certbot/dns-route53 certonly \
    --dns-route53 \
    --dns-route53-propagation-seconds 30 \
    -d sl.example.com \
    -d "*.sl.example.com"
```

**For other DNS providers:**

```bash
# Azure DNS
docker run --rm \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  certbot/dns-azure certonly \
    --dns-azure \
    -d sl.example.com

# Google Cloud DNS
docker run --rm \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  -v /path/to/gcp-credentials.json:/gcp-credentials.json:ro \
  certbot/dns-google certonly \
    --dns-google \
    --dns-google-credentials /gcp-credentials.json \
    -d sl.example.com

# Cloudflare DNS
docker run --rm \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  -v ~/.secrets/certbot/cloudflare.ini:/root/.secrets/certbot/cloudflare.ini:ro \
  certbot/dns-cloudflare certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /root/.secrets/certbot/cloudflare.ini \
    -d sl.example.com
```

**When to use DNS challenge:**
- Development environments with self-signed certificates
- Internal deployments behind firewalls
- When HTTP port 80 is blocked or unavailable
- Multi-domain or wildcard certificates
- Automated certificate renewal with DNS API integration

**AWS Route53 IAM Permissions Required:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetChange"
      ],
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZonesByName"
      ],
      "Resource": "*"
    }
  ]
}
```

**Verify certificate generation:**

```bash
# Check certificate details
docker exec certbot certbot certificates

# List generated certificates
ls -la ./data/certbot/conf/live/sl.example.com/
```

#### 4. Start the Services

```bash
# Start all containers in background
docker compose up -d

# Monitor startup progress
docker compose logs -f

# Wait for database initialization (check logs for "database ready")
```

#### 5. Initialize the Database

```bash
# Initialize PostgreSQL database and schema
docker exec -i scalelite-api bundle exec rake db:setup
```

#### 6. Verify Installation

```bash
# Check container status
docker compose ps

# Test HTTPS endpoint
curl -vk https://localhost/health_check

# Check logs for errors
docker compose logs scalelite-proxy
docker compose logs scalelite-api
```

### Configuring BigBlueButton Servers

Now that Scalelite is running, you need to register your BigBlueButton servers:

```bash
# Check Scalelite server status (should show 0 servers)
docker exec scalelite-api bundle exec rake status

# List registered servers
docker exec scalelite-api bundle exec rake servers

# Add a BigBlueButton server
# Format: servers:add[BBB_URL,BBB_SECRET]
docker exec scalelite-api bundle exec rake servers:add[https://bbb1.example.com/bigbluebutton/api/,your-bbb-secret]

# This returns a server ID, e.g.: 27243e91-35a3-42ee-80a7-bd5980b0728f
```

**Important:** Include the `/api/` suffix in the BigBlueButton URL.

Enable the registered server:

```bash
docker exec scalelite-api bundle exec rake servers:enable[27243e91-35a3-42ee-80a7-bd5980b0728f]
```

Run the poller to check server status:

```bash
docker exec scalelite-api bundle exec rake poll:all
```

### Using Scalelite with External Applications

Once configured, use Scalelite in your application:

**Scalelite URL:**
```
https://sl.example.com/bigbluebutton/api/
```

**Scalelite Secret:**
```
(Your LOADBALANCER_SECRET from .env)
```

Configure your application (Moodle, WordPress, etc.) to use these credentials instead of direct BigBlueButton servers.

### Optional: Enable Recordings

To enable recording aggregation from BigBlueButton servers:

**On your Scalelite server:**
```bash
./init-recordings-scalelite.sh
```

**On each BigBlueButton server:**
```bash
wget -qO- https://raw.githubusercontent.com/jfederico/scalelite-run/master/init-recordings-bigbluebutton.sh | bash -s -- -s sl.example.com
```

Follow the on-screen instructions to configure SSH key exchange for secure recording transfer.



## Deployment Options

This project includes two docker-compose configuration files optimized for different use cases:

### `docker-compose.yml` - Production Deployment

Use this file for production or production-like deployments.

**Characteristics:**
- Database services (PostgreSQL, Redis) are **not exposed** to the host (port binding disabled) for security
- SSL certificates managed by Let's Encrypt via certbot container
- Nginx automatic certificate renewal with periodic reload
- Production-grade security and reliability
- Suitable for public internet-facing deployments

**When to use:**
- Production environments
- Public internet deployments
- When you need automatic HTTPS certificate management
- When you want security hardening (no exposed databases)

### `docker-compose-dev.yml` - Local Development

Use this file for local development on your machine.

**Characteristics:**
- **Exposed database ports** for direct debugging access:
  - PostgreSQL: `localhost:5432` (connect with `psql`)
  - Redis: `localhost:6379` (connect with `redis-cli`)
  - Recordings proxy: `localhost:8001` (direct access)
- SSL certificates loaded from host system (`/etc/letsencrypt`)
- Nginx runs without periodic reload (faster startup and iteration)
- Simplified setup without needing certbot to generate certificates

**When to use:**
- Local development and debugging
- When you want to inspect databases directly
- When you want faster container restarts
- When you have pre-existing SSL certificates on your host system

**Usage:**
```bash
docker-compose -f docker-compose-dev.yml up -d
```

## Operations and Management

### Common Administration Tasks

#### Monitor System Status

```bash
# View all running containers
docker compose ps

# Check specific service logs
docker compose logs scalelite-api
docker compose logs scalelite-poller
docker compose logs scalelite-proxy

# Follow logs in real-time
docker compose logs -f scalelite-api

# View last 100 lines with timestamp
docker compose logs --tail=100 --timestamps scalelite-api
```

#### Server Management

```bash
# List all registered servers
docker exec scalelite-api bundle exec rake servers

# Check server status
docker exec scalelite-api bundle exec rake status

# Add a BigBlueButton server
docker exec scalelite-api bundle exec rake servers:add[https://bbb1.example.com/bigbluebutton/api/,secret]

# Enable a server for load balancing
docker exec scalelite-api bundle exec rake servers:enable[SERVER_ID]

# Disable a server gracefully
docker exec scalelite-api bundle exec rake servers:disable[SERVER_ID]

# Emergency: Stop routing to a server (panic mode)
docker exec scalelite-api bundle exec rake servers:panic[SERVER_ID]

# Remove a server
docker exec scalelite-api bundle exec rake servers:remove[SERVER_ID]

# Force immediate status check of all servers
docker exec scalelite-api bundle exec rake poll:all
```

#### Backup and Recovery

```bash
# Backup PostgreSQL database
docker exec postgres pg_dump -U postgres scalelite > scalelite-backup.sql

# Restore PostgreSQL database
docker exec -i postgres psql -U postgres scalelite < scalelite-backup.sql

# Backup Redis data
docker cp redis:/data/dump.rdb ./redis-backup.rdb

# Check certificate status
docker exec scalelite-proxy ls -la /etc/letsencrypt/live/$(grep DOMAIN_NAME .env | cut -d= -f2)/
```

#### Update Scalelite

```bash
# Pull latest changes from repository
git pull origin master

# Restart containers with updated images
docker compose pull
docker compose up -d

# Run any database migrations
docker exec scalelite-api bundle exec rake db:migrate
```

### Maintenance

#### Clear Docker Cache and Rebuild

```bash
# Remove unused containers and images
docker system prune -a

# Rebuild containers from fresh images
docker compose build --no-cache
docker compose up -d
```

#### Certificate Renewal

Certificates are automatically renewed by certbot. Monitor renewal status:

```bash
# Check certbot logs
docker compose logs certbot

# Manual renewal (if needed)
docker exec certbot certbot renew --dry-run

# Force immediate renewal
docker exec certbot certbot renew --force-renewal
```

#### Database Maintenance

```bash
# Connect to PostgreSQL
docker exec -it postgres psql -U postgres -d scalelite

# Useful commands once inside psql:
\dt                 # List tables
\du                 # List users
SELECT * FROM servers;  # View registered servers
\q                  # Exit psql
```

#### Troubleshoot Container Issues

```bash
# Restart a specific container
docker compose restart scalelite-api

# Stop and remove containers (data persists)
docker compose down

# Complete reset (removes volumes - data loss!)
docker compose down -v

# Inspect container resource usage
docker stats

# Debug container network connectivity
docker compose exec scalelite-api ping redis
docker compose exec scalelite-api ping postgres
```



## Troubleshooting

### Nginx cannot access private key after Docker Compose restart

When Docker Compose restarts, the SSL certificate private key file permissions may be reset, preventing nginx from reading them. This typically manifests as nginx failing to start or SSL connection errors.

#### Symptoms
- Nginx container fails to start or crashes after a restart
- SSL certificate errors in logs
- `Permission denied` errors when accessing HTTPS
- Errors like `failed to populate volume` when starting containers

#### Solution (Automatic - Using Entrypoint Script)

The docker-compose files now include an entrypoint script (`docker/nginx-entrypoint.sh`) that automatically fixes certificate permissions **before nginx starts**. This is critical because:

1. **Timing matters**: Permissions must be fixed in the container initialization sequence, before nginx attempts to read the certificates
2. **Reliable approach**: Uses `find` commands to locate and fix permissions across all certificate files and directories
3. **No manual intervention**: The script runs automatically with every container start

The entrypoint script:
- Fixes all certificate directories to be traversable (755)
- Fixes all private key files to be readable (644)
- Handles multiple key versions from certificate renewals
- Configures nginx from the template
- Starts nginx in foreground mode

This approach solves the problem permanently without requiring manual fixes after each restart.

#### Alternative Manual Fixes

If you need to manually fix permissions for troubleshooting:

**Option 1: Using the provided helper script**
```bash
./fix-permissions.sh
docker-compose restart scalelite-proxy
```

**Option 2: Manual fix on the host using find**
```bash
# Fix permissions on certificate directories
find data/certbot/conf/live -type d -exec chmod 755 {} \;
find data/certbot/conf/archive -type d -exec chmod 755 {} \;

# Fix permissions on private key files
find data/certbot/conf -name "privkey*.pem" -exec chmod 644 {} \;

# Restart nginx
docker-compose restart scalelite-proxy
```

**Option 3: Fix inside the container**
```bash
docker exec -it scalelite-proxy sh -c 'find /etc/letsencrypt -name "privkey*.pem" -exec chmod 644 {} \;'
docker-compose restart scalelite-proxy
```

#### Root Cause

Docker volume mounts from the host can cause permission issues because:
- Certificate files are owned by the host system user (root)
- Nginx runs as the `www-data` user inside the container
- Docker Compose restarts reset file permissions when volumes are remounted
- Certbot certificate renewal may reset permissions as part of its renewal process
- Multiple private key versions (privkey1.pem, privkey2.pem, etc.) exist from certificate renewals

The entrypoint script approach fixes this by:
- Correcting permissions at the right time (container initialization, before nginx starts)
- Using `find` commands instead of glob patterns (more reliable)
- Processing all certificate files and directories comprehensively
- Running on every container start without requiring manual intervention

#### Technical Details

The `docker/nginx-entrypoint.sh` script:
```bash
#!/bin/bash
set -e

# Fix SSL certificate permissions BEFORE nginx starts
find /etc/letsencrypt/live -type d -exec chmod 755 {} \;
find /etc/letsencrypt/archive -type d -exec chmod 755 {} \;
find /etc/letsencrypt -name 'privkey*.pem' -exec chmod 644 {} \;

# Configure nginx from template
envsubst '${NGINX_HOSTNAME}' < /etc/nginx/sites.template > /etc/nginx/conf.d/default.conf

# Start nginx in foreground
exec nginx -g 'daemon off;'
```

This is executed as the entrypoint in the scalelite-proxy service:
```yaml
scalelite-proxy:
  image: nginx:1.24
  entrypoint: /usr/local/bin/nginx-entrypoint.sh
  volumes:
    - ./docker/nginx-entrypoint.sh:/usr/local/bin/nginx-entrypoint.sh
```

### PostgreSQL and Redis data loss after container restart

When Docker Compose containers restart, PostgreSQL and Redis data was being lost because the volumes were not persisted to the host filesystem.

#### Symptoms
- Database is empty after restarting Docker Compose
- Redis data is lost after container restart
- Scalelite API shows "database does not exist" errors

#### Solution

The docker-compose files have been updated to use persistent bind mounts by default. Data is now stored in:
- PostgreSQL: `./data/postgres/db`
- Redis: `./data/redis/db`

These directories are created automatically when you set up the project. Data will persist across container restarts.

If you want to use custom paths for data storage, you can override the defaults in your `.env` file:

```bash
# Optional - customize data storage locations
DOCKER_VOL_POSTGRES_DATA=/mnt/persistent/postgres
DOCKER_VOL_REDIS_DATA=/mnt/persistent/redis
```

To migrate existing data from a running container, you can:

```bash
# Stop the containers
docker-compose down

# Copy data if it exists in Docker volumes
docker run --rm -v postgres-data:/data -v "$(pwd)/data/postgres/db":/backup \
  busybox cp -r /data/. /backup/ 2>/dev/null || true

# Restart containers
docker-compose up -d
```

#### Root Cause

The original docker-compose configuration used unnamed Docker volumes which are managed by Docker and not tied to specific host directories. When containers restart or are removed, these volumes could be lost or inaccessible. The fix uses bind mounts which explicitly link container storage to specific host directories, ensuring data persistence.

The benefits of bind mounts:
- Data is stored in predictable, accessible host directories
- Easy to backup and inspect data
- Data persists across container lifecycle events
- Works consistently across development and production
