#!/usr/bin/env python3
"""
backfill-czlonkowski.py — Standalone backfill from Zie619/n8n-workflows (MIT).

Targets thin categories that n8n.io's popularity-sorted list won't fill.
Categorizes by file path AND name (paths are like Acuityscheduling/, Aggregate/, etc.).

Usage:
  python3 backfill-czlonkowski.py
"""
import concurrent.futures as cf
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(os.path.expanduser("~/.claude/skills/ai-ops-architect/templates/n8n"))
ROOT.mkdir(parents=True, exist_ok=True)

# Same cats as main curator
CATS = [
    ("lead-capture",      r"\b(lead|form|signup|opt-?in|enquir|inquir|webhook|magnet|capture|subscribe)\b"),
    ("email-automation",  r"\b(email|gmail|outlook|inbox|reply|drip|sequence|newsletter|smtp|imap|mail|mandrill|sendgrid|mailchimp)\b"),
    ("crm-sync",          r"\b(crm|hubspot|salesforce|pipedrive|airtable|notion|contact|pipeline|zoho|copper|insightly)\b"),
    ("ecommerce",         r"\b(shopify|woocommerce|order|product|inventory|cart|stripe|checkout|abandon|sku|fulfill|magento|ebay)\b"),
    ("social-media",      r"\b(twitter|x\.com|linkedin|facebook|instagram|tiktok|youtube|reddit|social|hashtag|mastodon)\b"),
    ("content-pipeline",  r"\b(blog|content|article|wordpress|medium|publish|cms|substack|ghost|markdown|rss)\b"),
    ("ops-monitoring",    r"\b(monitor|alert|uptime|health|ping|statuspage|cron|schedule|sentry|datadog|metric|dashboard|incident|prometheus|grafana|pagerduty|nagios)\b"),
    ("finance-invoicing", r"\b(invoice|xero|quickbooks|expense|receipt|payment|stripe|billing|bank|reconcil|gst|vat|tax|paypal|wise|brex)\b"),
    ("ai-agents",         r"\b(ai|gpt|llm|openai|claude|anthropic|agent|chatbot|chat|rag|vector|embedding|qdrant|pinecone|mistral|gemini|cohere)\b"),
    ("data-sync",         r"\b(sync|database|postgres|mysql|mongodb|sheets|airtable|migrate|etl|warehouse|snowflake|bigquery|redis|s3|aws|gcp)\b"),
    ("support-helpdesk",  r"\b(support|helpdesk|ticket|zendesk|intercom|freshdesk|customer|crisp|drift)\b"),
    ("industry-specific", r"\b(real ?estate|trade|coach|agency|hotel|restaurant|salon|clinic|booking|appointment|reservation|gym|fitness|legal|medical|dental)\b"),
]
JUNK = re.compile(r"^(my workflow|test|untitled|copy of|sample|example|demo)\b", re.I)

QUOTAS = {
    "lead-capture": 25, "email-automation": 30, "crm-sync": 22, "ecommerce": 25,
    "social-media": 25, "content-pipeline": 18, "ops-monitoring": 15,
    "finance-invoicing": 18, "ai-agents": 30, "data-sync": 20,
    "support-helpdesk": 12, "industry-specific": 10,
}

MAX_WORKERS = 12
TIME_BUDGET = int(os.environ.get("MAX_SECONDS", "600"))  # 10 min default


def slug(s, n=60):
    return re.sub(r"[^a-zA-Z0-9._-]", "_", (s or "untitled"))[:n]


def categorize_text(s):
    sl = s.lower()
    for cat, rx in CATS:
        if re.search(rx, sl, re.I):
            return cat
    return None


def http_bytes(url, timeout=20):
    req = urllib.request.Request(
        url, headers={"User-Agent": "ai-ops-architect/curator", "Accept": "application/vnd.github+json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def existing_ids():
    seen = set()
    for cat in QUOTAS:
        d = ROOT / cat
        if not d.exists():
            continue
        for p in d.glob("*.json"):
            if p.name.endswith(".meta.json"):
                continue
            base = p.stem
            try:
                wid = int(base.split("__")[0])
                seen.add(wid)
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
    seen = existing_ids()
    counts = count_per_cat()
    needed = {c: QUOTAS[c] - counts[c] for c in QUOTAS if counts[c] < QUOTAS[c]}
    print(f"Start: {sum(counts.values())}/{sum(QUOTAS.values())} on disk")
    print(f"Needed per cat: {needed}")
    if not needed:
        print("All quotas filled!")
        return
    started = time.time()
    deadline = started + TIME_BUDGET

    # Fetch tree
    print("Fetching czlonkowski/Zie619 tree...", flush=True)
    tree = json.loads(http_bytes("https://api.github.com/repos/Zie619/n8n-workflows/git/trees/main?recursive=1"))
    items = [t for t in tree.get("tree", []) if t.get("type") == "blob"
             and t.get("path", "").startswith("workflows/")
             and t.get("path", "").endswith(".json")]
    print(f"  {len(items)} candidates")

    # Pre-categorize by path (file structure has hints like Acuityscheduling/, Stripe/, ...)
    targeted = {c: [] for c in needed}
    skipped_seen = 0
    for it in items:
        path = it["path"]
        # Synthetic stable id from path hash
        wid = abs(hash(path)) % (10**8) + 100_000_000
        if wid in seen:
            skipped_seen += 1
            continue
        # Categorize from path
        cat = categorize_text(path.replace("/", " ").replace("_", " ").replace(".json", ""))
        if not cat or cat not in needed:
            continue
        if len(targeted[cat]) >= needed[cat] * 4:  # 4x candidates so we can afford lint failures
            continue
        targeted[cat].append((wid, path))
    print(f"  pre-categorized into needed cats: { {k:len(v) for k,v in targeted.items()} }")

    base_raw = "https://raw.githubusercontent.com/Zie619/n8n-workflows/main/"
    pool = cf.ThreadPoolExecutor(max_workers=MAX_WORKERS)

    def fetch_one(item):
        wid, path = item
        try:
            raw = http_bytes(base_raw + path, timeout=15)
            wf = json.loads(raw)
            return (wid, path, wf)
        except Exception:
            return None

    saved = 0
    for cat, candidates in targeted.items():
        if time.time() >= deadline:
            print(f"deadline hit at cat={cat}", flush=True)
            break
        if counts[cat] >= QUOTAS[cat]:
            continue
        print(f"\n=== {cat}: need {QUOTAS[cat]-counts[cat]}, trying {len(candidates)} candidates ===", flush=True)
        # Submit all in parallel
        for fut in cf.as_completed([pool.submit(fetch_one, c) for c in candidates]):
            res = fut.result()
            if not res:
                continue
            wid, path, wf = res
            seen.add(wid)
            cur = count_per_cat()
            if cur[cat] >= QUOTAS[cat]:
                break
            nodes = wf.get("nodes", []) or []
            if len(nodes) < 3:  # lint
                continue
            # Re-categorize using node names + workflow name (more accurate)
            wf_name = wf.get("name") or path.split("/")[-1].replace(".json", "")
            if JUNK.match(wf_name):
                continue
            txt = wf_name + " " + " ".join((n.get("name", "") + " " + n.get("type", "")) for n in nodes)
            re_cat = categorize_text(txt)
            if re_cat and re_cat in needed and counts[re_cat] < QUOTAS[re_cat]:
                use_cat = re_cat
            elif counts[cat] < QUOTAS[cat]:
                use_cat = cat
            else:
                continue
            services = []
            for n in nodes:
                t = (n.get("type") or "").replace("n8n-nodes-base.", "").replace("@n8n/n8n-nodes-langchain.", "lc.")
                if t and t not in services and t not in ("set", "if", "switch", "merge", "code", "function", "stickyNote", "noOp"):
                    services.append(t)
            # Build description from sticky notes inline OR fall back to a synthesized one
            desc = ""
            for n in nodes:
                if n.get("type") == "n8n-nodes-base.stickyNote":
                    c = (n.get("parameters") or {}).get("content", "")
                    if c and len(c) > len(desc):
                        desc = c
            if len(desc.strip()) < 30:
                desc = (
                    f"n8n workflow: {wf_name}. {len(nodes)} nodes wired together. "
                    f"Uses: {', '.join(services[:5])}. "
                    f"Sourced from czlonkowski/Zie619 n8n-workflows community archive ({path}). "
                    f"Configure credentials and any hardcoded IDs before activating."
                )
            difficulty = "auto-deploy" if len(nodes) <= 5 else ("5min-config" if len(nodes) <= 15 else "30min-custom")
            meta = {
                "id": wid,
                "title": wf_name,
                "description": desc.strip(),
                "category": use_cat,
                "services_required": services[:8],
                "node_count": len(nodes),
                "opportunity_pattern": None,
                "difficulty": difficulty,
                "value": "varies — see workflow",
                "source_url": "https://github.com/Zie619/n8n-workflows",
                "source": "czlonkowski",
                "source_path": path,
                "license": "MIT (Zie619/n8n-workflows)",
                "curated_at": "2026-05-05",
                "tags": [use_cat, "czlonkowski-backfill"],
            }
            wf_with_note = add_sticky_note({"nodes": nodes, "connections": wf.get("connections", {}),
                                            "name": wf_name, "active": False}, meta)
            cat_dir = ROOT / use_cat
            cat_dir.mkdir(exist_ok=True)
            base = f"{wid}__{slug(wf_name)}"
            (cat_dir / f"{base}.json").write_text(json.dumps(wf_with_note, indent=2))
            (cat_dir / f"{base}.meta.json").write_text(json.dumps(meta, indent=2))
            counts = count_per_cat()
            saved += 1
            if saved % 10 == 0:
                print(f"  +{saved} saved, total {sum(counts.values())}/{sum(QUOTAS.values())}", flush=True)
            if time.time() >= deadline:
                break
    pool.shutdown(wait=False)

    counts = count_per_cat()
    elapsed = time.time() - started
    print(f"\nDONE in {elapsed:.0f}s: total {sum(counts.values())}/{sum(QUOTAS.values())}")
    for c, n in counts.items():
        marker = "OK " if n >= 0.8 * QUOTAS[c] else "LOW"
        print(f"  [{marker}] {c}: {n}/{QUOTAS[c]}")


if __name__ == "__main__":
    main()
