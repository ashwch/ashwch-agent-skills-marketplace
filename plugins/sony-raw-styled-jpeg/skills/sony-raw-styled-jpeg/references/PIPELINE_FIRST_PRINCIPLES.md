# Sony RAW -> Styled JPEG Playbook (First Principles + Exact Replication)

This document explains the exact first-export pipeline, why each step exists, and how to rerun it reliably. For revisions after user review or deletion, use the curated revision workflow in `ADAPTIVE_BATCH_WORKFLOW.md`.

## 1) Goal

Convert Sony `.ARW` RAW files into high-quality styled JPEGs while preserving EXIF metadata, especially click/capture timestamps:

- `DateTimeOriginal`
- `DateTimeDigitized`
- `TIFF DateTime`

Output location in this run:

- `/path/to/arw-folder/codex_output`

## 2) First Principles (Why This Pipeline Exists)

### Principle A: RAW is sensor data, not a final picture

A RAW file is mostly linear sensor information + camera metadata. It usually needs:

- Demosaicing
- White balance and color transform
- Tone mapping / highlight-shadow reconstruction
- Noise handling

Before it looks like a final photo.

### Principle B: JPEG is a display format

JPEG is compressed, view-ready output. So the pipeline must:

1. Decode RAW correctly.
2. Apply tone/color styling.
3. Encode with high quality settings.

### Principle C: Style should adapt to content

Not all images need the same treatment. Portraits, low-light scenes, and landscapes require different tuning.

So we:

- Analyze each image (luma, contrast, color ratios, edge detail, faces, labels).
- Classify into style buckets.
- Apply style-specific CoreImage filter chains.

### Principle D: Metadata and curation are part of the asset

Capture metadata is critical for cataloging, and the set of retained files reflects user choices.

So we:

- Copy metadata from source RAW to output JPEG.
- Validate timestamps across all files in the active scope.
- Require every processed RAW to have an output during first export.
- During revision, validate retained outputs only and never refill user-deleted gaps.
- Fail validation if required metadata mismatches.

## 3) System Architecture (ASCII)

```text
+-------------------+
| Sony RAW (.ARW)   |
+---------+---------+
          |
          v
+----------------------------+
| CoreImage RAW Decode       |
| - orientation applied      |
| - full-resolution image    |
+-------------+--------------+
              |
              +------------------------------------+
              |                                    |
              v                                    v
+----------------------------+        +-----------------------------+
| Stats Sampler              |        | Vision Analysis             |
| - luma / contrast          |        | - face detection            |
| - saturation / hue ratios  |        | - image classification      |
| - edge strength            |        +-------------+---------------+
+-------------+--------------+                      |
              \\                                    /
               \\                                  /
                v                                 v
                 +-------------------------------+
                 | Style Decision Engine         |
                 | portrait/landscape/lowLight  |
                 | urban/balanced               |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | Style Filter Chain            |
                 | (CoreImage filters per style) |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | JPEG Writer                   |
                 | quality=1.0, metadata copied  |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | EXIF Validator                |
                 | DateTimeOriginal parity check |
                 +-------------------------------+
```

## 4) Style Decision Model (ASCII)

```text
START
  |
  v
Is scene very dark?
(avgLuma < threshold)
  | yes -> lowLight
  | no
  v
Faces detected OR portrait labels OR warm skin-like ratio?
  | yes -> portrait
  | no
  v
Landscape labels OR high green/blue + edges?
  | yes -> landscape
  | no
  v
Urban labels OR high contrast + low saturation?
  | yes -> urban
  | no
  v
balanced
```

## 5) Exact Pipeline We Landed On

### Core script

- `scripts/raw_to_styled_jpeg.swift`

### Runner

- `scripts/run_exact_pipeline.sh`

### Metadata validator

- `scripts/verify_datetime_original.swift`

## 6) Interactive Prompt Pack (Copy/Paste)

Use this when you want the process to be explicitly interactive with the user before execution.

```text
I can run the Sony RAW -> styled JPEG pipeline exactly as before.
Please confirm these settings:

1) Input folder containing .ARW files
   Example: /path/to/arw-folder

2) Output folder name (inside input folder)
   Example: codex_output

3) Processing scope
   - all (full batch)
   - sample (first N images)

4) If sample: how many images?
   Example: 24

5) Metadata policy
   - preserve full EXIF (recommended)
   - preserve only capture timestamps

6) Quality profile
   - exact (JPEG quality=1.0, same style logic)
   - custom (if you want me to alter grading/quality)

7) Preview request
   - do you want me to return paths for 1-3 representative output pictures?

Once confirmed, I’ll run conversion + EXIF validation and report counts/style distribution.
```

## 7) One-Command Exact Reproduction

```bash
bash scripts/run_exact_pipeline.sh /path/to/arw-folder codex_output
```

What this command does:

1. Compiles Swift converter with module cache in `/tmp/swift-module-cache`.
2. Converts all `.ARW` -> styled JPEGs.
3. Writes `style_report.csv`.
4. Verifies EXIF timestamp parity and writes `exif_validation.txt`.

## 8) Interactive Runner (Prompted)

```bash
bash scripts/run_interactive_pipeline.sh
```

This asks for:

- Input folder
- Output folder
- Full batch vs sample
- Sample count (if sample)
- Whether to print representative output image paths

## 9) Output Contract

After run, you should have:

```text
<output_folder>/
  MONxxxxx.jpg
  ...
  style_report.csv
  exif_validation.txt
```

`style_report.csv` columns:

- `file`
- `style`
- `status`
- `error`

`exif_validation.txt` includes:

- Missing output count
- Missing DateTimeOriginal count
- Mismatch counts
- `RESULT: PASS` or `RESULT: FAIL`

## 10) Operational Constraints We Discovered

In this environment, full RAW decode required running outside the sandbox (escalated execution). Inside sandbox, decode paths could fail or produce invalid outputs.

Practical rule:

- If decode fails or output dimensions are wrong, rerun with escalation.

## 11) Determinism Notes

To replicate the same result behavior:

- Keep script and threshold values unchanged.
- Keep JPEG quality at `1.0`.
- Keep style filter chains unchanged.
- Keep metadata copy + validation enabled.
- Use same OS/CoreImage stack when possible.

## 12) Verification Checklist

Before accepting a first export:

1. Output JPEG count equals source ARW count (or sample count).
2. `style_report.csv` exists and has one row per processed file.
3. `exif_validation.txt` says `RESULT: PASS`.
4. Spot check 3 files for matching `DateTimeOriginal`.

Before accepting a curated revision:

1. Review staged JPEGs before applying them.
2. Confirm intentionally missing JPEGs remain absent.
3. Confirm approved local edits were excluded or skipped.
4. Validate with `verify_datetime_original.swift <raw_dir> <output_dir> --existing-only`.
5. Require `RESULT: PASS`; do not require output count to equal RAW count.

## 13) Troubleshooting Matrix

```text
Symptom                                Likely Cause                        Action
------------------------------------   ---------------------------------   ----------------------------------------------
No JPEG written                        RAW decode unavailable               Run with escalated permissions
Tiny/corrupt JPEG                      Metadata-only stub decode           Re-run pipeline outside sandbox
EXIF mismatch                          Metadata copy or write issue        Re-run validator, inspect failing filenames
Styles look too flat                   Wrong script version                Use exact bundled swift converter
Run fails at compile                   Swift module cache path blocked     Use /tmp/swift-module-cache
```

## 14) Why This Is Robust

From first principles, robustness comes from separating concerns:

```text
Decode correctness
  +
Style logic correctness
  +
Metadata integrity
  +
Validation gate
  =
Production-safe batch conversion
```

Without the validation gate, metadata regressions can silently ship.
Without content-aware styling, outputs become uniformly mediocre.
Without proper decode path, quality collapses before styling even starts.

All four layers are required.

## 15) Code Documentation Map (By File)

This section is the code-level map so anyone can read the scripts quickly.

### A) `raw_to_styled_jpeg.swift` (Core engine)

```text
run()
 ├── list ARW files
 ├── for each file:
 │    └── processFile()
 │         ├── RAW decode
 │         ├── sample rasterize
 │         ├── computeStats()
 │         ├── detectFaces() + classifyLabels()
 │         ├── chooseStyle()
 │         ├── applyStyle()
 │         ├── sourceMetadata()
 │         └── writeJPEG()
 └── write style_report.csv + summary
```

Core responsibilities:

- `computeStats`: low-level pixel statistics for decision features.
- `chooseStyle`: deterministic rule engine for style assignment.
- `applyStyle`: stable filter chains per style bucket.
- `writeJPEG`: high-quality output + metadata persistence.

### B) `verify_datetime_original.swift` (Validation gate)

```text
complete mode: list RAWs -> require matching JPEGs -> compare dates
existing-only mode: list retained JPEGs -> require matching RAWs -> compare dates
```

Use complete mode for first exports and `--existing-only` for curated revisions.

Validation fields:

- `DateTimeOriginal`
- `DateTimeDigitized`
- `TIFF DateTime`

### C) `run_exact_pipeline.sh` (Deterministic orchestrator)

```text
compile converter
   -> convert batch
      -> run metadata validator
         -> write exif_validation.txt
```

### D) `run_interactive_pipeline.sh` (Prompted operator UX)

Interactive inputs:

- Input folder
- Output folder
- Scope (all/sample)
- Sample size
- Metadata policy
- Quality profile
- Preview path count

Then it executes the exact pipeline and prints representative output image paths.

## 16) Pseudocode (Human-Friendly)

```text
for each raw in input_folder:
    image = decode_raw(raw)
    features = measure_scene(image)
    semantics = infer_faces_and_labels(image)
    style = choose_style(features, semantics)
    graded = apply_style(style, image)
    save_as_jpeg(graded, quality=1.0, copy_metadata_from=raw)

validate_all_outputs():
    for each raw:
        assert output_jpeg_exists(raw)
        assert DateTimeOriginal(raw) == DateTimeOriginal(output_jpeg)
```
