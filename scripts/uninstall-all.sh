#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME_DIR="${1:-${CODEX_HOME:-$HOME/.codex}}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for skill_dir in "$REPO_ROOT"/skills/*; do
  if [[ -d "$skill_dir" ]]; then
    skill_name="$(basename "$skill_dir")"
    bash "$REPO_ROOT/scripts/uninstall-skill.sh" "$skill_name" "$CODEX_HOME_DIR"
  fi
done
