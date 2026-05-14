#!/usr/bin/env bash
# Shared color and logging helpers for project shell scripts.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_COLORS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_COLORS_SH_LOADED=1

C_RESET=''
C_RED=''
C_GREEN=''
C_YELLOW=''
C_BLUE=''
C_CYAN=''

# Enable colors when stdout is a TTY. Respect the standard NO_COLOR opt-out.
setup_colors() {
    C_RESET=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''

    [[ -t 1 && -z "${NO_COLOR:-}" ]] || return 0

    C_RESET=$'\033[0m'
    C_RED=$'\033[1;31m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'
    C_CYAN=$'\033[1;36m'
}

_log_line() {
    local color="$1"
    local label="$2"
    shift 2
    printf '%s%s:%s %s\n' "$color" "$label" "$C_RESET" "$*"
}

log() { _log_line "$C_BLUE" 'info' "$@"; }
ok() { _log_line "$C_GREEN" 'ok' "$@"; }
note() { _log_line "$C_CYAN" 'note' "$@"; }
warn() { _log_line "$C_YELLOW" 'warn' "$@" >&2; }
step() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }

fail() {
    _log_line "$C_RED" 'error' "$@" >&2
    exit 1
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

setup_colors
