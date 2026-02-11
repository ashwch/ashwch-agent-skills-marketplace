#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <skill-name> [codex-home]"
  exit 1
fi

SKILL_NAME="$1"
CODEX_HOME_DIR="${2:-${CODEX_HOME:-$HOME/.codex}}"
DST_DIR="$CODEX_HOME_DIR/skills/$SKILL_NAME"

if [[ ! -d "$DST_DIR" ]]; then
  echo "Skill not installed: $SKILL_NAME"
  echo "Expected location: $DST_DIR"
  exit 0
fi

rm -rf "$DST_DIR"
echo "Uninstalled skill: $SKILL_NAME"
echo "Removed: $DST_DIR"
