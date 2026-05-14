#!/usr/bin/env bash
# Shared project path constants for shell scripts.
# Source this file after scripts/lib/common.sh.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.
# shellcheck disable=SC2034 # Shared constants are consumed by scripts after sourcing.

if [[ -n "${APP_NAME_PLACEHOLDER_PROJECT_ENV_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_PROJECT_ENV_SH_LOADED=1

ROOT="$(repo_root_from "$(script_dir)")"
BUILD_ROOT="$ROOT/.build"
ANDROID_ROOT="$BUILD_ROOT/android"
JDK_ROOT="$ANDROID_ROOT/jdk"
SDK_ROOT="$ANDROID_ROOT/sdk"
DOWNLOAD_ROOT="$ANDROID_ROOT/downloads"
GRADLE_USER_HOME="$ANDROID_ROOT/gradle"
SIGNING_ROOT="$ANDROID_ROOT/signing"
ENV_FILE="$ANDROID_ROOT/env.sh"
APP_DIR="$ROOT/apps/app-name-placeholder"
TAURI_DIR="$APP_DIR/src-tauri"
ANDROID_DIR="$TAURI_DIR/gen/android"
APPLE_DIR="$TAURI_DIR/gen/apple"
DIST_ROOT="$ROOT/dist"
