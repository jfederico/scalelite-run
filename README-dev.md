# Scalelite Development Guide

This guide covers local development setup for working on Scalelite code and testing with `docker-compose-dev.yml`.

## Overview

The `docker-compose-dev.yml` configuration is optimized for:
- Local development with exposed database ports
- Direct code mounting for live editing
- Faster iteration without container rebuilds
- SSL certificates from host system
- Simplified debugging access

## Prerequisites

**Host machine requirements:**
- Ubuntu 22.04 LTS (or similar Linux distribution)
- Git
- Docker and Docker Compose v2
- Certbot (for SSL certificate generation)
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

### 3. Generate SSL Certificates

For development, use DNS challenge with manual verification:

```bash
source ./.env
certbot certonly --manual \
  -d $SL_HOST.$DOMAIN_NAME \
  --agree-tos \
  --no-bootstrap \
  --manual-public-ip-logging-ok \
  --preferred-challenges=dns \
  --email your@email.com \
  --server https://acme-v02.api.letsencrypt.org/directory

certbot certonly --manual \
  -d redis.$DOMAIN_NAME \
  --agree-tos \
  --no-bootstrap \
  --manual-public-ip-logging-ok \
  --preferred-challenges=dns \
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
docker exec -i scalelite-api bundle exec rake servers:add[https://bbb1.example.com/bigbluebutton/api/,secret]
docker exec -i scalelite-api bundle exec rake servers:enable[SERVER_ID]
```

## Development with Local Scalelite Code

For active development on Scalelite source code, mount it locally to edit without rebuilding containers.

### Setup Local Code Development

**1. Clone Scalelite repository:**

```bash
# Use the helper script (recommended)
./setup-dev.sh

# Or manually clone specific version
git clone https://github.com/blindsidenetworks/scalelite.git data/scalelite-api
cd data/scalelite-api
git checkout v1.6  # or your desired version
cd ../..
```

**2. Enable code mounting in `docker-compose-dev.yml`:**

Uncomment these lines in the `scalelite-api` service:

```yaml
volumes:
  - ./data/scalelite-api:/srv/scalelite:delegated
  - /srv/scalelite/tmp
  - /srv/scalelite/log
  - /srv/scalelite/.git

command: /bin/sh -c "bundle install && bundle exec rails server -b 0.0.0.0"
```

**3. Set development mode (optional):**

Add to `.env`:
```bash
RAILS_ENV=development
```

**4. Restart with local code:**

```bash
docker compose -f docker-compose-dev.yml down
docker compose -f docker-compose-dev.yml up -d

# Watch startup
docker compose -f docker-compose-dev.yml logs -f scalelite-api
```

### Development Workflow

**Access Rails console:**
```bash
docker exec -it scalelite-api bundle exec rails console
```

**Run database migrations:**
```bash
docker exec scalelite-api bundle exec rake db:migrate
```

**Run tests:**
```bash
# Full test suite
docker exec scalelite-api bundle exec rspec

# Specific test file
docker exec scalelite-api bundle exec rspec spec/models/server_spec.rb

# With coverage report
docker exec scalelite-api bundle exec rspec --format documentation
```

**Debug with breakpoints:**
```bash
# Attach to container for pry/byebug interaction
docker attach scalelite-api

# View logs with breakpoints
docker compose -f docker-compose-dev.yml logs -f scalelite-api
```

**Code quality checks:**
```bash
# Run rubocop linter
docker exec scalelite-api bundle exec rubocop

# Auto-fix style issues
docker exec scalelite-api bundle exec rubocop -a
```

**Adding new gems:**
```bash
# 1. Edit Gemfile in ./data/scalelite-api/
# 2. Install dependencies
docker exec scalelite-api bundle install

# 3. Restart if needed
docker compose -f docker-compose-dev.yml restart scalelite-api
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
