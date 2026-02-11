#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <plugin-name> [codex-home]"
  exit 1
fi

PLUGIN_NAME="$1"
CODEX_HOME_DIR="${2:-${CODEX_HOME:-$HOME/.codex}}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/plugins/$PLUGIN_NAME/skills/$PLUGIN_NAME"
DST_DIR="$CODEX_HOME_DIR/skills/$PLUGIN_NAME"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: plugin skill not found: $SRC_DIR"
  exit 1
fi

mkdir -p "$CODEX_HOME_DIR/skills"
rm -rf "$DST_DIR"
cp -R "$SRC_DIR" "$DST_DIR"

echo "Installed skill from plugin: $PLUGIN_NAME"
echo "Destination: $DST_DIR"
