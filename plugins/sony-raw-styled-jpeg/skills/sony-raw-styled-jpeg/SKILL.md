---
name: sony-raw-styled-jpeg
description: Convert and safely revise Sony A7-series RAW (.ARW) sets as high-quality JPEGs using exact, profiled, or curated revision workflows. Use for Sony RAW conversion, mixed-lighting adaptation, twilight correction, iterative grading, deletion-safe revisions, and metadata-safe exports with EXIF preservation.
---

# Sony RAW Styled JPEG

Use one of three workflows:

- `exact`: deterministic one-pass RAW -> styled JPEG conversion with fixed style buckets.
- `profiled`: `profile -> bucket -> render -> validate` for mixed first exports.
- `revision`: stage and review a selected cohort before replacing only JPEGs that still exist, remain unchanged, and keep their dimensions.

## Core Idea (First Principles)

1. RAW decode quality is foundational: a bad decode cannot be fixed later.
2. Profile before transform when the batch is heterogeneous.
3. Separate technical correction from optional mood or taste layers.
4. Work by cohorts, not by one batch-wide grade.
5. EXIF is part of the asset and must be preserved.
6. Validation is mandatory: trust output only after metadata checks pass.
7. A curated output folder is user state: never recreate a JPEG the user deleted.
8. Preserve approved local edits by excluding them from broad cohort revisions.

## Bundled Files

- `scripts/raw_to_styled_jpeg.swift`: Core converter and style engine.
- `scripts/profile_raw_images.swift`: Batch profiler that groups RAWs into treatment buckets.
- `scripts/render_profiled_batch.swift`: Profile-driven renderer with technical, subtle, and natural-twilight presets.
- `scripts/verify_datetime_original.swift`: EXIF timestamp validator.
- `scripts/run_exact_pipeline.sh`: Deterministic compile -> convert -> validate.
- `scripts/run_profiled_pipeline.sh`: Profile -> render -> validate workflow.
- `scripts/run_profiled_revision.sh`: Stage -> review -> safely replace an existing output cohort.
- `scripts/test_profiled_revision.sh`: Self-contained revision safety smoke test.
- `scripts/run_interactive_pipeline.sh`: Prompt-driven workflow chooser.
- `references/PIPELINE_FIRST_PRINCIPLES.md`: Visual, simple-language guide with ASCII diagrams.
- `references/ADAPTIVE_BATCH_WORKFLOW.md`: General-purpose profile/bucket/transform/validate playbook.

## Choose Workflow

Use `exact` when:

- The user wants strict reproducibility.
- The batch is fairly uniform.
- You want the original fixed style buckets with no iterative mood layer.

Use `profiled` when:

- The batch mixes bright sky, dark woods, overcast scenes, close details, and different tonal problems.
- You need to separate technical fixes from a later artistic pass.

Use `revision` when:

- The user gives feedback such as "these are too bright" or "redo the twilight colors" after curating the output folder.
- Some outputs were deleted and must remain absent.
- A broad cohort change must not overwrite approved local edits.
- You need a reversible preview before updating the final folder.

Use `natural-twilight` only on a selected twilight cohort. It bypasses auto-enhancement and uses restrained saturation, a gentle highlight roll-off, modest shadow recovery, and conservative sharpening. Do not apply it to a mixed batch.

Read `references/ADAPTIVE_BATCH_WORKFLOW.md` before selecting a revision cohort or changing a render preset.

## Required User Prompts

Before starting conversion, ask:

1. Input folder path containing `.ARW` files.
2. Output folder. First-export runners use a folder inside the input folder; revision mode accepts an existing output path.
3. Scope: full batch (`all`) or sample (`sample`).
4. If sample: number of files (`N`).
5. Workflow mode: `exact`, `profiled`, or `revision`.
6. If profiled or revision: render preset `none`, `subtle`, or `natural-twilight`.
7. If this is a first export and the output folder exists: preserve it first or stop.
8. If this is a revision: selection manifest, intentionally excluded approved edits, and staging folder.
9. Whether to print representative output image paths.

Defaults if user does not specify:

- Input folder: current working directory.
- Output folder: `codex_output`.
- Scope: `all`.
- Sample size: `24`.
- Workflow mode: `revision` for a curated output set, `profiled` for a mixed first export, otherwise `exact`.
- Render preset: `none`.
- Preserve existing output: `yes`.
- Preview paths: `yes`.
- EXIF preservation: always `yes`.

## Commands

Exact deterministic run:

- `bash scripts/run_exact_pipeline.sh . codex_output`

Profiled technical run:

- `bash scripts/run_profiled_pipeline.sh . codex_output none`

Profiled run with subtle mood layer:

- `bash scripts/run_profiled_pipeline.sh . codex_output subtle`

Profiled twilight cohort run:

- `bash scripts/run_profiled_pipeline.sh . codex_output natural-twilight`

Stage and apply a curated revision:

- `bash scripts/run_profiled_revision.sh stage /path/to/raws /path/to/final selection.txt /path/to/revision natural-twilight`
- Review `/path/to/revision/input/staged`.
- `bash scripts/run_profiled_revision.sh apply /path/to/raws /path/to/final /path/to/revision`

Interactive first-export run:

- `bash scripts/run_interactive_pipeline.sh`

The interactive runner handles `exact` and `profiled` first exports. Use `run_profiled_revision.sh` directly for revisions.

When installed in Codex at user scope, an absolute invocation is also valid:

- `bash "${CODEX_HOME:-$HOME/.codex}/skills/sony-raw-styled-jpeg/scripts/run_exact_pipeline.sh" . codex_output`
- `bash "${CODEX_HOME:-$HOME/.codex}/skills/sony-raw-styled-jpeg/scripts/run_profiled_pipeline.sh" . codex_output none`

## Non-Negotiable Settings

- Compile with Swift module cache at `/tmp/swift-module-cache`.
- Keep the exact pipeline thresholds unchanged when using `run_exact_pipeline.sh`.
- Export JPEGs with lossy quality `1.0`.
- Never modify RAW originals.
- Keep decoded dimensions; do not resize or upscale. Intentional crops may reduce dimensions.
- Preserve source metadata payload in every output JPEG.
- Require EXIF validator `RESULT: PASS`.
- In first-export mode, require one JPEG per processed RAW.
- In revision mode, use `verify_datetime_original.swift ... --existing-only`; missing outputs are intentional user state.
- Never copy from an older full batch to fill gaps in a curated output folder.
- Stage and inspect representative revisions before replacing final JPEGs.
- Do not claim recovery of clipped highlights, missed focus, or absent detail.

## Output Contract

Always report:

- Number of source `.ARW` files discovered.
- Number of output `.jpg` files written.
- For `exact`: style distribution from `style_report.csv`.
- For `profiled`: treatment distribution from `profiled_style_report.csv`.
- For `profiled`: profile summary path from `profiling/raw_profile_summary.txt`.
- Render preset, effective treatment, and any per-file mood modes that were applied.
- EXIF validation pass/fail and mismatch counts.
- 1-3 output image paths if preview was requested.
- For revisions: selected, staged, replaced, skipped-deleted, skipped-changed, and skipped-dimension counts.
- For revisions: paths to staged previews, prior JPEG backups, and the apply report.

## Operational Notes

For a new full export, preserve or rename the previous output directory before writing. For a curated revision, do not rename, refill, or rebuild the final folder: use `run_profiled_revision.sh`, which stages only selected JPEGs that currently exist, backs them up, and skips files deleted, changed, or dimensionally incompatible with the staged render.

A rendered sky can look burned out even when the RAW still contains detail. Diagnose the source before editing. Prefer one gentle RAW-based correction chain over stacked auto-enhancement, warm color matrices, steep tone curves, vignette, and grain; stacked global effects can flatten twilight gradients into pastel bands.

If RAW decode fails or output dimensions are invalid in restricted environments, rerun with permissions that allow the full CoreImage RAW decode path.
