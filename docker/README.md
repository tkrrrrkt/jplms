# Docker Development Environment

## Quick Start (Automated)

The setup script handles everything: cloning Moodle, starting containers, installing, and fixing permissions.

```bash
cd docker

# Windows (Command Prompt or PowerShell)
setup.bat

# Linux / macOS / Git Bash
bash setup.sh
```

To reset the environment (drop DB and reinstall):

```bash
# Windows
setup.bat --reset

# Linux / macOS / Git Bash
bash setup.sh --reset
```

> **Note**: Moodle installation takes 15-25 minutes (200+ plugins). Please be patient.

## Quick Start (Manual)

If you prefer manual setup:

```bash
cd docker

# 1. Clone Moodle source (once only, ~500MB)
git clone --branch MOODLE_405_STABLE --depth 1 https://github.com/moodle/moodle.git moodle

# 2. Start containers
docker compose up -d

# 3. Wait for MySQL to be healthy (~30 seconds), then install Moodle
#    IMPORTANT: Use "docker exec" (not "docker compose exec") to avoid
#    Windows Git Bash path mangling issues.
docker exec jplms-moodle bash -c "php /var/www/html/admin/cli/install.php \
  --wwwroot='http://localhost:8880' \
  --dataroot='/var/www/moodledata' \
  --dbtype='mysqli' --dbhost='db' --dbname='moodle' --dbuser='moodle' --dbpass='moodle' \
  --fullname='Japan LMS Dev' --shortname='JPLMS' \
  --adminuser='admin' --adminpass='Admin1234!' --adminemail='admin@example.com' \
  --lang='ja' --agree-license --non-interactive"

# 4. Fix config.php permissions (required after install)
docker exec jplms-moodle bash -c "chmod 644 /var/www/html/config.php && chown www-data:www-data /var/www/html/config.php"

# 5. Fix double-slash path issue (Windows only)
docker exec jplms-moodle bash -c "sed -i 's|//var/www/moodledata|/var/www/moodledata|g' /var/www/html/config.php"

# 6. Reset admin password (ensures login works)
docker exec jplms-moodle bash -c "php /var/www/html/admin/cli/reset_password.php --username='admin' --password='Admin1234!'"
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

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Port 8880 in use | Another service on that port | Change port in docker-compose.yml |
| "Missing TABLES section" | Empty install.xml in a plugin | Delete install.xml until tables are defined |
| config.php permission denied | install.php creates as root:root 640 | `docker exec jplms-moodle bash -c "chmod 644 /var/www/html/config.php"` |
| Can't login after install | Password shell-escaping issue | Reset: `docker exec jplms-moodle bash -c "php /var/www/html/admin/cli/reset_password.php --username='admin' --password='Admin1234!'"` |
| `upgraderunning` lock | Previous install failed mid-way | `docker exec jplms-db mysql -u moodle -pmoodle moodle -e "DELETE FROM mdl_config WHERE name='upgraderunning';"` |
| Path has double-slash | Windows Git Bash path mangling | Use `docker exec` with `bash -c` instead of `docker compose exec` |

## Directory Structure

```
docker/
├── docker-compose.yml    # Container definitions
├── setup.sh              # Automated setup script (Linux/macOS/Git Bash)
├── setup.bat             # Automated setup script (Windows)
├── moodle/               # Moodle source (git cloned, NOT committed)
└── README.md             # This file
```

Note: `docker/moodle/` is gitignored. Each developer clones Moodle source locally.
