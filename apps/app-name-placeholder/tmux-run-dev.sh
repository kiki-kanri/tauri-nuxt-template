#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

SESSION_NAME='nuxt-project'

if ! tmux ls | grep -q "^${SESSION_NAME}:"; then
    tmux new-session -ds "${SESSION_NAME}"
    tmux send-keys -t "${SESSION_NAME}" 'pnpm run dev' C-m
fi
