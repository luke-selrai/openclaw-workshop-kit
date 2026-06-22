# FreshBooks connector — live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22 (secrets redacted). FreshBooks is the heaviest connector in the kit — full OAuth2 with app registration and refresh-token rotation — and this run surfaced three gotchas now baked into the SKILL.

## Setup

- Account: Selr AI, account_id `qKQxnJ`, owner Rodolfo Raquion. Linux/Wayland, Playwright MCP persistent profile.
- Pre-state: no `~/.config/freshbooks/credentials.env`.

## What Claude did (happy path)

1. **Verified the API model first** (Dext/Asana discipline): FreshBooks docs → OAuth2 only, no PAT, HTTPS redirect required. So this is an app-registration flow, not a token grab.
2. **Opened the dev console** (`my.freshbooks.com/#/developer`), user already signed in.
3. **Created the app** `Claude Code — SelrAI`, type **Private App**, scopes `profile:read` + invoices r/w + clients r/w + expenses:read + payments:read + reports:read, redirect `https://example.com/callback`.
4. **Captured Client ID + Secret** from the Edit Application page (revealed the masked secret), persisted them.
5. **Ran consent**: navigated the authorize URL → FreshBooks showed "Connect Claude Code — SelrAI wants to: Manage & View Your Invoices and Expenses / Manage Your Clients / View Your Profile / View Your Payments and Reports" → clicked **Allow**.
6. **Captured the code** from the redirect `https://example.com/callback?code=<64hex>` (example.com loads a static page; the code is in the URL).
7. **Exchanged** the code → access token (~12 h) + refresh token, all 8 scopes.
8. **Discovered account_id** via `/auth/api/v1/users/me` → `qKQxnJ` (business "Selr AI", id 14713850, role owner).
9. **Persisted atomically** (temp-file + rename), scrubbed Playwright snapshots, **verified**: invoices/clients/expenses all HTTP 200 (totals 0 — fresh account).
10. **Proved refresh rotation**: refreshed once → got a *new* refresh token (confirmed different), persisted atomically, new access token returned 200.

## The three gotchas this run surfaced (now in the SKILL)

1. **App name is globally unique.** The first two saves returned **HTTP 422**; the inline UI error pointed at the redirect, but reading the POST response body (`…/partners/applications`) revealed the real cause: **"Validation failed: Name has already been taken."** Plain `Claude Code` was taken globally. Renaming to `Claude Code — SelrAI` fixed it. *Lesson: read the 422 body — the inline error misleads.*
2. **No localhost redirect.** `https://localhost/callback` is rejected (422). FreshBooks requires public HTTPS. Solution: register a neutral public HTTPS redirect (`https://example.com/callback`) and capture the code from the browser. The single-use code briefly transits example.com on the redirect GET — accepted trade-off (chosen by the maintainer).
3. **Ember form mechanics.** `fill()` and synthetic clicks didn't reliably trigger Ember bindings; the redirect URI also needed its **"+" button** to commit to the list (else "This cannot be blank"), and adding scopes re-rendered the form and **blanked the redirect field** — so the redirect had to be re-entered right before Save. Use the real click tool and re-verify fields pre-save.

## Verification facts

- `Authorization: Bearer` → 200 on accounting reads; response shape `{"response":{"result":{...}}}`.
- Refresh token **rotates on every refresh** (one-time-use) — atomic re-persist is mandatory.
- account_id `qKQxnJ` is alphanumeric (≠ numeric business_id 14713850) — accounting endpoints use account_id.
