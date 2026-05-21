#!/usr/bin/env bash
# Shared Tauri CLI helpers.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317

if [[ -n "${LINUX_CONFIGS_LIBS_TAURI_CLI_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

LINUX_CONFIGS_LIBS_TAURI_CLI_LOADED=1

: "${TAURI_CLI_CRATE:=tauri-cli}"
: "${TAURI_CLI_VERSION_REQ:=^2.0.0}"

install_tauri_cli() {
    require_cmd cargo

    log_info "==> Installing/updating Tauri CLI"
    cargo +stable install "${TAURI_CLI_CRATE}" --version "${TAURI_CLI_VERSION_REQ}" --locked
    cargo tauri --version
}
