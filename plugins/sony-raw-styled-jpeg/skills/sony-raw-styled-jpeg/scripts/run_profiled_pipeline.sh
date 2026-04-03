#!/usr/bin/env bash
set -euo pipefail

# Profile-driven runner for Sony RAW -> styled JPEG conversion.
#
# Why this wrapper exists:
# - Splits technical correction from optional mood shaping.
# - Buckets mixed batches before rendering instead of forcing one global grade.
# - Preserves the same EXIF validation contract as the exact pipeline.
#
# Usage:
#   bash run_profiled_pipeline.sh <input_dir> <output_subdir> [mood_preset]
#
# Example:
#   bash run_profiled_pipeline.sh /path/to/arw-folder codex_output none
#   bash run_profiled_pipeline.sh /path/to/arw-folder codex_output subtle

INPUT_DIR="${1:-.}"
OUTPUT_SUBDIR="${2:-codex_output}"
MOOD_PRESET="${3:-none}"

case "$MOOD_PRESET" in
  none|subtle) ;;
  *)
    echo "ERROR: mood preset must be 'none' or 'subtle'" >&2
    exit 2
    ;;
esac

INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
OUTPUT_DIR="$INPUT_DIR/$OUTPUT_SUBDIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILER="$SCRIPT_DIR/profile_raw_images.swift"
RENDERER="$SCRIPT_DIR/render_profiled_batch.swift"
VERIFIER="$SCRIPT_DIR/verify_datetime_original.swift"
MODULE_CACHE_DIR="/tmp/swift-module-cache"
BUILD_DIR="$(mktemp -d /tmp/sony-raw-profiled.XXXXXX)"
PROFILER_BIN="$BUILD_DIR/profile_raw_images"
RENDERER_BIN="$BUILD_DIR/render_profiled_batch"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

mkdir -p "$MODULE_CACHE_DIR"

if [[ -e "$OUTPUT_DIR" ]] && [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "ERROR: output path exists and is not a directory: $OUTPUT_DIR" >&2
  exit 2
fi

if [[ -d "$OUTPUT_DIR" ]] && find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 | read -r _; then
  echo "ERROR: output directory already exists and is not empty: $OUTPUT_DIR" >&2
  echo "ERROR: rename/remove it first or use the interactive runner to preserve it automatically." >&2
  exit 2
fi

echo "[1/5] Compiling profiler"
swiftc -module-cache-path "$MODULE_CACHE_DIR" "$PROFILER" -o "$PROFILER_BIN"

echo "[2/5] Profiling RAW batch"
"$PROFILER_BIN" "$INPUT_DIR"

echo "[3/5] Compiling profiled renderer"
swiftc -module-cache-path "$MODULE_CACHE_DIR" "$RENDERER" -o "$RENDERER_BIN"

echo "[4/5] Rendering profiled JPEG batch"
"$RENDERER_BIN" "$INPUT_DIR" "$OUTPUT_DIR" "$MOOD_PRESET"

echo "[5/5] Validating EXIF timestamps"
swift -module-cache-path "$MODULE_CACHE_DIR" "$VERIFIER" "$INPUT_DIR" "$OUTPUT_DIR" | tee "$OUTPUT_DIR/exif_validation.txt"

echo "Profiled pipeline complete"
echo "  Output JPEG dir: $OUTPUT_DIR"
echo "  Profile CSV: $INPUT_DIR/profiling/raw_profile.csv"
echo "  Profile summary: $INPUT_DIR/profiling/raw_profile_summary.txt"
echo "  Treatment report: $OUTPUT_DIR/profiled_style_report.csv"
echo "  EXIF validation: $OUTPUT_DIR/exif_validation.txt"
