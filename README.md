# scalelite-run

A simple way to deploy Scalelite as for production using docker-compose.

## Overview

[Scalelite](https://github.com/blindsidenetworks/scalelite) is an open-source load balancer, designed specifically for [BigBlueButton](https://bigbluebutton.org/), that evenly spreads the meeting load over a pool of BigBlueButton servers. It makes the pool of BigBlueButton servers appear to a front-end application such as Moodle [2], as a single and yet very scalable BigBlueButton server.

It was released by [Blindside Networks](https://blindsidenetworks.com/) under the AGPL license on March 13, 2020, in response to the high demand of Universities looking into scaling BigBlueButton in response to the [COVID-19 pandemic lock-downs](https://campustechnology.com/articles/2020/03/03/coronavirus-pushes-online-learning-forward.aspx).

The full source code is available on GitHub and pre-built docker images can be found on [DockerHub](https://hub.docker.com/r/blindsidenetwks/scalelite).

Scaleite itself is a ruby on rails application.

For its deployment it is required some experience with BigBlueButton and Scalelite itself, and all the tools and components used as part of the stack such as redis, postgres, nginx, docker and docker-compose, as well as ubuntu and AWS infrastructure.

For those new to system administration or any of the components mentioned the article [Scalelite lazy deployment
](https://jffederico.medium.com/scalelite-lazy-deployment-745a7be849f6) is a step-by-step guide on how to complete a full installation of Scalelite on AWS using this script. Also [Scalelite lazy deployment (Part II)](https://jffederico.medium.com/scalelite-lazy-deployment-part-ii-ca3e4bf82f8d) is a step-by-step guide to complete the installation with support for recordings.

## Installation (short version)

On an Ubuntu 22.04 machine available to the Internet (AWS EC2 instance, LXC container, VMWare machine etc).

### Prerequisites

This machine needs to be updated and have installed:

- Git
- [Docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04)
- [Docker Compose](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-22-04)

### Fetching the scripts

```
git clone https://github.com/jfederico/scalelite-run
cd scalelite-run
```

### Initializing environment variables

Create a new .env file based on the dotenv file included.

```
cp dotenv .env
```

Most required variables are pre-set by default, the ones that must be set before starting are:

```
SECRET_KEY_BASE=
LOADBALANCER_SECRET=
SL_HOST=
DOMAIN_NAME=
```

Obtain the value for SECRET_KEY_BASE and LOADBALANCER_SECRET with:

```
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" .env
sed -i "s/LOADBALANCER_SECRET=.*/LOADBALANCER_SECRET=$(openssl rand -hex 24)/" .env
```

Set the hostname on SL_HOST (E.g. sl)

```
sed -i "s/SL_HOST=.*/SL_HOST=sl" .env
```

Set the domain name on DOMAIN_NAME (E.g. example.com)

```
sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=example.com" .env
```

Start the services.

```
docker-compose up -d
```

Now, the scalelite server is running, but it is not quite yet ready. The database must be initialized.

```
docker exec -i scalelite-api bundle exec rake db:setup
```

## Choosing the Right Docker Compose File

This project includes two docker-compose configuration files optimized for different use cases:

### `docker-compose.yml` - Production Deployment

Use this file for production or production-like deployments.

**Characteristics:**
- Database services (PostgreSQL, Redis) are **not exposed** to the host (port binding disabled)
- SSL certificates managed by Let's Encrypt via certbot container
- Nginx periodic reload (6-hour interval) for automatic certificate renewal
- Suitable for public deployments with security in mind

**Usage:**
```bash
docker-compose up -d
```

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

**Usage:**
```bash
docker-compose -f docker-compose-dev.yml up -d
```

**When to use dev version:**
- Local development and debugging
- When you want to inspect databases directly
- When you want faster container restarts
- When using pre-existing SSL certificates on your host system

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
