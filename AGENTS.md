# AGENTS

## Purpose

Maintain a personal marketplace of reusable agent skills for both Claude Code and Codex.

## Core Rules

1. Canonical skill source lives in `skills/<skill-name>/`.
2. Claude plugin mirror lives in `plugins/<skill-name>/skills/<skill-name>/`.
3. Run `scripts/sync-skill-to-plugin.sh <skill-name>` after editing canonical skills.
4. Every skill must include `SKILL.md` with YAML frontmatter:
   - `name`
   - `description`
5. Every skill must include `README.md` for human-facing quick usage and file map.
6. Skill folder name must match `name` exactly (kebab-case).
7. Keep commands portable; avoid machine-specific paths in docs.
8. Prefer user-level install guidance over project-level guidance.

## Claude Packaging Rules

1. Keep `.claude-plugin/marketplace.json` updated when adding/removing plugins.
2. Each plugin requires `plugins/<plugin>/.claude-plugin/plugin.json`.
3. Each plugin should expose at least one `commands/*.md` entrypoint.

## Validation Checklist

- Any referenced script path exists.
- Codex install/uninstall scripts still work.
- Claude install/uninstall instructions remain user-scope by default.
- For metadata-sensitive skills, validation step is preserved and documented.
- `README.md` and `CONTRIBUTING.md` reflect current plugin/skill list.
