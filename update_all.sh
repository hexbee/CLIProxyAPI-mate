#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
LOG_ROOT="${SCRIPT_DIR}/tmp/update-all"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${LOG_ROOT}/${RUN_ID}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR}" ]; then
        rm -rf "${TMP_DIR}"
    fi
}

run_job() {
    local key="$1"
    local script_name="$2"
    local log_path="${LOG_DIR}/${key}.log"
    local status_path="${TMP_DIR}/${key}.status"

    if bash "${SCRIPT_DIR}/${script_name}" >"${log_path}" 2>&1; then
        printf '0\n' >"${status_path}"
    else
        printf '%s\n' "$?" >"${status_path}"
    fi
}

extract_summary_value() {
    local summary_line="$1"
    local field_name="$2"

    printf '%s\n' "${summary_line}" | tr '|' '\n' | sed -n "s/^${field_name}=//p" | head -n 1
}

print_summary() {
    local failures=0
    local key=""
    local script_name=""
    local display_name=""
    local status_path=""
    local log_path=""
    local exit_code=""
    local version_summary=""
    local old_version=""
    local new_version=""

    echo
    echo "Summary:"

    while IFS='|' read -r key script_name display_name; do
        status_path="${TMP_DIR}/${key}.status"
        log_path="${LOG_DIR}/${key}.log"
        exit_code="1"

        if [ -f "${status_path}" ]; then
            exit_code="$(cat "${status_path}")"
        fi

        version_summary="$(grep 'VERSION_SUMMARY|' "${log_path}" | tail -n 1 || true)"
        old_version=""
        new_version=""

        if [ -n "${version_summary}" ]; then
            old_version="$(extract_summary_value "${version_summary}" "old")"
            new_version="$(extract_summary_value "${version_summary}" "new")"
        fi

        if [ "${exit_code}" = "0" ]; then
            if [ -n "${old_version}" ] || [ -n "${new_version}" ]; then
                echo -e "${GREEN}[OK]${NC} ${display_name}: ${old_version:-unknown} -> ${new_version:-unknown}"
            else
                echo -e "${GREEN}[OK]${NC} ${display_name}"
            fi
        else
            failures=1
            if [ -n "${old_version}" ] || [ -n "${new_version}" ]; then
                echo -e "${RED}[FAIL]${NC} ${display_name}: ${old_version:-unknown} -> ${new_version:-unknown}"
            else
                echo -e "${RED}[FAIL]${NC} ${display_name}"
            fi
            echo "Script: ${script_name}"
            echo "Log: ${log_path}"
        fi
    done <<'EOF'
cliproxyapiplus|update_cliproxyapiplus.sh|CLIProxyAPIPlus
claude|update_claude_code.sh|Claude Code
codex|update_openai_codex.sh|OpenAI Codex
EOF

    return "${failures}"
}

main() {
    local pid_cliproxyapiplus=""
    local pid_claude=""
    local pid_codex=""

    trap cleanup EXIT

    mkdir -p "${LOG_DIR}"

    echo -e "${YELLOW}Starting parallel updates...${NC}"
    echo "Logs: ${LOG_DIR}"

    run_job "cliproxyapiplus" "update_cliproxyapiplus.sh" &
    pid_cliproxyapiplus=$!

    run_job "claude" "update_claude_code.sh" &
    pid_claude=$!

    run_job "codex" "update_openai_codex.sh" &
    pid_codex=$!

    wait "${pid_cliproxyapiplus}" || true
    wait "${pid_claude}" || true
    wait "${pid_codex}" || true

    if print_summary; then
        echo
        echo -e "${GREEN}All update scripts completed successfully.${NC}"
        exit 0
    fi

    echo
    echo -e "${RED}One or more update scripts failed.${NC}"
    exit 1
}

main "$@"
