#!/usr/bin/env bash
# Shared Apple platform setup helpers.
# Source this file after scripts/lib/common.sh.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_APPLE_ENV_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_APPLE_ENV_SH_LOADED=1

apple_require_macos() {
    [[ "$(host_os)" == macos ]] || fail "$1 requires a macOS host"
}

apple_xcode_developer_dir() {
    xcode-select -p 2>/dev/null || true
}

apple_require_xcode_tools() {
    local developer_dir

    need_command xcodebuild
    need_command xcrun

    developer_dir="$(apple_xcode_developer_dir)"
    [[ -n "$developer_dir" ]] || fail "Xcode tools path is not selected; run xcode-select --install or select Xcode"

    xcodebuild -version >/dev/null
    ok "Xcode tools: $developer_dir"
}

apple_require_full_xcode() {
    local developer_dir

    apple_require_xcode_tools

    developer_dir="$(apple_xcode_developer_dir)"
    [[ "$developer_dir" == *'.app/Contents/Developer' ]] || fail "Full Xcode is required, not Command Line Tools: $developer_dir"
}

apple_install_brew_packages() {
    local missing=() package

    need_command brew

    for package in "$@"; do
        if ! brew list --versions "$package" >/dev/null 2>&1; then
            missing+=("$package")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        ok "Homebrew packages installed: $*"
        return 0
    fi

    step "Installing Homebrew packages: ${missing[*]}"
    brew install "${missing[@]}"
}
