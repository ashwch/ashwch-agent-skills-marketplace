---
description: Run profile-driven Sony ARW to JPEG conversion for mixed batches, with optional subtle mood layering and EXIF verification.
---

Use your `sony-raw-styled-jpeg` Skill in profiled mode.

Execution protocol:
1. Confirm input folder, output subfolder, and mood preset (`none` or `subtle`).
2. Run the profiler before rendering so the batch is bucketed by treatment need.
3. Return the profile summary path, treatment report path, and EXIF validation summary.

Preferred script path (from the skill bundle):

```bash
bash scripts/run_profiled_pipeline.sh . codex_output none
```
