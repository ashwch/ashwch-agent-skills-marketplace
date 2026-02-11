# Contributing

## Skill Structure

1. Add canonical skill at `skills/<skill-name>/`.
2. Add Claude plugin wrapper at `plugins/<skill-name>/`:
   - `.claude-plugin/plugin.json`
   - `commands/*.md`
   - mirrored skill at `plugins/<skill-name>/skills/<skill-name>/`
3. Include required `SKILL.md` frontmatter:
   - `name`
   - `description`
4. Add `README.md` inside each skill directory (`skills/<skill-name>/README.md`).

## Sync Flow

After editing `skills/<skill-name>/`, run:

```bash
bash scripts/sync-skill-to-plugin.sh <skill-name>
```

## Pull Request Checklist

- Marketplace manifest updated if plugin list changed.
- Command entrypoints exist for Claude plugin.
- Codex install scripts validated (`install-skill.sh`, `uninstall-skill.sh`).
- Skill README exists and reflects current scripts/outputs.
- README install/uninstall steps remain accurate and user-level by default.
