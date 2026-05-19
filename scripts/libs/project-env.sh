#!/usr/bin/env bash
# Shared project path constants for shell scripts.
# Source this file after scripts/libs/common.sh.

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2317

if [[ -n "${LINUX_CONFIGS_LIBS_PROJECT_ENV_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

LINUX_CONFIGS_LIBS_PROJECT_ENV_LOADED=1

ROOT="${REPO_ROOT:?source scripts/libs/common.sh before scripts/libs/project-env.sh}"
APP_NAME="app-name-placeholder"

BUILD_ROOT="${ROOT}/.build"
DIST_ROOT="${ROOT}/dist"
APP_DIR="${ROOT}/apps/${APP_NAME}"
TAURI_DIR="${APP_DIR}/src-tauri"

ANDROID_ROOT="${BUILD_ROOT}/android"
JDK_ROOT="${ANDROID_ROOT}/jdk"
SDK_ROOT="${ANDROID_ROOT}/sdk"
DOWNLOAD_ROOT="${ANDROID_ROOT}/downloads"
GRADLE_USER_HOME="${ANDROID_ROOT}/gradle"
ANDROID_USER_HOME="${ANDROID_ROOT}/user-home"
SIGNING_ROOT="${ANDROID_ROOT}/signing"
ENV_FILE="${ANDROID_ROOT}/env.sh"
ANDROID_DIR="${TAURI_DIR}/gen/android"
APPLE_DIR="${TAURI_DIR}/gen/apple"
