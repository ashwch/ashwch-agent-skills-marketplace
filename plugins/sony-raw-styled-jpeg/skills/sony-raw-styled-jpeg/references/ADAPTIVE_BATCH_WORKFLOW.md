# Adaptive Batch Workflow

Use this reference when the batch is mixed, the user is iterating on feel, or one global grade is causing regressions.

## General Rules

1. Profile before transform.
2. Separate technical correction from artistic mood.
3. Work by cohorts, not batch averages.
4. Promote repeated exceptions into named treatment buckets.
5. Keep runs reversible by preserving prior outputs or writing to a new output folder.
6. Validate hard invariants after every rerender.

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

1. Inspect its current treatment and mood mode.
2. Ask whether the problem is local or shared by similar images.
3. If similar images exist, define a subgroup rule.
4. Rerender only after the subgroup logic is explicit.

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
