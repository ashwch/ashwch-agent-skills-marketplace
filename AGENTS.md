# AGENTS

## Purpose

Maintain a personal marketplace of reusable agent skills.

## Repository conventions

1. Skills live under `skills/<skill-name>/`.
2. Each skill must include `SKILL.md` with YAML frontmatter:
   - `name`
   - `description`
3. Skill folder name must match `name` exactly.
4. Use kebab-case for skill names.
5. Keep `SKILL.md` concise and move deep docs to `references/`.
6. Put executable helpers in `scripts/`.
7. Keep example commands portable; avoid machine-specific absolute paths.

## Validation checklist for edits

- Any referenced script path exists.
- Installer scripts still work (`scripts/install-skill.sh`).
- For metadata-sensitive skills, validation step is preserved and documented.
- `README.md` skill table is updated.
