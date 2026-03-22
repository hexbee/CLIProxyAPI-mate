#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
readonly LOG_ROOT="${SCRIPT_DIR}/tmp/update-all"
readonly RUN_ID="$(date +%Y%m%d-%H%M%S)"
readonly LOG_DIR="${LOG_ROOT}/${RUN_ID}"
readonly JOBS=(
    "cliproxyapiplus|update_cliproxyapiplus.sh|CLIProxyAPIPlus"
    "claude|update_claude_code.sh|Claude Code"
    "codex|update_openai_codex.sh|OpenAI Codex"
)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR}" ]; then
        rm -rf "${TMP_DIR}"
    fi
}

run_job_and_capture_status() {
    local job_key="$1"
    local script_name="$2"
    local log_path="${LOG_DIR}/${job_key}.log"
    local status_path="${TMP_DIR}/${job_key}.status"

    if bash "${SCRIPT_DIR}/${script_name}" >"${log_path}" 2>&1; then
        printf '0\n' >"${status_path}"
    else
        printf '%s\n' "$?" >"${status_path}"
    fi
}

parse_version_summary() {
    local summary_line="$1"
    parsed_old_version=""
    parsed_new_version=""

    while IFS='=' read -r key value; do
        case "${key}" in
            old)
                parsed_old_version="${value}"
                ;;
            new)
                parsed_new_version="${value}"
                ;;
        esac
    done < <(printf '%s\n' "${summary_line}" | tr '|' '\n' | sed '1d')
}

read_exit_code() {
    local status_path="$1"

    if [ -f "${status_path}" ]; then
        tr -d '\n' <"${status_path}"
        return
    fi

    printf '1'
}

read_version_summary() {
    local log_path="$1"

    sed -n '/VERSION_SUMMARY|/h; ${g;p;}' "${log_path}" 2>/dev/null || true
}

read_job_result() {
    local job_definition="$1"

    IFS='|' read -r result_key result_script_name result_display_name <<<"${job_definition}"
    result_status_path="${TMP_DIR}/${result_key}.status"
    result_log_path="${LOG_DIR}/${result_key}.log"
    result_exit_code="$(read_exit_code "${result_status_path}")"

    local version_summary=""
    version_summary="$(read_version_summary "${result_log_path}")"
    parse_version_summary "${version_summary}"

    result_old_version="${parsed_old_version}"
    result_new_version="${parsed_new_version}"
}

print_job_result() {
    local summary_text="${result_display_name}"

    if [ -n "${result_old_version}" ] || [ -n "${result_new_version}" ]; then
        summary_text="${summary_text}: ${result_old_version:-unknown} -> ${result_new_version:-unknown}"
    fi

    if [ "${result_exit_code}" = "0" ]; then
        echo -e "${GREEN}[OK]${NC} ${summary_text}"
        return 0
    fi

    echo -e "${RED}[FAIL]${NC} ${summary_text}"
    echo "Script: ${result_script_name}"
    echo "Log: ${result_log_path}"
    return 1
}

print_summary() {
    local failures=0

    echo
    echo "Summary:"

    for job_definition in "${JOBS[@]}"; do
        read_job_result "${job_definition}"
        if ! print_job_result; then
            failures=1
        fi
    done

    return "${failures}"
}

main() {
    local pids=()
    local job_definition=""
    local key=""
    local script_name=""
    local display_name=""

    trap cleanup EXIT

    mkdir -p "${LOG_DIR}"

    echo -e "${YELLOW}Starting parallel updates...${NC}"
    echo "Logs: ${LOG_DIR}"

    for job_definition in "${JOBS[@]}"; do
        IFS='|' read -r key script_name display_name <<<"${job_definition}"
        run_job_and_capture_status "${key}" "${script_name}" &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        wait "${pid}" || true
    done

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
