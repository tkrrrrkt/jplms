# Docker Development Environment

## Quick Start (First Time)

```bash
cd docker

# 1. Clone Moodle source (once only, ~500MB)
git clone --branch MOODLE_405_STABLE --depth 1 https://github.com/moodle/moodle.git moodle

# 2. Start containers
docker compose up -d

# 3. Wait for MySQL to be healthy (~30 seconds), then install Moodle
docker compose exec moodle php /var/www/html/admin/cli/install.php \
  --wwwroot=http://localhost:8880 \
  --dataroot=/var/www/moodledata \
  --dbtype=mysqli --dbhost=db --dbname=moodle --dbuser=moodle --dbpass=moodle \
  --fullname="Japan LMS Dev" --shortname="JPLMS" \
  --adminuser=admin --adminpass=Admin1234! --adminemail=admin@example.com \
  --lang=ja --agree-license --non-interactive
```

## Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Moodle | http://localhost:8880 | admin / Admin1234! |
| MySQL | localhost:13306 | moodle / moodle |
| Redis Session | localhost:16379 | — |
| Redis Cache | localhost:16380 | — |

## Custom Code Mounting

Plugin and theme directories are bind-mounted from the host:

```
../local/timetrack     →  /var/www/html/local/timetrack
../theme/lambda_child  →  /var/www/html/theme/lambda_child
```

Changes to these directories are reflected immediately (no rebuild needed).
After modifying PHP files, purge Moodle cache:

```bash
docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php
```

## Common Commands

```bash
# Start/Stop
docker compose up -d
docker compose down

# View logs
docker compose logs -f moodle

# Moodle CLI (inside container)
docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php
docker compose exec moodle php /var/www/html/admin/cli/upgrade.php

# MySQL CLI
docker exec -it jplms-db mysql -u moodle -pmoodle moodle

# Reset everything (DESTRUCTIVE - deletes DB and moodledata)
docker compose down -v
```

## Redis Configuration in Moodle

After first startup, configure Redis in Moodle Admin:

1. Site Administration → Plugins → Caching → Configuration
2. Add Redis store for Session: `redis-session:6379`
3. Add Redis store for Application cache: `redis-cache:6379`

## Directory Structure

```
docker/
├── docker-compose.yml    # Container definitions
├── moodle/               # Moodle source (git cloned, NOT committed)
└── README.md             # This file
```

Note: `docker/moodle/` is gitignored. Each developer clones Moodle source locally.
