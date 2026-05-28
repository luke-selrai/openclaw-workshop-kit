---
name: twenty-connector
description: "Connect the user's Twenty CRM workspace to Claude Code so Claude can list and manage Companies, People, Opportunities, Notes, Tasks, custom objects, workflows, and the Skills/AI-Agent surface on their behalf — and so a Phase 3 build-your-own-CRM team can extend Twenty with custom objects and automations. Drives the entire setup autonomously through the user's Twenty workspace in a Playwright MCP browser: the user logs in to their Twenty workspace once, then Claude navigates to Settings → API & Webhooks, creates a long-lived API key, and writes it to ~/.claude/twenty-connector.env plus a credentials-only ~/.claude.json entry — no copy-paste. The only human moment is the user logging in once. Use this skill when the user says 'connect my Twenty', 'set up Twenty CRM', 'connect my CRM', 'I'm using Twenty', 'I want to build my own CRM', or asks about Twenty API key, Twenty webhooks, Twenty workspace, Twenty self-host, or the AGPL open-source CRM alternative to Salesforce."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: CRM & Integrations
  tags:
    - twenty
    - crm
    - sales-pipeline
    - self-hosted
    - companies
    - people
    - opportunities
    - workflows
    - rest-api
    - graphql
    - webhooks
  pairs-with:
    - skill: ghl-connector
      reason: Sibling CRM connector for the hosted-SaaS path (GoHighLevel). If the user wants a hosted CRM without owning infrastructure, route to ghl-connector instead. If they want to BUILD their own CRM, this is the right skill.
    - skill: medusa-connector
      reason: Structurally identical pattern (self-hosted Node + Postgres + Redis stack, user-supplied URL, Bearer API key). The same dispatch table for Step 10B platform menu applies. Reuse the env-file chain pattern.
    - skill: railway-deployment
      reason: Step 10B Path 1 (workshop-default self-host stack) dispatches here. Twenty's docker-compose can be lifted into a Railway service for one-click backend + Postgres + Redis provisioning.
    - skill: supabase-admin
      reason: For users who'd rather keep their Postgres on Supabase than on Railway, this is the alternative DB host. Twenty's Postgres requirements are vanilla (no extensions beyond pg).
    - skill: n8n-workflow-patterns
      reason: Twenty has its own internal workflow builder, but for cross-system automations (Twenty webhook → Slack / Gmail / Sheets), n8n still fits. Pair when the user wants to chain Twenty events outside the workspace.
---

# Twenty Connector

## Overview

This skill captures the credentials Claude needs to talk to the user's **Twenty CRM workspace** and persists them so any later Claude Code session — agent or interactive — can operate the workspace via REST or GraphQL.

One credential is captured:

- **API key** — `Authorization: Bearer <jwt>` on `/rest/*` and `/graphql` endpoints. Permission-inherits from the role of the user who created it (no per-object scopes — see Troubleshooting). This is what every Phase 3 build-your-own-CRM team will use to create custom objects, log activities, and read pipeline data.

> **Account support:** Twenty self-hosted (any version from v0.50+, recommended v1.0+) OR Twenty Cloud at `app.twenty.com`. The user must have a Twenty workspace with admin permissions on it. For self-host, the workspace lives at whatever URL the user provides (e.g. `https://crm.example.com` or `http://localhost:3000`).

> **No upstream MCP for Twenty** as of January 2026. Twenty's "Skills & Agents" feature is an *internal* AI surface running Claude *inside* Twenty's own product — not a public MCP server external Claude Code sessions can register. This SKILL captures credentials and documents the curl-based / GraphQL operation pattern; for deep introspection of the workspace schema, agents call Twenty's metadata API at runtime.

**The user does exactly TWO things across the entire setup. Everything else is autonomous.**

1. Tell me whether they want to **build their own CRM (self-host)**, **try Twenty Cloud (managed)**, or **already have a workspace** (point me at it).
2. Log in to their Twenty workspace in the Playwright browser when it opens (Step 3). One-time, their credentials, on screen they already know.

That's the complete list. The user does NOT click menus, do NOT generate the API key, do NOT copy or paste it. Claude drives every step from Step 3 onward.

---

## Communication rules

Identical contract to `medusa-connector` and `shopify-connector`. Summary:

- **You drive, not them.** Never ask the user to click menus, copy tokens, or paste anything.
- **Plain English only.** No jargon. Never say Bearer, Authorization header, REST, GraphQL, JWT, JSON, env var, claude.json, mcpServers, jq, AGPL, NestJS, Postgres, Redis, docker-compose. Say "the CRM key" or "your Twenty connection".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start, once when you need them ("please sign in"), once when you're done. No commentary in between.
- **Short responses.** Max 8 lines per message during install phase.
- **React warmly.** Good: "That worked — your Twenty CRM is now connected." Bad: "POST /rest/apiKeys 201 Created."
- **Never echo the API key.** Once written to disk, the key's job is done. Do not re-read the env file, do not include the key in any later tool-call return value the user can see. Same rule for the user's Twenty login password — Claude never sees it (it goes to the Twenty login form), and Claude must never ask for it.

---

## PHASE A — Bootstrap a new Twenty workspace (skip if user already has one)

Before anything else, ask the user exactly once:

> *"Do you already have a Twenty workspace — self-hosted or on twenty.com — or do we need to create one?"*

Branch:

- **Already have one** → ask for the URL (e.g. `https://crm.example.com` or `https://app.twenty.com`). Skip to **Phase 0**.
- **Want to create one** → continue with the rest of Phase A. Two sub-paths:
  - **A.1 — Twenty Cloud trial** (fastest, no infra; 30-day free trial, then $9/seat/mo Pro or $19/seat/mo Org)
  - **A.2 — Self-host via Docker Compose** (free, AGPL-3.0; ~10 min on a laptop, ~30 min on a server)

### Step A.1 — Twenty Cloud trial signup (managed path)

Open `https://app.twenty.com/sign-up` in Playwright. Walk the user through the signup form:

- Email + password OR "Continue with Google" (workshop-friendlier — fewer credentials)
- Workspace name (default: `<user-first-name>-workspace` if they don't have one in mind)
- Wait for the consent screen on Google OAuth → user clicks Allow
- Twenty lands on the default workspace home at `https://<workspace-slug>.twenty.com/`

Capture the workspace URL from the address bar. Set `TWENTY_BACKEND_URL` to that URL.

> **30-day trial reminder.** The Pro tier auto-renews to $9/seat/mo after the trial. If the user just wants to evaluate, write a reminder to `~/.claude/state/twenty-connector-trial.json` so future sessions can warn about the renewal date:
> ```bash
> mkdir -p "$HOME/.claude/state"
> cat > "$HOME/.claude/state/twenty-connector-trial.json" <<EOF
> {
>   "workspace_url": "$TWENTY_BACKEND_URL",
>   "trial_started_at": "$(date -u +%Y-%m-%d)",
>   "trial_renews_at": "$(date -u -d '+30 days' +%Y-%m-%d)",
>   "tier": "Pro",
>   "cancel_path": "Settings → Billing → Cancel Plan"
> }
> EOF
> ```

Continue to Phase 0 with `TWENTY_DEPLOY_TARGET="cloud"`.

### Step A.2 — Self-host via Docker Compose

Twenty's canonical self-host path uses the `twenty-docker` package's docker-compose.yml. Two sub-paths:

- **Local laptop dev**: clone the repo, `docker compose up`. Useful for trying it out; dies on laptop sleep.
- **Persistent server**: deploy to Railway / AWS / Azure / Render / Fly.io / DigitalOcean / VPS via Step 10B's platform dispatch.

For local dev (the quickest "see Twenty running"), drive this in Bash:

```bash
mkdir -p "$HOME/projects"
cd "$HOME/projects"
git clone https://github.com/twentyhq/twenty.git twenty
cd twenty/packages/twenty-docker
cp .env.example .env

# Twenty requires APP_SECRET and PG_DATABASE_PASSWORD set; generate them
APP_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | head -c 40)
PG_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)

# Write into .env (replace placeholder lines)
sed -i "s|APP_SECRET=.*|APP_SECRET=${APP_SECRET}|" .env
sed -i "s|PG_DATABASE_PASSWORD=.*|PG_DATABASE_PASSWORD=${PG_PASS}|" .env

# Start the stack (server, worker, postgres, redis)
docker compose up -d 2>&1 | tail -10

# Poll for the server to be ready (first start does migrations; takes 1-3 min)
for i in {1..120}; do
  if curl -sS -m 2 http://localhost:3000/healthz 2>/dev/null | grep -q ok; then
    break
  fi
  sleep 2
done
```

The first start runs database migrations + seeds the demo workspace. Once the healthcheck passes:

- Workspace URL: `http://localhost:3000`
- Sign up at `http://localhost:3000/sign-up` to create the workspace admin
- Tell the user *"Twenty is running locally. Open the browser I just launched and create your admin account — that's the only thing I can't automate (Twenty requires the password to be set by you, not generated by us)."*

Drive the signup form in Playwright. Capture the workspace URL after the admin is created.

Persist:

```bash
cat > "$HOME/.claude/state/twenty-connector-bootstrap.json" <<EOF
{
  "project_path": "$HOME/projects/twenty",
  "docker_compose_path": "$HOME/projects/twenty/packages/twenty-docker",
  "workspace_url": "$TWENTY_BACKEND_URL",
  "deploy_target": "self-host-local",
  "bootstrapped_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
chmod 600 "$HOME/.claude/state/twenty-connector-bootstrap.json"
```

> **The local docker-compose stack will die on laptop reboot.** To restart: `cd ~/projects/twenty/packages/twenty-docker && docker compose up -d`. To stop: `docker compose down`. To wipe and re-bootstrap from scratch: `docker compose down -v` (the `-v` removes volumes — data loss).

Continue to Phase 0 with `TWENTY_DEPLOY_TARGET="self-host"` and `TWENTY_DEPLOY_BACKEND_HOST="local"`. For a persistent server, the user re-runs the connector with `MEDUSA_DEPLOY_BACKEND_HOST` empty and lets Step 10B's platform menu handle it.

---

## PHASE 0 — Resume check

Read `~/.claude/twenty-connector.env` if it exists:

```bash
test -f "$HOME/.claude/twenty-connector.env" && grep -E '^TWENTY_(BACKEND_URL|API_KEY)=' "$HOME/.claude/twenty-connector.env"
```

- Both vars present and non-empty → run smoke test (Step 7's `/rest/companies?limit=1`). Report result, stop.
- One present, one missing → tell the user *"Looks like you started this earlier. Want me to pick up where you left off, or start completely fresh?"*
- File missing → run Phase 1.

---

## PHASE 1 — Capture the API key via Playwright

### Step 1 — Sanity-check the URL is reachable

```bash
HTTP=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" "$TWENTY_BACKEND_URL/healthz")
[[ "$HTTP" == "200" ]] || echo "BACKEND_NOT_REACHABLE"
```

- `200` → proceed.
- Connection refused / timeout → tell the user *"I can't reach your Twenty workspace from your computer. Is it running? If self-hosted, is the server up?"* Stop.

### Step 2 — Open the workspace in Playwright, the user signs in

Open `${TWENTY_BACKEND_URL}/sign-in` in Playwright. Tell the user:

> *"I've opened your Twenty workspace. Please sign in — I'll take it from there."*

Poll with `browser_snapshot` until the URL changes to a path inside the workspace (typically `/objects/company` or `/`). That's the success signal.

If the user is already signed in (persistent profile from a prior session — see `playwright_persistent_profile` memory), Playwright lands straight on the workspace home. No login step needed; proceed to Step 3.

### Step 3 — Navigate to API & Webhooks settings

Navigate to `${TWENTY_BACKEND_URL}/settings/developers`. The page lists existing API keys + webhooks.

Take `browser_snapshot` to verify the page loaded. Look for the **"Create key"** button (in the API Keys section, not Webhooks).

> **UI drift caveat.** Twenty's settings menu structure has changed across releases. If "API & Webhooks" isn't at `/settings/developers`, look for: Settings → Developers, Settings → API & Webhooks, Settings → Integrations → API. The page is unique by the presence of an "API Keys" table and a "Create key" button.

### Step 4 — Create the API key

Click **"Create key"**. In the modal:

- **Name:** `Claude Code agent (${date_iso})` — workshop-friendly default with the current date so the user can recognize it later
- **Expiration:** if a select appears, pick "Never" or the longest-available option (Twenty's default is no-expiry for API keys; if the user later wants rotation they revoke + recreate)

Click **Create**. The token reveals once.

Read the token via `browser_evaluate` on the input's `.value` property (NOT innerHTML, NOT textContent — the input may be masked but the underlying value is still readable):

```javascript
// Run this in Playwright via browser_evaluate
document.querySelector('input[name="apiKeyValue"]')?.value ||
document.querySelector('[data-testid="api-key-value"]')?.textContent?.trim() ||
'NOT_FOUND'
```

Twenty's API keys are JWTs — they start with `eyJ` and contain dots (`eyJhbGciOi...payload...signature`). Validate the shape:

```bash
echo "$TWENTY_API_KEY" | grep -qE '^eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' || echo "INVALID_JWT"
```

**Mask immediately**: treat `TWENTY_API_KEY` like `MEDUSA_ADMIN_SECRET_KEY` in medusa-connector. Do not print to chat. Do not include in any tool-call return value. The first thing Step 5 does is persist it.

### Step 5 — Persist the API key to disk

Two writes:

**Write 1: plain env file at `~/.claude/twenty-connector.env`** — source of truth for Bash recipes and agent invocations:

```bash
mkdir -p "$HOME/.claude"
umask 077
cat > "$HOME/.claude/twenty-connector.env" <<EOF
# Twenty Connector — credentials captured $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Source this file before calling /rest/* or /graphql endpoints.
# DO NOT commit. DO NOT share publicly.
TWENTY_BACKEND_URL="${TWENTY_BACKEND_URL}"
TWENTY_API_KEY="${TWENTY_API_KEY}"
TWENTY_DEPLOY_TARGET="${TWENTY_DEPLOY_TARGET:-unknown}"
EOF
chmod 600 "$HOME/.claude/twenty-connector.env"
```

**Write 2: credentials-only stub in `~/.claude.json`** under `mcpServers.twenty`. This is **not** a launchable MCP entry (Twenty has no upstream MCP) — it's a parking spot so future skills can detect the install:

```bash
cp -p "$HOME/.claude.json" "$HOME/.claude.json.backup-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null
```

Then merge into `mcpServers`:

```jsonc
{
  "mcpServers": {
    "twenty": {
      "type": "credentials-only",
      "env": {
        "TWENTY_BACKEND_URL": "<the URL>",
        "TWENTY_API_KEY": "<the JWT>"
      },
      "_note": "No launchable command — Twenty has no upstream MCP. Credentials duplicated in ~/.claude/twenty-connector.env. Source that file from Bash to operate the workspace."
    }
  }
}
```

Preserve every other `mcpServers` entry. Use `Write` (not `Edit`) so the merge happens via parsed-JSON → re-serialize.

Verify both files: re-read each, parse, confirm all vars are present and non-empty. If either fails, do not proceed to Step 6 — tell the user something went wrong with saving and offer to retry.

### Step 6 — Wipe local variables

```bash
unset TWENTY_API_KEY
```

The key now lives only on disk in mode-600 files. The shell context has no copy.

### Step 7 — Smoke-test the connection

```bash
source "$HOME/.claude/twenty-connector.env"

# Smoke 1: list companies (REST) — proves Bearer auth works
COMPANIES_HTTP=$(curl -sS -m 10 -o /tmp/twenty-smoke.json -w "%{http_code}" \
  -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/companies?limit=1")

# Smoke 2: list object metadata (REST metadata) — proves schema introspection works
META_HTTP=$(curl -sS -m 10 -o /tmp/twenty-meta-smoke.json -w "%{http_code}" \
  -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/metadata/objects?limit=5")

echo "rest=$COMPANIES_HTTP metadata=$META_HTTP"
```

- `rest=200 metadata=200` → fully connected. Tell the user: *"All set — your Twenty CRM is now connected. I can read and create Companies, People, Opportunities, and custom objects, and I can see your workspace's full schema."*
- `rest=401` → the API key didn't authenticate. Most common cause: the user revoked the key between Step 4 and Step 7. Re-run Phase 1 from Step 4.
- `rest=403` → permission issue. The API key inherits from the creator's role; if the user's role doesn't have CRUD on Companies, the key won't either. Tell them.
- Connection error → backend stopped responding. Suggest checking the server.

Wipe the smoke-test files:

```bash
rm -f /tmp/twenty-smoke.json /tmp/twenty-meta-smoke.json
unset TWENTY_API_KEY
```

---

## PHASE 2 — Operate the workspace

Source the env file, then call REST or GraphQL.

```bash
source "$HOME/.claude/twenty-connector.env"
```

### Common REST recipes

```bash
# List the 10 most recently created companies
curl -sS -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/companies?limit=10&orderBy=createdAt[DescNullsLast]" | jq

# Get a specific company by ID
curl -sS -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/companies/$COMPANY_ID" | jq

# Create a Company
curl -sS -X POST -H "Authorization: Bearer $TWENTY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"Acme Corp","domainName":{"primaryLinkUrl":"https://acme.example"},"employees":100}' \
  "$TWENTY_BACKEND_URL/rest/companies" | jq

# List People (contacts) attached to a Company
curl -sS -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/people?filter=company.id[eq]:$COMPANY_ID" | jq

# Create a Note attached to a Company
curl -sS -X POST -H "Authorization: Bearer $TWENTY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Demo call notes","body":"...","noteTargets":[{"companyId":"'"$COMPANY_ID"'"}]}' \
  "$TWENTY_BACKEND_URL/rest/notes" | jq
```

### Schema introspection via metadata API

```bash
# List every object type in the workspace (including custom)
curl -sS -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/metadata/objects" | jq '.data.objects[] | {name: .nameSingular, label: .labelSingular, isCustom: .isCustom}'

# List fields on a specific object
curl -sS -H "Authorization: Bearer $TWENTY_API_KEY" \
  "$TWENTY_BACKEND_URL/rest/metadata/objects/$OBJECT_ID/fields" | jq
```

### GraphQL (for complex joins or batched mutations)

```bash
# Single GraphQL request — example: companies with their people
curl -sS -X POST -H "Authorization: Bearer $TWENTY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { companies(first: 5) { edges { node { id name people { edges { node { id name { firstName } } } } } } } }"}' \
  "$TWENTY_BACKEND_URL/graphql" | jq
```

For any endpoint not in this list, the agent runs `curl -sS -H "Authorization: Bearer $TWENTY_API_KEY" "$TWENTY_BACKEND_URL/rest/metadata/objects/$OBJECT_NAME"` to introspect the schema at runtime — Twenty's metadata API is the canonical source of truth, more current than any frozen recipe sheet.

### Hand-off to a Phase 3 build-your-own-CRM team

The Phase 3 crm-twenty team (`prompts/08-crm-twenty-team.md` in `claude-workshop-v3-building`) expects these env vars. After this SKILL completes, that team's agents read the env file directly:

```bash
source ~/.claude/twenty-connector.env
# TWENTY_BACKEND_URL + TWENTY_API_KEY + TWENTY_DEPLOY_TARGET available
```

---

## PHASE 9 — Self-host or Twenty Cloud? (skip if Phase A already set the target)

If `TWENTY_DEPLOY_TARGET` is already set in the env file (Phase A set it), skip this phase. Otherwise ask exactly once:

> *"For your Twenty workspace's host, do you want to **self-host it** — you own the server, the database, and the deploy pipeline; no monthly Twenty fee; AGPL-3.0 open source — or use **Twenty Cloud** — Twenty Labs hosts it for you, managed deploy, $9-19/seat/mo, 30-day free trial?"*

Two short bullets if they ask for clarification:

- **Self-host** — pick this if you want full ownership, no per-seat fees, and don't mind running Docker Compose. Workflow credits are unlimited (no per-period metering like Cloud's 5-credit Pro tier). Setup is ~30 min on the workshop default stack (Railway).
- **Twenty Cloud** — pick this if you want zero infra and are OK with $9/seat/mo Pro (or $19/seat/mo Org for SSO + row-level perms). Workflow credits metered to 5/period on Pro.

Branch:

- **Twenty Cloud** → set `TWENTY_DEPLOY_TARGET="cloud"`. Already set up via Phase A.1 or by user's prior signup. Stop here.
- **Self-host** → continue to Phase 10B.

---

## PHASE 10B — Self-host platform menu (if Phase 9 answered "self-host")

Three pieces of infrastructure are needed for self-hosted Twenty: **backend host** (runs the Twenty server + worker), **Postgres** (Twenty's persistence), **Redis** (Twenty requires it for queues/cache). File storage is optional and only needed if users upload attachments (Twenty supports local-disk by default; S3-compatible for production).

### Path 1 — Workshop default stack (~20 min, all Playwright-drivable)

Same recommended stack as Medusa's Step 10B Path 1:

| Piece | Platform | Why | Skill to dispatch into |
|---|---|---|---|
| Backend + Postgres + Redis | **Railway** | Has a Twenty template via twenty-docker; one-click; ~3 min | [`railway-deployment`](../railway-deployment/SKILL.md) (Phase 3B — custom Git repo path; fork `twentyhq/twenty` and deploy) |
| File storage (optional) | **Cloudflare R2** | S3-compatible; free tier; only needed if attachments are in scope | [`cloudflare-deployment`](../cloudflare-deployment/SKILL.md) |

> *"My recommendation: Railway for the backend (database, Redis, and server all in one project), Cloudflare R2 for any file uploads (skip if you're not handling attachments). Want me to set those up now? You'll click 'Allow' a couple times in a browser window."*

After confirmation, dispatch into the platform skills. Each writes back to `~/.claude/twenty-connector.env`. Same chain pattern as `medusa-connector` — read `feedback_dispatch_architecture` memory for the rationale.

### Path 2 — BYO platforms (user already has cloud accounts)

| Backend host | Postgres | Redis | Skill to dispatch into |
|---|---|---|---|
| **Railway** (workshop default) | Railway Postgres | Railway Redis | [`railway-deployment`](../railway-deployment/SKILL.md) |
| **AWS** ECS Fargate / App Runner / EC2 | RDS Postgres / Aurora | ElastiCache | [`aws-connector`](../aws-connector/SKILL.md) |
| **Azure** Container Apps / AKS | Azure DB for Postgres | Azure Cache for Redis | [`azure-connector`](../azure-connector/SKILL.md) |
| **Render** | Render Postgres | Render Key-Value (Redis) | [`render-deployment`](../render-deployment/SKILL.md) |
| **Supabase + Render combo** | Supabase Postgres | Render Redis or Upstash | [`supabase-admin`](../supabase-admin/SKILL.md) + [`render-deployment`](../render-deployment/SKILL.md) |
| **Fly.io** | Fly Postgres | Fly Upstash Redis | (no kit skill — CLI-driven; `flyctl launch`) |
| **DigitalOcean** App Platform | Managed Postgres | Managed Redis | (no kit skill — defer to user) |
| **GCP** Cloud Run / GKE | Cloud SQL Postgres | Memorystore | (no kit skill — defer to user) |
| **Self-managed VPS** | self-managed | self-managed | (no kit skill — user owns the infra) |

Ask which one. Persist:

```bash
cat >> "$HOME/.claude/twenty-connector.env" <<EOF
TWENTY_DEPLOY_BACKEND_HOST="<pick>"
TWENTY_DEPLOY_STORAGE="<pick or 'none'>"
EOF
chmod 600 "$HOME/.claude/twenty-connector.env"
```

Then dispatch into the paired skill.

---

## Troubleshooting

### `rest=401` on the smoke test

The API key didn't authenticate. Three causes in likelihood order:

1. **The user revoked the key in Settings → API & Webhooks between Step 4 and Step 7.** Re-run Phase 1 from Step 4.
2. **The token captured from the DOM was truncated.** JWTs are long (~300+ chars); if `browser_evaluate` read from `innerHTML` instead of the input's `.value`, the field may have been truncated by CSS overflow. Re-capture from `.value` directly.
3. **The user is on a Twenty version that scopes API keys per role.** Check the role of the user who created the key in Settings → Members. If the role doesn't include CRUD on Companies, the smoke test fails with 401 even though the key is valid.

### `rest=403` on a specific endpoint

Twenty's API keys inherit from the creator's role (no per-key scope tickbox). If the smoke test passes on `/companies` but later fails on `/opportunities`, the creator's role lacks Opportunities permissions. Fix in Settings → Members → Roles, or have the workspace admin create a new key.

### "Create key" button is missing from Settings → API & Webhooks

The user's role doesn't have the `developer:manage` permission (or equivalent in this Twenty version). Tell the user *"Your Twenty account doesn't have permission to create API keys. Ask whoever runs your Twenty workspace to give you that permission, or sign in as the workspace admin."* Stop.

### `healthz` endpoint returns non-200

For self-host: check the backend pod/container is running (`docker compose ps` if local, or the platform's status dashboard). For Twenty Cloud: rare; would indicate Twenty Labs is having an outage.

### Token leaked to chat by accident

If the API key appears in any chat output, tool-call return, or screen recording before Step 5 completes:

1. **Immediately revoke.** Settings → API & Webhooks → click the leaked key → **Revoke**. The leaked key becomes invalid instantly.
2. Create a fresh key (re-run Step 4 with a new name like `Claude Code agent (rotated YYYY-MM-DD)`).
3. Update `~/.claude/twenty-connector.env` with the new value.
4. Save a memory entry noting how the leak happened so future sessions avoid the same path.

---

## What this SKILL does NOT cover

- **Twenty's internal Skills & Agents system.** That's Twenty's *own* AI feature — workspace admins define skills + agents that run inside Twenty's product, using Twenty's own Claude integration. It is NOT a public MCP an external Claude Code session can call. If you want to extend Twenty's *internal* AI with new skills, do that via Twenty's admin UI per their developer docs at https://docs.twenty.com/developers/extend/apps/logic/skills-and-agents — outside this connector's scope.
- **Migrating data into Twenty from another CRM.** Twenty has CSV import in the admin UI; for programmatic import, use the REST recipes above. Schema-mapping decisions (Salesforce fields → Twenty fields) are out of scope for this SKILL.
- **Custom-object schema design.** That's the Phase 3 build-your-own-CRM team's job — see `prompts/08-crm-twenty-team.md` in `claude-workshop-v3-building`. This SKILL captures credentials; the team designs the workspace.
- **Twenty's workflow / automation surface.** Twenty has a visual workflow builder with credit-metered execution. Workflows are designed in the workspace UI, not via this connector. The connector exposes the API so external automations (n8n, Zapier, etc.) can react to webhook events.

---

## See also

- [`../medusa-connector/SKILL.md`](../medusa-connector/SKILL.md) — sibling self-host-or-Cloud open-source platform connector; mirror reference for this SKILL's shape.
- [`../ghl-connector/SKILL.md`](../ghl-connector/SKILL.md) — hosted-CRM alternative (GoHighLevel). Route here if the user wants a CRM but does NOT want to build/own one.
- [`../railway-deployment/SKILL.md`](../railway-deployment/SKILL.md) — Step 10B Path 1 dispatch target for the workshop-default stack.
- [`../CLAUDE.md`](../CLAUDE.md) — Twenty is "first-party-stdio / out-of-pattern" classification, same bucket as `medusa-connector`, `wordpress-connector`, `shopify-connector`.
- [Twenty REST API reference](https://docs.twenty.com/developers/extend/api) — endpoint docs.
- [Twenty Skills & Agents docs](https://docs.twenty.com/developers/extend/apps/logic/skills-and-agents) — Twenty's INTERNAL AI system (not relevant for this connector; provided for context).
- [twentyhq/twenty on GitHub](https://github.com/twentyhq/twenty) — source repo, AGPL-3.0 + commercial-licensed enterprise files. 47K stars, actively maintained.
- [`packages/twenty-claude-skills/`](https://github.com/twentyhq/twenty/tree/main/packages/twenty-claude-skills) — Twenty's published Claude skills (1 skill: `twenty-record-presentation`). AGPL-3.0; mirroring into our kit is permitted with attribution. Not done in this version; would pair with a future MCP wrapper if we build one.
