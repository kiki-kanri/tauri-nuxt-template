#!/usr/bin/env bash
set -euo pipefail

# Android release build entrypoint. Produces both release APKs for device
# testing/sideloading and signed Android App Bundles (AABs) for Google Play.

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

# shellcheck source=scripts/libs/project-env.sh
source "${SCRIPT_DIR}/libs/project-env.sh"

ANDROID_ENV_FILE="${ENV_FILE}"
ANDROID_SIGNING_PROPERTIES="${ANDROID_DIR}/keystore.properties"
ANDROID_DIST_ROOT="${DIST_ROOT}/android"
SETUP_LINUX_PACKAGES_SCRIPT="${ROOT}/scripts/setup-linux-packages.sh"
SETUP_ANDROID_ENV_SCRIPT="${ROOT}/scripts/setup-android-env.sh"
SETUP_TAURI_TOOLCHAIN_SCRIPT="${ROOT}/scripts/setup-tauri-toolchain.sh"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/build-android-release-apk.sh

Runs prerequisite setup scripts, prepares the project-local Android build
environment, initializes the Tauri Android project when missing, then builds
release APK and AAB outputs.
EOF_USAGE
}

run_setup_scripts() {
    "${SETUP_LINUX_PACKAGES_SCRIPT}"
    "${SETUP_ANDROID_ENV_SCRIPT}"
    "${SETUP_TAURI_TOOLCHAIN_SCRIPT}"
}

ensure_android_project() {
    if [[ -d "${ANDROID_DIR}" ]]; then
        log_success "Tauri Android project exists: ${ANDROID_DIR}"
        return 0
    fi

    log_info "==> Initializing Tauri Android project"
    (cd "${APP_DIR}" && cargo tauri android init --ci --skip-targets-install)
}

build_android_release() {
    log_info "==> Building Android release APK and AAB"
    (cd "${APP_DIR}" && cargo tauri android build --apk --aab --ci --target aarch64 x86_64)
}

copy_release_outputs() {
    local output copied=0

    log_info "==> Copying Android release outputs to dist/android"
    safe_rm_rf_under "${ANDROID_DIST_ROOT}" "${ROOT}"
    mkdir -p -- "${ANDROID_DIST_ROOT}"

    while IFS= read -r output; do
        copy_path_into_dir "${output}" "${ANDROID_DIST_ROOT}"
        copied=$((copied + 1))
        log_success "Android output: ${ANDROID_DIST_ROOT}/$(basename "${output}")"
    done < <(find "${ANDROID_DIR}/app/build/outputs" -type f \( -name '*release*.apk' -o -name '*release*.aab' \) 2>/dev/null | sort)

    [[ "${copied}" -gt 0 ]] || fail "No release APK/AAB files found under ${ANDROID_DIR}/app/build/outputs"
}

prepare_android_signing() {
    require_env APP_NAME_PLACEHOLDER_ANDROID_KEYSTORE_PROPERTIES
    [[ -f "${APP_NAME_PLACEHOLDER_ANDROID_KEYSTORE_PROPERTIES}" ]] || fail "Android signing properties not found: ${APP_NAME_PLACEHOLDER_ANDROID_KEYSTORE_PROPERTIES}"

    cp -- "${APP_NAME_PLACEHOLDER_ANDROID_KEYSTORE_PROPERTIES}" "${ANDROID_SIGNING_PROPERTIES}"
    chmod 600 "${ANDROID_SIGNING_PROPERTIES}"
}

main() {
    case "${1:-}" in
    -h | --help)
        usage
        return 0
        ;;
    '') ;;
    *) fail "Unexpected argument: ${1}" ;;
    esac

    run_setup_scripts

    [[ -d "${APP_DIR}" ]] || fail "App directory not found: ${APP_DIR}"
    [[ -f "${ANDROID_ENV_FILE}" ]] || fail "Android env file not found; run scripts/setup-android-env.sh first"

    # shellcheck source=/dev/null
    source "${ANDROID_ENV_FILE}"

    require_env ANDROID_HOME
    require_env ANDROID_SDK_ROOT
    require_env ANDROID_NDK_HOME
    require_env GRADLE_USER_HOME

    ensure_android_project
    prepare_android_signing
    build_android_release
    copy_release_outputs
}

main "$@"
