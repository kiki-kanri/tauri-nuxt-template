#!/usr/bin/env bash
# Project setup runtime helpers that bridge scripts to the shared libs API.
# Source this file after scripts/libs/common.sh.

# shellcheck shell=bash
# shellcheck disable=SC2317

if [[ -n "${LINUX_CONFIGS_LIBS_SETUP_RUNTIME_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

LINUX_CONFIGS_LIBS_SETUP_RUNTIME_LOADED=1

SETUP_RUNTIME_TEMP_DIRS=()

require_env() {
    local name

    (($# == 1)) || fail "require_env requires exactly one variable name."
    name="${1}"
    if [[ -n "${!name:-}" ]]; then
        return 0
    fi

    fail "Required environment variable is not set: ${name}"
}

fail() {
    log_error "$@"
    exit 1
}

ensure_parent_dir() {
    (($# == 1)) || fail "ensure_parent_dir requires exactly one path."
    mkdir -p -- "$(dirname -- "${1}")"
}

write_file_if_changed() {
    local target tmp

    (($# == 1)) || fail "write_file_if_changed requires exactly one target path."
    target="${1}"
    tmp="$(mktemp)"
    cat >"${tmp}"

    ensure_parent_dir "${target}"
    if [[ -f "${target}" ]] && cmp -s "${tmp}" "${target}"; then
        rm -f -- "${tmp}"
        return 0
    fi

    mv -- "${tmp}" "${target}"
}

copy_dir_contents() {
    local source_dir target_dir

    (($# == 2)) || fail "copy_dir_contents requires source and target directories."
    source_dir="${1}"
    target_dir="${2}"
    [[ -d "${source_dir}" ]] || fail "Source directory does not exist: ${source_dir}"
    mkdir -p -- "${target_dir}"
    cp -R "${source_dir}"/. "${target_dir}"/
}

copy_path_into_dir() {
    local source_path target_dir

    (($# == 2)) || fail "copy_path_into_dir requires source path and target directory."
    source_path="${1}"
    target_dir="${2}"
    [[ -e "${source_path}" ]] || fail "Source path does not exist: ${source_path}"
    mkdir -p -- "${target_dir}"
    if [[ -d "${source_path}" ]]; then
        cp -R -- "${source_path}" "${target_dir}/$(basename -- "${source_path}")"
    else
        cp -- "${source_path}" "${target_dir}/$(basename -- "${source_path}")"
    fi
}

cleanup_temp_dirs() {
    local status=$?
    local dir

    for dir in "${SETUP_RUNTIME_TEMP_DIRS[@]}"; do
        [[ -n "${dir}" && -d "${dir}" ]] && rm -rf -- "${dir}"
    done

    return "${status}"
}

install_cleanup_trap() {
    trap cleanup_temp_dirs EXIT
}

make_temp_dir() {
    local tmp
    tmp="$(mktemp -d)"
    SETUP_RUNTIME_TEMP_DIRS+=("${tmp}")
    printf '%s\n' "${tmp}"
}

safe_rm_rf_under() {
    local path root

    (($# == 2)) || fail "safe_rm_rf_under requires path and root."
    path="$(absolute_path "${1}")"
    root="$(absolute_path "${2}")"

    case "${path%/}" in
    '' | '/' | "${root%/}")
        fail "Refusing to remove unsafe path: ${path}"
        ;;
    "${root%/}"/*) ;;
    *)
        fail "Path is outside allowed root: ${path} (root: ${root})"
        ;;
    esac

    rm -rf -- "${path}"
}
