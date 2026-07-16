#!/usr/bin/env python3
"""lint-templates.py — flag and optionally remove skeleton-only templates.

Definition of "skeleton": a template where >50% of nodes have empty `type`
field or empty `parameters` (just `{}`). These pass the basic curate lint
(node count >= 3) but are not actually deployable for non-technical users.

Usage:
    lint-templates.py                   # report only
    lint-templates.py --remove          # delete .json + .meta.json for skeletons
    lint-templates.py --label           # add "schema_only": true to .meta.json
"""
import json
import os
import sys
from pathlib import Path

ROOT = Path(os.environ.get('AOA_TEMPLATES_ROOT') or (Path(__file__).resolve().parent.parent / 'templates' / 'n8n'))


def is_skeleton(wf_path):
    try:
        wf = json.loads(wf_path.read_text(encoding='utf-8'))
    except (json.JSONDecodeError, OSError):
        return None, "unreadable"
    nodes = wf.get("nodes", []) if isinstance(wf, dict) else []
    # Drop the curator-injected sticky-note/header node before computing the ratio.
    nodes = [n for n in nodes if n.get("type") != "n8n-nodes-base.stickyNote"]
    if not nodes:
        return True, "no nodes"
    real = sum(1 for n in nodes if n.get("type") and n.get("parameters"))
    pct = real / len(nodes)
    if pct < 0.5:
        return True, f"{real}/{len(nodes)} nodes typed ({pct*100:.0f}%)"
    return False, f"{real}/{len(nodes)} nodes typed ({pct*100:.0f}%)"


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    mode = "report"
    if "--remove" in sys.argv:
        mode = "remove"
    elif "--label" in sys.argv:
        mode = "label"

    skeletons = []
    real = []
    bad = []

    for cat_dir in sorted(ROOT.glob("*/")):
        if not cat_dir.is_dir():
            continue
        for wf in sorted(cat_dir.glob("*.json")):
            if wf.name.endswith(".meta.json"):
                continue
            verdict, reason = is_skeleton(wf)
            entry = (cat_dir.name, wf.name, reason)
            if verdict is None:
                bad.append(entry)
            elif verdict:
                skeletons.append(entry)
            else:
                real.append(entry)

    print(f"REAL: {len(real)}  SKELETON: {len(skeletons)}  UNREADABLE: {len(bad)}")
    print(f"Skeleton ratio: {len(skeletons) / (len(real)+len(skeletons)) * 100:.0f}%" if real or skeletons else "")
    print()
    if mode == "report":
        for cat, name, reason in skeletons[:30]:
            print(f"  [SKELETON] {cat}/{name}: {reason}")
        if len(skeletons) > 30:
            print(f"  ... and {len(skeletons) - 30} more")
        print()
        print("Run with --remove to delete, --label to mark schema_only=true in .meta.json")
        return

    for cat, name, reason in skeletons:
        wf = ROOT / cat / name
        meta = wf.with_suffix(".meta.json")
        if mode == "remove":
            wf.unlink(missing_ok=True)
            meta.unlink(missing_ok=True)
            print(f"  REMOVED {cat}/{name}")
        elif mode == "label":
            if meta.exists():
                try:
                    m = json.loads(meta.read_text(encoding='utf-8'))
                    m["schema_only"] = True
                    m["lint_reason"] = reason
                    meta.write_text(json.dumps(m, indent=2), encoding='utf-8')
                    print(f"  LABELLED {cat}/{name}")
                except json.JSONDecodeError:
                    pass


if __name__ == "__main__":
    main()
