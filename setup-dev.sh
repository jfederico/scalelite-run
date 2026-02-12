#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                  Scalelite Development Environment Setup                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
SCALELITE_REPO="https://github.com/blindsidenetworks/scalelite.git"
SCALELITE_DIR="./data/scalelite-api"
SCALELITE_VERSION="${1:-v1.6}"

# Check if directory already exists
if [ -d "$SCALELITE_DIR" ]; then
    echo "⚠️  Directory $SCALELITE_DIR already exists."
    read -p "Do you want to remove it and clone fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing existing directory..."
        rm -rf "$SCALELITE_DIR"
    else
        echo "ℹ️  Using existing directory. Pulling latest changes..."
        cd "$SCALELITE_DIR"
        git fetch origin
        git checkout "$SCALELITE_VERSION"
        git pull origin "$SCALELITE_VERSION" 2>/dev/null || true
        cd ../..
        echo "✅ Updated to $SCALELITE_VERSION"
        exit 0
    fi
fi

# Clone the repository
echo "📥 Cloning Scalelite repository..."
git clone "$SCALELITE_REPO" "$SCALELITE_DIR"

# Checkout specific version
echo "🔄 Checking out version $SCALELITE_VERSION..."
cd "$SCALELITE_DIR"
git checkout "$SCALELITE_VERSION"
cd ../..

echo ""
echo "✅ Scalelite code cloned successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Edit docker-compose-dev.yml and uncomment these lines in scalelite-api:"
echo ""
echo "   volumes:"
echo "     - ./data/scalelite-api:/srv/scalelite:delegated"
echo "     - /srv/scalelite/tmp"
echo "     - /srv/scalelite/log"
echo "     - /srv/scalelite/.git"
echo ""
echo "   command: /bin/sh -c \"bundle install && bundle exec rails server -b 0.0.0.0\""
echo ""
echo "2. (Optional) Set RAILS_ENV=development in your .env file for development mode"
echo ""
echo "3. Restart the services:"
echo "   docker compose -f docker-compose-dev.yml down"
echo "   docker compose -f docker-compose-dev.yml up -d"
echo ""
echo "4. Watch logs to see bundle install and rails server start:"
echo "   docker compose -f docker-compose-dev.yml logs -f scalelite-api"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Development Tips:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• Edit files in ./data/scalelite-api/ - changes reflect immediately"
echo "• Access Rails console:"
echo "  docker exec -it scalelite-api bundle exec rails console"
echo ""
echo "• Run database migrations after code changes:"
echo "  docker exec scalelite-api bundle exec rake db:migrate"
echo ""
echo "• Run tests:"
echo "  docker exec scalelite-api bundle exec rspec"
echo ""
echo "• If you add gems to Gemfile, rebuild:"
echo "  docker compose -f docker-compose-dev.yml restart scalelite-api"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
