#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(mktemp -d /tmp/sony-revision-test.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/runner" "$TEST_ROOT/raw" "$TEST_ROOT/final"
cp "$SCRIPT_DIR/run_profiled_revision.sh" "$TEST_ROOT/runner/"
cp "$SCRIPT_DIR/verify_datetime_original.swift" "$TEST_ROOT/runner/"

cat > "$TEST_ROOT/runner/run_profiled_pipeline.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
input_dir="$1"
output_dir="$input_dir/$2"
mkdir -p "$output_dir"
printf 'file,treatment,mood_mode,status,error\n' > "$output_dir/profiled_style_report.csv"
for raw_path in "$input_dir"/*.ARW; do
  raw_name="$(basename "$raw_path")"
  jpeg_name="${raw_name%.ARW}.jpg"
  cp "$raw_path" "$output_dir/$jpeg_name"
  printf '%s,test,none,ok,\n' "$raw_name" >> "$output_dir/profiled_style_report.csv"
done
printf 'RESULT: PASS\n' > "$output_dir/exif_validation.txt"
RUNNER
chmod +x "$TEST_ROOT/runner/run_profiled_pipeline.sh"

printf 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==\n' | base64 -D > "$TEST_ROOT/pixel.gif"
sips -s format jpeg -z 2 2 "$TEST_ROOT/pixel.gif" --out "$TEST_ROOT/square.jpg" >/dev/null
sips -s format jpeg -z 2 3 "$TEST_ROOT/pixel.gif" --out "$TEST_ROOT/wide.jpg" >/dev/null

for image_name in safe deleted changed dimension missing; do
  cp "$TEST_ROOT/square.jpg" "$TEST_ROOT/raw/$image_name.ARW"
done
for image_name in safe deleted changed dimension; do
  cp "$TEST_ROOT/square.jpg" "$TEST_ROOT/final/$image_name.jpg"
done
printf '%s\n' safe deleted changed dimension missing > "$TEST_ROOT/selection.txt"

REVISION_RUNNER="$TEST_ROOT/runner/run_profiled_revision.sh"
if bash "$REVISION_RUNNER" stage "$TEST_ROOT/raw" "$TEST_ROOT/final" "$TEST_ROOT/selection.txt" "$TEST_ROOT/invalid" invalid >/dev/null 2>&1; then
  echo "ERROR: invalid render preset passed" >&2
  exit 1
fi
[[ ! -e "$TEST_ROOT/invalid" ]]

bash "$REVISION_RUNNER" stage "$TEST_ROOT/raw" "$TEST_ROOT/final" "$TEST_ROOT/selection.txt" "$TEST_ROOT/revision" none >/dev/null
[[ "$(wc -l < "$TEST_ROOT/revision/skipped_missing_outputs.txt" | tr -d ' ')" -eq 1 ]]

cp "$TEST_ROOT/wide.jpg" "$TEST_ROOT/revision/input/staged/dimension.jpg"
rm "$TEST_ROOT/final/deleted.jpg"
printf '\0' >> "$TEST_ROOT/final/changed.jpg"
bash "$REVISION_RUNNER" apply "$TEST_ROOT/raw" "$TEST_ROOT/final" "$TEST_ROOT/revision" >/dev/null

grep -q $'^applied\tsafe.jpg$' "$TEST_ROOT/revision/revision_apply.txt"
grep -q $'^skipped_deleted_after_stage\tdeleted.jpg$' "$TEST_ROOT/revision/revision_apply.txt"
grep -q $'^skipped_changed_after_stage\tchanged.jpg$' "$TEST_ROOT/revision/revision_apply.txt"
grep -q $'^skipped_dimension_change\tdimension.jpg\t' "$TEST_ROOT/revision/revision_apply.txt"
grep -q '^RESULT: PASS$' "$TEST_ROOT/final/exif_validation.txt"

echo "Profiled revision safety test passed"
