---
description: Run deterministic Sony ARW to styled JPEG conversion with fixed settings and EXIF verification.
---

Use your `sony-raw-styled-jpeg` Skill in exact mode.

Execution protocol:
1. Confirm input folder and output subfolder.
2. Run deterministic compile -> convert -> validate path.
3. Return style report path and EXIF validation summary.

Preferred script path (from the skill bundle):

```bash
bash scripts/run_exact_pipeline.sh . codex_output
```
