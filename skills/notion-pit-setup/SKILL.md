---
name: notion-pit-setup
description: "Connect the user's Notion workspace to Claude Code via a Personal Integration Token (PIT), so the resulting MCP entry is replicable to a headless agent server. Install is autonomous Playwright-driven: drive `notion.so/profile/integrations` in the Playwright MCP browser, detect login state and prompt sign-in only if needed, autonomously create a new internal integration (name + workspace + capabilities + submit), reveal and extract the PIT from the DOM via clipboard transit (the raw token NEVER appears in chat or tool-call returns), then register the MCP server entry via `claude mcp add --transport http --header`. The user's only manual moments are signing in to Notion (if not already), confirming the workspace + capabilities on the creation form, and choosing the page-access strategy (workspace teamspace connection if admin/Plus, otherwise per-page sharing). Use this skill when the user asks to set up Notion FOR THE AGENT SERVER, mentions needing Notion in a headless install, or explicitly asks for the PIT path. For laptop-only use, prefer the `notion-connector` skill (plugin OAuth path), this skill is the headless-friendly Model 1 alternative."
allowed-tools: mcp__plugin_playwright_playwright__*, mcp__playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - notion
    - workspace
    - mcp
    - pit
    - headless
    - server-friendly
  pairs-with:
    - skill: notion-connector
      reason: Sibling skill for the laptop-friendly Model 2 (plugin OAuth) path, this skill is the Model 1 alternative for headless servers
    - skill: xero-connector
      reason: Sibling Playwright-driven autonomous connector, admin-portal + DOM-extract pattern, clipboard-transit secret handling
    - skill: hubspot-connector
      reason: Sibling Playwright-driven autonomous connector, same Bearer-token-from-developer-portal pattern
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives Notion's integration portal
---

# Notion PIT setup (server-friendly, Model 1)

> **Install pattern:** Playwright-driven PIT creation, see [skills/CLAUDE.md](../CLAUDE.md) for the canonical Playwright autonomous-portal pattern (xero-connector).

## Overview

This skill connects a user's Notion workspace to Claude Code by creating a **Personal Integration Token (PIT)** in Notion's integration portal and registering the MCP server with the resulting bearer. It's the **Model 1** path: token lives inline in `~/.claude.json` `mcpServers.notion.headers.Authorization`, fully replicable to a headless agent server via the kit's connector framework.

**Use this skill when**:
- The user explicitly asks to set up Notion for an **agent server** or **headless** environment
- The agent stack at [`advanced-claude-workshop-kit`](https://github.com/selrai-company/advanced-claude-workshop-kit) needs Notion access on its EC2
- The user mentions wanting their Notion configuration to **sync from laptop to server** via `sync-connectors.sh`
- The user has already tried the plugin (Model 2) and hit headless-server OAuth limitations

**Use [`notion-connector`](../notion-connector/SKILL.md) instead when**:
- Laptop-only Notion usage
- User wants the plugin's curated skill set (`Notion:tasks:plan`, etc.)
- No server-side access needed

The two skills coexist intentionally, they target different deployment models. See the architectural finding in [`advanced-claude-workshop-kit/connectors/notion/README.md`](https://github.com/selrai-company/advanced-claude-workshop-kit/blob/main/connectors/notion/README.md) for the Model 1 / Model 2 distinction.

### What this skill writes

After Phase 1 completes, `~/.claude.json` will have a new `mcpServers.notion` entry shaped like:

```json
{
  "mcpServers": {
    "notion": {
      "type": "http",
      "url": "https://mcp.notion.com/mcp",
      "headers": {
        "Authorization": "Bearer ntn_<your-pit-here>",
        "Notion-Version": "2022-06-28"
      }
    }
  }
}
```

This shape matches the URL-substring-detect rule used by [`advanced-claude-workshop-kit/connectors/notion/detect.sh`](https://github.com/selrai-company/advanced-claude-workshop-kit/blob/main/connectors/notion/detect.sh), so `sync-connectors.sh --only notion` will pick it up and replicate it to the agent server.

---

## ⚠️ Safety gate, run this BEFORE Phase 1 Step 1

Before opening any browser, confirm the user understands the security trade-offs:

> "I'm about to create a Notion Personal Integration Token (PIT) on your behalf. A PIT is a long-lived API key tied to your Notion account, it doesn't expire (unlike the plugin's OAuth token, which auto-refreshes). It gives whatever pages you share with it full Read/Update/Insert access. You can revoke it any time at notion.so/profile/integrations. OK to proceed?"

If the user explicitly says no, do not proceed. If they say "use the plugin instead," hand off to `notion-connector`.

---

## Communication rules for Phase 1

- Speak to a **non-technical workshop participant**. Never expose Playwright tool names, DOM selectors, or shell snippets in chat output.
- Each step has a one-line user-facing message. If the step is silent (DOM read, env-var write), say nothing.
- The token is sensitive. The **raw `ntn_...` string MUST NEVER appear in chat output, tool-call returns, or anywhere visible to the user as printed text**. Use clipboard transit (see Step 4).
- Be patient with login waits. Notion's login can take 5+ seconds after consent; don't nag.

---

## Phase 0, Pre-flight (silent)

### 0.1, Resume check

Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`). If `mcpServers.notion` is already present AND its `headers.Authorization` is non-empty AND starts with `Bearer ntn_`, then the connector is already configured. Short-circuit:

> "Your Notion is already connected via a PIT. Want me to swap in a new one (rotation), or use the existing setup?"

If they say use existing: stop. If rotate: continue to Phase 1, but in Step 6, replace the existing entry rather than appending.

### 0.2, Tooling check (silent)

Verify the `claude` CLI is on PATH (`claude --version` returns a non-empty version), and Playwright MCP is available (the `mcp__plugin_playwright_playwright__browser_navigate` or `mcp__playwright__browser_navigate` tool is in the surface).

If `claude` is missing → fall back to the `first-run-setup` skill (it installs Claude Code).

If Playwright MCP is missing → install autonomously:
```bash
claude mcp add playwright --scope user -- npx @playwright/mcp@latest
```
Then ask the user to close and reopen the chat. Retry on resume.

---

## PHASE 1, Create PIT & register (autonomous via Playwright, 7 numbered steps)

### Step 1, Orient the user

One short message:

> "I'll set up a Notion connector you can use on a server. I'll open Notion's integration portal in a browser, create a new integration in your workspace, and grab the token. You'll need to (1) sign in to Notion if it asks, and (2) pick which pages or teamspace the integration can access. Two clicks at most. Ready?"

Wait for any affirmative ("yes", "go", "ok", "ready"). If they refuse or ask to use the plugin, hand off to `notion-connector`.

### Step 2, Open `notion.so/developers/connections` + handle login

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://www.notion.so/developers/connections" })
```

> **Real-world note (verified 2026-05-27)**: Notion renamed "Integrations" → "Connections" in early 2026. The URL `notion.so/profile/integrations` redirects to `notion.so/developers/connections`, but go directly to the new URL to avoid the redirect hop. The button text is now `"New connection"` (not "+ New integration"), the auth-method choice is `"Access token"` (not "Internal Integration"). Skill selectors below are based on the post-2026 UI.

Take a `mcp__plugin_playwright_playwright__browser_snapshot()`. Reason from the snapshot:

- **Already logged in** (page shows "Connections" heading, table of existing connections, "New connection" button at top-right) → proceed to Step 3.
- **Login screen** (heading "Log in to your Notion account", email input, Google/Apple/Microsoft/Passkey/SSO buttons) → tell the user, *once*: *"Please sign in to your Notion account in the browser window I just opened, I'll wait. Same Notion account that owns the workspace you want the agent to access."* Then `mcp__plugin_playwright_playwright__browser_wait_for` polling for the post-login signal, either the **New connection** button text via `browser_evaluate`, or the URL changing to include `notion.so/developers/connections`.
- **SSO redirect** (Google / Apple / SSO flow) → same as login: wait silently with a generous timeout (5 min).

After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

### Step 3, Create the connection autonomously

#### 3a, Click "New connection"

Locate the button via Playwright's accessibility tree (text-based: `getByRole('button', { name: 'New connection' })`). Click it. Notion opens a creation dialog (modal overlay, not a separate page).

#### 3b, Fill the form

The post-2026 form is **simpler** than the older Internal/Public + capabilities form. It has exactly 3 inputs:

- **Connection name**, textbox with placeholder `"<User's name>'s connection"`. Type your chosen name. Default to `"SelrAI Agent Stack"`; if the user already has many connections with similar names (e.g. multiple Claude bots), ask once: *"What should I name this connection?"*, accept any non-empty string.
- **Authentication method**, radio buttons: `"Access token"` (workspace-scoped static, what we want, usually pre-selected) vs `"OAuth"` (user-scoped, multi-workspace, Marketplace-eligible). Leave on `"Access token"`. Verify with `browser_evaluate` if the default ever changes.
- **Installable in**, workspace selector, already populated with the user's primary workspace. If the user has multiple workspaces AND the dropdown shows >1, ask once: *"Which Notion workspace should the agent access?"*, let them pick from the dropdown.

#### 3c, Submit

Click the **"Create connection"** button (text-based locator). It's disabled until name is non-empty. Wait for the redirect to the connection detail page, URL changes to `notion.so/developers/connections/<connection-id>` and heading shows the connection name.

> **Real-world note (verified 2026-05-27)**: Capabilities are now configured on the **connection detail page** (the next screen) via toggle-style buttons, NOT in the creation form. Notion ships defaults that work for most use cases (Read/Update/Insert content, Read user info excluding email). If you want to verify/adjust, click each capability button and check whether it shows a "selected" state via `browser_evaluate`. For most workshop participants, the defaults are fine, skip this micro-step unless a specific capability is needed.

### Step 4, Reveal and extract the access token via clipboard transit

On the connection detail page (`Configuration` tab, selected by default), the **Access token** is hidden behind a masked display by default. Three buttons sit next to it: `"Show or hide access token"`, `"Refresh access token"`, `"Copy"`.

#### 4a, Click "Show or hide access token"

Locate the button via text: `getByRole('button', { name: 'Show or hide access token' })`. Click it. The token now renders in a span/div (not an `<input>`).

#### 4b, Extract the token via JS eval

`browser_evaluate` extracts the PIT from the DOM and copies it to the OS clipboard. The function returns metadata only (length / found), the raw value **never enters the tool-call return**:

```javascript
() => {
  // Notion renders the revealed PIT in an input or code element next to a "Internal Integration Secret" label
  const candidates = [...document.querySelectorAll('input[type="text"], input[type="password"], code, [data-secret], [data-testid*="secret" i]')];
  for (const el of candidates) {
    const text = (el.value || el.textContent || '').trim();
    // Notion PIT format: ntn_<long-base64ish-string>, ~50 chars total
    const match = text.match(/\bntn_[A-Za-z0-9]{40,80}\b/);
    if (match) {
      navigator.clipboard.writeText(match[0]);
      return { found: true, length: match[0].length };
    }
  }
  return { found: false };
}
```

Read the clipboard from Bash into a shell-local env var, validate, **wipe clipboard immediately**:

```bash
case "$(uname -s 2>/dev/null)" in
  Darwin*)  export NOTION_PIT=$(pbpaste) ;;
  Linux*)
    if command -v wl-paste >/dev/null 2>&1; then
      export NOTION_PIT=$(wl-paste 2>/dev/null)
    else
      export NOTION_PIT=$(xclip -selection clipboard -o 2>/dev/null)
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*) export NOTION_PIT=$(powershell.exe -NoProfile -Command "Get-Clipboard" | tr -d '\r') ;;
  *) echo "UNKNOWN_PLATFORM" >&2; exit 1 ;;
esac
[[ "$NOTION_PIT" =~ ^ntn_[A-Za-z0-9]{40,}$ ]] || { echo "PIT format check failed"; exit 1; }
# Wipe clipboard NOW — token has reached the env var
case "$(uname -s 2>/dev/null)" in
  Darwin*)  printf "" | pbcopy ;;
  Linux*)
    if command -v wl-copy >/dev/null 2>&1; then
      printf "" | wl-copy
    else
      printf "" | xclip -selection clipboard 2>/dev/null
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*) powershell.exe -NoProfile -Command "Set-Clipboard -Value ''" ;;
esac
```

If extraction fails (the regex doesn't match anything in the DOM), fall back: take a snapshot and check whether the "Show" button was actually clicked, or whether the token format has changed. Last resort: *"I couldn't read the integration token automatically, could you copy it from the page and paste it to me? It starts with `ntn_`."* Do not paste it back into chat; treat the user's paste as immediate clipboard transit.

### Step 5, Page-access strategy (Content access tab)

After the connection is created, click the **"Content access"** tab (it's on the same connection detail page, second tab after "Configuration"). This is where you grant page-level scope.

> **Real-world note (verified 2026-05-27)**: Before any pages are shared, the integration sees NO content, `/v1/search` against the Notion API returns `{"object": "list", "results": []}` even though the token itself is valid. This is the integration working as designed (least-privilege), but is easy to mistake for a broken auth. Verify the token via `/v1/users/me` (which works without any page access) BEFORE worrying about search results being empty.

There are two paths depending on the user's plan and role:

The PIT only sees pages that have the integration explicitly added. There are two paths depending on the user's plan and role:

#### 5a, Workspace teamspace connection (preferred for admin / Plus+ users)

Check whether the user is a workspace admin on a Plus/Business/Enterprise plan. Visible signals:
- The "Settings & members" UI has a "Connections" or "Integrations" section in the workspace-level settings (not just personal settings)
- "Add to teamspace" or "Grant access to all current and future pages" controls are present

If available: navigate to `notion.so/<workspace>/settings/connections` (or similar), find the new "SelrAI Agent Stack" integration in the list, toggle it on for the teamspace(s) the user picks.

Ask once: *"Which teamspaces should the agent be able to read? Pick from: [list extracted via browser_evaluate]. Type 'all' for every teamspace."*

#### 5b, Per-page sharing (fallback, free tier and personal workspaces)

If 5a isn't available, fall back to per-page sharing. Tell the user:

> "Your plan doesn't support workspace-level integration sharing. You'll need to add the integration to each page or database you want the agent to access. The fastest path is: open the page → click ⋯ in the top-right → 'Add connections' → search 'SelrAI Agent Stack' → click it. Let me know when you've added it to the pages you care about, and I'll continue."

Wait for "done" or "ok" from the user. Don't try to automate per-page sharing, Notion's UI for this is per-page and would require iterating every page the user wants, which is brittle and tedious.

### Step 6, Register the MCP server entry

With the PIT captured in a shell-local env var, register the Notion MCP server entry. The token goes into the `headers.Authorization` of the registered server.

> **⚠️ SECURITY, Verified gotcha 2026-05-27**: `claude mcp add` (v2.1.x) **echoes its `--header` argument values verbatim to stdout** when it succeeds, including the bearer token. Without redirection, your token lands in terminal scrollback and (in agent contexts) the tool-call return. **Always redirect stdout AND stderr to `/dev/null`** for this call. The side effect, writing to `~/.claude.json`, is what we want; we don't need the stdout confirmation.

**Primary path**, `claude mcp add` with `--transport http --header`, output suppressed. Note the positional argument order: `<name>` then `<url>` come BEFORE the option flags (the CLI parser requires it this way; flags-first will error with `missing required argument 'commandOrUrl'`):

```bash
claude mcp add notion https://mcp.notion.com/mcp \
  --scope user \
  --transport http \
  --header "Authorization: Bearer $NOTION_PIT" \
  --header "Notion-Version: 2022-06-28" >/dev/null 2>&1
```

Verify the entry landed without re-reading stdout, read `~/.claude.json` directly:

```bash
python3 -c "
import json, os
d = json.load(open(os.path.expanduser('~/.claude.json')))
e = d.get('mcpServers', {}).get('notion', {})
assert e.get('url') == 'https://mcp.notion.com/mcp', f'wrong url: {e.get(\"url\")}'
assert (e.get('headers', {}).get('Authorization') or '').startswith('Bearer ntn_'), 'token missing or wrong shape'
print('mcpServers.notion entry verified ✓')
"
```

If verification fails, fall back to the Node merge path below.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output), write the entry directly to `~/.claude.json` via the Node merge pattern. This path **never echoes headers** and is the strictly safer choice if you don't trust the CLI's output handling on your version:

```bash
node -e '
  const fs = require("fs"), path = require("path"), home = require("os").homedir();
  const cfg = path.join(home, ".claude.json");
  const pit = process.env.NOTION_PIT;
  if (!pit || !pit.startsWith("ntn_")) { console.error("MISSING_OR_INVALID_PIT"); process.exit(1); }
  let j = {};
  if (fs.existsSync(cfg)) {
    try { j = JSON.parse(fs.readFileSync(cfg, "utf8")); }
    catch (e) {
      const backup = cfg + ".backup-" + Date.now();
      fs.copyFileSync(cfg, backup);
      console.error("CONFIG_BACKUP=" + backup);
      j = {};
    }
  }
  j.mcpServers = j.mcpServers || {};
  j.mcpServers.notion = {
    type: "http",
    url: "https://mcp.notion.com/mcp",
    headers: {
      Authorization: "Bearer " + pit,
      "Notion-Version": "2022-06-28",
    },
  };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

**Immediately unset the env var**:

```bash
unset NOTION_PIT
```

### Step 7, Close the browser + verify

Close Playwright:

```
mcp__plugin_playwright_playwright__browser_close()
```

Verify the registration:

```bash
claude mcp list 2>&1 | grep -E "^notion[[:space:]]"
```

Expect a line containing `notion` and either `Connected` or the URL. If the line is missing or shows `Failed`, run the troubleshooting block (below).

Optional smoke test (don't print the result to the user, just check exit code):

```bash
claude -p --output-format json "Search Notion for any recent page, just name 1 result" 2>&1 | head -50
```

If the response contains a real page title from the user's workspace, the connector is functional end-to-end.

### Step 8, Success message

One short message:

> "Notion is connected via a PIT, the token's already saved in your Claude Code config and the connector is ready to sync to a server via `sync-connectors.sh --only notion` (if you have the agent stack installed). Try asking me: 'Search my Notion for a recent meeting.'"

---

## PHASE 2, Using the connector

Once Phase 1 completes, the user interacts with Notion via the **raw MCP tool surface** that the Notion MCP server exposes:

| Tool | Purpose |
|---|---|
| `mcp__notion__notion-search` | Search workspace (across Notion + connected sources if the user has Notion AI) |
| `mcp__notion__notion-fetch` | Fetch full page or database contents by ID |
| `mcp__notion__notion-create-pages` | Create new pages |
| `mcp__notion__notion-update-page` | Update page properties or content |
| `mcp__notion__notion-create-database` | Create a new database |
| `mcp__notion__notion-update-data-source` | Update database schema |
| `mcp__notion__notion-create-comment` / `notion-get-comments` | Comment threads |
| `mcp__notion__notion-get-users` / `notion-get-teams` | Workspace member directory |
| `mcp__notion__notion-duplicate-page` / `notion-move-pages` | Page-level moves |

These are the SAME tools the official plugin exposes (the plugin and PIT path hit the same `https://mcp.notion.com/mcp` endpoint). The plugin additionally ships **curated `Notion:*` skills** (Notion:search, Notion:tasks:plan, etc.) on top of the raw tools, those skills are NOT available via the PIT path. If the user wants the curated skills, install the plugin via `notion-connector` instead (the two coexist; both can be active).

---

## Troubleshooting

### `claude mcp add` fails with "missing required argument 'commandOrUrl'"

You put the URL after the options. Reorder so `notion` (name) and `https://mcp.notion.com/mcp` (url) come immediately after `add`, then options follow:

```bash
# WRONG (will error):
claude mcp add notion --scope user --transport http ... https://mcp.notion.com/mcp

# RIGHT:
claude mcp add notion https://mcp.notion.com/mcp --scope user --transport http ...
```

### Token leaked into stdout / terminal scrollback

If you forgot to redirect `claude mcp add`'s output and the bearer is now in your terminal history, **rotate immediately**:

1. Navigate Playwright (or your own browser) to the connection detail page (`notion.so/developers/connections/<id>`)
2. Click the **"Refresh access token"** button
3. In the confirmation dialog, choose **"Revoke immediately"** (NOT the default 7-day grace), this invalidates the leaked token instantly
4. Click **"Refresh access token"** to confirm
5. Re-extract the new token (Step 4) and re-register (Step 6, this time **with** redirection)

The Step-6 verification block above proves the new token works without re-printing it.

### `claude mcp list` doesn't show `notion`

The `--transport http --header` syntax may have failed silently in older Claude Code versions. Re-run Step 6's **fallback** (Node merge), then `claude mcp list` again.

### Notion MCP returns 401 / "Unauthorized" on first call

The PIT was written but Notion isn't accepting it. Three causes:

1. **No pages shared with the integration**, Step 5 was skipped or the user said "ok" before actually adding pages. Go back to step 5b, share at least one page, retry.
2. **PIT was malformed when written**, verify the `Authorization` header in `~/.claude.json` starts with `Bearer ntn_` followed by 40+ alphanumeric chars. If truncated, re-run Step 4.
3. **Integration was created in the wrong workspace**, go to `notion.so/profile/integrations`, check the workspace label next to "SelrAI Agent Stack". If wrong, delete it and re-run from Step 3 picking the right workspace.

### `ntn_` regex doesn't match (Step 4b returns `{ found: false }`)

Notion may have rotated the PIT format. Take a fresh snapshot of the integration detail page and look at the revealed secret string. Adjust the regex in Step 4b if the prefix changed (e.g. to match a new `notn_` or `notion_` prefix). File an issue against this skill so the regex can be patched upstream.

### User has the plugin AND tries to run this skill

If `mcpServers.notion` already exists from a prior `claude mcp add` (PIT) OR the plugin is installed AND active (`claude plugin list | grep notion@`), explain the duplication:

> "Heads up, you already have Notion connected via the plugin. Adding a PIT-based entry on top means two paths to the same workspace, with different tools available depending on which path Claude Code routes through. Want me to: (a) leave the plugin alone and add the PIT entry too (both active), (b) replace the plugin with the PIT path only, or (c) abandon the PIT setup and stay on the plugin?"

Default to (a) if the user is mid-install of the agent stack, the agent server needs the PIT path, and removing the plugin would lose the curated `Notion:*` skills on the laptop.

### Workspace dropdown shows zero workspaces in Step 3b

The user is logged into a Notion account that has no workspaces yet. Pause and tell them: *"Looks like this Notion account doesn't have a workspace. Create one at notion.so first (it's free), then come back and I'll continue."*

---

## What this skill does NOT cover

- **OAuth-app developer flow**. That's the path for building your OWN Notion-using product. Out of scope for connecting Claude Code to Notion.
- **Multi-workspace setup**. The PIT is workspace-scoped. If the user needs access to multiple Notion workspaces simultaneously, they'd need multiple `mcpServers.notion-<workspace>` entries, run this skill once per workspace.
- **Token rotation on the server**. After Phase 1, the laptop's `~/.claude.json` has the new PIT. To propagate to an already-installed server, the user runs `sync-connectors.sh --only notion` (from `advanced-claude-workshop-kit`). This skill does not directly SSH anywhere.
- **Revoking the PIT**. Done at `notion.so/profile/integrations`, click the integration, click "Delete integration." This skill doesn't manage revocation.

---

## When this skill is NOT the right choice

- If the user only needs Notion **on their laptop** and explicitly mentions wanting Claude's curated skills (`Notion:tasks:plan`, `Notion:search`, etc.) → use `notion-connector` (plugin OAuth path)
- If the user is setting up a kit that lives entirely in claude.ai (web app) rather than Claude Code (CLI / app) → neither skill applies; the user authorizes via claude.ai's MCP marketplace UI
- If the user already has the plugin installed AND a working agent server with its own plugin install + OAuth completed → both paths are working in parallel, no action needed
