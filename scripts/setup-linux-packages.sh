#!/usr/bin/env bash
set -euo pipefail

# Install Linux system packages required by the project Android/Tauri setup.
# Project-local Android SDK/NDK artifacts are handled by setup-android-env.sh.

APT_PACKAGES=(
    build-essential
    ca-certificates
    curl
    git
    jq
    libssl-dev
    mold
    pkg-config
    unzip
)

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/setup-linux-packages.sh

Installs Linux system packages required before project-local Android/Tauri setup.
Currently supports Debian/Ubuntu systems through apt-get.
EOF_USAGE
}

apt_runner() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        printf 'apt-get\n'
        return 0
    fi

    require_cmd sudo
    printf 'sudo apt-get\n'
}

missing_apt_packages() {
    local package

    for package in "${APT_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -Fxq 'install ok installed'; then
            printf '%s\n' "${package}"
        fi
    done
}

install_apt_packages() {
    local apt missing_packages=()
    mapfile -t missing_packages < <(missing_apt_packages)

    if [[ "${#missing_packages[@]}" -eq 0 ]]; then
        log_success "Linux system packages already installed"
        return 0
    fi

    log_info "==> Installing missing Linux system packages: ${missing_packages[*]}"
    apt="$(apt_runner)"

    # shellcheck disable=SC2086 # apt may intentionally include sudo prefix.
    ${apt} update
    # shellcheck disable=SC2086 # apt may intentionally include sudo prefix.
    ${apt} install -y --no-install-recommends "${missing_packages[@]}"
}

main() {
    case "${1:-}" in
    -h | --help)
        usage
        return 0
        ;;
    '') ;;
    *) fail "Unexpected argument: ${1}" ;;
    esac

    [[ "$(host_os)" == linux ]] || fail "Linux package setup supports Linux only"
    require_cmd apt-get
    require_cmd dpkg-query

    install_apt_packages
    log_success "Linux package setup complete"
}

main "$@"
