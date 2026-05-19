#!/usr/bin/env bash
set -euo pipefail

# macOS release build entrypoint. Produces a signed universal .app/.dmg for
# direct distribution and a signed .pkg for Mac App Store upload.

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

# shellcheck source=scripts/libs/project-env.sh
source "${SCRIPT_DIR}/libs/project-env.sh"

SETUP_MACOS_ENV_SCRIPT="${ROOT}/scripts/setup-macos-env.sh"
MACOS_ENV_FILE="${BUILD_ROOT}/macos/env.sh"
MACOS_DIST_ROOT="${DIST_ROOT}/macos"
MACOS_APPSTORE_ROOT="${BUILD_ROOT}/macos/appstore"
MACOS_APPSTORE_CONFIG="${MACOS_APPSTORE_ROOT}/tauri.appstore.conf.json"
MACOS_APPSTORE_ENTITLEMENTS="${MACOS_APPSTORE_ROOT}/Entitlements.plist"
MACOS_BUILD_ROOT="${ROOT}/target/universal-apple-darwin/release"
MACOS_BUNDLE_ROOT="${MACOS_BUILD_ROOT}/bundle/macos"
MACOS_DMG_ROOT="${MACOS_BUILD_ROOT}/bundle/dmg"
MACOS_ALLOW_LOCAL_TEST_BUILD="${MACOS_ALLOW_LOCAL_TEST_BUILD:-0}"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/build-macos-release.sh [--local-test]

Runs macOS prerequisite setup, then builds:
  - a signed universal macOS .app bundle
  - a signed DMG for direct distribution
  - a signed PKG for Mac App Store upload

Use --local-test or MACOS_ALLOW_LOCAL_TEST_BUILD=1 to skip release signing
checks and build a local unsigned .app with Tauri --no-sign. This is only for
local testing and is not suitable for App Store or broad distribution.

Required signing environment:
  APPLE_SIGNING_IDENTITY           code signing identity for the app/DMG build
  APPLE_INSTALLER_SIGNING_IDENTITY Mac Installer Distribution identity for PKG
  APPLE_TEAM_ID                    Apple Developer team ID for App Store entitlements
  MACOS_APP_STORE_PROVISION_PROFILE path to Mac App Store Connect provisioning profile

Optional notarization/upload environment is passed through to Tauri/Xcode tools:
  APPLE_ID
  APPLE_PASSWORD
  APPLE_TEAM_ID
  APPLE_API_KEY
  APPLE_API_KEY_PATH
  APPLE_API_ISSUER
  APPLE_API_KEY_ID
EOF_USAGE
}

macos_signing_identity_configured() {
    grep -Eq '"signingIdentity"[[:space:]]*:[[:space:]]*"[^"]+"' "${TAURI_DIR}/tauri.conf.json" 2>/dev/null ||
        grep -Eq '"signingIdentity"[[:space:]]*:[[:space:]]*"[^"]+"' "${TAURI_DIR}/tauri.macos.conf.json" 2>/dev/null
}

validate_macos_signing() {
    if [[ "${MACOS_ALLOW_LOCAL_TEST_BUILD}" == 1 ]]; then
        log_warn "MACOS_ALLOW_LOCAL_TEST_BUILD=1: skipping release signing checks"
        return 0
    fi

    if [[ -z "${APPLE_SIGNING_IDENTITY:-}" ]] && ! macos_signing_identity_configured; then
        fail "Set APPLE_SIGNING_IDENTITY or configure bundle.macOS.signingIdentity before building macOS release artifacts"
    fi

    require_env APPLE_INSTALLER_SIGNING_IDENTITY
    require_env APPLE_TEAM_ID
    require_env MACOS_APP_STORE_PROVISION_PROFILE
    [[ -f "${MACOS_APP_STORE_PROVISION_PROFILE}" ]] || fail "Mac App Store provisioning profile not found: ${MACOS_APP_STORE_PROVISION_PROFILE}"
}

tauri_identifier() {
    sed -n 's/.*"identifier"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${TAURI_DIR}/tauri.conf.json" | head -n 1
}

write_app_store_config() {
    [[ "${MACOS_ALLOW_LOCAL_TEST_BUILD}" != 1 ]] || return 0

    local identifier
    identifier="$(tauri_identifier)"
    [[ -n "${identifier}" ]] || fail "Could not read Tauri identifier from ${TAURI_DIR}/tauri.conf.json"

    mkdir -p -- "${MACOS_APPSTORE_ROOT}"

    cat >"${MACOS_APPSTORE_ENTITLEMENTS}" <<EOF_ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.application-identifier</key>
    <string>${APPLE_TEAM_ID}.${identifier}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${APPLE_TEAM_ID}</string>
</dict>
</plist>
EOF_ENTITLEMENTS

    cat >"${MACOS_APPSTORE_CONFIG}" <<EOF_CONFIG
{
  "bundle": {
    "category": "Utility",
    "macOS": {
      "entitlements": "${MACOS_APPSTORE_ENTITLEMENTS}",
      "files": {
        "embedded.provisionprofile": "${MACOS_APP_STORE_PROVISION_PROFILE}"
      }
    }
  }
}
EOF_CONFIG
}

clean_macos_bundle_outputs() {
    safe_rm_rf_under "${MACOS_BUILD_ROOT}/bundle" "${ROOT}"
}

build_macos_artifacts() {
    clean_macos_bundle_outputs

    if [[ "${MACOS_ALLOW_LOCAL_TEST_BUILD}" == 1 ]]; then
        log_info "==> Building local unsigned macOS universal app"
        (cd "${APP_DIR}" && cargo tauri build --bundles app --target universal-apple-darwin --ci --no-sign)
        return 0
    fi

    log_info "==> Building macOS universal app and DMG"
    (cd "${APP_DIR}" && cargo tauri build --bundles app,dmg --target universal-apple-darwin --ci)
}

build_app_store_app() {
    [[ "${MACOS_ALLOW_LOCAL_TEST_BUILD}" != 1 ]] || return 0

    clean_macos_bundle_outputs

    log_info "==> Building Mac App Store app bundle"
    (cd "${APP_DIR}" && cargo tauri build --bundles app --target universal-apple-darwin --config "${MACOS_APPSTORE_CONFIG}" --ci)
}

copy_direct_distribution_outputs() {
    local output copied=0

    log_info "==> Copying macOS .app/.dmg outputs to dist/macos"
    safe_rm_rf_under "${MACOS_DIST_ROOT}" "${ROOT}"
    mkdir -p -- "${MACOS_DIST_ROOT}"

    while IFS= read -r output; do
        copy_path_into_dir "${output}" "${MACOS_DIST_ROOT}"
        copied=$((copied + 1))
        log_success "macOS output: ${MACOS_DIST_ROOT}/$(basename "${output}")"
    done < <(
        {
            find "${MACOS_BUNDLE_ROOT}" -maxdepth 1 -type d -name '*.app' 2>/dev/null
            find "${MACOS_DMG_ROOT}" -type f -name '*.dmg' 2>/dev/null
        } | sort
    )

    [[ "${copied}" -gt 0 ]] || fail "No macOS .app/.dmg outputs found under ${MACOS_BUILD_ROOT}/bundle"
}

build_app_store_pkg() {
    [[ "${MACOS_ALLOW_LOCAL_TEST_BUILD}" != 1 ]] || return 0

    local app_path pkg_path app_name_placeholder

    app_path="$(find "${MACOS_BUNDLE_ROOT}" -maxdepth 1 -type d -name '*.app' 2>/dev/null | sort | head -n 1)"
    [[ -n "${app_path}" ]] || fail "No .app bundle found under ${MACOS_BUNDLE_ROOT}"

    app_name_placeholder="$(basename "${app_path}" .app)"
    pkg_path="${MACOS_DIST_ROOT}/${app_name_placeholder}.pkg"

    log_info "==> Building Mac App Store PKG"
    xcrun productbuild \
        --sign "${APPLE_INSTALLER_SIGNING_IDENTITY}" \
        --component "${app_path}" /Applications \
        "${pkg_path}"

    log_success "PKG: ${pkg_path}"
}

main() {
    while [[ "$#" -gt 0 ]]; do
        case "${1}" in
        -h | --help)
            usage
            return 0
            ;;
        --local-test)
            MACOS_ALLOW_LOCAL_TEST_BUILD=1
            ;;
        *) fail "Unexpected argument: ${1}" ;;
        esac
        shift
    done

    "${SETUP_MACOS_ENV_SCRIPT}"

    [[ -d "${APP_DIR}" ]] || fail "App directory not found: ${APP_DIR}"
    [[ -f "${MACOS_ENV_FILE}" ]] || fail "macOS env file not found; run scripts/setup-macos-env.sh first"

    # shellcheck source=/dev/null
    source "${MACOS_ENV_FILE}"

    validate_macos_signing
    write_app_store_config
    build_macos_artifacts
    copy_direct_distribution_outputs
    build_app_store_app
    build_app_store_pkg
}

main "$@"
