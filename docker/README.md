# Docker Development Environment

## Quick Start

```bash
cd docker
cp ../.env.example ../.env   # Edit .env with your values
docker compose up -d          # First startup: 3-5 minutes
```

## Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Moodle | http://localhost:8080 | admin / Admin1234! |
| MySQL | localhost:13306 | moodle / moodle |
| Redis Session | localhost:16379 | — |
| Redis Cache | localhost:16380 | — |

## Custom Code Mounting

Plugin and theme directories are bind-mounted from the host:

```
../local/timetrack  →  /bitnami/moodle/local/timetrack
../theme/lambda_child  →  /bitnami/moodle/theme/lambda_child
```

Changes to these directories are reflected immediately (no rebuild needed).
After modifying PHP files, purge Moodle cache:

```bash
docker exec jplms-moodle php /bitnami/moodle/admin/cli/purge_caches.php
```

## Common Commands

```bash
# Start/Stop
docker compose up -d
docker compose down

# View logs
docker compose logs -f moodle

# Moodle CLI (inside container)
docker exec -it jplms-moodle php /bitnami/moodle/admin/cli/purge_caches.php
docker exec -it jplms-moodle php /bitnami/moodle/admin/cli/upgrade.php

# MySQL CLI
docker exec -it jplms-db mysql -u moodle -pmoodle moodle

# Reset everything (DESTRUCTIVE)
docker compose down -v
```

## Redis Configuration in Moodle

After first startup, configure Redis in Moodle Admin:

1. Site Administration → Plugins → Caching → Configuration
2. Add Redis store for Session: `redis-session:6379`
3. Add Redis store for Application cache: `redis-cache:6379`
