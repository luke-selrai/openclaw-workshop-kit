#!/usr/bin/env bash
# audit.sh — Phase 1 + 2 of ai-ops-architect.
# Reads existing memory if available, asks the 8 intake questions interactively
# for anything not auto-extractable, writes ~/.claude/skills/ai-ops-architect/.state/audit-result.json.
#
# Usage:
#   bash audit.sh                    # interactive (direct-terminal use only — NOT for Claude)
#   bash audit.sh --ingest <file>    # non-interactive: write the intake answers from a JSON file
#                                    # (this is the path Claude uses — it collects the 8 answers
#                                    #  conversationally, then persists them here. No TTY needed.)
#   bash audit.sh --reset            # wipe and re-ask everything
#   bash audit.sh --update <field> <value>   # change one saved answer (value JSON-parsed if structured)
#   bash audit.sh --auto             # extract from memory, mark missing as TBC, no prompts (for testing)
#
# NOTE: the interactive mode below uses python input() and therefore REQUIRES a real TTY.
# When Claude drives this skill there is no TTY, so Claude MUST use --ingest (see SKILL.md).

set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STATE="$ROOT/.state"
OUT="$STATE/audit-result.json"
MEMORY="$HOME/.claude/projects/-Users-$(whoami)/memory/MEMORY.md"

mkdir -p "$STATE"
chmod 700 "$STATE"

MODE="${1:-interactive}"

if [[ "$MODE" == "--reset" ]]; then
  rm -f "$OUT"
  echo "Reset. Run again without --reset to re-intake."
  exit 0
fi

# --ingest <file>: non-interactive intake (the path Claude uses). Validate the file up front.
INGEST_FILE=""
if [[ "$MODE" == "--ingest" ]]; then
  INGEST_FILE="${2:-}"
  if [[ -z "$INGEST_FILE" || ! -f "$INGEST_FILE" ]]; then
    echo "ERROR: --ingest requires a path to a JSON file of intake answers (got: '${INGEST_FILE:-<none>}')" >&2
    echo "Write the 8 answers to a JSON file first, then: bash audit.sh --ingest /path/to/answers.json" >&2
    exit 2
  fi
fi

# --update <field> <value>: change one already-saved answer (non-interactive, Claude-friendly).
UPDATE_FIELD=""
UPDATE_VALUE=""
if [[ "$MODE" == "--update" ]]; then
  UPDATE_FIELD="${2:-}"
  UPDATE_VALUE="${3:-}"
  if [[ -z "$UPDATE_FIELD" ]]; then
    echo "ERROR: --update needs a field and a value: bash audit.sh --update <field> <value>" >&2
    exit 2
  fi
fi

# Export to Python env so it can read MODE/STATE/MEMORY/INGEST_FILE/UPDATE_*
export STATE MEMORY MODE INGEST_FILE UPDATE_FIELD UPDATE_VALUE

# Use Python for the heavy lifting — more readable than pure bash for JSON + prompts.
# PYTHONUTF8=1 (UTF-8 Mode) forces utf-8 for BOTH stdout and file I/O (read_text/write_text),
# so the ✓ / box / arrow glyphs don't crash, and reading memory/JSON never mojibakes on Windows cp1252.
PYTHONUTF8=1 python3 <<'PYEOF'
import json, os, re, sys
from pathlib import Path

state = Path(os.environ.get("STATE", os.path.expanduser("~/.claude/skills/ai-ops-architect/.state")))
out = state / "audit-result.json"
mem_path = Path(os.environ.get("MEMORY", os.path.expanduser(f"~/.claude/projects/-Users-{os.getlogin()}/memory/MEMORY.md")))
mode = os.environ.get("MODE", "interactive")

# Load existing audit if present (for --update flow); otherwise start fresh
audit = {}
if out.exists() and "--update" not in sys.argv:
    audit = json.loads(out.read_text())

# ── AUTO-EXTRACT FROM MEMORY ──────────────────────────────────────────
mem_text = ""
if mem_path.exists():
    mem_text = mem_path.read_text(errors="ignore")

def extract_industry(text):
    # Match common industry signals from memory
    patterns = [
        (r"\b(real[- ]estate|property)\b", "real-estate"),
        (r"\b(plumber|electrician|sparky|tradie|builder|HVAC)\b", "trades"),
        (r"\b(coach|coaching|mentor|consultant)\b", "coaches"),
        (r"\b(shopify|woocommerce|ecommerce|online store)\b", "ecommerce"),
        (r"\b(agency|agencies|marketing agency)\b", "agencies"),
        (r"\b(accountant|legal|allied health|chiropractor|physio)\b", "professional-services"),
        (r"\b(cafe|restaurant|salon|gym|hospitality)\b", "hospitality"),
        (r"\b(creator|youtuber|content business|podcast)\b", "creators"),
    ]
    for rx, label in patterns:
        if re.search(rx, text, re.I):
            return label
    return None

def extract_tools(text):
    found = {"crm": [], "email": [], "calendar": [], "payments": [], "accounting": [],
             "messaging": [], "social": [], "ecom": []}
    if re.search(r"\b(GHL|GoHighLevel|highlevel)\b", text, re.I): found["crm"].append("GoHighLevel")
    if re.search(r"\bHubSpot\b", text, re.I): found["crm"].append("HubSpot")
    if re.search(r"\bSalesforce\b", text, re.I): found["crm"].append("Salesforce")
    if re.search(r"\bAirtable\b", text, re.I): found["crm"].append("Airtable")
    if re.search(r"\bNotion\b", text, re.I): found["crm"].append("Notion")
    if re.search(r"\bGmail|Google Workspace\b", text, re.I): found["email"].append("Gmail")
    if re.search(r"\bOutlook|Microsoft 365\b", text, re.I): found["email"].append("Outlook")
    if re.search(r"\bGoogle Calendar\b", text, re.I): found["calendar"].append("Google")
    if re.search(r"\bCalendly\b", text, re.I): found["calendar"].append("Calendly")
    if re.search(r"\bStripe\b", text, re.I): found["payments"].append("Stripe")
    if re.search(r"\bSquare\b", text, re.I): found["payments"].append("Square")
    if re.search(r"\bXero\b", text, re.I): found["accounting"].append("Xero")
    if re.search(r"\bQuickBooks|MYOB\b", text, re.I): found["accounting"].append("QuickBooks")
    if re.search(r"\bSlack\b", text, re.I): found["messaging"].append("Slack")
    if re.search(r"\bTelegram\b", text, re.I): found["messaging"].append("Telegram")
    if re.search(r"\bManyChat|Instagram\b", text, re.I): found["social"].append("Instagram")
    if re.search(r"\bShopify\b", text, re.I): found["ecom"].append("Shopify")
    return found

# Extract what we can
if mem_text:
    industry = extract_industry(mem_text)
    if industry and not audit.get("industry"):
        audit["industry"] = industry
    tools = extract_tools(mem_text)
    if any(v for v in tools.values()) and not audit.get("tools"):
        audit["tools"] = tools
    # Tech comfort defaults to 5 if memory exists at all
    if not audit.get("tech_comfort"):
        audit["tech_comfort"] = 5
    audit.setdefault("_extracted_from_memory", True)

# ── INTERACTIVE PROMPTS ───────────────────────────────────────────────
def ask(prompt, default=None, options=None):
    suffix = f" [default: {default}]" if default else ""
    if options:
        for i, opt in enumerate(options, 1):
            print(f"  {i}. {opt}")
        ans = input(f"{prompt}{suffix} > ").strip()
        if not ans and default:
            return default
        if ans.isdigit() and 1 <= int(ans) <= len(options):
            return options[int(ans)-1]
        return ans
    ans = input(f"{prompt}{suffix} > ").strip()
    return ans or default

REQUIRED = ["industry", "team_size", "tools", "pains", "volume", "tech_comfort", "budget", "north_star"]

if mode == "--auto":
    # In auto mode, just write whatever we have and mark gaps as TBC
    for k in REQUIRED:
        audit.setdefault(k, "TBC")
elif mode == "--ingest":
    # Non-interactive intake (the Claude path). Read the answers JSON and merge it over
    # anything auto-extracted from memory — the user's explicit answers win.
    ingest_file = os.environ.get("INGEST_FILE", "")
    try:
        payload = json.loads(Path(ingest_file).read_text())
    except Exception as e:
        sys.stderr.write(f"ERROR: could not read/parse --ingest file {ingest_file!r}: {e}\n")
        sys.exit(2)
    if not isinstance(payload, dict):
        sys.stderr.write("ERROR: --ingest JSON must be an object of {field: answer}\n")
        sys.exit(2)
    for k, v in payload.items():
        if v not in (None, "", []):
            audit[k] = v
    # Any of the 8 the caller didn't supply (and memory couldn't fill) get marked TBC,
    # and we tell the caller which — so Claude can ask the user before recommending.
    missing = [k for k in REQUIRED if not audit.get(k)]
    for k in missing:
        audit[k] = "TBC"
    if missing:
        sys.stderr.write("NOTE: marked TBC (not supplied): " + ", ".join(missing) + "\n")
elif mode == "--update":
    # Change one already-saved field. Value comes from argv via env (Claude-friendly, no TTY).
    field = os.environ.get("UPDATE_FIELD", "")
    raw_val = os.environ.get("UPDATE_VALUE", "")
    if field not in REQUIRED:
        sys.stderr.write(f"ERROR: unknown field {field!r}. One of: {', '.join(REQUIRED)}\n")
        sys.exit(2)
    # Parse the value as JSON when it looks structured (numbers, tools/volume dicts); else keep the string.
    try:
        audit[field] = json.loads(raw_val)
    except Exception:
        audit[field] = raw_val
elif mode != "--update":
    # Interactive flow — ask only for fields we don't have
    print("\n═══════════════════════════════════════════════════════════")
    print("   AI Ops Architect — Business Intake")
    print("═══════════════════════════════════════════════════════════")
    if audit.get("_extracted_from_memory"):
        print("\nFound existing memory — pre-filled what I could. Just confirming the rest.\n")
    else:
        print("\n8 quick questions. Skip-to-default with Enter.\n")

    if not audit.get("industry"):
        audit["industry"] = ask("1. What's your industry?",
            options=["real-estate", "trades", "coaches", "ecommerce", "agencies",
                     "professional-services", "hospitality", "creators", "other"])

    if not audit.get("team_size"):
        audit["team_size"] = ask("2. Team size?", options=["solo", "2-5", "6-20", "20-100", "100+"])

    if not audit.get("tools"):
        print("3. Which tools do you use? (comma-separated names, or 'none')")
        crm_in = ask("   CRM (GHL/HubSpot/Notion/Airtable/...)", default="none")
        email_in = ask("   Email (Gmail/Outlook/...)", default="none")
        pay_in = ask("   Payments (Stripe/Square/...)", default="none")
        acc_in = ask("   Accounting (Xero/QuickBooks/...)", default="none")
        audit["tools"] = {
            "crm": [s.strip() for s in crm_in.split(",") if s.strip() and s.strip().lower() != "none"],
            "email": [s.strip() for s in email_in.split(",") if s.strip() and s.strip().lower() != "none"],
            "payments": [s.strip() for s in pay_in.split(",") if s.strip() and s.strip().lower() != "none"],
            "accounting": [s.strip() for s in acc_in.split(",") if s.strip() and s.strip().lower() != "none"],
        }

    if not audit.get("pains"):
        print("4. Top 3 time-wasters right now (one per line, blank to finish):")
        pains = []
        for i in range(3):
            p = ask(f"   pain {i+1}", default="")
            if not p: break
            pains.append(p)
        audit["pains"] = pains

    if not audit.get("volume"):
        leads = ask("5a. New leads per month?", default="50")
        txns = ask("5b. Transactions per month?", default="20")
        msgs = ask("5c. Internal messages/tasks per day?", default="20")
        audit["volume"] = {"leads_per_month": int(leads or 0), "transactions_per_month": int(txns or 0), "messages_per_day": int(msgs or 0)}

    if not audit.get("tech_comfort"):
        tc = ask("6. Technical comfort (1-5)?", default="3")
        audit["tech_comfort"] = int(tc or 3)

    if not audit.get("budget"):
        audit["budget"] = ask("7. Monthly tools budget?",
            options=["under-100", "100-500", "500-2000", "2000+"])

    if not audit.get("north_star"):
        audit["north_star"] = ask("8. ONE thing you'd fix in the next 90 days?", default="")

# Stamp the result
from datetime import datetime, timezone
audit["intake_completed_at"] = datetime.now(timezone.utc).isoformat()

# Strip private marker before writing
audit.pop("_extracted_from_memory", None)

state.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(audit, indent=2))
os.chmod(out, 0o600)
print(f"\n✓ Saved: {out}")
print(json.dumps(audit, indent=2))
PYEOF
