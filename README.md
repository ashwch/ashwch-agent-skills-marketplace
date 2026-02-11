# ashwch-agent-skills-marketplace

Personal marketplace of reusable agent skills for both **Claude Code** and **OpenAI Codex**.

## Agent Skills Standard

This repo follows the [Agent Skills standard](https://agentskills.io/specification):

- Each skill has a required `SKILL.md` with YAML frontmatter (`name`, `description`).
- Optional helper folders: `scripts/`, `references/`, `assets/`.
- Skills are designed for progressive disclosure (metadata first, details on demand).

## Compatibility (Claude Code + Codex)

This repository supports both runtimes:

- **Claude Code** via plugin marketplace files under `.claude-plugin/` and `plugins/`.
- **Codex** via skill folders under `skills/` and user-level install scripts.

## User-Level Installation Policy

Use **user-level install** by default for both tools:

- Claude Code: install without `--scope project`.
- Codex: install to `${CODEX_HOME:-$HOME/.codex}/skills`.

This avoids workspace/worktree scope drift and makes skills available globally.

## Repository Structure

```text
ashwch-agent-skills-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── sony-raw-styled-jpeg/
│       ├── .claude-plugin/plugin.json
│       ├── commands/
│       │   ├── convert.md
│       │   └── exact.md
│       └── skills/
│           └── sony-raw-styled-jpeg/
│               ├── SKILL.md
│               ├── agents/openai.yaml
│               ├── scripts/
│               └── references/
├── skills/
│   └── sony-raw-styled-jpeg/   # Canonical copy for Codex
├── scripts/
│   ├── install-skill.sh
│   ├── install-all.sh
│   ├── uninstall-skill.sh
│   ├── uninstall-all.sh
│   ├── sync-skill-to-plugin.sh
│   ├── claude-install.sh
│   └── claude-uninstall.sh
├── AGENTS.md
├── CLAUDE.md
├── CONTRIBUTING.md
└── README.md
```

## Available Plugin/Skill

| Name | Purpose |
| --- | --- |
| `sony-raw-styled-jpeg` | Convert Sony `.ARW` images into high-quality content-aware JPEG while preserving EXIF and validating timestamps. |

---

## Install for Claude Code (User Scope)

### 1) Add marketplace

```bash
claude plugin marketplace add ashwch/ashwch-agent-skills-marketplace
```

### 2) Install plugin (user scope)

```bash
claude plugin install sony-raw-styled-jpeg@ashwch
```

Do **not** pass `--scope project` unless you explicitly need project-local behavior.

### 3) Use slash commands

```text
/sony-raw-styled-jpeg:convert   # Interactive pipeline
/sony-raw-styled-jpeg:exact     # Deterministic exact pipeline
```

### Optional helper script

```bash
bash scripts/claude-install.sh
```

---

## Uninstall for Claude Code

### Uninstall user-scoped plugin

```bash
claude plugin uninstall sony-raw-styled-jpeg@ashwch
```

### If accidentally installed at project scope

```bash
claude plugin uninstall sony-raw-styled-jpeg@ashwch --scope project
```

### Optional helper script

```bash
bash scripts/claude-uninstall.sh
```

---

## Install for Codex (User Scope)

### Option A: From local clone (recommended)

```bash
gh repo clone ashwch/ashwch-agent-skills-marketplace
cd ashwch-agent-skills-marketplace
bash scripts/install-skill.sh sony-raw-styled-jpeg
```

Install all skills:

```bash
bash scripts/install-all.sh
```

### Option B: Direct from GitHub with Skill Installer

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
python3 "$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --repo ashwch/ashwch-agent-skills-marketplace \
  --ref main \
  --path skills/sony-raw-styled-jpeg
```

### Use in Codex

```text
Use $sony-raw-styled-jpeg to convert ARW images into styled JPEGs and validate EXIF timestamps.
```

---

## Uninstall for Codex

Uninstall one skill:

```bash
bash scripts/uninstall-skill.sh sony-raw-styled-jpeg
```

Uninstall all skills from this repo:

```bash
bash scripts/uninstall-all.sh
```

Manual fallback:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
rm -rf "$CODEX_HOME/skills/sony-raw-styled-jpeg"
```

---

## Keeping Claude + Codex Copies in Sync

Canonical source is:

- `skills/<name>/`

Claude plugin copy is:

- `plugins/<name>/skills/<name>/`

After editing a canonical skill, sync it to plugin copy:

```bash
bash scripts/sync-skill-to-plugin.sh sony-raw-styled-jpeg
```

---

## Sony Skill: Outputs and Guarantees

Expected output artifacts:

- `<output>/MONxxxxx.jpg`
- `<output>/style_report.csv`
- `<output>/exif_validation.txt`

Validation guarantee:

- `DateTimeOriginal`, `DateTimeDigitized`, and `TIFF DateTime` parity checks are enforced.

Deep technical documentation:

- `skills/sony-raw-styled-jpeg/references/PIPELINE_FIRST_PRINCIPLES.md`

## Update Workflow

```bash
git pull
bash scripts/install-skill.sh sony-raw-styled-jpeg
# Claude users can reinstall plugin if needed:
claude plugin install sony-raw-styled-jpeg@ashwch
```

## License

MIT - see `LICENSE`.
