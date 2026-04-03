---
name: sony-raw-styled-jpeg
description: Convert Sony A7-series RAW (.ARW) sets into high-quality JPEGs using either an exact one-pass pipeline or a profile-driven batch workflow. Use when users request Sony RAW conversion, mixed-lighting batch adaptation, iterative mood adjustments, and metadata-safe exports with EXIF preservation.
---

# Sony RAW Styled JPEG

Use one of two workflows:

- `exact`: deterministic one-pass RAW -> styled JPEG conversion with fixed style buckets.
- `profiled`: `profile -> bucket -> render -> validate` for mixed batches or iterative feedback.

## Core Idea (First Principles)

1. RAW decode quality is foundational: a bad decode cannot be fixed later.
2. Profile before transform when the batch is heterogeneous.
3. Separate technical correction from optional mood or taste layers.
4. Work by cohorts, not by one batch-wide grade.
5. EXIF is part of the asset and must be preserved.
6. Validation is mandatory: trust output only after metadata checks pass.

## Bundled Files

- `scripts/raw_to_styled_jpeg.swift`: Core converter and style engine.
- `scripts/profile_raw_images.swift`: Batch profiler that groups RAWs into treatment buckets.
- `scripts/render_profiled_batch.swift`: Profile-driven renderer with optional subtle mood modes.
- `scripts/verify_datetime_original.swift`: EXIF timestamp validator.
- `scripts/run_exact_pipeline.sh`: Deterministic compile -> convert -> validate.
- `scripts/run_profiled_pipeline.sh`: Profile -> render -> validate workflow.
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
- The user gives qualitative feedback like "too blue", "too bright", or "make some of them moodier".
- You need to separate technical fixes from a later artistic pass.

Read `references/ADAPTIVE_BATCH_WORKFLOW.md` when you need to reason about feedback loops, subgroup creation, or future reuse of the workflow outside this specific image set.

## Required User Prompts (Interactive)

Before starting conversion, ask:

1. Input folder path containing `.ARW` files.
2. Output folder name inside that input folder.
3. Scope: full batch (`all`) or sample (`sample`).
4. If sample: number of files (`N`).
5. Workflow mode: `exact` or `profiled`.
6. If profiled: mood layer `none` or `subtle`.
7. If output folder already exists: preserve it first or stop.
8. Whether to print representative output image paths.

Defaults if user does not specify:

- Input folder: current working directory.
- Output folder: `codex_output`.
- Scope: `all`.
- Sample size: `24`.
- Workflow mode: `profiled` for mixed batches, otherwise `exact`.
- Mood layer: `none`.
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

Interactive run:

- `bash scripts/run_interactive_pipeline.sh`

When installed in Codex at user scope, an absolute invocation is also valid:

- `bash "${CODEX_HOME:-$HOME/.codex}/skills/sony-raw-styled-jpeg/scripts/run_exact_pipeline.sh" . codex_output`
- `bash "${CODEX_HOME:-$HOME/.codex}/skills/sony-raw-styled-jpeg/scripts/run_profiled_pipeline.sh" . codex_output none`

## Non-Negotiable Settings

- Compile with Swift module cache at `/tmp/swift-module-cache`.
- Keep the exact pipeline thresholds unchanged when using `run_exact_pipeline.sh`.
- Export JPEGs with lossy quality `1.0`.
- Preserve source metadata payload in every output JPEG.
- Require EXIF validator `RESULT: PASS`.

## Output Contract

Always report:

- Number of source `.ARW` files discovered.
- Number of output `.jpg` files written.
- For `exact`: style distribution from `style_report.csv`.
- For `profiled`: treatment distribution from `profiled_style_report.csv`.
- For `profiled`: profile summary path from `profiling/raw_profile_summary.txt`.
- If a mood layer was used: the mood preset and any per-file mood modes that were applied.
- EXIF validation pass/fail and mismatch counts.
- 1-3 output image paths if preview was requested.

## Operational Note

If rerunning after review, preserve or rename the previous output directory before writing a new batch. If RAW decode fails or output dimensions are invalid in restricted environments, rerun with permissions that allow full CoreImage RAW decode path.
