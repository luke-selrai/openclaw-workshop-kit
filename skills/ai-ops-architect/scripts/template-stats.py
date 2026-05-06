#!/usr/bin/env python3
"""template-stats.py — emit JSON stats so recommend.sh can downrank skeleton-heavy categories.

Output:
{
  "categories": {
    "finance-invoicing": {"total": 23, "real": 23, "schema_only": 0, "ratio_real": 1.0},
    ...
  },
  "global": {"total": 288, "real": 186, "schema_only": 102, "ratio_real": 0.65}
}
"""
import json
import sys
from pathlib import Path

ROOT = Path("~/.claude/skills/ai-ops-architect/templates/n8n").expanduser()


def category_stats(cat_dir):
    total = real = skeleton = 0
    for wf in cat_dir.glob("*.json"):
        if wf.name.endswith(".meta.json"):
            continue
        total += 1
        meta = wf.with_suffix(".meta.json")
        if meta.exists():
            try:
                m = json.loads(meta.read_text())
                if m.get("schema_only"):
                    skeleton += 1
                else:
                    real += 1
            except json.JSONDecodeError:
                real += 1  # assume real if unreadable
        else:
            real += 1
    return {
        "total": total,
        "real": real,
        "schema_only": skeleton,
        "ratio_real": round(real / total, 2) if total else 0.0,
    }


def main():
    cats = {}
    g_total = g_real = g_skel = 0
    for d in sorted(ROOT.glob("*/")):
        if not d.is_dir():
            continue
        s = category_stats(d)
        cats[d.name] = s
        g_total += s["total"]
        g_real += s["real"]
        g_skel += s["schema_only"]
    out = {
        "categories": cats,
        "global": {
            "total": g_total,
            "real": g_real,
            "schema_only": g_skel,
            "ratio_real": round(g_real / g_total, 2) if g_total else 0.0,
        },
    }
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
