# DEPRECATED

This skill has been superseded by **skill-architect** as of 2026-01-14.

## Why Deprecated

`skill-creator` and `skill-coach` have been unified into a single authoritative meta-skill (`skill-architect`) that combines:

- Systematic workflow from `skill-creator`
- Domain expertise encoding from `skill-coach`

## Migration

Use `skill-architect` instead of this skill.

All functionality from `skill-creator` has been preserved and enhanced in `skill-architect`.

## Location

The new skill is available in this repository at:

```
skills/skill-architect/
```

To install locally for Claude Code, copy it to your skills directory:

**Mac / Linux:**
```bash
cp -r skills/skill-architect ~/.claude/skills/
```

**Windows (PowerShell):**
```powershell
cp -Recurse skills\skill-architect $HOME\.claude\skills\
```

> Note: Do not use hardcoded absolute paths (e.g. `/Users/username/...`).
> Always install to `~/.claude/skills/` for cross-platform compatibility.
