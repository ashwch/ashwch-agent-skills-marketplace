#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME_DIR="${1:-${CODEX_HOME:-$HOME/.codex}}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for plugin_dir in "$REPO_ROOT"/plugins/*; do
  if [[ -d "$plugin_dir" ]]; then
    plugin_name="$(basename "$plugin_dir")"
    if [[ -d "$plugin_dir/skills/$plugin_name" ]]; then
      bash "$REPO_ROOT/scripts/install-skill.sh" "$plugin_name" "$CODEX_HOME_DIR"
    fi
  fi
done
