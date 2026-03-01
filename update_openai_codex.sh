#!/bin/bash

set -euo pipefail

PACKAGE_NAME="@openai/codex"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_final_version() {
    echo
    echo -e "${YELLOW}Checking final codex version...${NC}"

    if ! command -v codex >/dev/null 2>&1; then
        echo -e "${RED}Error: 'codex' command not found after update check.${NC}"
        exit 1
    fi

    codex --version
}

version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | tail -n 1)" = "$1" && [ "$1" != "$2" ]
}

echo -e "${YELLOW}Checking global ${PACKAGE_NAME} version...${NC}"

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}Error: 'npm' command not found.${NC}"
    exit 1
fi

latest_version=$(npm view "${PACKAGE_NAME}" version 2>/dev/null)

if [ -z "${latest_version}" ]; then
    echo -e "${RED}Error: failed to fetch the latest version from npm.${NC}"
    exit 1
fi

local_version=$(
    {
        npm list -g "${PACKAGE_NAME}" --depth=0 --json 2>/dev/null || true
    } | node -e 'let input=""; process.stdin.on("data", chunk => input += chunk); process.stdin.on("end", () => { try { const data = JSON.parse(input); process.stdout.write(data.dependencies?.["@openai/codex"]?.version || ""); } catch { process.stdout.write(""); } });'
)

if [ -n "${local_version}" ]; then
    echo "Local version: ${local_version}"
else
    echo "Local version: not installed"
fi

echo "Latest version: ${latest_version}"

if [ -z "${local_version}" ]; then
    echo -e "${YELLOW}${PACKAGE_NAME} is not installed globally. Installing latest...${NC}"
    npm i -g "${PACKAGE_NAME}@latest"
elif version_gt "${latest_version}" "${local_version}"; then
    echo -e "${YELLOW}New version detected. Updating ${PACKAGE_NAME}...${NC}"
    npm i -g "${PACKAGE_NAME}@latest"
else
    echo -e "${GREEN}${PACKAGE_NAME} is already up to date.${NC}"
fi

print_final_version
