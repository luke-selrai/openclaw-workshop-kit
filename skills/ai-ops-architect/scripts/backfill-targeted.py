#!/usr/bin/env python3
"""
backfill-targeted.py — laser-focused n8n.io search by integration/vertical keyword.

Use when curate-templates.py + czlonkowski backfill leave a category short and
you know exactly what's missing. Searches n8n.io's `?search=<keyword>` endpoint,
fetches detail for top candidates, lints, and routes to a category you specify
(bypassing the regex router).

Usage:
    backfill-targeted.py finance-invoicing stripe xero paypal square freshbooks
    backfill-targeted.py industry-specific real-estate fitness healthcare hospitality

Sources: https://api.n8n.io/api/templates/workflows?page=N&rows=50&search=<term>

Output: ~/.claude/skills/ai-ops-architect/templates/n8n/<cat>/<id>__<slug>.json + .meta.json
"""
import concurrent.futures as cf
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get('AOA_TEMPLATES_ROOT') or (Path(__file__).resolve().parent.parent / 'templates' / 'n8n'))
JUNK = re.compile(r"^(my workflow|test|untitled|copy of|sample|example|demo)\b", re.I)
MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "8"))
PER_KEYWORD_CAP = int(os.environ.get("PER_KEYWORD_CAP", "5"))  # cap per search term


def slug(s, n=60):
    return re.sub(r"[^a-zA-Z0-9._-]", "_", (s or "untitled"))[:n]


def http_json(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "ai-ops-architect/targeted"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def search_n8n(keyword, rows=50):
    q = urllib.request.quote(keyword)
    return http_json(f"https://api.n8n.io/api/templates/workflows?page=1&rows={rows}&search={q}")


def fetch_full(wid):
    return http_json(f"https://api.n8n.io/api/templates/workflows/{wid}")


def existing_ids_all():
    seen = set()
    for d in ROOT.glob("*/"):
        if not d.is_dir():
            continue
        for p in d.glob("*.json"):
            if p.name.endswith(".meta.json"):
                continue
            try:
                seen.add(int(p.stem.split("__")[0]))
            except (ValueError, IndexError):
                pass
    return seen


def lint(wf_full, name, description):
    if JUNK.match(name or ""):
        return False, "junk-name"
    if not description or len(description.strip()) < 30:
        return False, "weak-description"
    nodes = (wf_full.get("workflow") or {}).get("nodes", [])
    if len(nodes) < 3:
        return False, "too-few-nodes"
    return True, "ok"


# Domain filters: keyword search alone pulls noise (e.g. "wave" -> AI music videos).
# Require the workflow's name+description to contain at least one domain word
# before we'll save it under that category.
DOMAIN_FILTERS = {
    "finance-invoicing": [
        "invoice", "payment", "billing", "tax", "expense", "receipt",
        "accounting", "transaction", "refund", "subscription", "reconcil",
        "ledger", "bookkeep", "payroll", "payout", "remittance",
    ],
    "industry-specific": [
        "real estate", "realtor", "property", "listing", "tenant", "landlord",
        "fitness", "gym", "personal trainer", "workout", "wellness", "yoga",
        "healthcare", "clinic", "doctor", "patient", "dental", "medical",
        "hospitality", "hotel", "restaurant", "booking", "reservation",
        "construction", "trade", "contractor", "tradie", "renovation",
        "beauty", "salon", "barber", "spa",
        "automotive", "mechanic", "garage", "vehicle",
    ],
}


def domain_match(cat, name, description):
    """Return True if cat has no filter, or text mentions at least one domain word."""
    words = DOMAIN_FILTERS.get(cat)
    if not words:
        return True
    txt = f"{name} {description}".lower()
    return any(w in txt for w in words)


def add_sticky_note(workflow_json, meta):
    note = {
        "parameters": {
            "content": (
                f"## {meta['title']}\n\n"
                f"**Purpose**: {meta['description'][:400]}\n\n"
                f"**Services needed**: {', '.join(meta['services_required'])}\n\n"
                f"**Difficulty**: {meta['difficulty']}\n\n"
                f"**Setup**:\n"
                f"1. Configure credentials for the services above\n"
                f"2. Update any hardcoded IDs / URLs\n"
                f"3. Test with sample data before activating\n\n"
                f"_Source: {meta['source_url']}_\n"
                f"_Curated by ai-ops-architect (targeted backfill) on {meta['curated_at']}_"
            ),
            "height": 480,
            "width": 480,
        },
        "name": "Setup Guide (delete after configuring)",
        "type": "n8n-nodes-base.stickyNote",
        "typeVersion": 1,
        "position": [-400, -400],
        "id": "ai-ops-sticky-header",
    }
    workflow_json.setdefault("nodes", []).insert(0, note)
    return workflow_json


def save(wid, name, description, full, cat, keyword):
    """Save into the named category, bypassing regex routing."""
    ok, reason = lint(full, name, description)
    if not ok:
        return False, reason
    if not domain_match(cat, name, description):
        return False, f"off-domain ({cat})"
    wf_json = (full.get("workflow") or {})
    services = []
    for n in wf_json.get("nodes", []):
        t = (n.get("type") or "").replace("n8n-nodes-base.", "").replace("@n8n/n8n-nodes-langchain.", "lc.")
        if t and t not in services and t not in ("set", "if", "switch", "merge", "code", "function", "stickyNote"):
            services.append(t)
    nc = len(wf_json.get("nodes", []))
    difficulty = "auto-deploy" if nc <= 5 else ("5min-config" if nc <= 15 else "30min-custom")
    meta = {
        "id": wid,
        "title": name,
        "description": description.strip(),
        "category": cat,
        "services_required": services[:8],
        "node_count": nc,
        "difficulty": difficulty,
        "value": "varies — check workflow",
        "source_url": f"https://n8n.io/workflows/{wid}",
        "source": "n8n.io",
        "matched_keyword": keyword,
        "license": "n8n.io community",
        "curated_at": datetime.now(timezone.utc).date().isoformat(),
        "tags": [cat, keyword],
    }
    wf_json = add_sticky_note(wf_json, meta)
    out_dir = ROOT / cat
    out_dir.mkdir(parents=True, exist_ok=True)
    base = f"{wid}__{slug(name)}"
    (out_dir / f"{base}.json").write_text(json.dumps(wf_json, indent=2), encoding='utf-8')
    (out_dir / f"{base}.meta.json").write_text(json.dumps(meta, indent=2), encoding='utf-8')
    return True, cat


def run_keyword(cat, keyword, all_seen):
    """Search n8n.io for keyword, fetch top candidates in parallel, save to cat."""
    print(f"  -> searching '{keyword}' for {cat}...", flush=True)
    try:
        listing = search_n8n(keyword, rows=30)
    except Exception as e:
        print(f"     search failed: {e}")
        return 0
    candidates = listing.get("workflows") or []
    # Skip already-on-disk
    candidates = [w for w in candidates if w.get("id") and w["id"] not in all_seen]
    if not candidates:
        print("     no new candidates after dedup")
        return 0

    # Parallel fetch_full for top candidates
    fetched = []
    with cf.ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futs = {ex.submit(fetch_full, w["id"]): w for w in candidates[:20]}
        try:
            for fut in cf.as_completed(futs, timeout=120):
                w = futs[fut]
                try:
                    full = fut.result()
                    fetched.append((w, full))
                except Exception as e:
                    print(f"     fetch {w['id']} failed: {e}")
        except cf.TimeoutError:
            print(f"     fetch timeout — processing {len(fetched)} completed, continuing")

    saved = 0
    for w, full in fetched:
        if saved >= PER_KEYWORD_CAP:
            break
        wid = w["id"]
        name = w.get("name", "")
        # Detail endpoint description is on the workflow object
        description = (full.get("workflow") or {}).get("description") or w.get("description", "")
        ok, reason = save(wid, name, description, full, cat, keyword)
        if ok:
            print(f"     [SAVED] {wid}: {name[:60]}")
            all_seen.add(wid)
            saved += 1
        else:
            print(f"     [SKIP] {wid}: {reason}")
    return saved


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    cat = sys.argv[1]
    keywords = sys.argv[2:]
    if cat not in (
        "lead-capture", "email-automation", "crm-sync", "ecommerce", "social-media",
        "content-pipeline", "ops-monitoring", "finance-invoicing", "ai-agents",
        "data-sync", "support-helpdesk", "industry-specific",
    ):
        print(f"ERROR: unknown category '{cat}'")
        sys.exit(2)

    print(f"Targeted backfill -> {cat}")
    print(f"Keywords: {', '.join(keywords)}")
    print(f"Per-keyword cap: {PER_KEYWORD_CAP}, workers: {MAX_WORKERS}")
    print()

    before = sum(1 for p in (ROOT / cat).glob("*.json") if not p.name.endswith(".meta.json")) if (ROOT / cat).exists() else 0
    all_seen = existing_ids_all()
    total_saved = 0
    for kw in keywords:
        total_saved += run_keyword(cat, kw, all_seen)

    after = sum(1 for p in (ROOT / cat).glob("*.json") if not p.name.endswith(".meta.json"))
    print()
    print(f"Done. {cat}: {before} -> {after} (+{total_saved})")


if __name__ == "__main__":
    main()
