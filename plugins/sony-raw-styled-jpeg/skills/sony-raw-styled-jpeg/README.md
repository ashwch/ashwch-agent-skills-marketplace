# sony-raw-styled-jpeg

Sony RAW (`.ARW`) to high-quality JPEG conversion skill with two workflows:

- exact one-pass conversion
- profile-driven batch conversion for mixed lighting and iterative feedback

Both preserve EXIF metadata and validate capture timestamps.

## What it does

1. Decodes Sony RAW images with CoreImage.
2. Either runs a fixed exact style engine or profiles the batch into treatment cohorts.
3. Applies technical correction per cohort, with an optional subtle mood layer in profiled mode.
4. Exports JPEGs at high quality (`quality=1.0`).
5. Preserves EXIF metadata and validates date fields.

## Primary files

- `SKILL.md`: Invocation and runtime workflow.
- `scripts/raw_to_styled_jpeg.swift`: Conversion + style engine.
- `scripts/profile_raw_images.swift`: Batch profiler.
- `scripts/render_profiled_batch.swift`: Profile-driven renderer.
- `scripts/run_exact_pipeline.sh`: Deterministic batch pipeline.
- `scripts/run_profiled_pipeline.sh`: Profile-driven batch pipeline.
- `scripts/run_interactive_pipeline.sh`: Prompt-driven workflow chooser.
- `scripts/verify_datetime_original.swift`: EXIF/timestamp validator.
- `references/PIPELINE_FIRST_PRINCIPLES.md`: Full conceptual + ASCII documentation.
- `references/ADAPTIVE_BATCH_WORKFLOW.md`: Reusable profile/bucket/transform/validate playbook.

## Quick usage

From the skill folder:

```bash
bash scripts/run_exact_pipeline.sh /path/to/arw-folder codex_output
```

Profiled mode:

```bash
bash scripts/run_profiled_pipeline.sh /path/to/arw-folder codex_output none
```

Interactive mode:

```bash
bash scripts/run_interactive_pipeline.sh
```

## Outputs

Expected artifacts in output folder:

- `*.jpg` converted images
- `style_report.csv` or `profiled_style_report.csv`
- `exif_validation.txt`

Expected artifacts for profiled mode in the input folder:

- `profiling/raw_profile.csv`
- `profiling/raw_profile_summary.txt`

Success criteria:

- JPEG count matches processed ARW count.
- `exif_validation.txt` ends with `RESULT: PASS`.

## Runtime notes

- Designed for user-level installation in Codex and Claude plugin workflows.
- Interactive mode can preserve an existing output directory before a rerun.
- If RAW decode fails in restricted environments, rerun with permissions that allow full image decoding.
