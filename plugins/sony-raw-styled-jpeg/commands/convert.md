---
description: Convert Sony ARW images to content-aware high-quality JPEG with EXIF-preserving validation.
---

Use your `sony-raw-styled-jpeg` Skill to run the conversion pipeline.

Execution protocol:
1. Ask interactive setup questions (input folder, output folder, scope, sample size, preview count).
2. Run the interactive runner for user-guided execution.
3. Report source count, output count, style distribution, and EXIF validation result.

Preferred script path (from the skill bundle):

```bash
bash scripts/run_interactive_pipeline.sh
```
