#!/usr/bin/env bash
set -euo pipefail

# Project Tauri/Rust toolchain setup. Android SDK/JDK setup is handled by
# scripts/setup-android-env.sh.

ANDROID_RUST_TARGETS=(
    aarch64-linux-android
    x86_64-linux-android
)

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

# shellcheck source=scripts/libs/tauri-cli.sh
source "${SCRIPT_DIR}/libs/tauri-cli.sh"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/setup-tauri-toolchain.sh

Installs project Rust/Tauri prerequisites:
  - Rust Android targets for supported 64-bit ABIs
  - latest tauri-cli via cargo install

Does not install Android SDK, NDK, JDK, Gradle, or signing material.
EOF_USAGE
}

install_android_rust_targets() {
    log_info "==> Installing Rust Android targets"
    rustup target add "${ANDROID_RUST_TARGETS[@]}"
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

    require_cmd cargo
    require_cmd rustup

    install_android_rust_targets
    install_tauri_cli
}

main "$@"
