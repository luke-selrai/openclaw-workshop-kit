# Kit (ConvertKit) connector - live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22 (key redacted).

## Setup

- Account: SelrAI (rodolfo@selrai.com.au), creator plan. Linux/Wayland, Playwright MCP persistent profile.
- Pre-state: no `~/.config/kit/credentials.env`.

## What happened

1. **Verified the API model first**: Kit v4 API, self-serve key, header `X-Kit-Api-Key`, base `https://api.kit.com/v4`, verify `GET /account`. (Legacy v3 at api.convertkit.com/v3 with `api_key`/`api_secret` exists but is NOT used.)
2. **Opened `app.kit.com/account_settings/developer_settings`** → redirected to `app.kit.com/users/login` (signed out). User signed in **in the automated window**; page returned to Developer Settings.
3. **Distinguished V4 from V3.** The Developer page shows **V4 Keys** ("Add a new key") and a **V3 Key (Legacy)** (a 22-char key already present with Copy/Show/Regenerate). Targeted **V4 Keys → Add a new key** (the connector uses v4).
4. **Created the key.** "New API Key" modal → Name (`#api-key-name`, "internal use only") = `Claude Code` → **Create API Key**.
5. **Captured via Copy.** The reveal showed the key once - prefix `kit_`, ~36 chars - with a Copy button. Clicked Copy (key can't be retrieved again).
6. **Verify + store.** `GET /v4/account` → 200 (SelrAI / rodolfo@selrai.com.au / creator). Wrote `~/.config/kit/credentials.env` (mode 600), scrubbed Playwright snapshots.
7. **End-to-end check** (empty account): subscribers 0 (cursor pagination shape confirmed), tags 0, forms 1; created a tag (id 20542614) → deleted it (204) → confirmed gone. Read + write confirmed.

## Gotchas this run surfaced (now in the SKILL)

- **v4 + `X-Kit-Api-Key` header** (not Authorization, not query param); ignore the legacy v3 API.
- **Two key sections** - use **V4 Keys → Add a new key**, not the legacy 22-char V3 key on the same page.
- **Key prefix `kit_`, ~36 chars, shown once** → Copy-button capture.
- **Cursor pagination** (`pagination.end_cursor` + `after=`), not offset/page.
- **No hard subscriber delete** (use `/subscribers/<id>/unsubscribe`); tags delete cleanly (204).
- **Broadcasts/sequences send real email** - confirm with the user.

## Verification facts

- `X-Kit-Api-Key` v4 auth → 200; key `kit_…` 36 chars.
- Create tag → 201 (`tag.id`); delete tag → 204; subsequent list → gone.
- Account: SelrAI, creator plan, 1 form, 0 subscribers/tags (fresh account).
