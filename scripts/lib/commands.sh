#!/usr/bin/env bash
# Shared command, environment, and platform helpers.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_COMMANDS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_COMMANDS_SH_LOADED=1

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! declare -F need_command >/dev/null 2>&1; then
    need_command() {
        command_exists "$1" || {
            printf 'error: Required command not found: %s\n' "$1" >&2
            exit 1
        }
    }
fi

need_any_command() {
    local cmd
    for cmd in "$@"; do
        if command_exists "$cmd"; then
            printf '%s\n' "$cmd"
            return 0
        fi
    done

    if declare -F fail >/dev/null 2>&1; then
        fail "None of the required commands were found: $*"
    fi

    printf 'error: None of the required commands were found: %s\n' "$*" >&2
    exit 1
}

require_env() {
    local name="$1"
    if [[ -n "${!name:-}" ]]; then
        return 0
    fi

    if declare -F fail >/dev/null 2>&1; then
        fail "Required environment variable is not set: $name"
    fi

    printf 'error: Required environment variable is not set: %s\n' "$name" >&2
    exit 1
}

host_os() {
    case "$(uname -s)" in
    Linux) printf 'linux\n' ;;
    Darwin) printf 'macos\n' ;;
    MINGW* | MSYS* | CYGWIN*) printf 'windows\n' ;;
    *) printf 'unknown\n' ;;
    esac
}

host_arch() {
    case "$(uname -m)" in
    x86_64 | amd64) printf 'x86_64\n' ;;
    arm64 | aarch64) printf 'aarch64\n' ;;
    armv7l | armv7*) printf 'armv7\n' ;;
    *) uname -m ;;
    esac
}
