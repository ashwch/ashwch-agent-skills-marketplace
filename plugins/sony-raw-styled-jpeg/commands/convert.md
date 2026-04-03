---
description: Convert Sony ARW images to content-aware high-quality JPEG with EXIF-preserving validation.
---

Use your `sony-raw-styled-jpeg` Skill to run the conversion pipeline.

Execution protocol:
1. Ask interactive setup questions: input folder, output folder, scope, workflow mode, mood layer if profiled, and preview count.
2. Prefer `profiled` mode for mixed or iterative batches; use `exact` only when strict one-pass reproducibility is the goal.
3. Run the interactive runner for user-guided execution.
4. Report source count, output count, either style or treatment distribution, and EXIF validation result.

Preferred script path (from the skill bundle):

```bash
bash scripts/run_interactive_pipeline.sh
```
