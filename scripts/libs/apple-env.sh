#!/usr/bin/env bash
# Shared Apple platform setup helpers.
# Source this file after scripts/libs/common.sh.

# shellcheck shell=bash
# shellcheck disable=SC2317

if [[ -n "${LINUX_CONFIGS_LIBS_APPLE_ENV_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

LINUX_CONFIGS_LIBS_APPLE_ENV_LOADED=1

apple_fail() {
    if declare -F fail >/dev/null 2>&1; then
        fail "$@"
    fi

    log_error "$@"
    exit 1
}

apple_require_macos() {
    local subject="${1:-Apple platform setup}"

    [[ "$(host_os)" == macos ]] || apple_fail "${subject} requires a macOS host"
}

apple_xcode_developer_dir() {
    xcode-select -p 2>/dev/null || true
}

apple_require_xcode_tools() {
    local developer_dir

    require_cmd xcodebuild xcrun

    developer_dir="$(apple_xcode_developer_dir)"
    [[ -n "${developer_dir}" ]] || apple_fail "Xcode tools path is not selected; run xcode-select --install or select Xcode"

    xcodebuild -version >/dev/null
    log_success "Xcode tools: ${developer_dir}"
}

apple_require_full_xcode() {
    local developer_dir

    apple_require_xcode_tools

    developer_dir="$(apple_xcode_developer_dir)"
    [[ "${developer_dir}" == *'.app/Contents/Developer' ]] || apple_fail "Full Xcode is required, not Command Line Tools: ${developer_dir}"
}

apple_install_brew_packages() {
    local missing=()
    local package

    (($# > 0)) || return 0
    require_cmd brew

    for package in "$@"; do
        if ! brew list --versions "${package}" >/dev/null 2>&1; then
            missing+=("${package}")
        fi
    done

    if ((${#missing[@]} == 0)); then
        log_success "Homebrew packages installed: $*"
        return 0
    fi

    log_info "==> Installing Homebrew packages: ${missing[*]}"
    brew install "${missing[@]}"
}
