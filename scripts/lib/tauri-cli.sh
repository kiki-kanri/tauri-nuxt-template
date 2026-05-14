#!/usr/bin/env bash
# Shared Tauri CLI helpers.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_TAURI_CLI_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_TAURI_CLI_SH_LOADED=1

TAURI_CLI_CRATE=tauri-cli
TAURI_CLI_VERSION_REQ='^2.0.0'

install_tauri_cli() {
    step "Installing/updating Tauri CLI"
    cargo +stable install "$TAURI_CLI_CRATE" --version "$TAURI_CLI_VERSION_REQ" --locked
    cargo tauri --version
}
