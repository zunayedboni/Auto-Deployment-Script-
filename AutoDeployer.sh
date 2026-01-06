#!/bin/bash

execution_conf() {

read -p "Please check the script (php version, Build command and composer path) before execution. (yes/no):" confirm
if  [ "$confirm" != "yes" ]; then
    echo "Deployment aborted by user."
    exit 0
fi
}

show_menu() {
    clear
    # Get branch name safely
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    # Handle upstream count calculation safely
    if git rev-parse --abbrev-ref HEAD@{upstream} >/dev/null 2>&1; then
        local upstream_count=$(git rev-list --count HEAD..origin/$branch 2>/dev/null)
    else
        local upstream_count=0  # No upstream configured
    fi

    echo -e "\e[1;36m"
    echo " ╔═════════════════════════════════════════════╗"
    echo -e " \e[0m  Current Branch: \e[1;32m$branch\e[0m "
    echo -e "   Pending Updates: \e[31m$upstream_count commit(s)\e[0m "
    echo " ╚═════════════════════════════════════════════╝"
    echo -e "\e[0m"
}
# Function to handle git pull and stash if necessary
git_pull_or_stash() {
    git config --global credential.helper store
    if ! git fetch; then
        echo "Git fetch failed. Exiting..."
        exit 1
    fi
    
    local branch=$(git rev-parse --abbrev-ref HEAD)
    local upstream_count=0

    

    # Check if the branch has an upstream
    if git rev-parse --abbrev-ref HEAD@{upstream} >/dev/null 2>&1; then
        upstream_count=$(git rev-list --count HEAD..origin/$branch)
    fi

    if [ "$upstream_count" -gt 0 ]; then
        echo -e "\e[33m▲ $upstream_count updates available\e[0m"
        # Check for local modifications
        if ! git diff-index --quiet HEAD --; then
            echo "Found local changes - stashing..."
            git stash save "Auto-stash for deployment"
        fi
        
        if ! git pull; then
            echo "Error: Could not integrate changes. Check for conflicts."
            exit 1
        fi
    else
        echo -e "\e[32m✓ Repository current\e[0m"
    fi
}
# Function for backend deployment (NB: Change PHP version with path) use command "which" to get the path
deploy_backend() {
    cd backend || { echo "Failed to change directory to backend. Exiting..."; exit 1; }
    # Check Php and Composer Path
    local COMPOSER_=$(which composer)
    /usr/bin/php8.3 $COMPOSER_ update || { echo "Composer update failed. Exiting..."; exit 1; }
    /usr/bin/php8.3 artisan migrate || { echo "Artisan migrate failed. Exiting..."; exit 1; }
    
    #Comment Out these seeders if not needed.
     /usr/bin/php8.3 artisan db:seed --class=ShopfloorSuiteIdGeneratorSeeder || { echo "ShopfloorSuiteIdGeneratorSeeder seeding failed. Exiting..."; exit 1; }
 #   /usr/bin/php8.3 artisan db:seed --class=RoleSeeder || { echo "RoleSeeder seeding failed. Exiting..."; exit 1; }
    /usr/bin/php8.3 artisan optimize:clear || { echo "Optimize clear failed. Exiting..."; exit 1; }
    sudo supervisorctl restart laravel-worker:* || { echo "Laravel worker restart failed. Exiting..."; exit 1; }
    sudo supervisorctl restart scheduler-worker:* || { echo "Scheduler worker restart failed. Exiting..."; exit 1; }
    cd ..
}

# Function for frontend deployment
deploy_frontend() {
    local dir=$1
    local version=$2
    cd "$dir" || { echo "Failed to change directory to $dir. Exiting..."; exit 1; }
 #  cp src/assets/configs/config.development.example.json src/assets/configs/config.json || { echo "Failed to copy config file. Exiting..."; exit 1; }
    npm i || { echo "NPM install failed. Exiting..."; exit 1; }
    
    # Changes will be made based on requirements for multi-version deployment and low memory
            
    if [ "$version" == "v12" ]; then
    #This builds version 12
        node --max_old_space_size=12288 ./node_modules/@angular/cli/bin/ng build --base-href /v12/ --localize --configuration=production --no-source-map || { echo "NG build for v12 failed. Exiting..."; exit 1; }
    else
    # This builds Version 11
        ng build --base-href /v11/ --localize --configuration=production --no-source-map || { echo "NG build for v11 failed. Exiting..."; exit 1; }
    fi
    cd ..
}


# Main flow
show_menu
execution_conf
# Main script execution
git_pull_or_stash
# Deploy backend
deploy_backend
# Deploy frontend for both versions (Comment which one you dont want, and make changes in NG BUILD command too)
deploy_frontend "frontend" "v11"
deploy_frontend "frontend-sap" "v12"

echo "Deployment completed successfully."
echo "Please Check And Then Confirm..."





# Script By Zeha
