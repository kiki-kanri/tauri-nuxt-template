#!/usr/bin/env bash
set -euo pipefail

# Project Tauri/Rust toolchain setup. Android SDK/JDK setup is handled by
# scripts/setup-android-env.sh.

ANDROID_RUST_TARGETS=(
    aarch64-linux-android
    x86_64-linux-android
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# shellcheck source=scripts/lib/tauri-cli.sh
source "$SCRIPT_DIR/lib/tauri-cli.sh"

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
    step "Installing Rust Android targets"
    rustup target add "${ANDROID_RUST_TARGETS[@]}"
}

main() {
    case "${1:-}" in
    -h | --help)
        usage
        return 0
        ;;
    '') ;;
    *) fail "Unexpected argument: $1" ;;
    esac

    need_command cargo
    need_command rustup

    install_android_rust_targets
    install_tauri_cli
}

main "$@"
