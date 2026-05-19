#!/usr/bin/env bash
set -euo pipefail

# Install Eclipse Temurin JDK 21 under .build/android/jdk.
# Resolves an explicit latest GA release, tests Eclipse mirrors, downloads from
# the fastest reachable official URL, and verifies SHA-256 before installing.

JAVA_MAJOR_VERSION=21
ADOPTIUM_OS=linux
ADOPTIUM_ARCH=x64
ADOPTIUM_IMAGE_TYPE=jdk
ADOPTIUM_VENDOR=eclipse
ADOPTIUM_API_URL="https://api.adoptium.net/v3/assets/latest/${JAVA_MAJOR_VERSION}/hotspot?architecture=${ADOPTIUM_ARCH}&image_type=${ADOPTIUM_IMAGE_TYPE}&os=${ADOPTIUM_OS}&vendor=${ADOPTIUM_VENDOR}"
ECLIPSE_MIRROR_LIST_URL="https://download.eclipse.org/oomph/archive/mirror.php?location=temurin-compliance/temurin"

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/libs/common.sh
source "${SCRIPT_DIR}/libs/common.sh"

# shellcheck source=scripts/libs/project-env.sh
source "${SCRIPT_DIR}/libs/project-env.sh"

JDK_VERSION_FILE="${JDK_ROOT}/.temurin-version"

usage() {
    cat <<'EOF_USAGE'
Usage: scripts/setup-jdk.sh

Installs Eclipse Temurin JDK 21 into .build/android/jdk.
EOF_USAGE
}

require_jdk_setup_tools() {
    require_cmd curl jq sha256sum tar
}

jdk_java_feature_version() {
    "${JDK_ROOT}/bin/java" -XshowSettings:properties -version 2>&1 |
        awk -F'= ' '/java.specification.version/ {
            split($2, version, ".")
            if (version[1] == "1") print version[2]
            else print version[1]
            exit
        }'
}

jdk_is_valid() {
    local feature
    feature="$(jdk_java_feature_version 2>/dev/null || true)"
    [[ "${feature}" == "${JAVA_MAJOR_VERSION}" && -x "${JDK_ROOT}/bin/keytool" ]]
}

resolve_jdk_release() {
    local metadata_file="${1}"

    log_info "==> Resolving Eclipse Temurin JDK ${JAVA_MAJOR_VERSION} release" >&2
    curl --fail --location --silent --show-error "${ADOPTIUM_API_URL}" --output "${metadata_file}"

    jq -r '
        .[0] as $release
        | [
            ($release.version.semver // $release.version.openjdk_version),
            $release.binary.package.name,
            $release.binary.package.link,
            $release.binary.package.checksum
          ]
        | if any(.[]; . == null or . == "") then
            error("Adoptium release metadata missing required fields")
          else
            .[]
          end
    ' "${metadata_file}"
}

fetch_official_mirror_bases() {
    local mirror_page="${1}"

    if curl --fail --location --silent --show-error "${ECLIPSE_MIRROR_LIST_URL}" --output "${mirror_page}"; then
        grep -Eo 'https://[^"<>[:space:]]+/temurin-compliance/temurin' "${mirror_page}" | sed 's#/*$##' | sort -u
    fi

    cat <<'EOF_MIRRORS'
https://download.eclipse.org/oomph/archive/download.eclipse/temurin-compliance/temurin
https://download.eclipse.org/oomph/archive/eclipse/temurin-compliance/temurin
https://mirrors.ibiblio.org/pub/mirrors/eclipse/temurin-compliance/temurin
EOF_MIRRORS
}

official_mirror_url() {
    local base="${1}"
    local version="${2}"
    local filename="${3}"

    printf '%s/%s/jdk-%s/%s\n' \
        "${base%/}" \
        "${JAVA_MAJOR_VERSION}" \
        "${version}" \
        "${filename}"
}

measure_url() {
    local url="${1}"
    local result http_code time_total

    result="$(curl \
        --fail \
        --location \
        --range 0-1048575 \
        --max-filesize 2097152 \
        --max-time 12 \
        --silent \
        --show-error \
        --output /dev/null \
        --write-out '%{http_code} %{time_total}' \
        "${url}" 2>/dev/null || true)"

    http_code="${result%% *}"
    time_total="${result##* }"
    case "${http_code}" in
    206) printf '%s %s\n' "${time_total}" "${url}" ;;
    esac
}

select_fastest_jdk_url() {
    local version="${1}"
    local filename="${2}"
    local api_link="${3}"
    local mirror_page="${4}"
    local candidates_file results_file base url fastest

    candidates_file="$(make_temp_dir)/jdk-url-candidates.txt"
    results_file="$(make_temp_dir)/jdk-url-results.txt"

    fetch_official_mirror_bases "${mirror_page}" | awk 'NF && !seen[$0]++' | while IFS= read -r base; do
        official_mirror_url "${base}" "${version}" "${filename}"
    done >"${candidates_file}"

    printf '%s\n' "${api_link}" >>"${candidates_file}"

    log_info "==> Testing Eclipse Temurin download mirrors" >&2
    while IFS= read -r url; do
        measure_url "${url}" >>"${results_file}"
    done <"${candidates_file}"

    fastest="$(sort -n "${results_file}" | head -n 1 | cut -d' ' -f2-)"
    [[ -n "${fastest}" ]] || fail "No reachable Eclipse Temurin download URL"
    printf '%s\n' "${fastest}"
}

download_jdk_archive() {
    local url="${1}"
    local archive="${2}"
    local partial="${archive}.part"

    log_info "==> Downloading JDK from ${url}"
    rm -f -- "${partial}"
    curl --fail --location --show-error --progress-bar "${url}" --output "${partial}"
    mv -- "${partial}" "${archive}"
}

verify_jdk_archive() {
    local archive="${1}"
    local sha256="${2}"

    printf '%s  %s\n' "${sha256}" "${archive}" | sha256sum -c --status -
    tar -tzf "${archive}" >/dev/null || {
        rm -f -- "${archive}"
        fail "Downloaded JDK archive is incomplete or invalid: ${archive}"
    }
    log_success "JDK archive SHA-256 verified"
}

install_jdk_archive() {
    local archive="${1}"
    local version="${2}"

    safe_rm_rf_under "${JDK_ROOT}" "${BUILD_ROOT}"
    mkdir -p -- "${JDK_ROOT}"

    log_info "==> Installing JDK ${version}"
    tar -xzf "${archive}" -C "${JDK_ROOT}" --strip-components=1
    printf '%s\n' "${version}" >"${JDK_VERSION_FILE}"
    jdk_is_valid || fail "Installed JDK is invalid: ${JDK_ROOT}"
}

main() {
    local archive checksum filename link metadata mirror_page selected_url version
    local -a release

    case "${1:-}" in
    -h | --help)
        usage
        return 0
        ;;
    '') ;;
    *) fail "Unexpected argument: ${1}" ;;
    esac

    [[ "$(host_os)" == linux ]] || fail "JDK setup supports Linux only"
    require_jdk_setup_tools
    install_cleanup_trap
    mkdir -p -- "${DOWNLOAD_ROOT}"

    metadata="$(make_temp_dir)/adoptium-release.json"
    mirror_page="$(make_temp_dir)/eclipse-temurin-mirrors.html"
    mapfile -t release < <(resolve_jdk_release "${metadata}")
    version="${release[0]}"
    filename="${release[1]}"
    link="${release[2]}"
    checksum="${release[3]}"
    archive="${DOWNLOAD_ROOT}/${filename}"

    log_info "version: ${version}"
    log_info "archive: ${filename}"

    if [[ -f "${JDK_VERSION_FILE}" ]] && [[ "$(<"${JDK_VERSION_FILE}")" == "${version}" ]] && jdk_is_valid; then
        log_success "JDK ${version} exists: ${JDK_ROOT}"
        return 0
    fi

    selected_url="$(select_fastest_jdk_url "${version}" "${filename}" "${link}" "${mirror_page}")"
    log_info "selected: ${selected_url}"

    download_jdk_archive "${selected_url}" "${archive}"
    verify_jdk_archive "${archive}" "${checksum}"
    install_jdk_archive "${archive}" "${version}"
    log_success "JDK setup complete"
}

main "$@"
