#!/usr/bin/env bash
# telegram-commands-patch.sh — Deploys /ma, /killswitch, /cost commands to the server's Telegram bot.
# Builds on Luke's existing telegram-bot-v2.py (same allowlist, same auth).
set -euo pipefail

SSH_KEY="${SSH_KEY:-$HOME/.ssh/clawd-key.pem}"
SSH_HOST="${SSH_HOST:-ubuntu@100.119.119.120}"
SSH_CMD="ssh -o BatchMode=yes -i $SSH_KEY $SSH_HOST"

TMP_EXT=$(mktemp /tmp/ma-commands-ext.py.XXXXXX)
cat > "$TMP_EXT" <<'PY'
"""
ma_commands.py — Managed Agents commands for telegram-bot-v2.
Imported by bot.py. Adds /ma, /killswitch, /killall, /cost, /agents.
"""
import json
import os
import subprocess
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "managed-agents"
if not STATE_DIR.exists():
    STATE_DIR = Path.home() / "agents-cc" / "shared" / "managed-agents"


def handle_ma(parts, chat_id, send_message):
    if len(parts) < 2:
        send_message(chat_id, "Usage: /ma <preset> <message>")
        return
    preset = parts[0]
    msg = parts[1]
    agent_file = STATE_DIR / "agents" / f"{preset}.txt"
    env_file = STATE_DIR / "env-id.txt"
    if not agent_file.exists():
        send_message(chat_id, f"Preset '{preset}' not configured.")
        return
    if not env_file.exists():
        send_message(chat_id, "No environment configured.")
        return
    script = Path.home() / "agents-cc" / "shared" / "scripts" / "managed-agents.sh"
    if not script.exists():
        send_message(chat_id, "managed-agents.sh missing. Run link-to-server.sh.")
        return
    send_message(chat_id, f"Dispatching {preset}...")
    try:
        result = subprocess.run(
            [str(script), agent_file.read_text().strip(), env_file.read_text().strip(), msg],
            capture_output=True, text=True, timeout=30,
        )
        output = (result.stdout or result.stderr)[:3500]
        send_message(chat_id, f"*{preset}*\n```\n{output}\n```")
    except subprocess.TimeoutExpired:
        send_message(chat_id, "Session create timed out")


def _ma_headers():
    import os
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        return None
    return {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "managed-agents-2026-04-01",
    }


def handle_killswitch(chat_id, send_message):
    import urllib.request
    h = _ma_headers()
    if not h:
        send_message(chat_id, "ANTHROPIC_API_KEY not set on server.")
        return
    try:
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/sessions?status=running", headers=h)
        data = json.loads(urllib.request.urlopen(req, timeout=10).read())
        sessions = data.get("data", [])
        if not sessions:
            send_message(chat_id, "No running sessions.")
            return
        lines = [f"{len(sessions)} running session(s):"]
        for s in sessions[:10]:
            lines.append(f"  `{s['id']}` {s.get('title', '?')}")
        lines.append("\nSend /killall to interrupt every running session")
        send_message(chat_id, "\n".join(lines))
    except Exception as e:
        send_message(chat_id, f"Killswitch query failed: {e}")


def handle_killall(parts, chat_id, send_message):
    import urllib.request
    h = _ma_headers()
    if not h:
        send_message(chat_id, "ANTHROPIC_API_KEY not set.")
        return
    # M5: require an explicit kill target. Accept the first non-"---" positional
    # as a filter and only interrupt sessions matching it. Fail safe: with no
    # target we kill NOTHING rather than every running session.
    target = ""
    for p in (parts or []):
        if p and p != "---":
            target = p
            break
    if not target:
        send_message(
            chat_id,
            "Refusing to kill all sessions. Usage: /killall <id-or-title-substring>",
        )
        return
    try:
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/sessions?status=running", headers=h)
        sessions = json.loads(urllib.request.urlopen(req, timeout=10).read()).get("data", [])
        # Filter to sessions whose id or title contains the target substring.
        # UNVERIFIED API shape: if neither field is present a session simply does
        # not match, so the filter fails safe (matches nothing).
        matched = [
            s for s in sessions
            if target in str(s.get("id", "")) or target in str(s.get("title", ""))
        ]
        if not matched:
            send_message(chat_id, f"No running session matches '{target}'.")
            return
        killed = 0
        for s in matched:
            body = json.dumps({"events": [{"type": "user.interrupt"}]}).encode()
            ir = urllib.request.Request(
                f"https://api.anthropic.com/v1/sessions/{s['id']}/events",
                data=body, headers={**h, "content-type": "application/json"},
            )
            try:
                urllib.request.urlopen(ir, timeout=5)
                killed += 1
            except Exception:
                pass
        send_message(chat_id, f"Killed {killed}/{len(matched)} session(s) matching '{target}'.")
    except Exception as e:
        send_message(chat_id, f"Killall failed: {e}")


def handle_cost(chat_id, send_message):
    import urllib.request
    from datetime import datetime, timezone
    h = _ma_headers()
    if not h:
        send_message(chat_id, "ANTHROPIC_API_KEY not set.")
        return
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        req = urllib.request.Request("https://api.anthropic.com/v1/sessions?limit=100", headers=h)
        data = json.loads(urllib.request.urlopen(req, timeout=10).read())
        todays = [s for s in data.get("data", []) if s.get("created_at", "").startswith(today)]
        running = [s for s in data.get("data", []) if s.get("status") == "running"]
        est = len(todays) * 0.15
        send_message(chat_id, f"*Today:* {today}\nSessions: {len(todays)}\nRunning: {len(running)}\nEst spend: ${est:.2f}")
    except Exception as e:
        send_message(chat_id, f"Cost query failed: {e}")


def handle_agents(chat_id, send_message):
    agents_dir = STATE_DIR / "agents"
    if not agents_dir.exists():
        send_message(chat_id, "No agents configured.")
        return
    entries = []
    for f in sorted(agents_dir.glob("*.txt")):
        entries.append(f"  {f.stem} -> `{f.read_text().strip()}`")
    env_id = (STATE_DIR / "env-id.txt").read_text().strip() if (STATE_DIR / "env-id.txt").exists() else "none"
    send_message(chat_id, f"*Agents* (env={env_id}):\n" + "\n".join(entries))


def dispatch(cmd, parts, chat_id, send_message):
    if cmd == "ma":
        handle_ma(parts, chat_id, send_message); return True
    if cmd == "killswitch":
        handle_killswitch(chat_id, send_message); return True
    if cmd == "killall":
        handle_killall(parts, chat_id, send_message); return True
    if cmd == "cost":
        handle_cost(chat_id, send_message); return True
    if cmd == "agents":
        handle_agents(chat_id, send_message); return True
    return False
PY

echo "[telegram-patch] Copying extension to server..."
scp -o BatchMode=yes -i "$SSH_KEY" "$TMP_EXT" "$SSH_HOST:/home/ubuntu/agents-cc/shared/ma_commands.py"
rm -f "$TMP_EXT"

echo "[telegram-patch] Locating bot.py and patching..."
$SSH_CMD 'BOT_PY=$(find ~/agents-cc ~/archive 2>/dev/null -name "telegram-bot-v2.py" -o -name "bot.py" | head -1)
if [ -z "$BOT_PY" ]; then
  echo "[fatal] No telegram bot python file found"
  exit 1
fi
echo "[patch] Target: $BOT_PY"
cp "$BOT_PY" "$BOT_PY.bak-$(date +%s)"

python3 <<PY
import pathlib, re, sys
p = pathlib.Path("$BOT_PY")
src = p.read_text()
if "ma_commands" in src:
    print("[skip] Already patched")
    sys.exit(0)

lines = src.splitlines()
# Find end of imports
import_end = 0
for i, line in enumerate(lines):
    if line.startswith("import ") or line.startswith("from "):
        import_end = i + 1
inject = [
    "",
    "# Managed Agents commands extension",
    "import sys",
    "sys.path.insert(0, \"/home/ubuntu/agents-cc/shared\")",
    "try:",
    "    from ma_commands import dispatch as ma_dispatch",
    "except ImportError:",
    "    ma_dispatch = lambda *a, **kw: False",
    "",
]
lines[import_end:import_end] = inject
src = "\n".join(lines)

# M14: anchor the dispatch hook AFTER cmd/parts are defined, not at the def line
# (the hook references both). Require a real match — if we cannot find where the
# handler builds cmd from parts, refuse to write a broken file and bail non-zero.
m = re.search(
    r"^([ \t]+)cmd\s*=\s*parts\[0\][^\n]*\n",
    src, re.MULTILINE,
)
if not m:
    print("[fatal] Could not locate 'cmd = parts[0]' assignment; not patching.", file=sys.stderr)
    sys.exit(1)
indent = m.group(1)
inject_call = (
    f"{indent}if ma_dispatch(cmd, parts[1:] if len(parts) > 1 else [], chat_id, send_message):\n"
    f"{indent}    return\n"
)
src = src[:m.end()] + inject_call + src[m.end():]
p.write_text(src)
print("[patched]", p)
PY
PATCH_RC=$?
if [ "$PATCH_RC" -ne 0 ]; then
  echo "[fatal] Patch step failed (rc=$PATCH_RC); not restarting." >&2
  exit "$PATCH_RC"
fi

# M14: py_compile the patched file before any restart — a syntax-broken bot.py
# must abort here rather than take the live bot down.
if ! python3 -m py_compile "$BOT_PY"; then
  echo "[fatal] Patched $BOT_PY does not compile; restoring is on you via the .bak. Not restarting." >&2
  exit 1
fi

systemctl --user restart telegram-bot-v2
sleep 3
systemctl --user status telegram-bot-v2 --no-pager | head -5'

echo ""
echo "[done] Test in your Telegram chat:"
echo "  /agents   /cost   /killswitch   /killall   /ma <preset> <message>"
