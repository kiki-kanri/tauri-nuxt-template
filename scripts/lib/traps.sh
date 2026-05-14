#!/usr/bin/env bash
# Shared temporary-directory cleanup helpers.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_TRAPS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_TRAPS_SH_LOADED=1

APP_NAME_PLACEHOLDER_TEMP_DIRS=()

cleanup_temp_dirs() {
    local status=$?
    local dir

    for dir in "${APP_NAME_PLACEHOLDER_TEMP_DIRS[@]}"; do
        [[ -n "$dir" && -d "$dir" ]] && rm -rf -- "$dir"
    done

    return "$status"
}

install_cleanup_trap() {
    trap cleanup_temp_dirs EXIT
}

make_temp_dir() {
    local tmp
    tmp="$(mktemp -d)"
    APP_NAME_PLACEHOLDER_TEMP_DIRS+=("$tmp")
    printf '%s\n' "$tmp"
}
