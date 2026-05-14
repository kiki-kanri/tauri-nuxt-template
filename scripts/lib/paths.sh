#!/usr/bin/env bash
# Shared path helpers for project shell scripts.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_PATHS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_PATHS_SH_LOADED=1

script_dir() {
    local source_file="${1:-${BASH_SOURCE[1]}}"
    cd -- "$(dirname -- "$source_file")" && pwd -P
}

# Prefer the VCS root. If a script is copied outside a git checkout, fall back to
# the highest Cargo.toml found while walking upward.
repo_root_from() {
    local dir="${1:-$(pwd)}"
    local cargo_root=''
    dir="$(cd -- "$dir" && pwd -P)"

    while [[ "$dir" != '/' ]]; do
        if [[ -e "$dir/.git" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi

        if [[ -f "$dir/Cargo.toml" ]]; then
            cargo_root="$dir"
        fi

        dir="$(dirname -- "$dir")"
    done

    [[ -n "$cargo_root" ]] || return 1
    printf '%s\n' "$cargo_root"
}

absolute_path() {
    local path="$1"
    local base="${2:-$(pwd)}"

    case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$(cd -- "$base" && pwd -P)" "$path" ;;
    esac
}

require_under_root() {
    local path root
    path="$(absolute_path "$1")"
    root="$(absolute_path "$2")"

    case "${path%/}" in
    "${root%/}"/*) return 0 ;;
    esac

    if declare -F fail >/dev/null 2>&1; then
        fail "Path is outside allowed root: $path (root: $root)"
    fi

    printf 'error: Path is outside allowed root: %s (root: %s)\n' "$path" "$root" >&2
    exit 1
}
