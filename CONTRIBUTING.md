# Contributing

## Skill rules

1. Each skill lives at `skills/<skill-name>/`.
2. Every skill must include `SKILL.md` with YAML frontmatter containing:
   - `name`
   - `description`
3. `name` must match folder name and use kebab-case.
4. Keep `SKILL.md` concise; place deep docs in `references/` and scripts in `scripts/`.

## Pull request checklist

- Skill loads without path assumptions.
- Scripts run on a representative sample.
- Any metadata-sensitive workflows include validation steps.
- README table updated with new skill entry.
