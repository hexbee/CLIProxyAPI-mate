#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPO="router-for-me/CLIProxyAPI"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${SCRIPT_DIR}/CLIProxyAPI}"
CHECK_ONLY=0
DRY_RUN=0
FORCE_INSTALL=0
ALLOW_DOWNGRADE=0
KEEP_TEMP=0
TARGET_TAG=""
JSON_PARSER="shell"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cleanup() {
    if [ "${KEEP_TEMP}" -eq 1 ] && [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR}" ]; then
        echo -e "${YELLOW}Keeping temporary files at ${TMP_DIR}${NC}"
        return
    fi

    if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR}" ]; then
        rm -rf "${TMP_DIR}"
    fi
}

print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_error "'$1' command not found."
        exit 1
    fi
}

print_usage() {
    cat <<EOF
Usage: bash update_cliproxyapi.sh [options]

Options:
  --check-only                 Only print local and target version information.
  --dry-run                    Print the planned actions without making changes.
  --force                      Reinstall even when the local version matches the target version.
  --allow-downgrade            Allow installing an older target version.
  --keep-temp                  Keep downloaded archives and extracted temporary files.
  --target-version <tag>       Install a specific release tag, for example: v6.8.35
  --help                       Show this help message.
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --check-only)
                CHECK_ONLY=1
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            --force)
                FORCE_INSTALL=1
                ;;
            --allow-downgrade)
                ALLOW_DOWNGRADE=1
                ;;
            --keep-temp)
                KEEP_TEMP=1
                ;;
            --target-version)
                shift
                if [ "$#" -eq 0 ]; then
                    print_error "--target-version requires a value."
                    exit 1
                fi
                TARGET_TAG="$1"
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                print_error "unknown argument: $1"
                print_usage
                exit 1
                ;;
        esac
        shift
    done
}

header_value() {
    local header_file="$1"
    local header_name="$2"

    awk -F': ' -v name="$header_name" 'BEGIN { IGNORECASE = 1 } $1 == name { gsub(/\r/, "", $2); print $2; exit }' "${header_file}"
}

format_reset_time() {
    local reset_ts="$1"
    local formatted=""

    if formatted="$(LC_ALL=C date -d "@${reset_ts}" '+%I:%M:%S %p' 2>/dev/null)"; then
        echo "${formatted}"
        return
    fi

    if formatted="$(LC_ALL=C date -r "${reset_ts}" '+%I:%M:%S %p' 2>/dev/null)"; then
        echo "${formatted}"
        return
    fi

    echo "${reset_ts}"
}

normalize_version() {
    local version="$1"
    version="${version#v}"
    version="${version%-plus}"
    echo "${version}"
}

fetch_target_release() {
    local headers_file="${TMP_DIR}/github-headers.txt"
    local api_url=""

    RELEASE_JSON_PATH="${TMP_DIR}/github-release.json"

    if [ -n "${TARGET_TAG}" ]; then
        TARGET_TAG="v$(normalize_version "${TARGET_TAG}")"
        api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TARGET_TAG}"
        echo -e "${YELLOW}Fetching release metadata for ${TARGET_TAG} from GitHub...${NC}"
    else
        api_url="${GITHUB_API_URL}"
        echo -e "${YELLOW}Fetching latest release metadata from GitHub...${NC}"
    fi

    if ! curl -fsSL -D "${headers_file}" -H "Accept: application/vnd.github+json" "${api_url}" -o "${RELEASE_JSON_PATH}"; then
        if [ -n "${TARGET_TAG}" ]; then
            print_error "failed to fetch release metadata for ${TARGET_TAG}."
        else
            print_error "failed to fetch the latest release metadata."
        fi
        exit 1
    fi

    if command -v jq >/dev/null 2>&1; then
        JSON_PARSER="jq"
        RELEASE_TAG="$(jq -r '.tag_name // empty' "${RELEASE_JSON_PATH}")"
    else
        JSON_PARSER="shell"
        RELEASE_TAG="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "${RELEASE_JSON_PATH}" | head -n 1)"
    fi

    if [ -z "${RELEASE_TAG}" ]; then
        print_error "failed to parse tag_name from GitHub API response."
        exit 1
    fi

    VERSION="$(normalize_version "${RELEASE_TAG}")"

    local rate_limit rate_remaining rate_reset reset_display
    rate_limit="$(header_value "${headers_file}" "X-RateLimit-Limit")"
    rate_remaining="$(header_value "${headers_file}" "X-RateLimit-Remaining")"
    rate_reset="$(header_value "${headers_file}" "X-RateLimit-Reset")"

    if [ -n "${rate_limit}" ] && [ -n "${rate_remaining}" ] && [ -n "${rate_reset}" ]; then
        reset_display="$(format_reset_time "${rate_reset}")"
        echo "GitHub API: ${rate_remaining} / ${rate_limit} remaining | reset ${reset_display}"
    fi

    if [ -n "${TARGET_TAG}" ]; then
        echo "Target release: ${RELEASE_TAG}"
    else
        echo "Latest release: ${RELEASE_TAG}"
    fi
    echo "JSON parser: ${JSON_PARSER}"
}

extract_asset_names() {
    if [ "${JSON_PARSER}" = "jq" ]; then
        jq -r '.assets[]?.name // empty' "${RELEASE_JSON_PATH}"
        return
    fi

    awk '
        /"assets":[[:space:]]*\[/ { in_assets=1; next }
        in_assets && /^[[:space:]]*]/ { in_assets=0 }
        in_assets && /"name":[[:space:]]*"/ {
            line=$0
            sub(/.*"name":[[:space:]]*"/, "", line)
            sub(/".*/, "", line)
            print line
        }
    ' "${RELEASE_JSON_PATH}"
}

list_available_assets() {
    extract_asset_names | while IFS= read -r asset_name; do
        if [ -n "${asset_name}" ]; then
            echo "  - ${asset_name}"
        fi
    done
}

validate_release_asset() {
    if extract_asset_names | grep -Fx "${PACKAGE_NAME}" >/dev/null 2>&1; then
        return
    fi

    print_error "expected asset not found for this platform: ${PACKAGE_NAME}"
    echo "Available assets:"
    list_available_assets
    exit 1
}

map_arch() {
    case "$1" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            return 1
            ;;
    esac
}

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(map_arch "$(uname -m)")" || {
        print_error "unsupported architecture: $(uname -m)"
        exit 1
    }

    case "${os}" in
        Linux*)
            PLATFORM="linux"
            ARCHIVE_EXT="tar.gz"
            BINARY_NAME="cli-proxy-api"
            ;;
        Darwin*)
            PLATFORM="darwin"
            ARCHIVE_EXT="tar.gz"
            BINARY_NAME="cli-proxy-api"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            PLATFORM="windows"
            ARCHIVE_EXT="zip"
            BINARY_NAME="cli-proxy-api.exe"
            ;;
        *)
            print_error "unsupported platform: ${os}"
            exit 1
            ;;
    esac

    PACKAGE_NAME="CLIProxyAPI_${VERSION}_${PLATFORM}_${arch}.${ARCHIVE_EXT}"
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${PACKAGE_NAME}"
    PLATFORM_LABEL="${PLATFORM}/${arch}"
}

detect_local_version() {
    local binary_path="${INSTALL_DIR}/${BINARY_NAME}"

    LOCAL_VERSION=""

    if [ ! -f "${binary_path}" ]; then
        echo "Local version: not installed"
        return
    fi

    local help_output raw_version
    if ! help_output="$("${binary_path}" --help 2>&1)"; then
        print_error "failed to execute '${binary_path} --help' to detect the local version."
        exit 1
    fi

    raw_version="$(printf '%s\n' "${help_output}" | sed -n 's/^CLIProxyAPI Version:[[:space:]]*\([^,[:space:]]*\).*/\1/p' | head -n 1)"

    if [ -z "${raw_version}" ]; then
        print_error "failed to parse the local version from '${binary_path} --help'."
        exit 1
    fi

    LOCAL_VERSION="$(normalize_version "${raw_version}")"
    echo "Local version: ${raw_version}"
}

version_gt() {
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ] && [ "$1" != "$2" ]
}

print_planned_actions() {
    echo "Planned action summary:"
    echo "  Platform: ${PLATFORM_LABEL}"
    echo "  Install directory: ${INSTALL_DIR}"
    echo "  Target release: ${RELEASE_TAG}"
    echo "  Target package: ${PACKAGE_NAME}"
    echo "  Download URL: ${DOWNLOAD_URL}"
    echo "  JSON parser: ${JSON_PARSER}"
    echo "  Keep temp files: ${KEEP_TEMP}"

    if [ -z "${LOCAL_VERSION}" ]; then
        echo "  Local status: not installed"
        echo "  Decision: fresh install"
        return
    fi

    echo "  Local normalized version: ${LOCAL_VERSION}"

    if [ "${LOCAL_VERSION}" = "${VERSION}" ]; then
        if [ "${FORCE_INSTALL}" -eq 1 ]; then
            echo "  Decision: reinstall same version due to --force"
        else
            echo "  Decision: already up to date, would exit"
        fi
        return
    fi

    if version_gt "${LOCAL_VERSION}" "${VERSION}"; then
        if [ "${ALLOW_DOWNGRADE}" -eq 1 ]; then
            echo "  Decision: downgrade install allowed by --allow-downgrade"
        else
            echo "  Decision: downgrade detected, would exit"
        fi
        return
    fi

    echo "  Decision: update to newer version"
}

ensure_non_interactive_downgrade_allowed() {
    if [ "${ALLOW_DOWNGRADE}" -eq 1 ]; then
        echo -e "${YELLOW}Downgrade allowed by --allow-downgrade.${NC}"
        return
    fi

    print_error "local version (${LOCAL_VERSION}) is newer than target version (${VERSION}). Re-run with --allow-downgrade to continue."
    exit 1
}

extract_archive() {
    mkdir -p "${EXTRACT_DIR}"

    if [ "${PLATFORM}" = "windows" ]; then
        require_command unzip
        unzip -oq "${ARCHIVE_PATH}" -d "${EXTRACT_DIR}"
    else
        require_command tar
        tar -xzf "${ARCHIVE_PATH}" -C "${EXTRACT_DIR}"
    fi
}

resolve_package_root() {
    shopt -s nullglob dotglob
    local entries=("${EXTRACT_DIR}"/*)
    shopt -u nullglob dotglob

    if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
        PACKAGE_ROOT="${entries[0]}"
    else
        PACKAGE_ROOT="${EXTRACT_DIR}"
    fi
}

backup_existing_config() {
    BACKUP_NAME=""

    if [ -f "${INSTALL_DIR}/config.yaml" ]; then
        local timestamp
        timestamp="$(date +%Y%m%d-%H%M%S)"
        BACKUP_NAME="config.${timestamp}.yaml"
        cp "${INSTALL_DIR}/config.yaml" "${TMP_DIR}/${BACKUP_NAME}"
        echo -e "${YELLOW}Backed up existing config.yaml to ${BACKUP_NAME}.${NC}"
    fi
}

install_release() {
    rm -rf "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    cp -a "${PACKAGE_ROOT}/." "${INSTALL_DIR}/"

    if [ ! -f "${INSTALL_DIR}/config.example.yaml" ]; then
        print_error "config.example.yaml not found in the extracted package."
        exit 1
    fi

    mv -f "${INSTALL_DIR}/config.example.yaml" "${INSTALL_DIR}/config.yaml"

    if [ -n "${BACKUP_NAME}" ]; then
        cp "${TMP_DIR}/${BACKUP_NAME}" "${INSTALL_DIR}/${BACKUP_NAME}"
    fi

    if [ ! -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        print_error "expected binary '${BINARY_NAME}' not found after installation."
        exit 1
    fi
}

verify_installed_version() {
    detect_local_version

    if [ -z "${LOCAL_VERSION}" ]; then
        print_error "failed to verify the installed version after installation."
        exit 1
    fi

    if [ "${LOCAL_VERSION}" != "${VERSION}" ]; then
        print_error "installed version mismatch. Expected ${VERSION}, got ${LOCAL_VERSION}."
        exit 1
    fi

    echo -e "${GREEN}Verified installed version: ${LOCAL_VERSION}${NC}"
}

main() {
    trap cleanup EXIT

    parse_args "$@"

    require_command curl
    require_command mktemp

    TMP_DIR="$(mktemp -d)"
    EXTRACT_DIR="${TMP_DIR}/extracted"

    fetch_target_release
    detect_platform
    detect_local_version
    validate_release_asset

    ARCHIVE_PATH="${TMP_DIR}/package.${ARCHIVE_EXT}"

    if [ "${CHECK_ONLY}" -eq 1 ]; then
        echo -e "${GREEN}Check completed. No changes made.${NC}"
        exit 0
    fi

    if [ "${DRY_RUN}" -eq 1 ]; then
        print_planned_actions
        echo -e "${GREEN}Dry run completed. No changes made.${NC}"
        exit 0
    fi

    if [ -n "${LOCAL_VERSION}" ] && [ "${LOCAL_VERSION}" = "${VERSION}" ] && [ "${FORCE_INSTALL}" -eq 0 ]; then
        echo -e "${GREEN}CLIProxyAPI is already up to date. Exiting.${NC}"
        exit 0
    fi

    if [ -n "${LOCAL_VERSION}" ] && [ "${LOCAL_VERSION}" = "${VERSION}" ] && [ "${FORCE_INSTALL}" -eq 1 ]; then
        echo -e "${YELLOW}Local version matches target version, continuing due to --force.${NC}"
    fi

    if [ -n "${LOCAL_VERSION}" ] && version_gt "${LOCAL_VERSION}" "${VERSION}"; then
        ensure_non_interactive_downgrade_allowed
    fi

    echo -e "${YELLOW}Target platform: ${PLATFORM_LABEL}${NC}"
    echo -e "${YELLOW}Install directory: ${INSTALL_DIR}${NC}"
    echo -e "${YELLOW}Downloading ${PACKAGE_NAME}...${NC}"
    curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE_PATH}"

    echo -e "${YELLOW}Extracting package...${NC}"
    extract_archive
    resolve_package_root

    backup_existing_config

    echo -e "${YELLOW}Replacing installation directory...${NC}"
    install_release
    verify_installed_version

    echo -e "${GREEN}CLIProxyAPI ${VERSION} installed successfully.${NC}"
    echo "Binary: ${INSTALL_DIR}/${BINARY_NAME}"
    echo "Config: ${INSTALL_DIR}/config.yaml"

    if [ -n "${BACKUP_NAME}" ]; then
        echo "Backup: ${INSTALL_DIR}/${BACKUP_NAME}"
    fi
}

main "$@"
