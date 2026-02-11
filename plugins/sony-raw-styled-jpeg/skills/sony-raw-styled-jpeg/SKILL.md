---
name: sony-raw-styled-jpeg
description: Convert Sony A7-series RAW (.ARW) sets into very high-quality, content-aware styled JPEGs while preserving EXIF metadata (including DateTimeOriginal capture time). Use when users request batch RAW-to-JPEG conversion, per-image style adaptation by scene content, interactive run prompts (output location/scope/preferences), and metadata-safe exports into folders like codex_output.
---

# Sony RAW Styled JPEG

Run the exact RAW-to-styled-JPEG pipeline that was validated in this workspace.

## Core Idea (First Principles)

1. RAW decode quality is foundational: a bad decode cannot be fixed later.
2. Styling must be content-aware, not one-size-fits-all.
3. EXIF is part of the asset and must be preserved.
4. Validation is mandatory: trust output only after metadata checks pass.

## Bundled Files

- `scripts/raw_to_styled_jpeg.swift`: Core converter and style engine.
- `scripts/verify_datetime_original.swift`: EXIF timestamp validator.
- `scripts/run_exact_pipeline.sh`: Deterministic compile -> convert -> validate.
- `scripts/run_interactive_pipeline.sh`: Prompt-driven workflow.
- `references/PIPELINE_FIRST_PRINCIPLES.md`: Visual, simple-language guide with ASCII diagrams.

## Required User Prompts (Interactive)

Before starting conversion, ask:

1. Input folder path containing `.ARW` files.
2. Output folder name inside that input folder.
3. Scope: full batch (`all`) or sample (`sample`).
4. If sample: number of files (`N`).
5. Whether to print representative output image paths.
6. Confirmation that EXIF preservation is required.

Defaults if user does not specify:

- Input folder: current working directory.
- Output folder: `codex_output`.
- Scope: `all`.
- Sample size: `24`.
- Preview paths: `yes`.
- EXIF preservation: `yes`.

## Commands

Exact deterministic run:

- `bash scripts/run_exact_pipeline.sh . codex_output`

Interactive run:

- `bash scripts/run_interactive_pipeline.sh`

When installed in Codex at user scope, an absolute invocation is also valid:

- `bash "${CODEX_HOME:-$HOME/.codex}/skills/sony-raw-styled-jpeg/scripts/run_exact_pipeline.sh" . codex_output`

## Non-Negotiable Settings

- Compile with Swift module cache at `/tmp/swift-module-cache`.
- Keep style classifier thresholds unchanged for exact replication.
- Export JPEGs with lossy quality `1.0`.
- Preserve source metadata payload in every output JPEG.
- Require EXIF validator `RESULT: PASS`.

## Output Contract

Always report:

- Number of source `.ARW` files discovered.
- Number of output `.jpg` files written.
- Style distribution from `style_report.csv`.
- EXIF validation pass/fail and mismatch counts.
- 1-3 output image paths if preview was requested.

## Operational Note

If RAW decode fails or output dimensions are invalid in restricted environments, rerun with permissions that allow full CoreImage RAW decode path.
