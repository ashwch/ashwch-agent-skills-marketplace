---
description: Safely revise selected Sony RAW outputs without recreating deleted JPEGs or overwriting changed files.
---

Use your `sony-raw-styled-jpeg` Skill in revision mode.

Execution protocol:
1. Confirm the RAW folder, curated output folder, selection manifest, staging folder, and render preset.
2. Exclude approved local edits from the selection manifest.
3. Stage the revision; missing output JPEGs must remain absent.
4. Show representative staged images and wait for visual approval.
5. Apply only after approval. Files deleted, changed, or dimensionally incompatible with the staged render must be skipped.
6. Report staged, replaced, skipped-deleted, skipped-changed, skipped-dimension, and EXIF validation counts.

Preferred script path:

```bash
bash scripts/run_profiled_revision.sh stage /path/to/raws /path/to/final selection.txt /path/to/revision natural-twilight
# Review staged output, then:
bash scripts/run_profiled_revision.sh apply /path/to/raws /path/to/final /path/to/revision
```
