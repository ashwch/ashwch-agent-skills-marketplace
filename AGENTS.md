# AGENTS

## Purpose

Maintain a personal marketplace of reusable agent skills for both Claude Code and Codex.

## Core Rules

1. Single source of truth is `plugins/<plugin>/skills/<plugin>/`.
2. Do not add or maintain a top-level `skills/` directory.
3. Each skill must include:
   - `SKILL.md` with YAML frontmatter (`name`, `description`)
   - `README.md`
4. Plugin directory name must match skill `name` exactly (kebab-case).
5. Keep commands portable; avoid machine-specific paths in docs.
6. Prefer user-level install guidance over project-level guidance.

## Claude Packaging Rules

1. Keep `.claude-plugin/marketplace.json` updated when adding/removing plugins.
2. Each plugin requires `plugins/<plugin>/.claude-plugin/plugin.json`.
3. Each plugin should expose at least one `plugins/<plugin>/commands/*.md` entrypoint.

## Validation Checklist

- Referenced script paths exist under plugin skill directory.
- Codex install/uninstall scripts work against plugin paths.
- Claude install/uninstall docs default to user scope.
- Metadata-sensitive skills keep validation steps documented.
- `README.md` and `CONTRIBUTING.md` reflect current plugin list.
