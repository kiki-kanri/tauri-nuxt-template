#!/usr/bin/env bash
# Shared Apple platform setup helpers.
# Source this file after scripts/libs/common.sh.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${LINUX_CONFIGS_LIBS_APPLE_ENV_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

LINUX_CONFIGS_LIBS_APPLE_ENV_LOADED=1

apple_require_macos() {
    [[ "$(host_os)" == macos ]] || fail "${1} requires a macOS host"
}

apple_xcode_developer_dir() {
    xcode-select -p 2>/dev/null || true
}

apple_require_xcode_tools() {
    local developer_dir

    require_cmd xcodebuild xcrun

    developer_dir="$(apple_xcode_developer_dir)"
    [[ -n "${developer_dir}" ]] || fail "Xcode tools path is not selected; run xcode-select --install or select Xcode"

    xcodebuild -version >/dev/null
    log_success "Xcode tools: ${developer_dir}"
}

apple_require_full_xcode() {
    local developer_dir

    apple_require_xcode_tools

    developer_dir="$(apple_xcode_developer_dir)"
    [[ "${developer_dir}" == *'.app/Contents/Developer' ]] || fail "Full Xcode is required, not Command Line Tools: ${developer_dir}"
}

apple_install_brew_packages() {
    local missing=() package

    require_cmd brew

    for package in "$@"; do
        if ! brew list --versions "${package}" >/dev/null 2>&1; then
            missing+=("${package}")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        log_success "Homebrew packages installed: $*"
        return 0
    fi

    log_info "==> Installing Homebrew packages: ${missing[*]}"
    brew install "${missing[@]}"
}
