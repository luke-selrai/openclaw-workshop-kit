#!/usr/bin/env bash
# install-server-glue.sh — Install FastAPI webhook + cron + Telegram glue on the
# existing server-setup EC2 box. Replaces what a platform like n8n would do.
set -euo pipefail

SSH_KEY="${SSH_KEY:-$HOME/.ssh/clawd-key.pem}"
SSH_HOST="${SSH_HOST:-ubuntu@100.119.119.120}"
WEBHOOK_PORT="${WEBHOOK_PORT:-8080}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-$(python3 -c 'import secrets; print(secrets.token_hex(16))')}"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

SSH_CMD="ssh -i $SSH_KEY -o ConnectTimeout=5 $SSH_HOST"

echo "[glue] Checking server..."
if ! $SSH_CMD 'test -d ~/agents-cc' 2>/dev/null; then
  echo "[fatal] ~/agents-cc not found on server. Run server-setup first." >&2
  exit 3
fi

echo "[glue] Installing FastAPI + uvicorn..."
$SSH_CMD 'python3 -m pip install --user fastapi uvicorn httpx >/dev/null'

echo "[glue] Creating webhook-server directory..."
$SSH_CMD 'mkdir -p ~/agents-cc/webhook-server'

echo "[glue] Writing webhook app..."
$SSH_CMD 'cat > ~/agents-cc/webhook-server/app.py << '\''PY'\''
"""
FastAPI webhook receiver — inbound HTTP → Managed Agent session.
Routes:
  POST /hook/<name>    — fires a Managed Agent session with request body as message
  POST /fire/<trig_id> — fires a Claude Code routine (pass-through to /fire API)
  GET  /healthz        — liveness check

Each /hook/<name> is configured via ~/agents-cc/webhook-server/hooks.json
  {
    "inbound-lead": {"agent_id": "agent_...", "env_id": "env_...", "vault_id": "vlt_..."},
    ...
  }
"""
import hashlib
import hmac
import json
import os
import pathlib
import threading
import time
import httpx
from fastapi import FastAPI, Header, HTTPException, Request

API = "https://api.anthropic.com/v1"
BETA = "managed-agents-2026-04-01"
ROUTINE_BETA = "experimental-cc-routine-2026-04-01"
SECRET = os.environ.get("WEBHOOK_SECRET", "")
API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
ROUTINE_OAT = os.environ.get("ROUTINE_OAT_TOKEN", "")
HOOKS_FILE = pathlib.Path.home() / "agents-cc/webhook-server/hooks.json"

# NEW-4: open-relay hardening.
#   MAX_BODY_BYTES — reject oversized inbound bodies BEFORE forwarding upstream.
#   RATE_LIMIT_*   — per-(secret,path) request cap to stop a leaked secret from
#                    being used to hammer the paid Anthropic API.
MAX_BODY_BYTES = int(os.environ.get("WEBHOOK_MAX_BODY_BYTES", str(8 * 1024)))
RATE_LIMIT_MAX = int(os.environ.get("WEBHOOK_RATE_PER_MIN", "30"))
RATE_LIMIT_WINDOW = 60.0

app = FastAPI(title="Agent Glue")

# In-memory token bucket keyed on a hash of (secret, path). No external dep
# required; if slowapi is installed it could replace this, but the bucket is
# self-contained and survives a missing slowapi. State is per-process (the
# server binds 127.0.0.1 and runs single-instance under systemd).
_rate_lock = threading.Lock()
_rate_state: dict = {}  # key -> [tokens(float), last_refill_ts(float)]


def _rate_key(secret: str, path: str) -> str:
    # Hash so the raw secret is never used as a dict key / never logged.
    return hashlib.sha256(f"{secret}\x00{path}".encode("utf-8")).hexdigest()


def enforce_rate_limit(secret: str, path: str) -> None:
    key = _rate_key(secret, path)
    now = time.monotonic()
    refill_rate = RATE_LIMIT_MAX / RATE_LIMIT_WINDOW  # tokens per second
    with _rate_lock:
        tokens, last = _rate_state.get(key, (float(RATE_LIMIT_MAX), now))
        tokens = min(float(RATE_LIMIT_MAX), tokens + (now - last) * refill_rate)
        if tokens < 1.0:
            _rate_state[key] = (tokens, now)
            raise HTTPException(429, "rate limit exceeded")
        _rate_state[key] = (tokens - 1.0, now)


def check_secret(provided: str) -> None:
    # NEW-2: constant-time comparison defeats timing side-channels on the secret.
    if not SECRET:
        raise HTTPException(503, "WEBHOOK_SECRET not configured")
    if not hmac.compare_digest(provided or "", SECRET):
        raise HTTPException(401, "bad secret")


async def read_capped_body(request: Request) -> bytes:
    # NEW-4: reject bodies over the cap BEFORE forwarding. Trust Content-Length
    # when present for an early reject, but always re-check the actual bytes.
    cl = request.headers.get("content-length")
    if cl is not None:
        try:
            if int(cl) > MAX_BODY_BYTES:
                raise HTTPException(413, "request body too large")
        except ValueError:
            pass
    body = await request.body()
    if len(body) > MAX_BODY_BYTES:
        raise HTTPException(413, "request body too large")
    return body


def load_hooks():
    if HOOKS_FILE.exists():
        return json.loads(HOOKS_FILE.read_text())
    return {}


@app.get("/healthz")
def healthz():
    return {"ok": True, "hooks": list(load_hooks().keys())}


@app.post("/hook/{name}")
async def fire_hook(name: str, request: Request, x_webhook_secret: str = Header(default="")):
    check_secret(x_webhook_secret)  # NEW-2: constant-time, fail-closed
    enforce_rate_limit(x_webhook_secret, f"/hook/{name}")  # NEW-4
    hooks = load_hooks()
    if name not in hooks:
        raise HTTPException(404, f"hook {name} not configured")

    cfg = hooks[name]
    agent_id = cfg["agent_id"]
    env_id = cfg["env_id"]
    vault_id = cfg.get("vault_id")

    body = await read_capped_body(request)  # NEW-4: 8 KB cap before forwarding
    payload = body.decode("utf-8", errors="replace") or "{}"

    session_body = {
        "agent": agent_id,
        "environment_id": env_id,
        "title": f"glue-{name}",
    }
    if vault_id:
        session_body["vault_ids"] = [vault_id]

    headers = {
        "x-api-key": API_KEY,
        "anthropic-version": "2023-06-01",
        "anthropic-beta": BETA,
        "content-type": "application/json",
    }
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.post(f"{API}/sessions", headers=headers, json=session_body)
        r.raise_for_status()
        session = r.json()
        sid = session["id"]

        msg = {"events": [{"type": "user.message", "content": [{"type": "text", "text": payload}]}]}
        r2 = await c.post(f"{API}/sessions/{sid}/events", headers=headers, json=msg)
        r2.raise_for_status()

    return {"session_id": sid, "url": f"https://platform.claude.com/sessions/{sid}"}


@app.post("/fire/{trig_id}")
async def fire_routine(trig_id: str, request: Request, x_webhook_secret: str = Header(default="")):
    check_secret(x_webhook_secret)  # NEW-2: constant-time, fail-closed
    enforce_rate_limit(x_webhook_secret, f"/fire/{trig_id}")  # NEW-4
    if not ROUTINE_OAT:
        raise HTTPException(500, "ROUTINE_OAT_TOKEN not set")
    body = await read_capped_body(request)  # NEW-4: 8 KB cap before forwarding
    text = body.decode("utf-8", errors="replace") or "glue triggered"

    headers = {
        "Authorization": f"Bearer {ROUTINE_OAT}",
        "anthropic-version": "2023-06-01",
        "anthropic-beta": ROUTINE_BETA,
        "content-type": "application/json",
    }
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.post(f"{API}/claude_code/routines/{trig_id}/fire", headers=headers, json={"text": text})
        return {"status": r.status_code, "body": r.text}
PY'

echo "[glue] Seeding hooks.json (empty)..."
$SSH_CMD 'test -f ~/agents-cc/webhook-server/hooks.json || echo "{}" > ~/agents-cc/webhook-server/hooks.json'

echo "[glue] Injecting secret + API key into secrets.env..."
$SSH_CMD "sed -i '/^# --- Glue ---/,/^# --- End Glue ---/d' ~/agents-cc/shared/secrets.env 2>/dev/null || true"
# S7: build the secrets block locally and pipe it over stdin so the secret
# values never appear in a remote process arg list (ps/proc). systemd's
# EnvironmentFile parses plain KEY=VALUE, so no `export` prefix (S9).
secrets_block="$(printf '\n# --- Glue ---\nANTHROPIC_API_KEY=%s\nWEBHOOK_SECRET=%s\n# --- End Glue ---\n' "$ANTHROPIC_API_KEY" "$WEBHOOK_SECRET")"
printf '%s' "$secrets_block" | $SSH_CMD 'umask 077; cat >> ~/agents-cc/shared/secrets.env && chmod 600 ~/agents-cc/shared/secrets.env'

echo "[glue] Installing systemd user service..."
$SSH_CMD 'mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/webhook-server.service << '\''UNIT'\''
[Unit]
Description=Agent Glue Webhook Server
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/agents-cc/shared/secrets.env
WorkingDirectory=%h/agents-cc/webhook-server
ExecStart=/home/ubuntu/.local/bin/uvicorn app:app --host 127.0.0.1 --port '"$WEBHOOK_PORT"'
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT'

$SSH_CMD 'loginctl enable-linger ubuntu 2>/dev/null || true'
$SSH_CMD 'systemctl --user daemon-reload && systemctl --user enable webhook-server && systemctl --user restart webhook-server'

echo "[glue] Waiting for service..."
sleep 3
if $SSH_CMD "curl -sS -f http://localhost:$WEBHOOK_PORT/healthz" >/dev/null; then
  echo "[ok] Webhook server live on port $WEBHOOK_PORT"
else
  echo "[warn] Webhook server not responding — check: ssh $SSH_HOST 'journalctl --user -u webhook-server -n 50'"
fi

echo ""
echo "[ok] Server glue installed."
echo "    Webhook secret (save this): $WEBHOOK_SECRET"
echo "    Configure hooks: ssh $SSH_HOST 'vim ~/agents-cc/webhook-server/hooks.json'"
echo "    Fire a hook: curl -X POST http://<SERVER>:$WEBHOOK_PORT/hook/<name> -H 'X-Webhook-Secret: $WEBHOOK_SECRET' -d 'payload'"
echo ""
echo "[next] See references/server-glue-patterns.md for cron + Telegram patterns."
