#!/usr/bin/env bash
set -euo pipefail

# Interactive runner for Sony RAW -> styled JPEG conversion.
#
# This script intentionally asks the user for operational choices so a session
# can be guided without editing commands manually. The underlying conversion
# stays the same as run_exact_pipeline.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXACT_RUNNER="$SCRIPT_DIR/run_exact_pipeline.sh"

prompt_default() {
  local message="$1"
  local default_value="$2"
  local response
  read -r -p "$message [$default_value]: " response
  if [[ -z "$response" ]]; then
    response="$default_value"
  fi
  printf '%s' "$response"
}

prompt_yes_no() {
  local message="$1"
  local default_value="$2"
  local response
  read -r -p "$message [$default_value]: " response
  if [[ -z "$response" ]]; then
    response="$default_value"
  fi
  response="$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')"
  if [[ "$response" == "y" || "$response" == "yes" ]]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

prompt_choice() {
  local message="$1"
  local default_value="$2"
  shift 2
  local allowed=("$@")
  local response
  read -r -p "$message [$default_value]: " response
  if [[ -z "$response" ]]; then
    response="$default_value"
  fi
  response="$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')"
  for option in "${allowed[@]}"; do
    if [[ "$response" == "$option" ]]; then
      printf '%s' "$response"
      return 0
    fi
  done
  echo "ERROR: invalid option '$response'. Allowed: ${allowed[*]}" >&2
  exit 1
}

echo "Sony RAW -> Styled JPEG Interactive Pipeline"
echo ""

default_input="$(pwd)"
input_raw="$(prompt_default "1) Input folder containing .ARW files" "$default_input")"
if [[ ! -d "$input_raw" ]]; then
  echo "ERROR: Input folder does not exist: $input_raw"
  exit 1
fi

input_dir="$(cd "$input_raw" && pwd)"
output_subdir="$(prompt_default "2) Output folder name (inside input folder)" "codex_output")"

scope="$(prompt_choice "3) Processing scope (all/sample)" "all" all sample)"
sample_count="24"
if [[ "$scope" == "sample" ]]; then
  sample_count="$(prompt_default "4) Sample size (first N sorted RAW files)" "24")"
  if ! [[ "$sample_count" =~ ^[0-9]+$ ]] || [[ "$sample_count" -lt 1 ]]; then
    echo "ERROR: sample size must be a positive integer"
    exit 1
  fi
fi

metadata_policy="$(prompt_choice "5) Metadata policy (full/capture-only)" "full" full capture-only)"
if [[ "$metadata_policy" != "full" ]]; then
  echo "NOTE: exact replication always preserves full EXIF. Continuing with full EXIF."
fi

quality_profile="$(prompt_choice "6) Quality profile (exact/custom)" "exact" exact custom)"
if [[ "$quality_profile" != "exact" ]]; then
  echo "NOTE: exact pipeline is fixed to quality=1.0 and predefined style chains."
  echo "NOTE: this runner will continue with exact mode to preserve reproducibility."
fi

preview_choice="$(prompt_choice "7) Preview output picture paths? (yes/no)" "yes" yes no)"
preview_count="3"
if [[ "$preview_choice" == "yes" ]]; then
  preview_count="$(prompt_default "8) How many preview paths to print" "3")"
  if ! [[ "$preview_count" =~ ^[0-9]+$ ]] || [[ "$preview_count" -lt 1 ]]; then
    echo "ERROR: preview count must be a positive integer"
    exit 1
  fi
fi

echo ""
echo "Execution plan"
echo "  Input dir: $input_dir"
echo "  Output subdir: $output_subdir"
echo "  Scope: $scope"
if [[ "$scope" == "sample" ]]; then
  echo "  Sample count: $sample_count"
fi
echo "  Metadata policy: full EXIF (enforced)"
echo "  Quality profile: exact (enforced)"
if [[ "$preview_choice" == "yes" ]]; then
  echo "  Preview paths requested: $preview_count"
fi

proceed="$(prompt_yes_no "Proceed now" "yes")"
if [[ "$proceed" != "yes" ]]; then
  echo "Cancelled"
  exit 0
fi

shopt -s nullglob

if [[ "$scope" == "all" ]]; then
  bash "$EXACT_RUNNER" "$input_dir" "$output_subdir"
  final_output_dir="$input_dir/$output_subdir"
  final_style_report="$final_output_dir/style_report.csv"
  final_exif_report="$final_output_dir/exif_validation.txt"
else
  mapfile -t raw_files < <(find "$input_dir" -maxdepth 1 \( -type f -o -type l \) \( -iname '*.ARW' -o -iname '*.arw' \) | sort)
  if [[ "${#raw_files[@]}" -eq 0 ]]; then
    echo "ERROR: no ARW files found in $input_dir"
    exit 1
  fi

  temp_dir="$(mktemp -d /tmp/sony-raw-subset.XXXXXX)"
  cleanup() {
    rm -rf "$temp_dir"
  }
  trap cleanup EXIT

  selected=("${raw_files[@]:0:$sample_count}")
  for raw in "${selected[@]}"; do
    ln -s "$raw" "$temp_dir/$(basename "$raw")"
  done

  bash "$EXACT_RUNNER" "$temp_dir" "$output_subdir"

  final_output_dir="$input_dir/$output_subdir"
  mkdir -p "$final_output_dir"

  for jpg in "$temp_dir/$output_subdir"/*.jpg; do
    cp "$jpg" "$final_output_dir/"
  done

  final_style_report="$final_output_dir/style_report_sample.csv"
  final_exif_report="$final_output_dir/exif_validation_sample.txt"

  cp "$temp_dir/$output_subdir/style_report.csv" "$final_style_report"
  cp "$temp_dir/$output_subdir/exif_validation.txt" "$final_exif_report"
fi

if [[ -f "$final_exif_report" ]] && ! grep -q "RESULT: PASS" "$final_exif_report"; then
  echo "ERROR: EXIF validation did not pass. Check: $final_exif_report"
  exit 2
fi

if [[ "$preview_choice" == "yes" ]]; then
  echo ""
  echo "Representative output picture paths"
  mapfile -t previews < <(find "$final_output_dir" -maxdepth 1 -type f -iname '*.jpg' | sort | head -n "$preview_count")
  if [[ "${#previews[@]}" -eq 0 ]]; then
    echo "  (No JPEG files found in $final_output_dir)"
  else
    for p in "${previews[@]}"; do
      echo "  $p"
    done
  fi
fi

echo ""
echo "Interactive run complete"
echo "  Output dir: $final_output_dir"
echo "  Style report: $final_style_report"
echo "  EXIF report: $final_exif_report"
