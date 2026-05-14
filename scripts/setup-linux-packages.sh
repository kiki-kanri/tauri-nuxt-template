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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

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

    need_command sudo
    printf 'sudo apt-get\n'
}

missing_apt_packages() {
    local package

    for package in "${APT_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fxq 'install ok installed'; then
            printf '%s\n' "$package"
        fi
    done
}

install_apt_packages() {
    local apt missing_packages=()
    mapfile -t missing_packages < <(missing_apt_packages)

    if [[ "${#missing_packages[@]}" -eq 0 ]]; then
        ok "Linux system packages already installed"
        return 0
    fi

    step "Installing missing Linux system packages: ${missing_packages[*]}"
    apt="$(apt_runner)"

    # shellcheck disable=SC2086 # apt may intentionally include sudo prefix.
    $apt update
    # shellcheck disable=SC2086 # apt may intentionally include sudo prefix.
    $apt install -y --no-install-recommends "${missing_packages[@]}"
}

main() {
    case "${1:-}" in
    -h | --help)
        usage
        return 0
        ;;
    '') ;;
    *) fail "Unexpected argument: $1" ;;
    esac

    [[ "$(host_os)" == linux ]] || fail "Linux package setup supports Linux only"
    need_command apt-get
    need_command dpkg-query

    install_apt_packages
    ok "Linux package setup complete"
}

main "$@"
