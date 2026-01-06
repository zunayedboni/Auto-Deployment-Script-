# Schertech Shopfloor Deployment Script

This repository contains an interactive Bash script to **deploy the Shopfloor backend and frontend (v11 & v12)** from Git, run Laravel migrations/seeders, and build Angular applications with version‑specific commands.

The script is designed to be run **on an already configured server** where PHP, Composer, Node.js, npm, Supervisor, and all runtime dependencies are installed and working.

---

## Features

- Shows current Git branch and pending upstream commits.
- Safely fetches updates from the remote repository.
- Auto‑stashes local changes before pulling (if needed).
- Deploys Laravel backend:
  - `composer update`
  - `php artisan migrate`
  - optional seeders
  - `php artisan optimize:clear`
  - restarts Supervisor workers
- Deploys Angular frontends:
  - `frontend` (v11)
  - `frontend-sap` (v12)
  - Version‑specific `ng build` commands with `--base-href`, `--localize`, and `--no-source-map`.
- Basic safety checks and early exit on failure.

---

## Prerequisites

Before running this script, ensure:

- You are on a **Linux** server (e.g. Ubuntu).
- The **Shopfloor repository** is already cloned and you run the script from **its root**:
  - The following directories must exist:
    - `backend`
    - `frontend`
    - `frontend-sap`
- Installed and correctly configured:
  - PHP CLI (matching the version in the script, default `/usr/bin/php8.3`)
  - Composer (`composer` in PATH)
  - Node.js and npm
  - Angular CLI (globally or via `node_modules`)
  - Supervisor (`supervisorctl` available)
- Supervisor programs:
  - `laravel-worker:*`
  - `scheduler-worker:*`
- Correct `.env` configuration in `backend` and proper DB connection.

---

## Script Overview

### 1. Execution Confirmation
```bash
execution_conf() {
    read -p "Please check the script (php version, Build command and composer path) before execution. (yes/no):" confirm
    if  [ "$confirm" != "yes" ]; then
        echo "Deployment aborted by user."
        exit 0
    fi
}
```
Asks you to confirm you have checked:

PHP version

Angular build commands

Composer path

Aborts if you do not type yes.

2. Status Banner
```bash
show_menu() {
    clear
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if git rev-parse --abbrev-ref HEAD@{upstream} >/dev/null 2>&1; then
        local upstream_count=$(git rev-list --count HEAD..origin/$branch 2>/dev/null)
    else
        local upstream_count=0
    fi
    # Prints branch and pending updates
}
```
Displays:

Current Git branch.

Number of commits ahead on origin (pending updates).
```bash
3. Git Fetch / Pull with Auto‑Stash
bash
git_pull_or_stash() {
    git config --global credential.helper store
    git fetch
    # If upstream exists and commits are pending:
    #   - stash local changes
    #   - git pull
}
```
Fetches remote changes.

If the current branch has an upstream and there are new commits:

Stashes local changes (if any).

Pulls latest changes.

If repository is already up‑to‑date, prints a success message.

4. Backend Deployment
```bash
deploy_backend() {
    cd backend || { echo "Failed to change directory to backend. Exiting..."; exit 1; }

    local COMPOSER_=$(which composer)
    /usr/bin/php8.3 $COMPOSER_ update || { echo "Composer update failed. Exiting..."; exit 1; }
    /usr/bin/php8.3 artisan migrate || { echo "Artisan migrate failed. Exiting..."; exit 1; }

    /usr/bin/php8.3 artisan db:seed --class=ShopfloorSuiteIdGeneratorSeeder || { echo "ShopfloorSuiteIdGeneratorSeeder seeding failed. Exiting..."; exit 1; }
    # /usr/bin/php8.3 artisan db:seed --class=RoleSeeder ...

    /usr/bin/php8.3 artisan optimize:clear || { echo "Optimize clear failed. Exiting..."; exit 1; }

    sudo supervisorctl restart laravel-worker:* || { echo "Laravel worker restart failed. Exiting..."; exit 1; }
    sudo supervisorctl restart scheduler-worker:* || { echo "Scheduler worker restart failed. Exiting..."; exit 1; }
    cd ..
}
```
Runs backend deployment steps:
```bash
composer update (using system composer).

Database migrations.

Seeders (with one enabled by default).

Clears Laravel caches.

Restarts Supervisor workers.
```
Adjust /usr/bin/php8.3 to match your PHP CLI path, and comment/uncomment seeders as needed.

5. Frontend Deployment (v11 & v12)
```bash
deploy_frontend() {
    local dir=$1
    local version=$2
    cd "$dir" || { echo "Failed to change directory to $dir. Exiting..."; exit 1; }
    npm i || { echo "NPM install failed. Exiting..."; exit 1; }

    if [ "$version" == "v12" ]; then
        node --max_old_space_size=12288 ./node_modules/@angular/cli/bin/ng build --base-href /v12/ --localize --configuration=production --no-source-map
    else
        ng build --base-href /v11/ --localize --configuration=production --no-source-map
    fi

    cd ..
}
```
For each frontend directory:

``Runs npm i.``

For v12:

Uses Node with increased memory (--max_old_space_size=12288) and local CLI binary.

For v11:

Uses global ng build.

Both build commands:

Use --base-href (/v11/ or /v12/)

Enable --localize

Disable source maps (--no-source-map).

Main Flow
At the bottom of the script:

```bash
show_menu
execution_conf
git_pull_or_stash
deploy_backend
deploy_frontend "frontend" "v11"
deploy_frontend "frontend-sap" "v12"

echo "Deployment completed successfully."
echo "Please Check And Then Confirm..."

# Script By Zeha
```
Execution order:

Show Git status banner.

Ask for final confirmation.

Update the repository safely.

Deploy backend.

Deploy frontend v11.

Deploy frontend v12.

Print completion message.

Usage
Place the script in the root of your Shopfloor repository (same level as backend/, frontend/, frontend-sap/).

Make it executable:

bash
chmod +x deploy.sh
(Rename deploy.sh to your actual script name.)

Run it:

```bash
./deploy.sh
```
When prompted:

Confirm you have checked PHP version, build commands, and Composer path.

Let the script update Git, deploy backend, and build frontends.

Customization
PHP path / version
Update /usr/bin/php8.3 to match your PHP binary if different.

Composer command
If Composer is not in PATH, hard‑code COMPOSER_ to an explicit path.

Seeders
Uncomment or comment seeder lines depending on environment (e.g. disable on production if not needed on every deploy).

Angular builds
Change --base-href, --localize, --configuration, and memory limits based on your environment and Angular setup.

Supervisor programs
Adjust laravel-worker:* and scheduler-worker:* to match your Supervisor program names.
