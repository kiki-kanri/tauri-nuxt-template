#!/usr/bin/env bash
set -euo pipefail

# iOS release build entrypoint. Produces an App Store Connect IPA.

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

# shellcheck source=scripts/libs/project-env.sh
source "${SCRIPT_DIR}/libs/project-env.sh"

SETUP_IOS_ENV_SCRIPT="${ROOT}/scripts/setup-ios-env.sh"
IOS_DIST_ROOT="${DIST_ROOT}/ios"
IOS_ENV_FILE="${BUILD_ROOT}/ios/env.sh"
IOS_ALLOW_LOCAL_TEST_BUILD="${IOS_ALLOW_LOCAL_TEST_BUILD:-0}"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/build-ios-release-ipa.sh [--local-test]

Runs iOS prerequisite setup, initializes the Tauri iOS project when missing,
then builds an App Store Connect IPA and copies it to dist/ios.

Use --local-test or IOS_ALLOW_LOCAL_TEST_BUILD=1 to skip App Store signing
checks and build for the iOS simulator target. Unsigned builds cannot be
installed on a physical iPhone/iPad.

Signing/upload-related environment variables are passed through to Tauri/Xcode:
  APPLE_DEVELOPMENT_TEAM
  IOS_CERTIFICATE
  IOS_CERTIFICATE_PASSWORD
  IOS_MOBILE_PROVISION

Upload can be done separately with xcrun altool using:
  APPLE_API_KEY_ID
  APPLE_API_ISSUER
EOF_USAGE
}

ios_development_team_configured() {
    grep -Eq '"developmentTeam"[[:space:]]*:[[:space:]]*"[^"]+"' "${TAURI_DIR}/tauri.conf.json" 2>/dev/null ||
        grep -Eq '"developmentTeam"[[:space:]]*:[[:space:]]*"[^"]+"' "${TAURI_DIR}/tauri.ios.conf.json" 2>/dev/null
}

validate_ios_signing() {
    if [[ "${IOS_ALLOW_LOCAL_TEST_BUILD}" == 1 ]]; then
        log_warn "IOS_ALLOW_LOCAL_TEST_BUILD=1: skipping App Store signing checks"
        return 0
    fi

    if [[ -z "${APPLE_DEVELOPMENT_TEAM:-}" ]] && ! ios_development_team_configured; then
        fail "Set APPLE_DEVELOPMENT_TEAM or configure bundle.iOS.developmentTeam before building an App Store IPA"
    fi

    if [[ -n "${IOS_CERTIFICATE:-}${IOS_CERTIFICATE_PASSWORD:-}${IOS_MOBILE_PROVISION:-}" ]]; then
        require_env IOS_CERTIFICATE
        require_env IOS_CERTIFICATE_PASSWORD
        require_env IOS_MOBILE_PROVISION
    fi
}

ensure_ios_project() {
    if [[ -d "${APPLE_DIR}" ]]; then
        log_success "Tauri iOS project exists: ${APPLE_DIR}"
        return 0
    fi

    log_info "==> Initializing Tauri iOS project"
    (cd "${APP_DIR}" && cargo tauri ios init --ci --skip-targets-install)
}

build_ios_app_store_ipa() {
    safe_rm_rf_under "${APPLE_DIR}/build" "${ROOT}"

    if [[ "${IOS_ALLOW_LOCAL_TEST_BUILD}" == 1 ]]; then
        log_info "==> Building local iOS simulator app"
        (cd "${APP_DIR}" && cargo tauri ios build --target aarch64-sim --export-method debugging)
        return 0
    fi

    log_info "==> Building iOS App Store IPA"
    (cd "${APP_DIR}" && cargo tauri ios build --export-method app-store-connect)
}

copy_ios_outputs() {
    local output copied=0

    log_info "==> Copying iOS outputs to dist/ios"
    safe_rm_rf_under "${IOS_DIST_ROOT}" "${ROOT}"
    mkdir -p -- "${IOS_DIST_ROOT}"

    while IFS= read -r output; do
        copy_path_into_dir "${output}" "${IOS_DIST_ROOT}"
        copied=$((copied + 1))
        log_success "iOS output: ${IOS_DIST_ROOT}/$(basename "${output}")"
    done < <(
        if [[ "${IOS_ALLOW_LOCAL_TEST_BUILD}" == 1 ]]; then
            find "${APPLE_DIR}/build" -type d -name '*.app' 2>/dev/null
        else
            find "${APPLE_DIR}/build" -type f -name '*.ipa' 2>/dev/null
        fi | sort
    )

    [[ "${copied}" -gt 0 ]] || fail "No iOS outputs found under ${APPLE_DIR}/build"
}

main() {
    while [[ "$#" -gt 0 ]]; do
        case "${1}" in
        -h | --help)
            usage
            return 0
            ;;
        --local-test)
            IOS_ALLOW_LOCAL_TEST_BUILD=1
            ;;
        *) fail "Unexpected argument: ${1}" ;;
        esac
        shift
    done

    "${SETUP_IOS_ENV_SCRIPT}"

    [[ -d "${APP_DIR}" ]] || fail "App directory not found: ${APP_DIR}"
    [[ -f "${IOS_ENV_FILE}" ]] || fail "iOS env file not found; run scripts/setup-ios-env.sh first"

    # shellcheck source=/dev/null
    source "${IOS_ENV_FILE}"

    validate_ios_signing
    ensure_ios_project
    build_ios_app_store_ipa
    copy_ios_outputs
}

main "$@"
