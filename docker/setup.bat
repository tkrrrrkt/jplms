@echo off
REM ===========================================
REM Japan LMS MVP - Docker Environment Setup (Windows)
REM ===========================================
REM Usage:
REM   cd docker
REM   setup.bat              Full setup (clone + install)
REM   setup.bat --reset      Reset DB and reinstall
REM
REM Result:
REM   Moodle 4.5 at http://localhost:8880
REM   Admin login: admin / Admin1234!
REM ===========================================

setlocal enabledelayedexpansion

cd /d "%~dp0"

set "MOODLE_BRANCH=MOODLE_405_STABLE"
set "MOODLE_DIR=moodle"
set "CONTAINER=jplms-moodle"
set "DB_CONTAINER=jplms-db"

REM --- Parse arguments ---
set "RESET_MODE=0"
if "%~1"=="--reset" set "RESET_MODE=1"

REM ===========================================
REM Step 1: Clone Moodle source
REM ===========================================
if exist "%MOODLE_DIR%\lib" (
    echo [INFO] Moodle source already exists -- skipping clone.
) else (
    echo [INFO] Cloning Moodle (%MOODLE_BRANCH%) ... This may take a few minutes.
    git clone --branch %MOODLE_BRANCH% --depth 1 https://github.com/moodle/moodle.git %MOODLE_DIR%
    if errorlevel 1 (
        echo [ERROR] Failed to clone Moodle.
        exit /b 1
    )
    echo [INFO] Moodle source cloned successfully.
)

REM ===========================================
REM Step 2: Reset mode
REM ===========================================
if "%RESET_MODE%"=="1" (
    echo [WARN] Reset mode: stopping containers and removing volumes...
    docker compose down -v 2>nul
    echo [INFO] Volumes removed.
)

REM ===========================================
REM Step 3: Start Docker containers
REM ===========================================
echo [INFO] Starting Docker containers...
docker compose up -d
if errorlevel 1 (
    echo [ERROR] Failed to start Docker containers.
    exit /b 1
)

REM Wait for MySQL
echo [INFO] Waiting for MySQL to be healthy...
set "RETRIES=30"
:wait_mysql
docker exec %DB_CONTAINER% mysqladmin ping -h localhost -u root -prootpassword --silent 2>nul
if errorlevel 1 (
    set /a RETRIES-=1
    if !RETRIES! leq 0 (
        echo [ERROR] MySQL did not become healthy.
        exit /b 1
    )
    timeout /t 2 /nobreak >nul
    goto wait_mysql
)
echo [INFO] MySQL is healthy.
timeout /t 3 /nobreak >nul

REM ===========================================
REM Step 4: Check if already installed
REM ===========================================
docker exec %CONTAINER% test -f /var/www/html/config.php 2>nul
if not errorlevel 1 (
    for /f %%i in ('docker exec %DB_CONTAINER% mysql -u moodle -pmoodle moodle -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodle';" 2^>nul') do set "TABLE_COUNT=%%i"
    if !TABLE_COUNT! gtr 10 (
        echo [INFO] Moodle is already installed. Skipping install.
        goto fix_permissions
    )
)

REM ===========================================
REM Step 5: Install Moodle
REM ===========================================
echo [INFO] Installing Moodle via CLI... This takes 15-25 minutes.
echo [INFO] Please be patient.

docker exec %CONTAINER% bash -c "php /var/www/html/admin/cli/install.php --wwwroot='http://localhost:8880' --dataroot='/var/www/moodledata' --dbtype='mysqli' --dbhost='db' --dbname='moodle' --dbuser='moodle' --dbpass='moodle' --fullname='Japan LMS Dev' --shortname='JPLMS' --adminuser='admin' --adminpass='Admin1234!' --adminemail='admin@example.com' --lang='ja' --agree-license --non-interactive"

if errorlevel 1 (
    echo [ERROR] Moodle installation failed.
    exit /b 1
)
echo [INFO] Moodle installation completed.

REM ===========================================
REM Step 6: Fix permissions
REM ===========================================
:fix_permissions
echo [INFO] Fixing config.php permissions...
docker exec %CONTAINER% bash -c "chmod 644 /var/www/html/config.php && chown www-data:www-data /var/www/html/config.php"

REM Fix double-slash issue
docker exec %CONTAINER% bash -c "sed -i 's|//var/www/moodledata|/var/www/moodledata|g' /var/www/html/config.php" 2>nul

REM ===========================================
REM Step 7: Reset admin password
REM ===========================================
echo [INFO] Resetting admin password...
docker exec %CONTAINER% bash -c "php /var/www/html/admin/cli/reset_password.php --username='admin' --password='Admin1234!'" 2>nul

REM ===========================================
REM Step 8: Fix moodledata permissions
REM ===========================================
docker exec %CONTAINER% bash -c "chown -R www-data:www-data /var/www/moodledata" 2>nul

REM ===========================================
REM Done
REM ===========================================
echo.
echo =========================================
echo   Setup complete!
echo =========================================
echo   URL:   http://localhost:8880
echo   Login: admin / Admin1234!
echo =========================================
echo.

endlocal
