#!/bin/bash

set -euo pipefail

CHANGELOG_URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_version_summary() {
    local old_version="${1:-not installed}"
    local new_version="${2:-unknown}"
    echo "VERSION_SUMMARY|old=${old_version}|new=${new_version}"
}

version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

echo -e "${YELLOW}Checking Claude Code version...${NC}"

if ! command -v claude >/dev/null 2>&1; then
    echo -e "${RED}Error: 'claude' command not found. Visit https://code.claude.com/docs/en/quickstart for installation instructions.${NC}"
    exit 1
fi

local_version="$(claude --version | awk '{print $1}')"
echo "Local version: $local_version"

latest_version="$(curl -sL "$CHANGELOG_URL" | grep -E "^##? \[?[0-9]+\.[0-9]+\.[0-9]+" | head -n 1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")"

if [ -z "$latest_version" ]; then
    echo -e "${RED}Error: failed to fetch the remote version. Check your network connection.${NC}"
    exit 1
fi

echo "Latest version: $latest_version"

if [ "$local_version" = "$latest_version" ]; then
    print_version_summary "$local_version" "$local_version"
    echo -e "${GREEN}Claude Code is already up to date.${NC}"
    exit 0
fi

if version_gt "$latest_version" "$local_version"; then
    echo -e "${YELLOW}New version detected. Preparing update...${NC}"
    echo "Running command: claude install $latest_version"
    claude install "$latest_version"

    new_ver="$(claude --version | awk '{print $1}')"
    echo -e "${GREEN}Update completed successfully.${NC}"
    echo "Current version: $new_ver"
    print_version_summary "$local_version" "$new_ver"
    exit 0
fi

print_version_summary "$local_version" "$local_version"
echo -e "${GREEN}Local version ($local_version) is newer than or equal to changelog version ($latest_version).${NC}"
