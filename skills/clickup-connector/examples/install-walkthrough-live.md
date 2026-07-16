# ClickUp connector - live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22 (token redacted).

## Setup

- Account: workspace "Selrai", user Rodolfo Raquion (id 312738239). Linux/Wayland, Playwright MCP persistent profile.
- Pre-state: no `~/.config/clickup/credentials.env`, no token generated yet.

## What happened

1. **Verified the API model first**: ClickUp personal token (`pk_`), self-serve at Settings → Apps, sent as a RAW `Authorization` header (no Bearer), base `https://api.clickup.com/api/v2`.
2. **Opened `app.clickup.com/settings/apps`** → redirected to `/login` (signed out).
3. **Wrong-browser-session gotcha:** the user said "I'm logged in," but the Playwright window still showed ClickUp's login. The Playwright browser is its own Chromium instance - the user had signed in elsewhere. Resolution: asked them to sign in **in the window Claude opened**; then `/settings/apps` loaded (URL gained the workspace id: `app.clickup.com/90161667029/settings/apps`).
4. **Clicked Generate** under API Token. ClickUp popped a modal: **"Sign in with Google to generate API Token"** (this workspace is Google-SSO). The "Sign in with Google" button is a Google-rendered control (iframe) - Claude can't reliably click it and the account-pick is the user's action anyway. Asked the user to click it and pick their Google account.
5. **After the re-auth**, the API Token section switched to showing **Copy** + **Regenerate** (token generated, but **masked** on screen). Clicked the **Copy** button (`data-test="apps-settings__user-copy-api-key"`) to put the `pk_` token on the clipboard.
6. **Verified + stored**: read clipboard, confirmed `pk_…` shape, `GET /user` → 200 (Rodolfo Raquion). Wrote `~/.config/clickup/credentials.env` (mode 600), scrubbed Playwright snapshots.
7. **End-to-end check** (empty account had spaces but no lists): created a temp folderless list → created a task in it → read it back (status "to do") → deleted task (204) → deleted list (200). Read + write confirmed.

## Gotchas this run surfaced (now in the SKILL)

- **RAW Authorization header (no Bearer)** - confirmed: `Authorization: pk_…` returns 200.
- **Token generation needs a Google re-auth** for SSO accounts (the "Sign in with Google to generate API Token" modal). One quick user step.
- **Token is masked → capture via Copy button**, not a DOM read.
- **Generate = regenerate** - re-clicking invalidates the existing token; use Copy when one already exists.
- **Wrong-browser-session**: "I'm logged in" can mean a different browser; the automated Chromium needs its own sign-in.
- **Empty accounts have no lists** - to test (or to create a first task) you may need to create a list first.

## Verification facts

- Auth RAW header → 200; token `pk_…`.
- Hierarchy team→space→folder→list→task; tasks require a list scope.
- DELETE task → 204 (no body); delete list → 200.
- Dates are epoch milliseconds.
