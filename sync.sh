#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Configuration with defaults
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"
REPO_LIMIT="${REPO_LIMIT:-200}"
CHECK_LOCAL_FOLDERS="${CHECK_LOCAL_FOLDERS:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${BOLD}=== GitHub Repository Sync ===${NC}"
echo ""

# Get list of repos from GitHub (name and HTTPS URL)
echo -e "${BLUE}Fetching repository list from GitHub...${NC}"
repos=$(gh repo list --limit "$REPO_LIMIT" --json name,url)

if [ -z "$repos" ]; then
    echo -e "${RED}ERROR: Failed to fetch repository list from GitHub${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}--- Syncing Repositories ---${NC}"
echo ""

# Helper function to find existing repo by URL
find_repo_by_url() {
    local search_url="$1"
    for dir in "$PROJECTS_DIR"/*/; do
        if [ -d "$dir/.git" ]; then
            local remote_url
            remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null)
            if [ "$remote_url" = "$search_url" ]; then
                echo "$dir"
                return 0
            fi
        fi
    done
    return 1
}

# Parse JSON and process each repo
echo "$repos" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//' | while read -r name; do
    url=$(echo "$repos" | grep -o "\"url\":\"[^\"]*/$name\"" | sed 's/"url":"//;s/"$//')

    # Check if repo already exists (by URL) in any folder
    existing_path=$(find_repo_by_url "$url")

    if [ -n "$existing_path" ]; then
        # Repo exists under a (possibly different) folder name
        repo_path="$existing_path"
        folder_name=$(basename "$repo_path")
        echo -e "${BLUE}Pulling${NC} $name (in $folder_name)..."
    elif [ -d "$PROJECTS_DIR/$name" ]; then
        # Folder exists with matching name but different/no remote
        repo_path="$PROJECTS_DIR/$name"
        echo -e "${BLUE}Pulling${NC} $name..."
    else
        # Clone missing repo
        echo -e "${GREEN}Cloning${NC} $name..."
        if ! git clone "$url" "$PROJECTS_DIR/$name"; then
            echo -e "${RED}ERROR: Failed to clone $name${NC}"
        fi
        echo ""
        continue
    fi

    cd "$repo_path"

    # Check if it's a git repo
    if [ ! -d ".git" ]; then
        echo -e "${RED}ERROR: $name exists but is not a git repository${NC}"
        echo ""
        continue
    fi

    # Stash any local changes
    stash_result=$(git stash push -m "auto-stash before sync" 2>&1)
    stashed=false
    if [[ "$stash_result" != *"No local changes"* ]]; then
        stashed=true
        echo -e "  ${YELLOW}Stashed local changes${NC}"
    fi

    # Pull latest
    if ! git pull; then
        echo -e "${RED}ERROR: Failed to pull $name${NC}"
    fi

    # Restore stashed changes if any
    if [ "$stashed" = true ]; then
        if ! git stash pop >/dev/null 2>&1; then
            echo -e "${YELLOW}WARNING: Failed to restore stashed changes in $name${NC}"
        else
            echo -e "  ${YELLOW}Restored stashed changes${NC}"
        fi
    fi
    echo ""
done

# Check for folders without git or without remote origin
if [ "$CHECK_LOCAL_FOLDERS" = "true" ]; then
    echo -e "${BOLD}--- Checking Local Folders ---${NC}"
    echo ""

    found_issues=false

    # Build list of remote URLs to detect duplicates
    declare -A url_to_folders
    for dir in "$PROJECTS_DIR"/*/; do
        if [ -d "$dir/.git" ]; then
            remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null)
            if [ -n "$remote_url" ]; then
                dir_name=$(basename "$dir")
                if [ -n "${url_to_folders[$remote_url]}" ]; then
                    url_to_folders["$remote_url"]="${url_to_folders[$remote_url]}, $dir_name"
                else
                    url_to_folders["$remote_url"]="$dir_name"
                fi
            fi
        fi
    done

    # Check for duplicates
    for url in "${!url_to_folders[@]}"; do
        folders="${url_to_folders[$url]}"
        if [[ "$folders" == *","* ]]; then
            echo -e "${YELLOW}WARNING:${NC} Duplicate repos found: $folders"
            found_issues=true
        fi
    done

    for dir in "$PROJECTS_DIR"/*/; do
        dir_name=$(basename "$dir")

        # Skip hidden directories
        if [[ "$dir_name" == .* ]]; then
            continue
        fi

        if [ ! -d "$dir/.git" ]; then
            echo -e "${YELLOW}WARNING:${NC} $dir_name has no git initialized"
            found_issues=true
        elif ! git -C "$dir" remote get-url origin >/dev/null 2>&1; then
            echo -e "${YELLOW}WARNING:${NC} $dir_name has no remote origin"
            found_issues=true
        fi
    done

    if [ "$found_issues" = false ]; then
        echo -e "${GREEN}All folders have git initialized with remote origins${NC}"
    fi

    echo ""
fi

echo -e "${BOLD}${GREEN}Sync complete.${NC}"
echo ""
