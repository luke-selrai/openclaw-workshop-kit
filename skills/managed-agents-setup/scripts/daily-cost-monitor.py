#!/usr/bin/env python3
"""
daily-cost-monitor.py — Schedule as a Routine via create-routine.sh (daily 8am Brisbane).
There is NO --install-cron flag; this script does not self-schedule.

Pulls yesterday's session COUNT, flags anomalies, pushes a summary to Telegram.
NOTE: it reports an ESTIMATED SESSION COUNT, not verified spend. It does NOT have a
verified per-day dollar figure, so the spend cap is reported for context only and does
NOT, by itself, trip a killswitch. A killswitch webhook fires ONLY when a real, verified
cost figure exceeds the cap AND KILLSWITCH_WEBHOOK_URL is set; otherwise the report says so.

Env:
  ANTHROPIC_API_KEY          required
  TELEGRAM_BOT_TOKEN         required
  TELEGRAM_CHAT_ID           required
  DAILY_SPEND_CAP_USD        default 20 (compared ONLY against a verified cost, never the count)
  KILLSWITCH_WEBHOOK_URL     optional; only used if a verified cost exceeds the cap
"""
import argparse
import json
import os
import sys
import urllib.request
from datetime import datetime, timedelta, timezone

API = "https://api.anthropic.com/v1"
BETA = "managed-agents-2026-04-01"


def req(method: str, path: str, body: dict | None = None) -> dict:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        print("[fatal] ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(2)
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(
        f"{API}{path}",
        method=method,
        data=data,
        headers={
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
            "anthropic-beta": BETA,
            "content-type": "application/json",
        },
    )
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())


def tg_send(msg: str):
    tok = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat = os.environ.get("TELEGRAM_CHAT_ID")
    if not tok or not chat:
        print("[warn] Telegram creds missing, skipping notification")
        return
    url = f"https://api.telegram.org/bot{tok}/sendMessage"
    body = json.dumps({"chat_id": chat, "text": msg, "parse_mode": "Markdown"}).encode()
    r = urllib.request.Request(url, data=body, headers={"content-type": "application/json"})
    try:
        urllib.request.urlopen(r, timeout=10)
    except Exception as e:
        print(f"[warn] Telegram send failed: {e}")


def main():
    # UTF-8 stdout so report glyphs don't crash on non-UTF-8 consoles (e.g. Windows cp1252).
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    # S5: reject unknown args so a documented `--install-cron` does NOT silently no-op.
    # NOTE: there is no real `--install-cron` flag — this monitor must be SCHEDULED via
    # create-routine.sh (a Routine), not self-install a cron. argparse exits 2 on unknown args.
    parser = argparse.ArgumentParser(
        description="Managed Agents daily cost/usage report (run as a Routine via create-routine.sh)."
    )
    parser.parse_args()

    cap = float(os.environ.get("DAILY_SPEND_CAP_USD", "20"))
    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")

    # List running sessions (catches stuck runaway sessions)
    running = req("GET", "/sessions?status=running")
    running_ids = [s["id"] for s in running.get("data", [])]

    # List recent sessions (best-proxy-for-spend: count sessions created yesterday)
    recent = req("GET", "/sessions?limit=100")
    yday_sessions = [
        s for s in recent.get("data", [])
        if s.get("created_at", "").startswith(yesterday)
    ]

    # S4: this is a SESSION COUNT, not a verified dollar figure. The flat sessions*0.15
    # math structurally UNDER-reports real spend (a session can cost far more than $0.15),
    # so it MUST NOT gate a $/day killswitch — that cap is meaningless against this number.
    # Real spend lives in a workspace usage / cost endpoint whose exact shape is UNVERIFIED
    # against this beta API, so we do not fabricate one here. If/when a real cost call is
    # wired in, guard it so its absence does not crash this report.
    sess_count = len(yday_sessions)

    # Optional real-cost hook: only used if a verified cost figure is available; absence is
    # not an error and never crashes. Left None until a confirmed endpoint exists.
    real_cost = None  # populate ONLY from a verified usage/cost response, never from a guess

    # Compose report
    lines = [
        f"*Managed Agents daily report*",
        f"Date: {yesterday}",
        f"Sessions created yesterday: {sess_count} (estimated session COUNT, NOT verified spend)",
        f"Currently running: {len(running_ids)}",
        f"Daily spend cap: ${cap:.2f} (no verified spend figure available — count is NOT a $ amount)",
    ]

    # S4 + S6: only act on a REAL verified cost. The flat session count never trips the cap.
    if real_cost is not None:
        lines.append(f"Verified spend: ${real_cost:.2f} (cap ${cap:.2f})")
        if real_cost > cap:
            webhook = os.environ.get("KILLSWITCH_WEBHOOK_URL")
            if webhook:
                try:
                    urllib.request.urlopen(urllib.request.Request(webhook, method="POST"), timeout=10)
                    lines.append("\n*OVER CAP* — killswitch webhook fired")
                except Exception as e:
                    # S6: webhook configured but POST failed — do NOT claim it stopped.
                    lines.append(f"\n*OVER CAP* — NOT stopped, killswitch webhook FAILED: {e}")
            else:
                # S6: over cap but no webhook configured — be honest that nothing was stopped.
                lines.append("\n*OVER CAP* — NOT stopped, no webhook configured (KILLSWITCH_WEBHOOK_URL unset)")

    if len(running_ids) > 5:
        lines.append(f"\nUnusual: {len(running_ids)} running sessions — investigate")

    if running_ids:
        lines.append("\nRunning session ids:")
        lines.extend([f"  `{sid}`" for sid in running_ids[:5]])

    msg = "\n".join(lines)
    print(msg)
    tg_send(msg)


if __name__ == "__main__":
    main()
