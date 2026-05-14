#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

. ./.env.development.local
export PNPM_CONFIG_REGISTRY

pnpm i
./modify-files-permissions.sh
