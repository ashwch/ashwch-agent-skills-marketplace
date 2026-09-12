#!/usr/bin/env bash
set -euo pipefail

# Stage and apply a profile-driven revision without recreating user-deleted JPEGs.
#
# Usage:
#   bash run_profiled_revision.sh stage <raw_dir> <output_dir> <selection_file> <revision_dir> [render_preset]
#   bash run_profiled_revision.sh apply <raw_dir> <output_dir> <revision_dir>
#
# Selection files contain one image basename, RAW name, or JPEG name per line.
# Blank lines and lines beginning with # are ignored.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILED_RUNNER="$SCRIPT_DIR/run_profiled_pipeline.sh"
VERIFIER="$SCRIPT_DIR/verify_datetime_original.swift"
MODULE_CACHE_DIR="/tmp/swift-module-cache"
ACTION="${1:-}"

print_usage() {
  grep '^#   bash run_profiled_revision.sh' "$0" | sed 's/^#   //'
}

get_dimensions() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null \
    | awk '/pixelWidth:/ { width = $2 } /pixelHeight:/ { height = $2 } END { if (width == "" || height == "") exit 1; print width "x" height }'
}

if [[ "$ACTION" == "stage" ]]; then
  if [[ "$#" -lt 5 || "$#" -gt 6 ]]; then
    print_usage >&2
    exit 2
  fi

  RAW_DIR="$(cd "$2" && pwd)"
  OUTPUT_DIR="$(cd "$3" && pwd)"
  SELECTION_FILE="$(cd "$(dirname "$4")" && pwd)/$(basename "$4")"
  REVISION_DIR="$5"
  RENDER_PRESET="${6:-none}"

  case "$RENDER_PRESET" in
    none|subtle|natural-twilight) ;;
    *)
      echo "ERROR: render preset must be 'none', 'subtle', or 'natural-twilight'" >&2
      exit 2
      ;;
  esac

  if [[ ! -f "$SELECTION_FILE" ]]; then
    echo "ERROR: selection file does not exist: $SELECTION_FILE" >&2
    exit 2
  fi
  if [[ -d "$REVISION_DIR" ]] && find "$REVISION_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "ERROR: revision directory is not empty: $REVISION_DIR" >&2
    exit 2
  fi

  mkdir -p "$REVISION_DIR/input" "$REVISION_DIR/previous"
  REVISION_DIR="$(cd "$REVISION_DIR" && pwd)"
  INCLUDED_FILE="$REVISION_DIR/included_files.txt"
  SKIPPED_FILE="$REVISION_DIR/skipped_missing_outputs.txt"
  HASH_FILE="$REVISION_DIR/baseline_sha256.txt"
  : > "$INCLUDED_FILE"
  : > "$SKIPPED_FILE"
  : > "$HASH_FILE"

  while IFS= read -r requested_file || [[ -n "$requested_file" ]]; do
    requested_file="${requested_file%$'\r'}"
    [[ -z "$requested_file" || "$requested_file" == \#* ]] && continue

    requested_name="$(basename "$requested_file")"
    requested_stem="${requested_name%.*}"
    raw_path="$(find "$RAW_DIR" -maxdepth 1 \( -type f -o -type l \) -iname "$requested_stem.arw" -print -quit)"
    if [[ -z "$raw_path" ]]; then
      echo "ERROR: no matching RAW for selection: $requested_file" >&2
      exit 2
    fi

    raw_name="$(basename "$raw_path")"
    jpeg_name="${raw_name%.*}.jpg"
    if [[ ! -f "$OUTPUT_DIR/$jpeg_name" ]]; then
      printf '%s\n' "$jpeg_name" >> "$SKIPPED_FILE"
      continue
    fi
    if grep -Fqx "$jpeg_name" "$INCLUDED_FILE"; then
      continue
    fi

    ln -s "$raw_path" "$REVISION_DIR/input/$raw_name"
    cp -p "$OUTPUT_DIR/$jpeg_name" "$REVISION_DIR/previous/$jpeg_name"
    baseline_hash="$(shasum -a 256 "$OUTPUT_DIR/$jpeg_name" | cut -d ' ' -f 1)"
    printf '%s\t%s\n' "$baseline_hash" "$jpeg_name" >> "$HASH_FILE"
    printf '%s\n' "$jpeg_name" >> "$INCLUDED_FILE"
  done < "$SELECTION_FILE"

  included_count="$(wc -l < "$INCLUDED_FILE" | tr -d ' ')"
  skipped_count="$(wc -l < "$SKIPPED_FILE" | tr -d ' ')"
  if [[ "$included_count" -eq 0 ]]; then
    echo "ERROR: no selected images have an existing output JPEG" >&2
    exit 2
  fi

  bash "$PROFILED_RUNNER" "$REVISION_DIR/input" staged "$RENDER_PRESET"
  printf '%s\n' "$RENDER_PRESET" > "$REVISION_DIR/render_preset.txt"
  DIMENSION_CHANGES_FILE="$REVISION_DIR/dimension_changes.txt"
  : > "$DIMENSION_CHANGES_FILE"
  while IFS= read -r jpeg_name; do
    current_dimensions="$(get_dimensions "$OUTPUT_DIR/$jpeg_name")"
    staged_dimensions="$(get_dimensions "$REVISION_DIR/input/staged/$jpeg_name")"
    if [[ "$current_dimensions" != "$staged_dimensions" ]]; then
      printf '%s\t%s\t%s\n' "$jpeg_name" "$current_dimensions" "$staged_dimensions" >> "$DIMENSION_CHANGES_FILE"
    fi
  done < "$INCLUDED_FILE"
  dimension_change_count="$(wc -l < "$DIMENSION_CHANGES_FILE" | tr -d ' ')"

  echo "Revision staged"
  echo "  Existing outputs staged: $included_count"
  echo "  Missing outputs preserved as deleted: $skipped_count"
  echo "  Dimension changes requiring geometry-aware review: $dimension_change_count"
  echo "  Review JPEGs: $REVISION_DIR/input/staged"
  echo "  Apply after visual review with:"
  echo "    bash \"$SCRIPT_DIR/run_profiled_revision.sh\" apply \"$RAW_DIR\" \"$OUTPUT_DIR\" \"$REVISION_DIR\""
  exit 0
fi

if [[ "$ACTION" == "apply" ]]; then
  if [[ "$#" -ne 4 ]]; then
    print_usage >&2
    exit 2
  fi

  RAW_DIR="$(cd "$2" && pwd)"
  OUTPUT_DIR="$(cd "$3" && pwd)"
  REVISION_DIR="$(cd "$4" && pwd)"
  INCLUDED_FILE="$REVISION_DIR/included_files.txt"
  HASH_FILE="$REVISION_DIR/baseline_sha256.txt"
  STAGED_DIR="$REVISION_DIR/input/staged"
  APPLY_REPORT="$REVISION_DIR/revision_apply.txt"

  for required_path in "$INCLUDED_FILE" "$HASH_FILE" "$STAGED_DIR/exif_validation.txt"; do
    if [[ ! -f "$required_path" ]]; then
      echo "ERROR: incomplete staged revision; missing $required_path" >&2
      exit 2
    fi
  done
  if ! grep -q '^RESULT: PASS$' "$STAGED_DIR/exif_validation.txt"; then
    echo "ERROR: staged EXIF validation did not pass" >&2
    exit 2
  fi
  if [[ ! -s "$INCLUDED_FILE" ]]; then
    echo "ERROR: staged revision contains no images" >&2
    exit 2
  fi
  while IFS= read -r jpeg_name; do
    [[ -z "$jpeg_name" ]] && continue
    if [[ ! -f "$STAGED_DIR/$jpeg_name" || ! -f "$REVISION_DIR/previous/$jpeg_name" ]]; then
      echo "ERROR: staged revision is missing JPEG or backup for $jpeg_name" >&2
      exit 2
    fi
    baseline_hash="$(awk -F '\t' -v jpeg_name="$jpeg_name" '$2 == jpeg_name { print $1 }' "$HASH_FILE")"
    if [[ -z "$baseline_hash" ]]; then
      echo "ERROR: staged revision is missing baseline hash for $jpeg_name" >&2
      exit 2
    fi
  done < "$INCLUDED_FILE"

  : > "$APPLY_REPORT"
  applied_count=0
  skipped_deleted_count=0
  skipped_changed_count=0
  skipped_dimension_count=0
  while IFS= read -r jpeg_name; do
    [[ -z "$jpeg_name" ]] && continue
    if [[ ! -f "$OUTPUT_DIR/$jpeg_name" ]]; then
      printf 'skipped_deleted_after_stage\t%s\n' "$jpeg_name" >> "$APPLY_REPORT"
      skipped_deleted_count=$((skipped_deleted_count + 1))
      continue
    fi

    baseline_hash="$(awk -F '\t' -v jpeg_name="$jpeg_name" '$2 == jpeg_name { print $1 }' "$HASH_FILE")"
    current_hash="$(shasum -a 256 "$OUTPUT_DIR/$jpeg_name" | cut -d ' ' -f 1)"
    if [[ -z "$baseline_hash" || "$current_hash" != "$baseline_hash" ]]; then
      printf 'skipped_changed_after_stage\t%s\n' "$jpeg_name" >> "$APPLY_REPORT"
      skipped_changed_count=$((skipped_changed_count + 1))
      continue
    fi
    current_dimensions="$(get_dimensions "$OUTPUT_DIR/$jpeg_name")"
    staged_dimensions="$(get_dimensions "$STAGED_DIR/$jpeg_name")"
    if [[ "$current_dimensions" != "$staged_dimensions" ]]; then
      printf 'skipped_dimension_change\t%s\t%s\t%s\n' "$jpeg_name" "$current_dimensions" "$staged_dimensions" >> "$APPLY_REPORT"
      skipped_dimension_count=$((skipped_dimension_count + 1))
      continue
    fi

    temporary_output="$OUTPUT_DIR/.$jpeg_name.revision.$$"
    cp -p "$STAGED_DIR/$jpeg_name" "$temporary_output"
    mv -f "$temporary_output" "$OUTPUT_DIR/$jpeg_name"
    printf 'applied\t%s\n' "$jpeg_name" >> "$APPLY_REPORT"
    applied_count=$((applied_count + 1))
  done < "$INCLUDED_FILE"

  mkdir -p "$MODULE_CACHE_DIR"
  swift -module-cache-path "$MODULE_CACHE_DIR" "$VERIFIER" "$RAW_DIR" "$OUTPUT_DIR" --existing-only \
    | tee "$OUTPUT_DIR/exif_validation.txt"

  echo "Revision applied"
  echo "  Replaced: $applied_count"
  echo "  Deleted after staging and left absent: $skipped_deleted_count"
  echo "  Changed after staging and left untouched: $skipped_changed_count"
  echo "  Dimension changes left for geometry-aware rendering: $skipped_dimension_count"
  echo "  Previous JPEGs: $REVISION_DIR/previous"
  echo "  Apply report: $APPLY_REPORT"
  exit 0
fi

print_usage >&2
exit 2
