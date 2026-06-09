#!/usr/bin/env python3
"""
backfill-round2.py — second-pass czlonkowski backfill targeting the 4 still-thin cats:
  - finance-invoicing
  - ai-agents
  - support-helpdesk
  - industry-specific

Uses explicit folder-name matching against the czlonkowski tree (folders are
named by service: Stripe/, Xero/, Zendesk/, Openai/, Acuityscheduling/, etc.)
so we hit categories the keyword regex missed.
"""
import concurrent.futures as cf
import hashlib
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(os.environ.get('AOA_TEMPLATES_ROOT') or (Path(__file__).resolve().parent.parent / 'templates' / 'n8n'))

QUOTAS = {
    "finance-invoicing": 18, "ai-agents": 30,
    "support-helpdesk": 12, "industry-specific": 10,
}

# Folder-prefix → category map. Paths look like workflows/<Service>/<NNNN_...>.json
FOLDER_MAP = {
    # finance
    "Stripe": "finance-invoicing", "Xero": "finance-invoicing",
    "Quickbooks": "finance-invoicing", "Paypal": "finance-invoicing",
    "Gocardless": "finance-invoicing", "Wise": "finance-invoicing",
    "Brex": "finance-invoicing", "Square": "finance-invoicing",
    "Sage": "finance-invoicing", "Plaid": "finance-invoicing",
    "Chargebee": "finance-invoicing", "Clearbit": "finance-invoicing",
    # ai-agents
    "Openai": "ai-agents", "Anthropic": "ai-agents", "Aiagent": "ai-agents",
    "Pinecone": "ai-agents", "Qdrant": "ai-agents", "Weaviate": "ai-agents",
    "Cohere": "ai-agents", "Mistral": "ai-agents", "Gemini": "ai-agents",
    "Embeddings": "ai-agents", "Langchain": "ai-agents",
    "Chatbot": "ai-agents", "Llmchain": "ai-agents",
    # support
    "Zendesk": "support-helpdesk", "Intercom": "support-helpdesk",
    "Freshdesk": "support-helpdesk", "Helpscout": "support-helpdesk",
    "Drift": "support-helpdesk", "Crisp": "support-helpdesk",
    "Helpdesk": "support-helpdesk", "Ticket": "support-helpdesk",
    # industry-specific (booking/scheduling/vertical-specific tools)
    "Acuityscheduling": "industry-specific", "Calendly": "industry-specific",
    "Cal": "industry-specific", "Booking": "industry-specific",
    "Reservation": "industry-specific", "Realestate": "industry-specific",
    "Property": "industry-specific", "Salon": "industry-specific",
    "Hotel": "industry-specific", "Restaurant": "industry-specific",
    "Clinic": "industry-specific", "Gym": "industry-specific",
}

# Lowercased prefix → category map. Real czlonkowski folder names vary in case and
# carry suffixes (e.g. "stripe", "Stripe_v2", "openaiAssistant"), so exact-match
# misses them. Match the lowercased folder by prefix against these keys.
FOLDER_MAP_LC = {k.lower(): v for k, v in FOLDER_MAP.items()}


def match_category(folder):
    """Case-insensitive prefix match of a folder name against FOLDER_MAP."""
    f = (folder or "").lower()
    for prefix, cat in FOLDER_MAP_LC.items():
        if f.startswith(prefix):
            return cat
    return None


JUNK = re.compile(r"^(my workflow|test|untitled|copy of|sample|example|demo)\b", re.I)
MAX_WORKERS = 12


def slug(s, n=60):
    return re.sub(r"[^a-zA-Z0-9._-]", "_", (s or "untitled"))[:n]


def http_bytes(url, timeout=20):
    req = urllib.request.Request(
        url, headers={"User-Agent": "ai-ops-architect/curator", "Accept": "application/vnd.github+json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def existing_ids():
    seen = set()
    for d in ROOT.iterdir() if ROOT.exists() else []:
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


def count_per_cat():
    out = {c: 0 for c in QUOTAS}
    for cat in QUOTAS:
        d = ROOT / cat
        if d.exists():
            out[cat] = sum(1 for p in d.glob("*.json") if not p.name.endswith(".meta.json"))
    return out


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
                f"_Curated by ai-ops-architect on {meta['curated_at']}_"
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


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    seen = existing_ids()
    counts = count_per_cat()
    needed = {c: QUOTAS[c] - counts[c] for c in QUOTAS if counts[c] < QUOTAS[c]}
    print(f"Round 2: needed = {needed}")
    if not needed:
        print("All quotas filled!")
        return

    print("Fetching tree...")
    tree = json.loads(http_bytes("https://api.github.com/repos/Zie619/n8n-workflows/git/trees/main?recursive=1"))
    items = [t for t in tree.get("tree", []) if t.get("type") == "blob"
             and t.get("path", "").startswith("workflows/")
             and t.get("path", "").endswith(".json")]

    # Bucket by folder match
    buckets = {c: [] for c in needed}
    for it in items:
        path = it["path"]  # workflows/Stripe/0123_...
        parts = path.split("/")
        if len(parts) < 3:
            continue
        folder = parts[1]
        cat = match_category(folder)
        if not cat or cat not in needed:
            continue
        wid = int(hashlib.sha1(path.encode('utf-8')).hexdigest()[:8], 16) % (10**8) + 100_000_000
        if wid in seen:
            continue
        buckets[cat].append((wid, path))

    print(f"Folder-bucket sizes: { {k:len(v) for k,v in buckets.items()} }")

    base_raw = "https://raw.githubusercontent.com/Zie619/n8n-workflows/main/"
    pool = cf.ThreadPoolExecutor(max_workers=MAX_WORKERS)

    def fetch_one(item):
        wid, path = item
        try:
            raw = http_bytes(base_raw + path, timeout=15)
            return (wid, path, json.loads(raw))
        except Exception:
            return None

    saved = 0
    for cat, candidates in buckets.items():
        if counts[cat] >= QUOTAS[cat]:
            continue
        target = QUOTAS[cat] - counts[cat]
        # Take 3x candidates to allow lint failures
        sample = candidates[:max(target * 3, 30)]
        print(f"\n=== {cat}: need {target}, fetching {len(sample)} ===", flush=True)
        cat_count = counts[cat]   # in-memory tally — avoids re-globbing disk every iteration
        for fut in cf.as_completed([pool.submit(fetch_one, c) for c in sample]):
            res = fut.result()
            if not res:
                continue
            wid, path, wf = res
            seen.add(wid)
            nodes = wf.get("nodes", []) or []
            if len(nodes) < 3:
                continue
            wf_name = wf.get("name") or path.split("/")[-1].replace(".json", "")
            if JUNK.match(wf_name):
                continue
            services = []
            for n in nodes:
                t = (n.get("type") or "").replace("n8n-nodes-base.", "").replace("@n8n/n8n-nodes-langchain.", "lc.")
                if t and t not in services and t not in ("set", "if", "switch", "merge", "code", "function", "stickyNote", "noOp"):
                    services.append(t)
            desc = ""
            for n in nodes:
                if n.get("type") == "n8n-nodes-base.stickyNote":
                    c = (n.get("parameters") or {}).get("content", "")
                    if c and len(c) > len(desc):
                        desc = c
            if len(desc.strip()) < 30:
                desc = (
                    f"n8n workflow: {wf_name}. {len(nodes)} nodes. "
                    f"Uses: {', '.join(services[:5])}. "
                    f"Sourced from czlonkowski/Zie619 n8n-workflows community archive ({path}). "
                    f"Configure credentials and any hardcoded IDs before activating."
                )
            difficulty = "auto-deploy" if len(nodes) <= 5 else ("5min-config" if len(nodes) <= 15 else "30min-custom")
            meta = {
                "id": wid,
                "title": wf_name,
                "description": desc.strip(),
                "category": cat,
                "services_required": services[:8],
                "node_count": len(nodes),
                "opportunity_pattern": None,
                "difficulty": difficulty,
                "value": "varies — see workflow",
                "source_url": "https://github.com/Zie619/n8n-workflows",
                "source": "czlonkowski-r2",
                "source_path": path,
                "license": "MIT (Zie619/n8n-workflows)",
                "curated_at": "2026-05-05",
                "tags": [cat, "czlonkowski-backfill-r2"],
            }
            wf_with_note = add_sticky_note(
                {"nodes": nodes, "connections": wf.get("connections", {}), "name": wf_name, "active": False},
                meta
            )
            cat_dir = ROOT / cat
            cat_dir.mkdir(parents=True, exist_ok=True)
            base = f"{wid}__{slug(wf_name)}"
            (cat_dir / f"{base}.json").write_text(json.dumps(wf_with_note, indent=2), encoding='utf-8')
            (cat_dir / f"{base}.meta.json").write_text(json.dumps(meta, indent=2), encoding='utf-8')
            saved += 1
            cat_count += 1
            if cat_count >= QUOTAS[cat]:   # save first, THEN stop — don't discard the fetched workflow
                break
        counts[cat] = cat_count
        print(f"  cat now {counts[cat]}/{QUOTAS[cat]}", flush=True)
    pool.shutdown(wait=False)

    counts = count_per_cat()
    total_disk = sum(
        1 for d in ROOT.iterdir() if d.is_dir()
        for p in d.glob("*.json") if not p.name.endswith(".meta.json")
    )
    print(f"\nDONE: saved {saved} new, {total_disk} total templates")
    for c, q in QUOTAS.items():
        marker = "OK " if counts[c] >= 0.8 * q else "LOW"
        print(f"  [{marker}] {c}: {counts[c]}/{q}")


if __name__ == "__main__":
    main()
