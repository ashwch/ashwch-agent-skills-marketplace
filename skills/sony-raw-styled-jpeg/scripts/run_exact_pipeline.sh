#!/usr/bin/env bash
set -euo pipefail

# Deterministic runner for the Sony RAW -> styled JPEG pipeline.
#
# Why this wrapper exists:
# - Keeps compile flags and cache path stable.
# - Ensures conversion and EXIF validation always run together.
# - Produces standard artifact names for downstream automation.
#
# Usage:
#   bash run_exact_pipeline.sh <input_dir> <output_subdir>
#
# Example:
#   bash run_exact_pipeline.sh /path/to/arw-folder codex_output

INPUT_DIR="${1:-.}"
OUTPUT_SUBDIR="${2:-codex_output}"

# Normalize paths early to prevent relative-path surprises.
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
OUTPUT_DIR="$INPUT_DIR/$OUTPUT_SUBDIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTER="$SCRIPT_DIR/raw_to_styled_jpeg.swift"
VERIFIER="$SCRIPT_DIR/verify_datetime_original.swift"
BINARY="$INPUT_DIR/raw_to_styled_jpeg"
MODULE_CACHE_DIR="/tmp/swift-module-cache"

mkdir -p "$MODULE_CACHE_DIR"

echo "[1/3] Compiling converter"
swiftc -module-cache-path "$MODULE_CACHE_DIR" "$CONVERTER" -o "$BINARY"

echo "[2/3] Running conversion"
"$BINARY" "$INPUT_DIR" "$OUTPUT_DIR"

echo "[3/3] Validating EXIF timestamps"
swift -module-cache-path "$MODULE_CACHE_DIR" "$VERIFIER" "$INPUT_DIR" "$OUTPUT_DIR" | tee "$OUTPUT_DIR/exif_validation.txt"

echo "Pipeline complete"
echo "  Output JPEG dir: $OUTPUT_DIR"
echo "  Style report: $OUTPUT_DIR/style_report.csv"
echo "  EXIF validation: $OUTPUT_DIR/exif_validation.txt"
