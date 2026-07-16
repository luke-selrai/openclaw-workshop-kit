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
import os
import sys
from pathlib import Path

# Resolve the templates root relative to this script, with an env override and a
# ~/.claude fallback — mirrors the sibling shell scripts (recommend.sh/select.sh).
ROOT = Path(
    os.environ.get("AOA_TEMPLATES_ROOT")
    or (Path(__file__).resolve().parent.parent / "templates" / "n8n")
)


def category_stats(cat_dir):
    total = real = skeleton = 0
    for wf in cat_dir.glob("*.json"):
        if wf.name.endswith(".meta.json"):
            continue
        total += 1
        meta = wf.with_suffix(".meta.json")
        if meta.exists():
            try:
                m = json.loads(meta.read_text(encoding="utf-8"))
                if m.get("schema_only"):
                    skeleton += 1
                else:
                    real += 1
            except (json.JSONDecodeError, OSError, ValueError):
                real += 1  # one bad/unreadable meta.json is skipped, not fatal
        else:
            real += 1
    return {
        "total": total,
        "real": real,
        "schema_only": skeleton,
        "ratio_real": round(real / total, 2) if total else 0.0,
    }


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    # Fail LOUD if the templates tree is missing — an absent tree must never be
    # silently reported as 'all categories empty'.
    if not ROOT.is_dir():
        print(f"REFUSE: templates root not found: {ROOT}", file=sys.stderr)
        sys.exit(1)
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
