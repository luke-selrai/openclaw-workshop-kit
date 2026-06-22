# Trello connector — live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22 (token redacted). Trello's setup has **one unavoidable manual step** that this transcript exists to document.

## Setup

- Account: `rodolforaquion` (Rodolfo Raquion), workspace "Trello Workspace". Linux/Wayland, Playwright MCP persistent profile.
- Pre-state: no `~/.config/trello/credentials.env`, no existing Power-Up.

## What happened

1. **Verified the API model first**: Trello = API key (public) + token (secret), query-param auth, base `https://api.trello.com/1`. Getting a key requires creating a Power-Up.
2. **Opened the developer console** (`trello.com/power-ups/admin`), user signed in. Accepted the one-time **Developer Terms** gate (the checkbox is overlaid by `label[data-testid="clickable-checkbox"]` — clicked the label, then Continue).
3. **Power-Up creation form (`/power-ups/admin/new`) — THE WALL.** Claude attempted to fill + submit it programmatically and **could not enable the form's Create button** by any means:
   - Real Playwright clicks on Create (×3) → opened the *top-nav* "Create board" menu (there are two "Create" buttons; the form's is bottom-right and was greyed).
   - Real keystrokes for App name + Email; keyboard + type-to-filter selection for Workspace; native-setter + input/change events; **and direct React-fiber `onChange` injection** on all three fields.
   - Every field **displayed** correctly; Create stayed disabled regardless. No create request ever fired.
   - **Resolution: handed the form to the user.** Claude took a screenshot, explained the three fields (App name `Claude Code`, Workspace, Email) and which Create to click (bottom-right, not top-nav). The user typed the fields and clicked Create — and it worked instantly. Human input registers where automation can't.
4. **Claude resumed.** Landed on `/power-ups/<appId>/edit/api-key`. Clicked **Generate a new API key** → **Generate API key** (confirm) → DOM-read the 32-hex key (public-safe), persisted it.
5. **Token mint.** Navigated `…/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=<KEY>` → consent screen → clicked **Allow** (`#approveButton`) → landed on `…/1/token/approve` which **displays the token in the page text**. Captured it: format `ATTA…`, **76 chars, mixed-case** (the legacy 64-hex format is gone — the first capture regex `[a-f0-9]{64}` missed it; switched to `ATTA[A-Za-z0-9]{50,}`).
6. **Verify + store.** `GET /1/members/me` → 200 (Rodolfo Raquion / rodolforaquion). Wrote `~/.config/trello/credentials.env` (mode 600), scrubbed the Playwright snapshot dir (the token-reveal page lands in auto-snapshots).
7. **End-to-end check.** Boards ("My Trello board") → lists (Trello Starter Guide / Today / This Week / Later) → **write cycle**: created a card, deleted it (DELETE 200), confirmed gone (GET 404).

## The lesson (now in the SKILL)

Trello is categorically harder to set up than Pipedrive/Asana/FreshBooks because the secret lives behind a **creation form that resists automation**, not on a page you read. Phase 1 must hand the Power-Up *creation form* to the user — that single manual step is unavoidable. Everything else (terms, key generation, token authorize/Allow, capture, verify) automates cleanly. A workshop attendee should be told up front: "you'll fill one short form by hand; I do the rest."

## Verification facts

- Auth: `?key=&token=` query params → 200.
- Token: `ATTA`-prefixed, 76 chars, mixed-case; `expiration=never`, `scope=read,write,account`.
- API key is public-safe; token is the secret.
- Create→DELETE card cycle confirmed (DELETE 200 → GET 404). Prefer `closed=true` (archive) for reversible deletes.
