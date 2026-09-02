# Asana connector - live Phase 1 walkthrough (verified)

> **Which route this is.** This transcript is the kit's own route, now **Phase 1-alt** in `SKILL.md`. The default first stop is the built-in Asana connector (Phase 1); this route is for setting custom fields at task creation and for portfolios, or when built-in connectors can't be used. The flow below is unchanged.

A real, verified run of Phase 1 on 2026-06-22. The token is redacted; everything else is the actual flow, including the gotcha that bit the first capture attempt. This is the reference transcript for a clean install.

## Setup

- Account: Selr AI workspace `selrai.com.au`, token owner Rodolfo Raquion.
- Environment: Linux, Playwright MCP with persistent profile.
- Pre-state: no `~/.config/asana/credentials.env`.

## What Claude did (happy path)

1. **Phase 0 resume check** - `not-configured` → proceed to Phase 1.

2. **Opened the developer console** - `browser_navigate("https://app.asana.com/0/my-apps")`. Signed-out → redirected to `app.asana.com/-/login`.
   - User-facing: *"Opening a browser window - please sign in to Asana when it appears."*
   - **Did not snapshot the login page** (password-leak avoidance).

3. **Cleared a cookie banner** - the OneTrust consent banner was intercepting the sign-in buttons; dismissed via `#onetrust-accept-btn-handler` so Google/Microsoft/Email were clickable.

4. **Waited for sign-in** - polled `location.href`. The user signed in with Google SSO (selrai.com.au); polling settled on `https://app.asana.com/0/my-apps`.

5. **Created the token** - under **Personal access tokens** → **Create new token**; typed `Claude Code`, ticked **I agree to the Asana API Terms**, clicked **Create token**.

6. **Captured via the Copy button** - the **Token details** dialog showed the token once with *"Make sure to copy this access token now. You won't see it again."* Clicked the dialog's **Copy** button → full token on the clipboard.

7. **Verified, then stored** - read the clipboard, confirmed the three-segment shape, **verified against `/users/me` BEFORE writing**:
   ```
   HTTP 200 - Rodolfo Raquion (rodolfo@selrai.com.au), workspace selrai.com.au
   ```
   Wrote `~/.config/asana/credentials.env` (mode 600) with `ASANA_PAT=2/****…redacted`, then `rm -rf .playwright-mcp` to scrub snapshots.
   - User-facing: *"All connected - your Asana is ready. Try 'show my tasks due this week' or 'add a task to a project'."*
   - No Claude Code restart (no MCP server).

## The gotcha that bit the first attempt (now documented in the SKILL)

The **first** capture used a DOM regex `\d/\d{4,}:[0-9a-f]{20,}` - a **two-segment** pattern. Asana PATs are **three-segment**: `2/<user_gid>/<token_gid>:<hex>`. The regex matched a truncated middle slice (`2/<token_gid>:<hex>`, 51 chars) instead of the full 68-char token, and `/users/me` returned **401 Not Authorized** despite the slice looking structurally valid.

Fix: switched to the Token-details dialog's **Copy** button (authoritative source), which yielded the full `2/1215919238271902/1215924623120615:…` token → `/users/me` 200. The SKILL now prescribes the Copy button first, with the corrected `\d+/\d+/\d+:[0-9a-f]+` regex only as a fallback. **This is why Phase 1 verifies the token against the live API before persisting** - the truncated slice was caught in seconds instead of shipping a connector that 401s on every call.

## Verification facts captured during this run

- `Authorization: Bearer` → **200**; PAT is three-segment, 68 chars.
- Default object shape is `{gid, name, resource_type}` - **`opt_fields` required** for anything more (confirmed: `/users/me` default has 6 keys, `?opt_fields=email,name` narrows to 3).
- Workspace `selrai.com.au` = gid `1214794193114114`; one project ("Rodolfo's first project").
- `next_page` is `null` when there are no further pages (offset pagination).
