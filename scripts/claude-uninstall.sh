#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH"
  exit 1
fi

echo "Uninstalling user-scoped plugin: sony-raw-styled-jpeg@ashwch"
claude plugin uninstall sony-raw-styled-jpeg@ashwch || true

echo "If plugin was installed with --scope project, run:"
echo "  claude plugin uninstall sony-raw-styled-jpeg@ashwch --scope project"
