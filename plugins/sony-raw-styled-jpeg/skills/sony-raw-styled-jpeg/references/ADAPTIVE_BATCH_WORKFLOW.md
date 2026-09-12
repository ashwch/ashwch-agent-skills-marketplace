# Adaptive Batch Workflow

Use this reference when the batch is mixed, the user is iterating on feel, or one global grade is causing regressions.

## General Rules

1. Profile before transform.
2. Separate technical correction from artistic mood.
3. Work by cohorts, not batch averages.
4. Promote repeated exceptions into named treatment buckets.
5. Keep runs reversible by preserving prior outputs or writing to a new output folder.
6. Validate hard invariants after every rerender.
7. Treat missing files in a curated output folder as intentional deletions.
8. Protect approved local edits from later cohort-wide grades.

## Recommended Sequence

```text
RAW batch
  ->
profile
  ->
bucket into treatment groups
  ->
technical render per group
  ->
optional mood layer on selected groups
  ->
EXIF validation
  ->
human review
  ->
adjust grouping rules if needed
```

## When To Prefer Adaptive Mode

- The user describes a heterogeneous set: bright sky, shade, woods, clouds, close details.
- The first pass triggers feedback like "too blue", "too bright", "too flat", or "only some of them need to be darker".
- A previous mood pass improved some frames but harmed others.

## Treatment Thinking

Technical buckets should describe the correction problem:

- `shadow_lift`
- `bright_sky_rebalance`
- `landscape_rebalance`
- `detail_chroma_cleanup`
- `forest_shadow_lift`
- `overcast_gray_recovery`

Mood buckets should describe the aesthetic layer:

- `none`
- `atmospheric`
- `forest_trail`

Do not collapse these into one label. "Too blue" and "more mysterious" are different operations.

## Feedback Loop

When a user flags a single file:

1. Identify the RAW and inspect both the RAW preview and current JPEG.
2. Decide whether detail is clipped in the source or only flattened by the render.
3. Ask whether the problem is local or shared by similar images.
4. If similar images exist, create an explicit selection manifest for that cohort.
5. Remove approved local exceptions from the manifest.
6. Stage the cohort, inspect representative dark, middle, and bright frames, then apply.

Do not infer that every missing JPEG needs repair. In revision work, absence can be the user's edit.

## Curated Revision Contract

Use `scripts/run_profiled_revision.sh` instead of a full rerun once the user has reviewed or deleted outputs.

```text
selection manifest
  ->
include only names whose JPEG still exists
  ->
copy those JPEGs to revision/previous
  ->
profile and render selected RAWs into revision/input/staged
  ->
validate staged EXIF
  ->
human review
  ->
replace only outputs that still exist, have not changed, and retain dimensions
  ->
validate retained outputs with --existing-only
```

The stage command records a baseline hash and reports dimension changes for each selected JPEG. The apply command skips a target if the user deletes or changes it after staging, or if the staged dimensions differ from the current final. A dimension mismatch usually means the generic renderer would discard an approved crop or rotation. Replacements use a temporary file followed by a same-folder rename.

Selection manifests are deliberately plain text: one basename, RAW name, or JPEG name per line. Blank lines and `#` comment lines are ignored. This keeps cohort choices explicit without embedding image names in the skill.

## Twilight Highlight Guardrails

A pale or "burned" JPEG does not prove that the RAW is clipped. Compare the RAW preview first. If the RAW has smooth sky color and the JPEG has flat peach or gray bands, simplify the render rather than trying to recover nonexistent data.

For a selected twilight cohort, `natural-twilight`:

- starts from the RAW instead of auto-enhanced output;
- uses bounded exposure adjustment from measured luma;
- compresses highlights gently;
- lifts shadows modestly without lifting the whole sky;
- restrains saturation and contrast;
- uses conservative denoising and sharpening;
- adds no vignette or synthetic grain.

Avoid stacking auto-enhancement, warm matrices, selective color kernels, steep tone curves, vignette, and grain in one global twilight pass. Each effect may look mild alone but together they can erase color separation and reveal posterization.

Keep localized subject recovery separate. Restrict a shadow lift to the subject mask, keep the sky outside the mask, increase denoising inside deeply lifted shadows, and avoid adding grain there. If one frame has an approved mask or manual correction, exclude it from a broad rerender unless the user explicitly asks to replace that local edit. Shadow recovery can expose recorded detail; it cannot reconstruct missed focus or clipped data.

## Geometry Guardrails

Treat rotation, horizon correction, crop, and alignment as per-image settings, not batch-wide mood controls.

- Review horizon estimates visually; a detected line is not always the real horizon.
- Rotate around the image center, then use an inscribed crop so transparent corners never reach the JPEG.
- Never upscale to hide a crop.
- Preserve the prior geometry settings during a tonal rerender.
- If the generic renderer cannot reproduce an approved crop or rotation, exclude that image and use a geometry-aware render rather than silently resetting it.
- Validate final pixel dimensions and orientation as well as EXIF timestamps.

## Reusable Pattern Beyond Images

This skill's adaptive workflow is an instance of a broader pattern:

1. Ingest
2. Profile
3. Bucket
4. Normalize
5. Stylize
6. Validate
7. Review outliers
8. Update the rules

That same pattern applies to code cleanup, data normalization, document rewriting, and other mixed-quality batches.
