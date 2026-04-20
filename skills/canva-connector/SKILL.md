---
name: canva-connector
description: "Connect and operate Canva via the official first-party Canva MCP server (https://mcp.canva.com/mcp). Use this skill when the user asks to set up Canva, connect their account, search or export designs, generate AI designs, add or read comments, manage folders, resize designs, or edit design content. On first use run Phase 1 to configure the MCP server and authenticate before attempting tool calls."
allowed-tools: mcp__canva__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - canva
    - design
    - export
    - presentations
    - ai-design
    - brand-templates
    - mcp
  pairs-with:
    - skill: airtable-connector
      reason: Pair structured data (Airtable) with Canva designs — generate one design per row
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector — identical install pattern
    - skill: ad-creative
      reason: Generate ad copy variations then render them as Canva designs
    - skill: social-content
      reason: Turn social posts into Canva-ready visuals and resize for each platform
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Canva auth or API errors
---

# Canva Connector

## Overview

This skill lets you read and update a user's Canva account on their behalf using the **official first-party Canva MCP server** hosted at `https://mcp.canva.com/mcp`. It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You wire the hosted MCP server into Claude Code and walk the user through a one-click browser sign-in to Canva. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", or any file paths. They should feel like they are having a conversation, and at the end their Canva is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__canva__*` native tools to read and update Canva data.

**Which phase to run** — Before any tool call, check whether the Canva MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.canva` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **Canva API keys or personal access tokens** — Canva MCP **requires OAuth for every user on first connect**. Bearer-token / API-key access to the MCP server is not supported. Do not ask the user for an API key.
- **A self-hosted or community Canva MCP server** — Canva publishes the hosted endpoint at `https://mcp.canva.com/mcp` as the official first-party deployment. Always use the hosted URL.
- **Direct Canva REST API calls (Canva Connect API)** — all reads and writes go through the MCP server, not direct HTTP calls.
- **`.env` files** — nothing is stored in a local dotenv; the MCP config lives in `~/.claude.json`.

### How auth works under the hood

The hosted Canva MCP server uses OAuth 2.0 with PKCE and dynamic client registration. On first use, Claude Code opens a browser window, the user signs in to Canva, and the session is stored by Claude Code. No credentials are ever pasted. There is no fallback API-key path — if the browser sign-in fails (e.g. on a workspace where the admin restricts third-party app installs), the only option is to have the Canva workspace admin allowlist the Canva MCP app first.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, URL, JSON, REST, or environment variable. If you must refer to a technical thing, name it plainly: "a small connection setting on your computer", "your Canva sign-in page".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Canva is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase wires the hosted Canva MCP server into Claude Code and walks the user through the one-time browser sign-in. You do every technical action; the user only signs in to Canva once in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Canva, I am going to set up the connection on your computer, then ask you to sign in to Canva once in your browser. The whole thing takes about a minute. There is no key to copy — Canva handles the sign-in for us. Ready?"

### Step 2 — Save the connection

Once the user says they're ready, silently add or update the canva MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The Canva MCP server is **hosted only** — there is no local transport option and no API-key option. Use this exact entry:

```json
{
  "mcpServers": {
    "canva": {
      "url": "https://mcp.canva.com/mcp"
    }
  }
}
```

Merge into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the canva entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Tell the user: "I have saved the connection. Now please close Claude Code completely and reopen it once, so it picks up the new setting. Let me know when you're back."

### Step 3 — Walk the user through the browser sign-in

The first time the Canva MCP server is contacted after the restart, Claude Code will open a browser window asking the user to sign in to Canva and approve the connection. You cannot do this for them — Canva requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "You should now be back in a fresh Claude Code session. Say to me: **'connect to my Canva now'**. A browser window will pop up asking you to sign in to Canva. Tell me when you see it."

2. When they see the sign-in window → "Sign in with your Canva email and password, then click **Allow** on the permission screen. Let me know when you're back here."
   - If the user already signed in to Canva recently → "You may not need to type a password — Canva might just show the **Allow** screen straight away. That's fine, just click **Allow**."
   - If the user can't see the browser window → "Check behind your other windows — sometimes it opens in the background. If you really can't find it, tell me and I'll try again."

Common mistakes to look out for (and correct by re-asking):

- The user closes the browser window without clicking **Allow** → "No problem — let me try once more. I'll trigger the sign-in again, just click **Allow** when it pops up this time."
- The user signs in to the wrong Canva account (e.g. personal vs work) → "I think you might have signed in with a different email than you meant to. In your browser, sign out of Canva, then tell me 'try again' and I'll re-trigger the sign-in."
- The user reports a "this site can't be reached" page → "Sounds like a network hiccup. Is your internet working? Once you confirm, I'll try once more."
- The user reports their admin blocked the sign-in or they see an "administrator approval required" screen → see the Enterprise note at the bottom of this guide. There is no API-key fallback — their Canva workspace admin must allowlist the Canva MCP app.

When the user confirms they clicked **Allow**, immediately move to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to Canva correctly."

Call `mcp__canva__search-designs` with an empty query. If it returns a result (including an empty list — that's fine), the connection works. Move to the success message, including the live count.

If the verification tool returns an error:

- `401 Unauthorized` / `Not authenticated` → "The sign-in didn't quite stick. Let me trigger it once more for you." Re-do Step 3.
- `403 Forbidden` → "Your connection is working, but your Canva user doesn't have permission for that action. An admin on your Canva workspace may need to adjust your access."
- `429 Rate limited` → "Canva is asking us to slow down for a moment — let me try again in a few seconds." Wait 10s, retry.
- Tools not available in current session → "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my Canva connection' and I will verify it."
- Admin approval required → see the Enterprise note at the bottom. The user's Canva admin needs to allowlist the Canva MCP app before the sign-in will succeed.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-do the sign-in (Step 3).

### Step 5 — Success message

Tell the user, in one short message, and include the live design count from `search-designs` so the success feels real:

> "All done! Your Canva is now connected — I can see **N designs**. You can ask me things like 'show me my latest designs', 'export my pitch deck as a PDF', 'generate a new social post about X', or 'add a comment to that design'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__canva__*` MCP tools below to answer questions and make changes in Canva. The hosted Canva MCP server provides **30 first-party tools** across 10 categories covering designs, assets, folders, comments, exports, AI generation, and a transactional editing flow.

### Tool names use hyphens

Canva's tool names use hyphens, not underscores — e.g. `mcp__canva__search-designs`, `mcp__canva__export-design`. If a tool name does not resolve, list available tools with the `mcp__canva__` prefix to discover the current naming.

### Plan gating — know before you call

Some tools are gated by the user's Canva plan. Calling a gated tool on a lower plan returns `403 Forbidden` or a `plan_required` error. Check before calling:

| Plan | Tools available |
|---|---|
| **Free / all plans** | 25 tools — designs, comments, folders, exports, imports, assets, AI generation, editing transactions |
| **Pro and above** | Adds `resize-design` |
| **Enterprise only** | Adds `autofill-design`, `get-brand-template-dataset`, `search-brand-templates`, `list-brand-kits` |

**Export quality is also plan-gated.** `export-design` works on all plans, but Free plans only get standard-quality exports; Pro and above get lossless PNG, transparent backgrounds, and premium element export. If a design on a Free plan contains premium elements, the export may fail with `license_required` — tell the user they need a paid plan for that specific design.

### Tool Reference

#### Designs — read (no confirmation needed)

| Tool | Rate | Description |
|---|---|---|
| `search-designs` | 100/min | Find designs by name or keyword |
| `get-design` | 100/min | Retrieve a single design's metadata |
| `get-design-pages` | 100/min | Retrieve the page structure of a design |
| `get-design-content` | 100/min | Retrieve text and element content from a design |
| `get-presenter-notes` | 100/min | Retrieve speaker notes from a presentation |
| `get-design-export-formats` | 100/min | Check which formats a design can be exported as |

#### Designs — generate (destructive — always confirm)

| Tool | Rate | Description |
|---|---|---|
| `generate-design` | 20/min | AI-generate a new design from a prompt — **confirm first** |
| `generate-design-structured` | 20/min | AI-generate a design with a specified structure — **confirm first** |
| `create-design-from-candidate` | 20/min | Create a design from a previously generated AI candidate — **confirm first** |
| `request-outline-review` | 20/min | Request a review pass on an AI-generated outline |

#### Design imports & exports

| Tool | Rate | Plan | Description |
|---|---|---|---|
| `import-design-from-url` | 20/min | All plans | Import an external design from a URL — **confirm first** |
| `export-design` | 20/min | All plans* | Export a design as image or PDF — **confirm first**. Free = standard quality; Pro+ = lossless PNG, transparent bg, premium elements |

#### Assets

| Tool | Rate | Description |
|---|---|---|
| `upload-asset-from-url` | 30/min | Upload an image or video asset from a URL — **confirm first** |
| `get-assets` | 100/min | List or search assets in the user's library |

#### Comments

| Tool | Rate | Description |
|---|---|---|
| `list-comments` | 100/min | Read comment threads on a design |
| `list-replies` | 100/min | Read replies within a comment thread |
| `comment-on-design` | 100/min | Add a new comment to a design — **confirm first** |
| `reply-to-comment` | 20/min | Reply to an existing comment — **confirm first** |

#### Folders

| Tool | Rate | Description |
|---|---|---|
| `search-folders` | 100/min | Find folders by name |
| `list-folder-items` | 100/min | List the contents of a folder |
| `create-folder` | 20/min | Create a new folder — **confirm first** |
| `move-item-to-folder` | 100/min | Move a design or asset into a folder — **confirm first** |

#### Resize (Pro and above only)

| Tool | Rate | Description |
|---|---|---|
| `resize-design` | 20/min | Resize a design to new dimensions — **confirm first**. Returns `403` / `plan_required` on Free plans |

#### Brand templates and autofill (Enterprise only)

| Tool | Rate | Description |
|---|---|---|
| `search-brand-templates` | 100/min | Find Enterprise brand templates |
| `list-brand-kits` | 100/min | List Enterprise brand kits |
| `get-brand-template-dataset` | 100/min | Retrieve the field schema of an autofill-capable brand template |
| `autofill-design` | 10/min | Fill a brand template with data (one design per row) — **confirm first** |

#### Editing transactions — the 4-step edit pattern

Canva uses an explicit **transactional editing flow** for structural edits (different from simple write tools). To modify a design's content you open a transaction, apply operations, then commit or cancel. Never leave an uncommitted transaction dangling.

| Step | Tool | Rate | Purpose |
|---|---|---|---|
| 1. Open | `start-editing-transaction` | 20/min | Begin an edit session on a design |
| 2. Apply | `perform-editing-operations` | 50/min | Apply one or more operations within the transaction |
| 3a. Save | `commit-editing-transaction` | 20/min | Persist the changes |
| 3b. Abort | `cancel-editing-transaction` | 20/min | Discard the changes (use this on error or if the user backs out) |
| Inspect | `get-design-thumbnail` | 100/min | Fetch a preview thumbnail — helpful before/after an edit |

Rules for editing transactions:

- **Always confirm before `commit-editing-transaction`** — this is the destructive step. Summarise what is about to be saved and wait for the user's OK.
- **Always cancel on failure** — if `perform-editing-operations` fails or the user aborts, call `cancel-editing-transaction` so no half-applied edit sits open.
- **One transaction per design at a time** — don't open a second transaction on the same design before committing or cancelling the first.
- **Show a thumbnail first** when the user has not seen the current state of the design — it grounds the conversation in what they'll actually be changing.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my Canva" / "Help me set up Canva" | **Run Phase 1** |
| "Show me my latest designs" | `search-designs` (empty or recency-sorted query) |
| "Find my pitch deck" | `search-designs` (name match) |
| "What pages are in this design?" | `get-design` → `get-design-pages` |
| "Read the text in this design" | `get-design-content` |
| "Show me the speaker notes" | `get-presenter-notes` |
| "Export my pitch deck as a PDF" | `get-design-export-formats` → `export-design` — **confirm first** |
| "Generate a social post about our product launch" | `generate-design` → `create-design-from-candidate` — **confirm before creating** |
| "Import this design from <URL>" | `import-design-from-url` — **confirm first** |
| "Upload this image to my Canva assets" | `upload-asset-from-url` — **confirm first** |
| "Find the image I uploaded last week" | `get-assets` |
| "Show me the comments on this design" | `list-comments` (optionally `list-replies`) |
| "Leave a comment on this design saying X" | `comment-on-design` — **confirm first** |
| "Reply to that comment with Y" | `reply-to-comment` — **confirm first** |
| "Find my 'Q1 campaigns' folder" | `search-folders` → `list-folder-items` |
| "Create a new folder called 'Launch Week'" | `create-folder` — **confirm first** |
| "Move this design into my Launch Week folder" | `search-folders` → `move-item-to-folder` — **confirm first** |
| "Resize my Instagram post to a LinkedIn post" | `resize-design` — **confirm first** (Pro+ only) |
| "Fill this brand template with data from my spreadsheet" | `search-brand-templates` → `get-brand-template-dataset` → `autofill-design` — **Enterprise only, confirm per row** |
| "Change the title on slide 2 to 'Revenue'" | `get-design-thumbnail` → `start-editing-transaction` → `perform-editing-operations` → **confirm** → `commit-editing-transaction` |
| "Show me a preview of that design" | `get-design-thumbnail` |

---

## Error Handling (Phase 2)

When a Canva tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Canva sign-in has expired — let me reconnect you." | Re-trigger Phase 1 Step 3 |
| 403 Forbidden | "Your Canva user doesn't have permission for that. The design owner may need to share it with you, or your admin may need to grant access." | User talks to the design owner or workspace admin |
| 403 `plan_required` (on `resize-design` or Enterprise tools) | "That feature needs a paid Canva plan. `resize-design` needs Pro or above; brand templates and autofill need Enterprise." | User upgrades their plan, or you suggest an alternative tool |
| `license_required` on `export-design` | "This design uses premium Canva elements — exporting it needs a paid plan. On the Free plan, exports skip or fail if there are premium items." | User upgrades to Canva Pro, or removes the premium elements before export |
| 404 Not Found (design / folder / asset) | "I couldn't find that item — let me refresh the list." | Use `search-designs` / `search-folders` / `get-assets` to refresh |
| 422 Invalid request | "Canva rejected the request — usually a bad parameter. Let me check and try again." | Re-read the design with `get-design` / `get-design-pages` and reformat the call |
| 429 Rate limited | "Canva is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. Per-tool rate limits are listed in the Tool Reference above |
| Editing transaction already open | "I had an edit session open — let me close that first, then retry." | Call `cancel-editing-transaction` on the stale session before starting a new one |
| Editing transaction expired mid-edit | "The edit session timed out. Let me start fresh." | Re-open with `start-editing-transaction` and re-apply the operations |
| MCP server not running | "The Canva connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Admin approval required (Enterprise) | "Your workspace administrator has restricted this sign-in. They need to allowlist the Canva MCP app for your workspace — once done, the sign-in will work for you and your team." | Canva workspace admin allowlists the MCP app; there is no API-key fallback |
| Any other API error | "Something went wrong with Canva — let me try again." | Retry once; if still failing, re-do the sign-in |

---

## Scope Limitations

The Canva MCP connector **can** do (via the official Canva MCP server):

- Search, read, and retrieve designs, pages, content, presenter notes, and export formats
- Generate new designs from AI prompts (with or without a specified structure)
- Import designs from external URLs
- Export designs as image or PDF (quality depends on plan)
- Upload and list assets (images, videos)
- List, add, and reply to comments on designs
- Search folders, list folder contents, create folders, move items between folders
- Resize designs (Pro and above)
- Search Enterprise brand templates, list brand kits, and autofill brand templates with data (Enterprise)
- Run transactional edits on design content (start → perform → commit / cancel)
- Fetch design thumbnails for visual confirmation

The Canva MCP connector **cannot** do (needs the Canva UI or other tools):

- **Delete** designs, assets, folders, or comments — none of the 30 tools supports deletion. Use the Canva UI to delete.
- **Connect via API key** — Canva MCP is OAuth-only. No Bearer-token fallback.
- **Bypass plan gating** — `resize-design` requires Pro+; brand templates and autofill require Enterprise. Calling them on lower plans returns `403`.
- **Export premium elements on Free plans** — exports may fail with `license_required` if the design contains premium Canva content; the user must upgrade or remove those elements.
- **Edit structurally without a transaction** — all content edits go through the 4-step transactional flow; there is no single-call "update design" tool.
- **Access Canva Docs, Websites, or Print orders** via MCP — the current tool set is scoped to designs, assets, folders, comments, exports, and brand templates.
- **Run more than one edit transaction on the same design at a time** — commit or cancel the first before opening another.
- **Connect multiple Canva accounts simultaneously** — one browser session per `~/.claude.json` entry.
- **Bypass Enterprise admin allowlisting** — if the admin blocks third-party app installs, the only option is for the admin to allowlist the Canva MCP app. There is no PAT fallback.

---

## Enterprise note — admin allowlisting can block first connect

On **Canva Enterprise workspaces**, the workspace administrator can restrict which third-party apps are allowed to connect via OAuth. If this is enforced, the browser sign-in will show an "administrator approval required" screen or silently fail. In that case:

1. Unlike some other connectors (Airtable, for example), **there is no API-key fallback for Canva MCP** — OAuth is the only auth path supported by the hosted server.
2. The user's Canva workspace admin needs to allowlist the Canva MCP app for the workspace. That is a one-time setup on the admin's side. Once allowlisted, other team members can connect normally via the browser.

This mirrors the same shape as the Jotform "workspace admin must install first" limitation documented in `known-issues/JOTFORM-ADMIN-ONLY.md`.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, generating, editing, exporting, or moving** — summarise what you are about to do and wait for the user's OK before calling a write/generate/export tool. AI generation (`generate-design`, `generate-design-structured`, `create-design-from-candidate`) costs the user's Canva AI credits — always confirm before firing.
- **Discover IDs before writing** — Canva designs, folders, and assets are referenced by opaque IDs. Always call `search-designs` / `search-folders` / `get-assets` once per session before any write or edit, unless you already have the IDs from earlier in the conversation.
- **Handle the editing transaction lifecycle carefully** — always commit or cancel. Never leave a transaction open. If `perform-editing-operations` fails, call `cancel-editing-transaction` before retrying.
- **Show thumbnails before structural edits** — `get-design-thumbnail` grounds the user in what they are about to change. Cheap, fast, worth calling.
- **Respect plan gating before calling** — if the user is on Free, don't call `resize-design` or the Enterprise-only tools without warning. If you're unsure of their plan, attempt the call and translate the `403` / `plan_required` response into plain English.
- **Export quality caveat** — on the Free plan, `export-design` gives standard-quality output and may fail with `license_required` on designs with premium elements. Warn the user proactively when you detect premium content.
- **Designs often contain confidential content** — pitch decks, client work, internal campaigns. Never dump full design content into a public log without checking with the user first. Prefer titles and page counts over full text dumps.
- **Present designs clearly** — format results as readable lists or summaries, not raw JSON. For comment threads, group by thread and show author + text only.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 84 designs; the most recent is 'Q2 Launch Deck' from yesterday"), then offer to show details.
- **Pagination** — default to 25 designs or folder items per response unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits vary by tool** — the Tool Reference above lists per-minute limits. Bulk operations (autofill batches, multi-design exports) should respect the tightest limit in the chain.
- **Never log or echo credentials** — there is no user-visible token, but never paste the contents of `~/.claude.json` to the user either.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Canva auth or API errors
- **airtable-connector**: Sibling hosted OAuth MCP connector — pair structured data (Airtable rows) with Canva autofill to generate one design per row
- **jotform-connector**: Sibling hosted OAuth-only MCP connector — identical install pattern, no API-key fallback
- **ad-creative**: Generate ad copy variations then render them as Canva designs with `autofill-design` (Enterprise) or `generate-design`
- **social-content**: Turn social posts into Canva-ready visuals and `resize-design` across platforms (Pro+)
- **canva-sdks/canva-claude-skills** (external repo, 24 stars): Canva publishes ready-made Claude Skills that layer on top of this connector — branded-presentation, design-translation, implement-feedback, presentation-time-fitting, resize-for-social-media, bulk-create, classroom-helper. Mention these when the user wants a higher-level workflow.
