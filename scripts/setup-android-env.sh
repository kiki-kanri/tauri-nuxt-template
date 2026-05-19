#!/usr/bin/env bash
set -euo pipefail

# Project-local Android SDK/signing setup for Linux.
# All downloaded Android tooling is installed under .build/android.

ANDROID_CMDLINE_TOOLS_REV=14742923
SIGNING_KEY_ALIAS="${APP_NAME_PLACEHOLDER_ANDROID_SIGNING_KEY_ALIAS:-upload}"
SIGNING_KEYSTORE_PASSWORD="${APP_NAME_PLACEHOLDER_ANDROID_SIGNING_PASSWORD:-android-local-changeit}"
SIGNING_DNAME="${APP_NAME_PLACEHOLDER_ANDROID_SIGNING_DNAME:-CN=app-name-placeholder,O=Local Development,C=TW}"
SIGNING_VALIDITY_DAYS="${APP_NAME_PLACEHOLDER_ANDROID_SIGNING_VALIDITY_DAYS:-10000}"
SIGNING_KEYSTORE_NAME=upload-keystore.p12

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

# shellcheck source=scripts/libs/project-env.sh
source "${SCRIPT_DIR}/libs/project-env.sh"

SETUP_JDK_SCRIPT="${ROOT}/scripts/setup-jdk.sh"

# shellcheck source=scripts/libs/android-env.sh
source "${ROOT}/scripts/libs/android-env.sh"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/setup-android-env.sh

Installs project-local Android prerequisites under .build/android:
  - Eclipse Temurin JDK 21
  - Android SDK Command-line Tools
  - latest stable SDK Platform, Platform-Tools, Build-Tools, NDK
  - Gradle user home/cache path under .build/android/gradle
  - local Android signing keystore (EC P-384) and env file

Signing env overrides:
  APP_NAME_PLACEHOLDER_ANDROID_SIGNING_KEY_ALIAS
  APP_NAME_PLACEHOLDER_ANDROID_SIGNING_PASSWORD
  APP_NAME_PLACEHOLDER_ANDROID_SIGNING_DNAME
  APP_NAME_PLACEHOLDER_ANDROID_SIGNING_VALIDITY_DAYS

Does not install Rust targets or Tauri CLI.
EOF_USAGE
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

    android_require_linux
    android_require_host_tools
    install_cleanup_trap
    android_prepare_directories

    "${SETUP_JDK_SCRIPT}"
    android_install_cmdline_tools
    android_install_sdk_packages
    android_create_signing_material
    android_write_env_file
    log_success "Android environment setup complete"
}

main "$@"
