# Contributing

## Plugin + Skill Structure

For each plugin:

1. Add/update plugin at `plugins/<plugin>/`.
2. Include:
   - `.claude-plugin/plugin.json`
   - `commands/*.md`
   - `skills/<plugin>/` skill bundle under the plugin directory
3. In `plugins/<plugin>/skills/<plugin>/`, include:
   - `SKILL.md` with frontmatter (`name`, `description`)
   - `README.md`
   - optional `scripts/`, `references/`, `assets/`

## Pull Request Checklist

- Marketplace manifest updated if plugin list changed.
- Command entrypoints exist for each plugin.
- Codex install scripts validated (`install-skill.sh`, `uninstall-skill.sh`).
- Skill `README.md` exists and matches current scripts/outputs.
- README install/uninstall steps remain accurate and user-level by default.
