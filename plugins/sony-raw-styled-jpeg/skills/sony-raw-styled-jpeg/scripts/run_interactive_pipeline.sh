#!/usr/bin/env bash
set -euo pipefail

# Interactive runner for Sony RAW -> styled JPEG conversion.
#
# This script intentionally asks the user for operational choices so a session
# can be guided without editing commands manually. It can run either the
# exact one-pass pipeline or the profiled adaptive pipeline.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXACT_RUNNER="$SCRIPT_DIR/run_exact_pipeline.sh"
PROFILED_RUNNER="$SCRIPT_DIR/run_profiled_pipeline.sh"

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

workflow_mode="$(prompt_choice "5) Workflow mode (exact/profiled)" "profiled" exact profiled)"
mood_preset="none"
if [[ "$workflow_mode" == "profiled" ]]; then
  mood_preset="$(prompt_choice "6) Mood layer (none/subtle)" "none" none subtle)"
fi

preserve_existing="$(prompt_choice "7) If output folder exists, preserve it first? (yes/no)" "yes" yes no)"

preview_choice="$(prompt_choice "8) Preview output picture paths? (yes/no)" "yes" yes no)"
preview_count="3"
if [[ "$preview_choice" == "yes" ]]; then
  preview_count="$(prompt_default "9) How many preview paths to print" "3")"
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
echo "  Workflow mode: $workflow_mode"
if [[ "$workflow_mode" == "profiled" ]]; then
  echo "  Mood layer: $mood_preset"
fi
echo "  EXIF preservation: full metadata (enforced)"
echo "  Preserve existing output dir: $preserve_existing"
if [[ "$preview_choice" == "yes" ]]; then
  echo "  Preview paths requested: $preview_count"
fi

proceed="$(prompt_yes_no "Proceed now" "yes")"
if [[ "$proceed" != "yes" ]]; then
  echo "Cancelled"
  exit 0
fi

shopt -s nullglob
final_output_dir="$input_dir/$output_subdir"

prepare_output_dir() {
  local target="$1"
  local preserve_mode="$2"

  if [[ ! -e "$target" ]]; then
    return 0
  fi

  if [[ "$preserve_mode" == "yes" ]]; then
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local backup_path="${target}_backup_${timestamp}"
    mv "$target" "$backup_path"
    echo "Preserved existing output dir: $backup_path"
    return 0
  fi

  echo "ERROR: output folder already exists: $target"
  echo "ERROR: choose a new output name or rerun with preserve=yes"
  exit 2
}

if [[ "$workflow_mode" == "exact" ]]; then
  runner="$EXACT_RUNNER"
else
  runner="$PROFILED_RUNNER"
fi

if [[ "$scope" == "all" ]]; then
  prepare_output_dir "$final_output_dir" "$preserve_existing"
  if [[ "$workflow_mode" == "exact" ]]; then
    bash "$runner" "$input_dir" "$output_subdir"
    final_report="$final_output_dir/style_report.csv"
  else
    bash "$runner" "$input_dir" "$output_subdir" "$mood_preset"
    final_report="$final_output_dir/profiled_style_report.csv"
    final_profile_csv="$input_dir/profiling/raw_profile.csv"
    final_profile_summary="$input_dir/profiling/raw_profile_summary.txt"
  fi
  final_exif_report="$final_output_dir/exif_validation.txt"
else
  raw_files=()
  while IFS= read -r line; do
    raw_files+=("$line")
  done < <(find "$input_dir" -maxdepth 1 \( -type f -o -type l \) \( -iname '*.ARW' -o -iname '*.arw' \) | sort)
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

  prepare_output_dir "$final_output_dir" "$preserve_existing"
  mkdir -p "$final_output_dir"

  if [[ "$workflow_mode" == "exact" ]]; then
    bash "$runner" "$temp_dir" "$output_subdir"
  else
    bash "$runner" "$temp_dir" "$output_subdir" "$mood_preset"
  fi

  for jpg in "$temp_dir/$output_subdir"/*.jpg; do
    cp "$jpg" "$final_output_dir/"
  done

  if [[ "$workflow_mode" == "exact" ]]; then
    final_report="$final_output_dir/style_report_sample.csv"
    cp "$temp_dir/$output_subdir/style_report.csv" "$final_report"
  else
    final_report="$final_output_dir/profiled_style_report_sample.csv"
    final_profile_csv="$final_output_dir/raw_profile_sample.csv"
    final_profile_summary="$final_output_dir/raw_profile_summary_sample.txt"
    cp "$temp_dir/$output_subdir/profiled_style_report.csv" "$final_report"
    cp "$temp_dir/profiling/raw_profile.csv" "$final_profile_csv"
    cp "$temp_dir/profiling/raw_profile_summary.txt" "$final_profile_summary"
  fi
  final_exif_report="$final_output_dir/exif_validation_sample.txt"
  cp "$temp_dir/$output_subdir/exif_validation.txt" "$final_exif_report"
fi

if [[ -f "$final_exif_report" ]] && ! grep -q "RESULT: PASS" "$final_exif_report"; then
  echo "ERROR: EXIF validation did not pass. Check: $final_exif_report"
  exit 2
fi

if [[ "$preview_choice" == "yes" ]]; then
  echo ""
  echo "Representative output picture paths"
  previews=()
  while IFS= read -r line; do
    previews+=("$line")
  done < <(find "$final_output_dir" -maxdepth 1 -type f -iname '*.jpg' | sort | head -n "$preview_count")
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
echo "  Report: $final_report"
if [[ "$workflow_mode" == "profiled" ]]; then
  echo "  Profile CSV: $final_profile_csv"
  echo "  Profile summary: $final_profile_summary"
fi
echo "  EXIF report: $final_exif_report"
