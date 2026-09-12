---
description: Convert Sony ARW images to content-aware high-quality JPEG with EXIF-preserving validation.
---

Use your `sony-raw-styled-jpeg` Skill to run the conversion pipeline.

Execution protocol:
1. Ask setup questions: input folder, output folder, scope, workflow mode, render preset, and preview count.
2. Prefer `profiled` for a mixed first export, `revision` after the user has curated outputs, and `exact` only for strict one-pass reproducibility.
3. For first exports, run the interactive runner. For revisions, use the staged revision runner and wait for visual approval before applying.
4. Report source, output, replaced, and skipped counts plus EXIF validation.

Preferred script path (from the skill bundle):

```bash
bash scripts/run_interactive_pipeline.sh
```
