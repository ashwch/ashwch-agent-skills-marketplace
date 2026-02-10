#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <skill-name> [codex-home]"
  exit 1
fi

SKILL_NAME="$1"
CODEX_HOME_DIR="${2:-${CODEX_HOME:-$HOME/.codex}}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills/$SKILL_NAME"
DST_DIR="$CODEX_HOME_DIR/skills/$SKILL_NAME"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: skill not found: $SRC_DIR"
  exit 1
fi

mkdir -p "$CODEX_HOME_DIR/skills"
rm -rf "$DST_DIR"
cp -R "$SRC_DIR" "$DST_DIR"

echo "Installed skill: $SKILL_NAME"
echo "Destination: $DST_DIR"
