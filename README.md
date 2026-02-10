# ashwch-agent-skills-marketplace

Personal marketplace of reusable Codex/agent skills, starting with a production-ready Sony RAW image pipeline.

## Why this repository exists

This repo is the single source of truth for my skills collection so I can:

- Version skill logic and prompts.
- Reuse skills across machines/sessions.
- Add new skills without losing prior workflows.

## Repository layout

```text
ashwch-agent-skills-marketplace/
├── skills/
│   └── sony-raw-styled-jpeg/
│       ├── SKILL.md
│       ├── agents/openai.yaml
│       ├── scripts/
│       │   ├── raw_to_styled_jpeg.swift
│       │   ├── verify_datetime_original.swift
│       │   ├── run_exact_pipeline.sh
│       │   └── run_interactive_pipeline.sh
│       └── references/
│           └── PIPELINE_FIRST_PRINCIPLES.md
├── scripts/
│   ├── install-skill.sh
│   └── install-all.sh
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Included skills

| Skill | Purpose |
| --- | --- |
| `sony-raw-styled-jpeg` | Convert Sony `.ARW` sets to high-quality styled JPEG with EXIF-preserving validation. |

## Quick start

### 1) Clone with `gh`

```bash
gh repo clone ashwch/ashwch-agent-skills-marketplace
cd ashwch-agent-skills-marketplace
```

### 2) Install the Sony skill into Codex home

```bash
bash scripts/install-skill.sh sony-raw-styled-jpeg
```

Or install all skills in this repo:

```bash
bash scripts/install-all.sh
```

### 3) Use in Codex

Ask:

```text
Use $sony-raw-styled-jpeg to convert ARW files in <input-folder> to styled JPEGs in codex_output and validate EXIF timestamps.
```

## Sony skill: outputs and guarantees

The Sony skill enforces this pipeline:

1. Full-quality RAW decode (CoreImage).
2. Scene analysis (luminance/contrast/color/edges + Vision labels/faces).
3. Per-image style selection (`portrait`, `landscape`, `lowLight`, `urban`, `balanced`).
4. High-quality JPEG export (`quality=1.0`).
5. EXIF retention with timestamp parity checks.

Expected output artifacts:

- `<output>/MONxxxxx.jpg`
- `<output>/style_report.csv`
- `<output>/exif_validation.txt`

## First-principles docs

See:

- `skills/sony-raw-styled-jpeg/references/PIPELINE_FIRST_PRINCIPLES.md`

This document explains the full system with ASCII diagrams, pseudocode, and troubleshooting.

## Roadmap

- Add general image processing skill pack.
- Add backend productivity skills from local collection.
- Add CI checks for skill schema consistency.
