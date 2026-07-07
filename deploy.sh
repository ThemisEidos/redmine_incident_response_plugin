#!/usr/bin/env bash
set -euo pipefail

# Always operate from the repo root, wherever the script is invoked from.
cd "$(dirname "$0")"

PLUGIN_DIR="${PLUGIN_DIR:-/root/redmine-6.1/plugins/redmine_incident_response}"
REDMINE_TMP="${REDMINE_TMP:-/root/redmine-6.1/tmp}"

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${branch}" != "main" ]]; then
  echo "ERROR: deploy.sh deploys 'main' only (currently on '${branch}')." >&2
  exit 1
fi

echo "==> Pulling latest from git..."
git pull --ff-only origin main

echo "==> Syncing plugin files to ${PLUGIN_DIR}..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='deploy.sh' \
  --exclude='Templates/' \
  --exclude='Guidance Documents/' \
  --exclude='docs/superpowers/' \
  --exclude='claude.md' \
  ./ "${PLUGIN_DIR}/"

echo "==> Triggering Passenger restart..."
touch "${REDMINE_TMP}/restart.txt"

echo "==> Done. Plugin deployed."
