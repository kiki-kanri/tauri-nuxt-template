#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

. ./.env.development.local
export PNPM_CONFIG_REGISTRY

pnpm i
./modify-files-permissions.sh
