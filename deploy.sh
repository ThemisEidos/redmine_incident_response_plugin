#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="/root/redmine-6.1/plugins/redmine_incident_response"
REDMINE_TMP="/root/redmine-6.1/tmp"

echo "==> Pulling latest from git..."
git pull origin main

echo "==> Syncing plugin files to ${PLUGIN_DIR}..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='deploy.sh' \
  --exclude='Templates/' \
  --exclude='Guidance Documents/' \
  --exclude='claude.md' \
  ./ "${PLUGIN_DIR}/"

echo "==> Triggering Passenger restart..."
touch "${REDMINE_TMP}/restart.txt"

echo "==> Done. Plugin deployed."
