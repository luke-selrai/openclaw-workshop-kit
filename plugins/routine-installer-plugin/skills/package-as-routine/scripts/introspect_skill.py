#!/usr/bin/env python3
"""Scan a Claude Code skill folder for dependencies and emit a JSON manifest.

This is the dynamic-introspection step. Pattern-match (no AST parsing) every
file under the skill folder for the surface area the routine sandbox needs to
replicate: MCP server names, CLI invocations, env-var references, asset paths,
helper-script files.

The manifest output is consumed by map_deps_to_connectors.py to match each
CLI / MCP to a connector folder in the (optional) connector library.

Usage:
    python3 introspect_skill.py /path/to/skill-folder

Skill folder is expected to contain SKILL.md at its root.
"""
import json
import re
import sys
from pathlib import Path

MCP_PATTERN = re.compile(r"mcp__([a-z][a-z0-9_-]*?)_")
# Match a tool only when it stands alone as a command token. The lookbehind and
# lookahead reject the delimiters that appear in domains, emails, URLs, paths
# and quoted string literals (. : / @ " '), so `notion.so`, `from:notion.so`,
# `claude.ai/code` and a dict entry like "notion": "Notion" are NOT treated as
# CLI usage — these are the recurring false positives. A real invocation like
# `notion search` or `gws auth` (backtick/whitespace-delimited) still matches.
# Hyphen is intentionally allowed (e.g. the `gws-luke` alias).
CLI_PATTERN = re.compile(
    r"""(?<![A-Za-z0-9_/.:@"'])"""
    r"(gws|gh|m365|notion|python3?|node|npx|claude|jq|aws|gcloud|az)"
    r"""(?![A-Za-z0-9_./:@"'])"""
)
ENV_VAR_PATTERN = re.compile(r"\$\{?([A-Z][A-Z0-9_]{2,})\}?")
ASSET_PATTERN = re.compile(r"assets/([A-Za-z0-9_.\-/]+)")

SKILL_INTERNAL_NAMES = {"sample-skill"}


def readAllFiles(skillPath):
    files = {}
    for p in skillPath.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".pyc"}:
            continue
        try:
            files[str(p.relative_to(skillPath))] = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
    return files


def extractFrontmatterName(skillMdText):
    if not skillMdText.startswith("---"):
        return None
    end = skillMdText.find("\n---", 3)
    if end == -1:
        return None
    header = skillMdText[3:end]
    for line in header.splitlines():
        if line.strip().startswith("name:"):
            return line.split(":", 1)[1].strip()
    return None


def introspect(skillPath):
    skillPath = Path(skillPath).resolve()
    if not skillPath.is_dir():
        raise FileNotFoundError(f"skill folder does not exist: {skillPath}")

    skillMdPath = skillPath / "SKILL.md"
    if not skillMdPath.is_file():
        raise FileNotFoundError(f"SKILL.md not found in {skillPath}")

    files = readAllFiles(skillPath)
    combinedText = "\n".join(files.values())

    mcpServers = sorted(set(MCP_PATTERN.findall(combinedText)))
    clis = sorted(set(CLI_PATTERN.findall(combinedText)))
    envVars = sorted(set(ENV_VAR_PATTERN.findall(combinedText)))
    assetPaths = sorted(set(ASSET_PATTERN.findall(combinedText)))

    scriptFiles = sorted(
        relPath for relPath in files
        if relPath.startswith("scripts/")
    )

    name = extractFrontmatterName(files.get("SKILL.md", "")) or skillPath.name

    return {
        "name": name,
        "path": str(skillPath),
        "mcp_servers": mcpServers,
        "clis": clis,
        "env_vars": envVars,
        "asset_paths": assetPaths,
        "script_files": scriptFiles,
        "all_files": sorted(files.keys()),
    }


def main():
    if len(sys.argv) != 2:
        print("usage: introspect_skill.py <skill-folder>", file=sys.stderr)
        sys.exit(1)
    try:
        manifest = introspect(sys.argv[1])
    except FileNotFoundError as e:
        print(f"introspect_skill: {e}", file=sys.stderr)
        sys.exit(1)
    sys.stdout.write(json.dumps(manifest, indent=2))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
