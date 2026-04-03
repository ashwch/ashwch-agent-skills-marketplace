# ashwch-agent-skills-marketplace

Personal marketplace of reusable agent skills for both **Claude Code** and **OpenAI Codex**.

## Compatibility

- **Claude Code**: via `.claude-plugin/marketplace.json` + `plugins/*`.
- **Codex**: install skill bundles from `plugins/<plugin>/skills/<plugin>/` into `${CODEX_HOME:-$HOME/.codex}/skills`.

## Installation Scope Policy

Use **user-level install** by default for both tools.

- Claude: install without `--scope project`.
- Codex: install to `${CODEX_HOME:-$HOME/.codex}/skills`.

## Repository Structure (Plugins-Only)

```text
ashwch-agent-skills-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── sony-raw-styled-jpeg/
│       ├── .claude-plugin/plugin.json
│       ├── commands/
│       │   ├── convert.md
│       │   ├── exact.md
│       │   └── profiled.md
│       └── skills/
│           └── sony-raw-styled-jpeg/
│               ├── SKILL.md
│               ├── README.md
│               ├── agents/openai.yaml
│               ├── scripts/
│               └── references/
├── scripts/
│   ├── install-skill.sh
│   ├── install-all.sh
│   ├── uninstall-skill.sh
│   ├── uninstall-all.sh
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
| `sony-raw-styled-jpeg` | Convert Sony `.ARW` images into high-quality JPEGs using either exact one-pass conversion or a profiled adaptive workflow, while preserving EXIF and validating timestamps. |

## Claude Code: Install (User Scope)

1. Add marketplace:

```bash
claude plugin marketplace add ashwch/ashwch-agent-skills-marketplace
```

2. Install plugin (user scope):

```bash
claude plugin install sony-raw-styled-jpeg@ashwch
```

3. Use slash commands:

```text
/sony-raw-styled-jpeg:convert
/sony-raw-styled-jpeg:exact
/sony-raw-styled-jpeg:profiled
```

Optional helper:

```bash
bash scripts/claude-install.sh
```

## Claude Code: Uninstall

User scope:

```bash
claude plugin uninstall sony-raw-styled-jpeg@ashwch
```

If it was installed in project scope accidentally:

```bash
claude plugin uninstall sony-raw-styled-jpeg@ashwch --scope project
```

Optional helper:

```bash
bash scripts/claude-uninstall.sh
```

## Codex: Install (User Scope)

From local clone:

```bash
gh repo clone ashwch/ashwch-agent-skills-marketplace
cd ashwch-agent-skills-marketplace
bash scripts/install-skill.sh sony-raw-styled-jpeg
```

Install all plugin-backed skills:

```bash
bash scripts/install-all.sh
```

Direct from GitHub with skill installer:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
python3 "$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --repo ashwch/ashwch-agent-skills-marketplace \
  --ref main \
  --path plugins/sony-raw-styled-jpeg/skills/sony-raw-styled-jpeg
```

Use in Codex:

```text
Use $sony-raw-styled-jpeg to choose between exact and profiled ARW conversion, optionally add subtle mood shaping, and validate EXIF timestamps.
```

## Codex: Uninstall

Uninstall one:

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

## Sony Skill Outputs

- `<output>/MONxxxxx.jpg`
- `<output>/style_report.csv` or `<output>/profiled_style_report.csv`
- `<output>/exif_validation.txt`
- `<input>/profiling/raw_profile.csv` for profiled mode
- `<input>/profiling/raw_profile_summary.txt` for profiled mode

Details:

- `plugins/sony-raw-styled-jpeg/skills/sony-raw-styled-jpeg/README.md`
- `plugins/sony-raw-styled-jpeg/skills/sony-raw-styled-jpeg/references/PIPELINE_FIRST_PRINCIPLES.md`

## License

MIT - see `LICENSE`.
