# sony-raw-styled-jpeg

Sony RAW (`.ARW`) to high-quality JPEG conversion skill with three workflows:

- exact one-pass conversion
- profile-driven first export for mixed lighting
- staged cohort revision that preserves user deletions and approved exceptions

All three preserve EXIF metadata and validate capture timestamps.

## What it does

1. Decodes Sony RAW images with CoreImage.
2. Either runs a fixed exact style engine or profiles the batch into treatment cohorts.
3. Applies the chosen render preset: technical (`none`), mood-only (`subtle`), or replacement treatment (`natural-twilight`).
4. Stages reviewed revisions before replacing existing JPEGs.
5. Exports JPEGs at high quality (`quality=1.0`).
6. Preserves EXIF metadata and validates date fields.

## Primary files

- `SKILL.md`: Invocation and runtime workflow.
- `scripts/raw_to_styled_jpeg.swift`: Conversion + style engine.
- `scripts/profile_raw_images.swift`: Batch profiler.
- `scripts/render_profiled_batch.swift`: Profile-driven renderer.
- `scripts/run_exact_pipeline.sh`: Deterministic batch pipeline.
- `scripts/run_profiled_pipeline.sh`: Profile-driven batch pipeline.
- `scripts/run_profiled_revision.sh`: Safe staged revision of retained outputs.
- `scripts/test_profiled_revision.sh`: Self-contained revision safety smoke test.
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

Natural twilight mode, after selecting only the twilight cohort:

```bash
bash scripts/run_profiled_pipeline.sh /path/to/arw-folder codex_output natural-twilight
```

Revise an existing curated folder using a text file with one selected basename per line:

```bash
bash scripts/run_profiled_revision.sh stage /path/to/raws /path/to/final selection.txt /path/to/revision natural-twilight
# Review /path/to/revision/input/staged before applying.
bash scripts/run_profiled_revision.sh apply /path/to/raws /path/to/final /path/to/revision
```

Interactive first-export mode:

```bash
bash scripts/run_interactive_pipeline.sh
```

Use the revision runner directly for curated output folders.

Revision safety check:

```bash
bash scripts/test_profiled_revision.sh
```

## Outputs

Expected artifacts in output folder:

- `*.jpg` converted images
- `style_report.csv` or `profiled_style_report.csv`
- `exif_validation.txt`

Expected artifacts for profiled mode in the input folder:

- `profiling/raw_profile.csv`
- `profiling/raw_profile_summary.txt`

Expected artifacts in a revision folder:

- `input/staged/`: JPEGs to review
- `previous/`: backups of selected current JPEGs
- `skipped_missing_outputs.txt`: selected files left deleted
- `dimension_changes.txt`: staged files requiring geometry-aware review
- `revision_apply.txt`: applied and skipped results

Success criteria:

- First export: JPEG count matches processed RAW count.
- Curated revision: every retained JPEG has a matching RAW; deleted outputs remain absent.
- `exif_validation.txt` ends with `RESULT: PASS`.

## Runtime notes

- Designed for user-level installation in Codex and Claude plugin workflows.
- Interactive mode can preserve an existing output directory before a first-export rerun.
- Revision mode backs up selected current JPEGs, stages replacements for review, and refuses to overwrite files deleted, changed, or dimensionally incompatible with the staged render.
- `natural-twilight` avoids auto-enhancement and stacked color effects that can flatten sky gradients.
- If RAW decode fails in restricted environments, rerun with permissions that allow full image decoding.
