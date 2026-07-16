#!/usr/bin/env python3
"""
curate-templates.py — Phase B v2: pull n8n.io templates, parallel + list-first +
resume-friendly, then backfill thin categories from czlonkowski/n8n-mcp bundle.

Target: 250 elite templates across 12 categories, with sticky-note headers + meta.json sidecars.

Speedups vs v1:
  1. List-first categorize: route by name on the list endpoint (~150ms each).
     Only fetch_full when name passes a category and we still have quota for it.
  2. Parallel fetch_full via ThreadPoolExecutor(max_workers=8).
  3. Resume-friendly: skip IDs already on disk.
  4. czlonkowski backfill: gap-fill thin categories from
     https://github.com/czlonkowski/n8n-workflows (raw JSON dumps).

Sources:
  https://api.n8n.io/api/templates/workflows?page=N&rows=50  (list)
  https://api.n8n.io/api/templates/workflows/{id}            (full workflow)
  https://github.com/czlonkowski/n8n-workflows                (backfill, MIT)

Output: ~/.claude/skills/ai-ops-architect/templates/n8n/<cat>/<id>__<slug>.json + .meta.json
"""
import concurrent.futures as cf
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

ROOT = Path(os.environ.get('AOA_TEMPLATES_ROOT') or (Path(__file__).resolve().parent.parent / 'templates' / 'n8n'))
ROOT.mkdir(parents=True, exist_ok=True)

# Category routing — first match wins. Names matter most; descriptions backfill.
CATS = [
    ("lead-capture",      r"\b(lead|form|signup|opt-?in|enquir|inquir|webhook to crm|magnet|capture)\b"),
    ("email-automation",  r"\b(email|gmail|outlook|inbox|reply|drip|sequence|newsletter|smtp|imap|mail)\b"),
    ("crm-sync",          r"\b(crm|hubspot|salesforce|pipedrive|airtable|notion|contact|pipeline|hubspot)\b"),
    ("ecommerce",         r"\b(shopify|woocommerce|order|product|inventory|cart|stripe|checkout|abandon|sku|fulfill)\b"),
    ("social-media",      r"\b(twitter|x\.com|linkedin|facebook|instagram|tiktok|youtube|reddit|social|post|hashtag)\b"),
    ("content-pipeline",  r"\b(blog|content|article|wordpress|medium|publish|cms|substack|ghost|markdown)\b"),
    ("ops-monitoring",    r"\b(monitor|alert|uptime|health|ping|statuspage|cron|schedule|sentry|datadog|metric|dashboard|incident)\b"),
    ("finance-invoicing", r"\b(invoice|xero|quickbooks|expense|receipt|payment|stripe|billing|bank|reconcil|gst|vat|tax)\b"),
    ("ai-agents",         r"\b(ai|gpt|llm|openai|claude|anthropic|agent|chatbot|chat|rag|vector|embedding|qdrant|pinecone)\b"),
    ("data-sync",         r"\b(sync|database|postgres|mysql|mongodb|sheets|airtable|migrate|etl|warehouse|snowflake|bigquery)\b"),
    ("support-helpdesk",  r"\b(support|helpdesk|ticket|zendesk|intercom|freshdesk|customer service|crisp)\b"),
    ("industry-specific", r"\b(real ?estate|trade|coach|agency|hotel|restaurant|salon|clinic|booking|appointment|reservation)\b"),
]
JUNK = re.compile(r"^(my workflow|test|untitled|copy of|sample|example|demo)\b", re.I)

# Quotas per category (totals 250)
QUOTAS = {
    "lead-capture": 25, "email-automation": 30, "crm-sync": 22, "ecommerce": 25,
    "social-media": 25, "content-pipeline": 18, "ops-monitoring": 15,
    "finance-invoicing": 18, "ai-agents": 30, "data-sync": 20,
    "support-helpdesk": 12, "industry-specific": 10,
}
TOTAL_TARGET = sum(QUOTAS.values())  # 250

MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "8"))
MAX_SECONDS = int(os.environ.get("MAX_SECONDS", "1500"))  # 25 min default
DISABLE_BACKFILL = os.environ.get("DISABLE_BACKFILL", "0") == "1"


def slug(s, n=60):
    return re.sub(r"[^a-zA-Z0-9._-]", "_", (s or "untitled"))[:n]


def categorize(name, description=""):
    txt = f"{name} {description or ''}".lower()
    for cat, rx in CATS:
        if re.search(rx, txt, re.I):
            return cat
    return None


def http_json(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "ai-ops-architect/curator"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def fetch_list(page):
    return http_json(f"https://api.n8n.io/api/templates/workflows?page={page}&rows=50")


def fetch_full(wid):
    return http_json(f"https://api.n8n.io/api/templates/workflows/{wid}")


def opportunity_match(name, description, nodes):
    txt = f"{name} {description or ''}".lower()
    for opp_id, kws in [
        ("lead-form-to-crm",       ["form", "crm"]),
        ("stripe-payment-to-crm",  ["stripe", "payment"]),
        ("calendly-booking-flow",  ["calendly", "booking"]),
        ("inbox-triage-agent",     ["inbox", "triage"]),
        ("shopify-order-log",      ["shopify", "order"]),
        ("abandoned-cart",         ["cart", "abandon"]),
        ("daily-leads-digest",     ["digest", "daily"]),
        ("invoice-from-timesheet", ["invoice", "timesheet"]),
        ("blog-to-social",         ["blog", "social"]),
        ("support-triage-agent",   ["ticket", "support"]),
    ]:
        if all(k in txt for k in kws):
            return opp_id
    return None


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


def lint(wf_full, name, description):
    if JUNK.match(str(name or '')):
        return False, "junk-name"
    if not description or len(description.strip()) < 30:
        return False, "weak-description"
    nodes = (wf_full.get("workflow") or {}).get("nodes", [])
    if len(nodes) < 3:
        return False, "too-few-nodes"
    for n in nodes:
        if n.get("type") == "n8n-nodes-base.httpRequest" and n.get("typeVersion", 99) <= 1:
            return False, "deprecated-http-v1"
    return True, "ok"


def existing_ids():
    """Resume-friendly: collect IDs already saved on disk."""
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


def save_template(wid, name, description, full, source_label="n8n.io"):
    """Common save path used by both n8n.io path and czlonkowski backfill."""
    cat = categorize(name, description)
    if not cat:
        return False, "no-cat"
    counts = count_per_cat()
    if counts[cat] >= QUOTAS[cat]:
        return False, f"quota-full:{cat}"
    ok, reason = lint(full, name, description)
    if not ok:
        return False, reason
    wf_json = (full.get("workflow") or {})
    services = []
    for n in wf_json.get("nodes", []):
        t = (n.get("type") or "").replace("n8n-nodes-base.", "").replace("@n8n/n8n-nodes-langchain.", "lc.")
        if t and t not in services and t not in ("set", "if", "switch", "merge", "code", "function", "stickyNote"):
            services.append(t)
    nc = len(wf_json.get("nodes", []))
    difficulty = "auto-deploy" if nc <= 5 else ("5min-config" if nc <= 15 else "30min-custom")
    opp = opportunity_match(name, description, wf_json.get("nodes", []))
    meta = {
        "id": wid,
        "title": name,
        "description": description.strip(),
        "category": cat,
        "services_required": services[:8],
        "node_count": nc,
        "opportunity_pattern": opp,
        "difficulty": difficulty,
        "value": "varies — check workflow",
        "source_url": (
            f"https://n8n.io/workflows/{wid}" if source_label == "n8n.io"
            else "https://github.com/Zie619/n8n-workflows"
        ),
        "source": source_label,
        "license": "n8n.io community / MIT (see source repo)",
        "curated_at": "2026-05-05",
        "tags": [cat] + ([opp] if opp else []),
    }
    wf_with_note = add_sticky_note(wf_json, meta)
    cat_dir = ROOT / cat
    cat_dir.mkdir(exist_ok=True)
    base = f"{wid}__{slug(name)}"
    (cat_dir / f"{base}.json").write_text(json.dumps(wf_with_note, indent=2), encoding='utf-8')
    (cat_dir / f"{base}.meta.json").write_text(json.dumps(meta, indent=2), encoding='utf-8')
    return True, cat


def n8nio_pass(seen_ids, started, deadline):
    """Pass 1: scan n8n.io list pages, parallel-fetch detail for name-matching candidates."""
    page = 1
    saved_total = 0
    pool = cf.ThreadPoolExecutor(max_workers=MAX_WORKERS)
    while time.time() < deadline:
        try:
            data = fetch_list(page)
        except Exception as e:
            print(f"  list page {page} failed: {e}", flush=True)
            time.sleep(1)
            page += 1
            if page > 200:
                break
            continue
        rows = data.get("workflows") or []
        if not rows:
            break

        # Pre-filter on list endpoint: name-only categorize, skip junk, skip seen
        candidates = []
        for row in rows:
            wid = row.get("id")
            if not wid or wid in seen_ids:
                continue
            seen_ids.add(wid)
            name = row.get("name") or ""
            if JUNK.match(name):
                continue
            cat_guess = categorize(name)
            if not cat_guess:
                continue
            counts = count_per_cat()
            if counts[cat_guess] >= QUOTAS[cat_guess]:
                continue
            candidates.append((wid, name))

        if not candidates:
            page += 1
            continue

        # Parallel fetch_full
        def task(item):
            wid, name = item
            try:
                full = fetch_full(wid)
                desc = (full.get("workflow") or {}).get("description", "") or ""
                return (wid, name, desc, full)
            except Exception:
                return None

        for fut in cf.as_completed([pool.submit(task, c) for c in candidates]):
            res = fut.result()
            if not res:
                continue
            wid, name, desc, full = res
            ok, info = save_template(wid, name, desc, full, source_label="n8n.io")
            if ok:
                saved_total += 1
                if saved_total % 10 == 0:
                    counts = count_per_cat()
                    total = sum(counts.values())
                    print(f"  saved {saved_total} this run, total on disk {total}/{TOTAL_TARGET}", flush=True)
            if time.time() >= deadline:
                pool.shutdown(wait=False)
                return saved_total
        page += 1
        if page > 200:
            break
    pool.shutdown(wait=True)
    return saved_total


def czlonkowski_backfill(seen_ids, deadline):
    """Pass 2: Pull from Zie619/n8n-workflows (MIT) bundled JSONs to fill thin categories.

    The repo has 2,053 workflows under workflows/<category>/ in its main branch.
    We pull the GitHub trees API for cheap enumeration, then fetch raw JSON for each.
    """
    if DISABLE_BACKFILL:
        print("  backfill disabled by env", flush=True)
        return 0

    counts = count_per_cat()
    needed = {c: QUOTAS[c] - counts[c] for c in QUOTAS if counts[c] < QUOTAS[c]}
    if not needed:
        return 0
    print(f"  backfill needed: {needed}", flush=True)

    # Use the GitHub trees API for the workflows directory
    try:
        tree = http_json("https://api.github.com/repos/Zie619/n8n-workflows/git/trees/main?recursive=1")
    except Exception as e:
        print(f"  backfill: tree fetch failed: {e}", flush=True)
        return 0

    # Filter to .json under workflows/
    items = [t for t in tree.get("tree", []) if t.get("type") == "blob"
             and t.get("path", "").startswith("workflows/")
             and t.get("path", "").endswith(".json")]
    print(f"  backfill: {len(items)} candidate files in czlonkowski repo", flush=True)

    saved = 0
    pool = cf.ThreadPoolExecutor(max_workers=MAX_WORKERS)
    base_raw = "https://raw.githubusercontent.com/Zie619/n8n-workflows/main/"

    def task(it):
        path = it["path"]
        try:
            raw = urllib.request.urlopen(base_raw + path, timeout=15).read()
            wf = json.loads(raw)
        except Exception:
            return None
        # The czlonkowski repo wraps workflows directly as the n8n export object.
        # Adapt to our save shape: wrap in { "workflow": ... }.
        full = {"workflow": wf}
        # Generate a stable synthetic ID from the path
        wid_synth = int(hashlib.sha1(path.encode('utf-8')).hexdigest()[:8], 16) % (10**8) + 100_000_000  # 9-digit, > n8n.io ids, stable across processes
        name = str(wf.get('name') or path.rsplit('/', 1)[-1].replace('.json', ''))
        # Description from sticky note nodes (czlonkowski templates often have inline notes)
        desc = ""
        for n in wf.get("nodes", []):
            if n.get("type") == "n8n-nodes-base.stickyNote":
                c = (n.get("parameters") or {}).get("content", "")
                if c and len(c) > len(desc):
                    desc = c
        if len(desc.strip()) < 30:
            desc = f"n8n workflow: {name}. {len(wf.get('nodes', []))} nodes. Source: czlonkowski/n8n-workflows ({path})."
        return (wid_synth, name, desc, full, path)

    futures = []
    for it in items[:1500]:  # cap to save time
        if time.time() >= deadline:
            break
        futures.append(pool.submit(task, it))
        if len(futures) >= 200:  # process batches
            for fut in cf.as_completed(futures):
                res = fut.result()
                if not res:
                    continue
                wid, name, desc, full, path = res
                if wid in seen_ids:
                    continue
                seen_ids.add(wid)
                # Only save if this category still needs more
                cat = categorize(name, desc)
                if not cat:
                    continue
                cur_counts = count_per_cat()
                if cur_counts[cat] >= QUOTAS[cat]:
                    continue
                ok, info = save_template(wid, name, desc, full, source_label="czlonkowski")
                if ok:
                    saved += 1
                    if saved % 10 == 0:
                        cur = count_per_cat()
                        print(f"  backfill saved {saved}, total {sum(cur.values())}/{TOTAL_TARGET}", flush=True)
                if time.time() >= deadline:
                    pool.shutdown(wait=False)
                    return saved
            futures = []

    # Drain any remaining futures
    for fut in cf.as_completed(futures):
        res = fut.result()
        if not res:
            continue
        wid, name, desc, full, path = res
        if wid in seen_ids:
            continue
        seen_ids.add(wid)
        cat = categorize(name, desc)
        if not cat:
            continue
        cur_counts = count_per_cat()
        if cur_counts[cat] >= QUOTAS[cat]:
            continue
        ok, info = save_template(wid, name, desc, full, source_label="czlonkowski")
        if ok:
            saved += 1
        if time.time() >= deadline:
            break
    pool.shutdown(wait=True)
    return saved


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    seen_ids = existing_ids()
    print(f"Resume: {len(seen_ids)} templates already on disk", flush=True)
    started = time.time()
    deadline = started + MAX_SECONDS

    counts = count_per_cat()
    total = sum(counts.values())
    print(f"Starting at {total}/{TOTAL_TARGET}, per-cat: {counts}", flush=True)

    saved_n8nio = 0
    if total < TOTAL_TARGET:
        print("=== PASS 1: n8n.io list crawl (parallel fetch_full) ===", flush=True)
        saved_n8nio = n8nio_pass(seen_ids, started, deadline)
        print(f"  pass 1 saved {saved_n8nio}", flush=True)

    counts = count_per_cat()
    total = sum(counts.values())
    print(f"After pass 1: {total}/{TOTAL_TARGET}, per-cat: {counts}", flush=True)

    saved_back = 0
    if total < TOTAL_TARGET and time.time() < deadline:
        print("=== PASS 2: czlonkowski/n8n-workflows backfill ===", flush=True)
        saved_back = czlonkowski_backfill(seen_ids, deadline)
        print(f"  backfill saved {saved_back}", flush=True)

    counts = count_per_cat()
    total = sum(counts.values())
    elapsed = time.time() - started
    print(f"\nDONE in {elapsed:.0f}s: {total}/{TOTAL_TARGET} templates across "
          f"{sum(1 for n in counts.values() if n > 0)} categories", flush=True)
    for c, n in counts.items():
        marker = "OK " if n >= 0.8 * QUOTAS[c] else "LOW"
        print(f"  [{marker}] {c}: {n}/{QUOTAS[c]}")


if __name__ == "__main__":
    main()
