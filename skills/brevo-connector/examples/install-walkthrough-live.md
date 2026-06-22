# Brevo connector — live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22 (key redacted).

## Setup

- Account: SelrAI (rodolfo@selrai.com.au), free plan. Linux/Wayland, Playwright MCP persistent profile.
- Pre-state: no `~/.config/brevo/credentials.env`.

## What happened

1. **Verified the API model first**: Brevo key (`xkeysib-`), self-serve, sent via the `api-key` header (not Authorization), base `https://api.brevo.com/v3`, verify with `GET /account`.
2. **Opened `app.brevo.com/settings/keys/api`** → redirected to `login.brevo.com` (signed out). User signed in **in the automated window** (after a reminder that the Playwright Chromium is its own instance); page returned to the API-keys settings.
3. **Clicked Generate API key.** Modal asked for a name + expiry:
   - Name `Claude Code`.
   - Expiry: opened the dropdown (options 7 days → 1 year → **No expiration**) and chose **No expiration** so the connector won't silently lapse (default was 1 year).
   - Clicked the modal **Generate**.
4. **reCAPTCHA gate.** Brevo gates key generation behind reCAPTCHA (invisible this run). After Generate, the create modal closed and a **reveal modal** appeared: *"copy this key and save it somewhere safe. For security reasons, we cannot show it to you again."*
5. **Key-capture timing + format gotchas:**
   - The reveal field took a moment to render — an immediate scan found nothing; a re-check found it.
   - The key is **~89 chars and contains hyphens** (`xkeysib-<hex>-<suffix>`), so a `[A-Za-z0-9]`-only regex failed to match it. Switched to `xkeysib-[A-Za-z0-9-]+`.
   - Captured via the modal's **Copy** button (authoritative; key shown once).
6. **Verify + store.** Read clipboard, `GET /account` → 200 (SelrAI / rodolfo@selrai.com.au). Wrote `~/.config/brevo/credentials.env` (mode 600), scrubbed Playwright snapshots.
7. **End-to-end check.** Listed contact lists ("Your first list", id 2) + senders (rodolfo@selrai.com.au, active); created a test contact (201, id 2) → read it back → deleted it (204) → confirmed gone (404). Read + write confirmed.

## Gotchas this run surfaced (now in the SKILL)

- **`api-key` header** (custom), not `Authorization`.
- **Key contains hyphens, ~89 chars** → use `xkeysib-[A-Za-z0-9-]+`; shown once → Copy-button capture.
- **reCAPTCHA gates generation** (usually invisible; user solves if a challenge appears).
- **Pick "No expiration"** (default is 1 year).
- **Reveal modal renders with a slight delay** — re-check before concluding the key isn't there.
- **`/smtp/email` and campaign sends actually deliver** — confirm with the user; reads + contact CRUD are safe.

## Verification facts

- `api-key` header auth → 200; key `xkeysib-…` 89 chars (hyphenated), No expiration.
- Create contact → 201; delete contact → 204; subsequent GET → 404.
- Sender rodolfo@selrai.com.au verified/active; one default list ("Your first list").
