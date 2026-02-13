# Scalelite Development Guide

This guide covers local development setup for working on Scalelite code and testing with `docker-compose-dev.yml`.

## Overview

The `docker-compose-dev.yml` configuration is optimized for:
- Local development with exposed database ports
- Direct code mounting for live editing
- Faster iteration without container rebuilds
- SSL certificates stored in ./data/certbot/conf (same layout as production)
- Simplified debugging access

## Prerequisites

**Host machine requirements:**
- Ubuntu 22.04 LTS (or similar Linux distribution)
- Git
- Docker and Docker Compose v2
- Certbot (optional if using the Dockerized certbot commands below)
- Minimum 2 vCPU, 4GB RAM for development

## Quick Start for Development

### 1. Clone the Repository

```bash
git clone https://github.com/jfederico/scalelite-run
cd scalelite-run
```

### 2. Setup Environment Variables

Create environment configuration:

```bash
cp dotenv .env
```

Generate required secrets:

```bash
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" .env
sed -i "s/LOADBALANCER_SECRET=.*/LOADBALANCER_SECRET=$(openssl rand -hex 24)/" .env
sed -i "s/SL_HOST=.*/SL_HOST=sl/" .env
sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=example.com/" .env
```

### 3. Clone Scalelite Code (Optional)

To enable local code development with live editing:

```bash
# Clone Scalelite repository to data/scalelite-api
./setup-dev.sh

# Or manually:
git clone https://github.com/blindsidenetworks/scalelite.git data/scalelite-api
cd data/scalelite-api && git checkout v1.7
```

If you skip this step, the dev environment will use Scalelite code from the Docker image.

### 4. Generate SSL Certificates

For development, use DNS challenge with manual verification and store certs in
`./data/certbot/conf` (aligned with docker-compose-dev.yml):

```bash
source ./.env
docker run --rm -it \
  -v ./data/certbot/conf:/etc/letsencrypt \
  -v ./data/certbot/www:/var/www/certbot \
  -v ./log/certbot:/var/log/letsencrypt \
  certbot/certbot certonly \
    --manual \
    --preferred-challenges=dns \
    -d $SL_HOST.$DOMAIN_NAME \
    -d redis.$DOMAIN_NAME \
    --agree-tos \
    --manual-public-ip-logging-ok \
    --email your@email.com \
    --server https://acme-v02.api.letsencrypt.org/directory
```

**Note:** For alternative SSL setup methods including AWS Route53 automation, see the [main README](README.md#3-set-up-ssl-certificates).

### 4. Start Development Services

```bash
docker compose -f docker-compose-dev.yml up -d
```

### 5. Initialize Database

```bash
docker exec -i scalelite-api bundle exec rake db:setup
```

### 6. Add BigBlueButton Servers

```bash
curl -X POST http://localhost:3000/bigbluebutton/api/servers \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "bbb.example.com",
    "url": "https://bbb.example.com",
    "secret": "YOUR_BBB_SECRET"
  }'
```

## Validate Development Environment

After starting services, verify everything is working:

### 1. Check All Services Are Running

```bash
docker compose -f docker-compose-dev.yml ps
```

Expected output shows all services with status "Up":
- certbot
- postgres
- redis
- scalelite-api
- scalelite-poller
- scalelite-recording-importer
- scalelite-proxy
- scalelite-recordings

### 2. Test API Health Check

```bash
curl -k https://localhost/health_check
```

Expected: `success`

### 3. Test Database Connectivity

```bash
docker exec scalelite-api bundle exec rails runner \
  "puts 'Connected to: ' + ActiveRecord::Base.connection.select_all('SELECT version()').rows[0][0]"
```

Expected: Shows PostgreSQL 16 version information

### 4. Test API Endpoint

```bash
curl -k https://localhost/api/v1/servers.json
```

Expected: Returns XML response (with `unsupportedRequest` if no credentials, which is expected)

### 5. Access Rails Console

```bash
docker exec -it scalelite-api bundle exec rails console
```

In the console:
```ruby
Server.count  # Should return number of configured BBB servers
```

## Development Workflow

### Local Code Editing

Scalelite code is mounted at `./data/scalelite-api:/srv/scalelite:delegated`. Changes to Ruby files are automatically reloaded in development mode:

```bash
# Edit a file locally
nano data/scalelite-api/app/controllers/api_controller.rb

# Changes are visible in running Rails immediately
curl -k https://localhost/health_check
```

### Database Migrations

```bash
# Run pending migrations
docker exec scalelite-api bundle exec rake db:migrate

# Create new migration
docker exec -it scalelite-api bundle exec rails generate migration YourMigrationName

# Reset database (warning: deletes all data)
docker exec scalelite-api bundle exec rake db:reset
```

### Running Tests

```bash
docker exec scalelite-api bundle exec rspec
```

### Rails Console

Interactive Rails console for development:

```bash
docker exec -it scalelite-api bundle exec rails console
```

### Viewing Logs

```bash
# API logs
docker compose -f docker-compose-dev.yml logs -f scalelite-api

# Poller logs
docker compose -f docker-compose-dev.yml logs -f scalelite-poller

# Recording importer logs
docker compose -f docker-compose-dev.yml logs -f scalelite-recording-importer

# Nginx proxy logs
docker compose -f docker-compose-dev.yml logs -f scalelite-proxy

# All services
docker compose -f docker-compose-dev.yml logs -f
```

## Direct Database Access

Access PostgreSQL and Redis directly from your host machine:

### PostgreSQL

```bash
# Connection details (from .env):
# Host: localhost
# Port: 5432
# User: postgres
# Password: password (from DATABASE_URL in .env)
# Database: scalelite

psql -h localhost -U postgres -d scalelite

# Or via docker:
docker exec -it postgres psql -U postgres -d scalelite
```

### Redis

```bash
# Connection details:
# Host: localhost
# Port: 6379
# No authentication

redis-cli -h localhost -p 6379
```

### Recording Development

The BigBlueButton recordings proxy is available at:
```
https://localhost:8001
```

To test recording processing:
1. Create a recording on a connected BigBlueButton server
2. Wait for it to process
3. Check Scalelite logs for import progress:
   ```bash
   docker compose -f docker-compose-dev.yml logs -f scalelite-recording-importer
   ```

## Adding BigBlueButton Servers

```bash
docker exec -i scalelite-api bundle exec rake servers:add[https://bbb1.example.com/bigbluebutton/api/,secret]
docker exec -i scalelite-api bundle exec rake servers:enable[SERVER_ID]
```

## Advanced Development Topics
```

### Database Access

**PostgreSQL:**
```bash
# Connect from host
psql -h localhost -U postgres -d scalelite
# Password from .env: POSTGRES_PASSWORD

# Or from container
docker exec -it postgres psql -U postgres -d scalelite
```

**Redis:**
```bash
# Connect from host
redis-cli -h localhost

# Or from container
docker exec -it redis redis-cli
```

### Debugging Tips

- **Live code changes**: Edit files in `./data/scalelite-api/` - Rails reloads automatically in development mode
- **Volume exclusions**: Always exclude `/srv/scalelite/tmp`, `/srv/scalelite/log`, and `/srv/scalelite/.git` to avoid conflicts
- **Performance**: Use `:delegated` mount option on macOS for better file sync performance
- **Bundle issues**: If gems don't load, restart the container: `docker compose -f docker-compose-dev.yml restart scalelite-api`
- **Database seeds**: Load test data with `docker exec scalelite-api bundle exec rake db:seed`

### Debugging Tips

- **Live code changes**: Edit files in `./data/scalelite-api/` - Rails reloads automatically in development mode
- **Volume exclusions**: Always exclude `/srv/scalelite/tmp`, `/srv/scalelite/log`, and `/srv/scalelite/.git` to avoid conflicts
- **Performance**: Use `:delegated` mount option on macOS for better file sync performance
- **Bundle issues**: If gems don't load, restart the container: `docker compose -f docker-compose-dev.yml restart scalelite-api`
- **Database seeds**: Load test data with `docker exec scalelite-api bundle exec rake db:seed`

## Recording Development Setup

### Configuring BigBlueButton Server for Recording Transfer

Follow the main setup to initialize the BBB server, then customize for local development.

**1. Edit SSH config on BBB server:**

Edit `/home/bigbluebutton/.ssh/config`:

```
Host scalelite-spool
  HostName sl.example.com
  User <YOUR_USERNAME>          # Use your local username, not 'bigbluebutton'
  Port 22
  IdentityFile /home/bigbluebutton/.ssh/id_rsa
```

**2. Add BBB server's public key to your local machine:**

```bash
# On your development machine
nano ~/.ssh/authorized_keys
# Paste the public key from /home/bigbluebutton/.ssh/id_rsa.pub on the BBB server
```

**3. Test SSH connection from BBB server:**

```bash
# On BBB server
ssh scalelite-spool
# Accept the host key fingerprint
```

**4. Configure recording spool directory:**

Edit `/usr/local/bigbluebutton/core/scripts/scalelite.yml` on BBB server:

```yaml
# Original:
# spool_dir: scalelite-spool:/var/bigbluebutton/spool

# Development (local machine):
spool_dir: scalelite-spool:/home/<YOUR_USERNAME>/spool
```

### Local Machine Setup for Recordings

**1. Set permissions for recording spool:**

```bash
sudo chown -R root:$USER /mnt/scalelite-recordings/var/bigbluebutton/spool/
sudo chmod -R 775 /mnt/scalelite-recordings/var/bigbluebutton/spool/
```

**2. Create symbolic link:**

```bash
ln -s /mnt/scalelite-recordings/var/bigbluebutton/spool/ ~/spool
```

**3. Verify recording transfer:**

Create a test recording on your BBB server and check:

```bash
# Watch for incoming recordings
watch -n 5 'ls -la ~/spool'

# Check Scalelite recording importer logs
docker compose -f docker-compose-dev.yml logs -f scalelite-recording-importer
```

## Development Best Practices

### Code Quality

- Run tests before committing: `docker exec scalelite-api bundle exec rspec`
- Check code style: `docker exec scalelite-api bundle exec rubocop`
- Review security: `docker exec scalelite-api bundle exec brakeman`

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes in ./data/scalelite-api/
# Test thoroughly

# Commit to Scalelite repository (not scalelite-run)
cd data/scalelite-api
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

### Container Management

```bash
# View all containers
docker compose -f docker-compose-dev.yml ps

# Restart specific service
docker compose -f docker-compose-dev.yml restart scalelite-api

# View resource usage
docker stats

# Clean up unused resources
docker system prune -a
```

### Troubleshooting

**Port conflicts:**
```bash
# Check if ports are in use
sudo lsof -i :5432  # PostgreSQL
sudo lsof -i :6379  # Redis
sudo lsof -i :8001  # Recordings proxy
```

**Database connection issues:**
```bash
# Reset database
docker exec scalelite-api bundle exec rake db:reset

# Check PostgreSQL logs
docker compose -f docker-compose-dev.yml logs postgres
```

**Rails console not loading:**
```bash
# Clear Spring cache
docker exec scalelite-api bin/spring stop
docker compose -f docker-compose-dev.yml restart scalelite-api
```

## Production Deployment

When your development is complete, test with production configuration:

```bash
# Switch to production compose file
docker compose down
docker compose up -d

# Run production checks
docker exec scalelite-api bundle exec rake scalelite:check
```

For full production deployment guide, see the [main README](README.md).

## Additional Resources

- [Scalelite GitHub Repository](https://github.com/blindsidenetworks/scalelite)
- [BigBlueButton Documentation](https://docs.bigbluebutton.org/)
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
