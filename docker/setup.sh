#!/bin/bash
# ===========================================
# Japan LMS MVP - Docker Environment Setup
# ===========================================
# This script automates the full setup of the development environment.
#
# Usage:
#   cd docker
#   bash setup.sh          # Full setup (clone + install)
#   bash setup.sh --reset  # Reset DB and reinstall (keeps Moodle source)
#
# Prerequisites:
#   - Docker & Docker Compose
#   - Git
#   - ~1GB disk space (Moodle source + DB + moodledata)
#
# Result:
#   Moodle 4.5 at http://localhost:8880
#   Admin login: admin / Admin1234!
# ===========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# --- Configuration ---
MOODLE_BRANCH="MOODLE_405_STABLE"
MOODLE_DIR="./moodle"
CONTAINER_NAME="jplms-moodle"
WWWROOT="http://localhost:8880"
DATAROOT="/var/www/moodledata"
DB_TYPE="mysqli"
DB_HOST="db"
DB_NAME="moodle"
DB_USER="moodle"
DB_PASS="moodle"
ADMIN_USER="admin"
ADMIN_PASS="Admin1234!"
ADMIN_EMAIL="admin@example.com"
SITE_FULLNAME="Japan LMS Dev"
SITE_SHORTNAME="JPLMS"
LANG="ja"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Parse arguments ---
RESET_MODE=false
if [[ "${1:-}" == "--reset" ]]; then
    RESET_MODE=true
fi

# ===========================================
# Step 1: Clone Moodle source (skip if exists)
# ===========================================
if [[ -d "$MOODLE_DIR/lib" ]]; then
    info "Moodle source already exists at $MOODLE_DIR — skipping clone."
else
    info "Cloning Moodle ($MOODLE_BRANCH) ... This may take a few minutes."
    git clone --branch "$MOODLE_BRANCH" --depth 1 https://github.com/moodle/moodle.git "$MOODLE_DIR"
    info "Moodle source cloned successfully."
fi

# ===========================================
# Step 2: Reset mode — drop volumes and rebuild
# ===========================================
if [[ "$RESET_MODE" == true ]]; then
    warn "Reset mode: stopping containers and removing volumes..."
    docker compose down -v 2>/dev/null || true
    info "Volumes removed. Starting fresh install."
fi

# ===========================================
# Step 3: Start Docker containers
# ===========================================
info "Starting Docker containers..."
docker compose up -d

# Wait for MySQL to be healthy
info "Waiting for MySQL to be healthy..."
RETRIES=30
until docker exec jplms-db mysqladmin ping -h localhost -u root -prootpassword --silent 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [[ $RETRIES -le 0 ]]; then
        error "MySQL did not become healthy within timeout."
    fi
    sleep 2
done
info "MySQL is healthy."

# Small extra wait for full readiness
sleep 3

# ===========================================
# Step 4: Check if Moodle is already installed
# ===========================================
INSTALLED=false
if docker exec "$CONTAINER_NAME" test -f /var/www/html/config.php 2>/dev/null; then
    # Check if DB has tables
    TABLE_COUNT=$(docker exec jplms-db mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" 2>/dev/null || echo "0")
    if [[ "$TABLE_COUNT" -gt "10" ]]; then
        INSTALLED=true
        info "Moodle is already installed ($TABLE_COUNT tables found). Skipping install."
    fi
fi

# ===========================================
# Step 5: Run Moodle CLI install
# ===========================================
if [[ "$INSTALLED" == false ]]; then
    info "Installing Moodle via CLI... This takes 15-25 minutes (200+ plugins)."
    info "Please be patient."
    echo ""

    docker exec "$CONTAINER_NAME" bash -c "php /var/www/html/admin/cli/install.php \
        --wwwroot='$WWWROOT' \
        --dataroot='$DATAROOT' \
        --dbtype='$DB_TYPE' \
        --dbhost='$DB_HOST' \
        --dbname='$DB_NAME' \
        --dbuser='$DB_USER' \
        --dbpass='$DB_PASS' \
        --fullname='$SITE_FULLNAME' \
        --shortname='$SITE_SHORTNAME' \
        --adminuser='$ADMIN_USER' \
        --adminpass='$ADMIN_PASS' \
        --adminemail='$ADMIN_EMAIL' \
        --lang='$LANG' \
        --agree-license \
        --non-interactive"

    info "Moodle installation completed."
fi

# ===========================================
# Step 6: Fix config.php permissions
# ===========================================
info "Fixing config.php permissions..."
docker exec "$CONTAINER_NAME" bash -c "
    if [ -f /var/www/html/config.php ]; then
        chmod 644 /var/www/html/config.php
        chown www-data:www-data /var/www/html/config.php
    fi
"

# Fix dataroot double-slash issue (Windows Git Bash path mangling)
docker exec "$CONTAINER_NAME" bash -c "
    if grep -q '//var/www/moodledata' /var/www/html/config.php 2>/dev/null; then
        sed -i 's|//var/www/moodledata|/var/www/moodledata|g' /var/www/html/config.php
    fi
"

# ===========================================
# Step 7: Reset admin password (ensure it works)
# ===========================================
info "Resetting admin password..."
docker exec "$CONTAINER_NAME" bash -c "php /var/www/html/admin/cli/reset_password.php \
    --username='$ADMIN_USER' \
    --password='$ADMIN_PASS'" 2>/dev/null || warn "Password reset skipped (may not be needed)."

# ===========================================
# Step 8: Fix moodledata permissions
# ===========================================
docker exec "$CONTAINER_NAME" bash -c "chown -R www-data:www-data /var/www/moodledata" 2>/dev/null || true

# ===========================================
# Done
# ===========================================
echo ""
info "========================================="
info "  Setup complete!"
info "========================================="
info "  URL:   $WWWROOT"
info "  Login: $ADMIN_USER / $ADMIN_PASS"
info "========================================="
echo ""
