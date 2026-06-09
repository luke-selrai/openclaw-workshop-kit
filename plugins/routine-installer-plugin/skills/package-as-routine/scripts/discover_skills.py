#!/usr/bin/env python3
"""List Claude Code skills available in the user's standard skill paths.

Skills live in a few standard places: project-local `.claude/skills/` and
user-global `~/.claude/skills/` (where workshop installs land).

This script enumerates every directory directly under each search path that
contains a SKILL.md, and emits a JSON list with `name`, `description`, and
`path` per skill.

To scan additional locations, override the search paths via the
ROUTINE_INSTALLER_SKILL_PATHS env var (colon-separated absolute paths).

Usage:
    python3 discover_skills.py
"""
import json
import os
import sys
from pathlib import Path

DEFAULT_SEARCH_PATHS = [
    Path.cwd() / ".claude" / "skills",
    Path.home() / ".claude" / "skills",
]


def extractFrontmatterField(skillMdText, field):
    if not skillMdText.startswith("---"):
        return None
    end = skillMdText.find("\n---", 3)
    if end == -1:
        return None
    header = skillMdText[3:end]
    for line in header.splitlines():
        if line.strip().startswith(f"{field}:"):
            return line.split(":", 1)[1].strip()
    return None


def discoverSkills(searchPaths):
    skills = []
    seenPaths = set()
    for base in searchPaths:
        basePath = Path(base).expanduser()
        if not basePath.is_dir():
            continue
        for child in sorted(basePath.iterdir()):
            if not child.is_dir():
                continue
            skillMd = child / "SKILL.md"
            if not skillMd.is_file():
                continue
            absPath = str(child.resolve())
            if absPath in seenPaths:
                continue
            seenPaths.add(absPath)
            text = skillMd.read_text(encoding="utf-8", errors="replace")
            name = extractFrontmatterField(text, "name") or child.name
            description = extractFrontmatterField(text, "description") or ""
            skills.append({
                "name": name,
                "description": description,
                "path": absPath,
            })
    return skills


def main():
    override = os.environ.get("ROUTINE_INSTALLER_SKILL_PATHS")
    if override:
        searchPaths = [p for p in override.split(":") if p]
    else:
        searchPaths = DEFAULT_SEARCH_PATHS
    skills = discoverSkills(searchPaths)
    sys.stdout.write(json.dumps(skills, indent=2))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
