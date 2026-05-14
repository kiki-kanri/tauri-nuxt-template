#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

. ./.env.development.local
export PNPM_CONFIG_REGISTRY

rm -rf ./.nuxt
[[ " $@ " =~ ' -c ' ]] && rm -rf ./node_modules ./pnpm-lock.yaml

pnpm upgrade -L
pnpm run postinstall
./modify-files-permissions.sh
