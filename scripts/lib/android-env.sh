#!/usr/bin/env bash
# Android SDK/signing setup helpers for project-local toolchains.
# Source this file after scripts/lib/common.sh and after defining paths/constants.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_ANDROID_ENV_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_ANDROID_ENV_SH_LOADED=1

android_require_linux() {
    [[ "$(host_os)" == linux ]] || fail "Android environment setup currently supports Linux only"
}

android_require_host_tools() {
    need_command curl
    need_command awk
    need_command sort
    need_command find
    need_command yes
    need_command tar
    need_command unzip
}

android_prepare_directories() {
    ensure_dir "$DOWNLOAD_ROOT"
    ensure_dir "$JDK_ROOT"
    ensure_dir "$SDK_ROOT"
    ensure_dir "$GRADLE_USER_HOME"
}

android_download_file() {
    local url="$1"
    local output="$2"
    local partial="$output.part"

    ensure_parent_dir "$output"
    if [[ -s "$output" ]]; then
        ok "download exists: $output"
        return 0
    fi

    step "Downloading $url"
    rm -f -- "$partial"
    curl --fail --location --show-error --progress-bar "$url" --output "$partial"
    mv -- "$partial" "$output"
}

android_require_zip_archive() {
    local archive="$1"
    unzip -tq "$archive" >/dev/null || {
        rm -f -- "$archive"
        fail "Downloaded archive is incomplete or invalid: $archive"
    }
}

android_install_cmdline_tools() {
    local archive extracted url
    archive="$DOWNLOAD_ROOT/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_REV}_latest.zip"
    url="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_REV}_latest.zip"

    android_cleanup_duplicate_cmdline_tools

    if android_cmdline_tools_are_valid; then
        ok "Android command-line tools exist: $SDK_ROOT/cmdline-tools/latest"
        return 0
    fi

    if [[ -e "$SDK_ROOT/cmdline-tools/latest" ]]; then
        warn "Android command-line tools are incomplete or invalid; reinstalling: $SDK_ROOT/cmdline-tools/latest"
        safe_rm_rf_under "$SDK_ROOT/cmdline-tools" "$BUILD_ROOT"
    fi

    android_download_file "$url" "$archive"
    android_require_zip_archive "$archive"
    safe_rm_rf_under "$SDK_ROOT/cmdline-tools" "$BUILD_ROOT"
    ensure_dir "$SDK_ROOT/cmdline-tools"
    extracted="$(make_temp_dir)"
    step "Installing Android command-line tools"
    unzip -q "$archive" -d "$extracted"
    ensure_dir "$SDK_ROOT/cmdline-tools/latest"
    cp -R "$extracted/cmdline-tools"/. "$SDK_ROOT/cmdline-tools/latest"/
    android_cmdline_tools_are_valid || fail "Installed Android command-line tools are invalid: $SDK_ROOT/cmdline-tools/latest"
}

android_cleanup_duplicate_cmdline_tools() {
    local duplicate

    for duplicate in "$SDK_ROOT"/cmdline-tools/latest-*; do
        [[ -e "$duplicate" ]] || continue
        warn "Removing duplicate Android command-line tools directory: $duplicate"
        safe_rm_rf_under "$duplicate" "$BUILD_ROOT"
    done
}

android_cmdline_tools_are_valid() {
    [[ -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]] || return 1
    [[ -f "$SDK_ROOT/cmdline-tools/latest/source.properties" ]] || return 1
    JAVA_HOME="$JDK_ROOT" PATH="$JDK_ROOT/bin:$PATH" GRADLE_USER_HOME="$GRADLE_USER_HOME" \
        "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --version >/dev/null 2>&1
}

android_sdkmanager() {
    JAVA_HOME="$JDK_ROOT" PATH="$JDK_ROOT/bin:$PATH" GRADLE_USER_HOME="$GRADLE_USER_HOME" \
        "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_ROOT" "$@"
}

android_latest_sdk_package() {
    local regex="$1"
    android_sdkmanager --list | awk -F'|' -v regex="$regex" '
        {
            path = $1
            version = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", path)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", version)
        }
        path ~ regex && version !~ /rc/ {
            print path
        }
    ' | sort -V | tail -n 1
}

android_accept_licenses() {
    local sdkmanager_status

    step "Accepting Android SDK licenses"
    set +o pipefail
    yes | android_sdkmanager --licenses >/dev/null
    sdkmanager_status="${PIPESTATUS[1]}"
    set -o pipefail

    [[ "$sdkmanager_status" -eq 0 ]] || fail "Android SDK license acceptance failed"
}

android_install_sdk_packages() {
    local build_tools_pkg ndk_pkg platform_pkg

    step "Resolving latest stable Android SDK packages"
    platform_pkg="$(android_latest_sdk_package '^platforms;android-[0-9]+([.][0-9]+)?$')"
    build_tools_pkg="$(android_latest_sdk_package '^build-tools;[0-9.]+$')"
    ndk_pkg="$(android_latest_sdk_package '^ndk;[0-9.]+$')"

    [[ -n "$platform_pkg" ]] || fail "Could not resolve latest Android SDK platform"
    [[ -n "$build_tools_pkg" ]] || fail "Could not resolve latest Android build-tools"
    [[ -n "$ndk_pkg" ]] || fail "Could not resolve latest Android NDK"

    note "platform: $platform_pkg"
    note "build-tools: $build_tools_pkg"
    note "ndk: $ndk_pkg"

    android_accept_licenses
    step "Installing Android SDK packages"
    android_sdkmanager \
        "platform-tools" \
        "$platform_pkg" \
        "$build_tools_pkg" \
        "$ndk_pkg"

    android_accept_licenses
}

android_latest_ndk_home() {
    find "$SDK_ROOT/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1
}

android_create_signing_material() {
    local keystore="$SIGNING_ROOT/$SIGNING_KEYSTORE_NAME"
    local properties="$SIGNING_ROOT/keystore.properties"

    ensure_dir "$SIGNING_ROOT"
    chmod 700 "$SIGNING_ROOT"

    if [[ ! -f "$keystore" ]]; then
        step "Creating local Android signing keystore"
        "$JDK_ROOT/bin/keytool" -genkeypair \
            -v \
            -keystore "$keystore" \
            -storetype PKCS12 \
            -keyalg EC \
            -groupname secp384r1 \
            -sigalg SHA384withECDSA \
            -validity "$SIGNING_VALIDITY_DAYS" \
            -alias "$SIGNING_KEY_ALIAS" \
            -storepass "$SIGNING_KEYSTORE_PASSWORD" \
            -keypass "$SIGNING_KEYSTORE_PASSWORD" \
            -dname "$SIGNING_DNAME"

        chmod 600 "$keystore"
    else
        ok "signing keystore exists: $keystore"
    fi

    cat >"$properties" <<EOF_PROPERTIES
keyAlias=$SIGNING_KEY_ALIAS
password=$SIGNING_KEYSTORE_PASSWORD
storeFile=$keystore
EOF_PROPERTIES
    chmod 600 "$properties"
}

android_write_env_file() {
    local ndk_home
    ndk_home="$(android_latest_ndk_home)"
    [[ -n "$ndk_home" ]] || fail "NDK was not installed under $SDK_ROOT/ndk"

    cat >"$ENV_FILE" <<EOF_ENV
# Source this file before Android dev or build commands:
#   source .build/android/env.sh
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export JAVA_HOME="$JDK_ROOT"
export NDK_HOME="$ndk_home"
export ANDROID_NDK_HOME="$ndk_home"
export GRADLE_USER_HOME="$GRADLE_USER_HOME"
export PATH="$JDK_ROOT/bin:$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:\$PATH"
export APP_NAME_PLACEHOLDER_ANDROID_KEYSTORE="$SIGNING_ROOT/$SIGNING_KEYSTORE_NAME"
export APP_NAME_PLACEHOLDER_ANDROID_KEYSTORE_PROPERTIES="$SIGNING_ROOT/keystore.properties"
EOF_ENV
    ok "env file: $ENV_FILE"
}
