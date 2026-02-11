#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH"
  exit 1
fi

echo "Adding marketplace: ashwch/ashwch-agent-skills-marketplace"
claude plugin marketplace add ashwch/ashwch-agent-skills-marketplace || true

echo "Installing plugin at user scope: sony-raw-styled-jpeg@ashwch"
claude plugin install sony-raw-styled-jpeg@ashwch

echo "Done"
