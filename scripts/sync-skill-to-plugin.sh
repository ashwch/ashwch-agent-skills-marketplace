#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <skill-name>"
  exit 1
fi

SKILL_NAME="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills/$SKILL_NAME"
DST_DIR="$REPO_ROOT/plugins/$SKILL_NAME/skills/$SKILL_NAME"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: skill not found at $SRC_DIR"
  exit 1
fi

mkdir -p "$DST_DIR"
rsync -a --delete "$SRC_DIR/" "$DST_DIR/"

echo "Synced skill -> plugin copy"
echo "  Source: $SRC_DIR"
echo "  Target: $DST_DIR"
