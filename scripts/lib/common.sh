#!/usr/bin/env bash
# Convenience aggregator for shared script helpers.
# Source this file from scripts that want the standard helper set.

# shellcheck shell=bash
# shellcheck disable=SC2317 # Source guard intentionally returns when already loaded.

if [[ -n "${APP_NAME_PLACEHOLDER_COMMON_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi

APP_NAME_PLACEHOLDER_COMMON_SH_LOADED=1

APP_NAME_PLACEHOLDER_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=scripts/lib/colors.sh
source "$APP_NAME_PLACEHOLDER_LIB_DIR/colors.sh"

# shellcheck source=scripts/lib/paths.sh
source "$APP_NAME_PLACEHOLDER_LIB_DIR/paths.sh"

# shellcheck source=scripts/lib/commands.sh
source "$APP_NAME_PLACEHOLDER_LIB_DIR/commands.sh"

# shellcheck source=scripts/lib/fs.sh
source "$APP_NAME_PLACEHOLDER_LIB_DIR/fs.sh"

# shellcheck source=scripts/lib/traps.sh
source "$APP_NAME_PLACEHOLDER_LIB_DIR/traps.sh"
