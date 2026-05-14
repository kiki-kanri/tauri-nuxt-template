#!/usr/bin/env bash
# Shared filesystem helpers for project shell scripts.
# Source this file; do not execute it directly.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_FS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_FS_SH_LOADED=1

ensure_dir() {
    mkdir -p -- "$1"
}

ensure_parent_dir() {
    mkdir -p -- "$(dirname -- "$1")"
}

write_file_if_changed() {
    local target="$1"
    local tmp
    tmp="$(mktemp)"
    cat >"$tmp"

    ensure_parent_dir "$target"
    if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
        rm -f -- "$tmp"
        return 0
    fi

    mv -- "$tmp" "$target"
}

copy_dir_contents() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ ! -d "$source_dir" ]]; then
        if declare -F fail >/dev/null 2>&1; then
            fail "Source directory does not exist: $source_dir"
        fi

        printf 'error: Source directory does not exist: %s\n' "$source_dir" >&2
        exit 1
    fi

    ensure_dir "$target_dir"
    cp -R "$source_dir"/. "$target_dir"/
}

copy_path_into_dir() {
    local source_path="$1"
    local target_dir="$2"

    [[ -e "$source_path" ]] || {
        if declare -F fail >/dev/null 2>&1; then
            fail "Source path does not exist: $source_path"
        fi

        printf 'error: Source path does not exist: %s\n' "$source_path" >&2
        exit 1
    }

    ensure_dir "$target_dir"
    if [[ -d "$source_path" ]]; then
        cp -R -- "$source_path" "$target_dir/$(basename -- "$source_path")"
    else
        cp -- "$source_path" "$target_dir/$(basename -- "$source_path")"
    fi
}

_safe_absolute_path() {
    local path="$1"
    local base="${2:-$(pwd)}"
    case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$(cd -- "$base" && pwd -P)" "$path" ;;
    esac
}

safe_rm_rf_under() {
    local path root
    path="$(_safe_absolute_path "$1")"
    root="$(_safe_absolute_path "$2")"

    case "${path%/}" in
    '' | '/' | "${root%/}")
        if declare -F fail >/dev/null 2>&1; then
            fail "Refusing to remove unsafe path: $path"
        fi
        printf 'error: Refusing to remove unsafe path: %s\n' "$path" >&2
        exit 1
        ;;
    "${root%/}"/*) ;;
    *)
        if declare -F fail >/dev/null 2>&1; then
            fail "Path is outside allowed root: $path (root: $root)"
        fi
        printf 'error: Path is outside allowed root: %s (root: %s)\n' "$path" "$root" >&2
        exit 1
        ;;
    esac

    rm -rf -- "$path"
}
