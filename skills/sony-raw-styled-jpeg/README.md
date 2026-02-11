# sony-raw-styled-jpeg

Content-aware Sony RAW (`.ARW`) to high-quality JPEG conversion skill with EXIF preservation and timestamp validation.

## What it does

1. Decodes Sony RAW images with CoreImage.
2. Analyzes scene content (luma/contrast/color/edges + Vision labels/faces).
3. Applies style-specific grading (`portrait`, `landscape`, `lowLight`, `urban`, `balanced`).
4. Exports JPEGs at high quality (`quality=1.0`).
5. Preserves EXIF metadata and validates date fields.

## Primary files

- `SKILL.md`: Invocation and runtime workflow.
- `scripts/raw_to_styled_jpeg.swift`: Conversion + style engine.
- `scripts/run_exact_pipeline.sh`: Deterministic batch pipeline.
- `scripts/run_interactive_pipeline.sh`: Prompt-driven batch pipeline.
- `scripts/verify_datetime_original.swift`: EXIF/timestamp validator.
- `references/PIPELINE_FIRST_PRINCIPLES.md`: Full conceptual + ASCII documentation.

## Quick usage

From the skill folder:

```bash
bash scripts/run_exact_pipeline.sh /path/to/arw-folder codex_output
```

Interactive mode:

```bash
bash scripts/run_interactive_pipeline.sh
```

## Outputs

Expected artifacts in output folder:

- `*.jpg` converted images
- `style_report.csv`
- `exif_validation.txt`

Success criteria:

- JPEG count matches processed ARW count.
- `exif_validation.txt` ends with `RESULT: PASS`.

## Runtime notes

- Designed for user-level installation in Codex and Claude plugin workflows.
- If RAW decode fails in restricted environments, rerun with permissions that allow full image decoding.
