#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Load local .env if present (strictly excluded from Git)
if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source ".env"
fi

: "${GITLAB_USER:?Error: GITLAB_USER is not set. Define it in .env or export it in your shell.}"
: "${GITLAB_PROJECT_ID:?Error: GITLAB_PROJECT_ID is not set. Define it in .env or export it in your shell.}"
: "${GITLAB_TOKEN:?Error: GITLAB_TOKEN is not set. Define it in .env or export it in your shell.}"
STATE_NAME="${STATE_NAME:-homelab-bootstrap}"

STATE_URL="https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/terraform/state/${STATE_NAME}"

echo "Initializing OpenTofu HTTP backend against GitLab project ${GITLAB_PROJECT_ID} (state: ${STATE_NAME})..."

tofu init -reconfigure \
  -backend-config="address=${STATE_URL}" \
  -backend-config="lock_address=${STATE_URL}/lock" \
  -backend-config="unlock_address=${STATE_URL}/lock" \
  -backend-config="username=${GITLAB_USER}" \
  -backend-config="password=${GITLAB_TOKEN}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
