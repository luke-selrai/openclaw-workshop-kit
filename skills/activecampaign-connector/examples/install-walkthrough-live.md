# ActiveCampaign connector - live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22 (key redacted).

## Setup

- Account: selrai.activehosted.com (admin / rodolfo@selrai.com.au). Linux/Wayland, Playwright MCP persistent profile.
- Pre-state: no `~/.config/activecampaign/credentials.env`. (Account was created fresh during this run.)

## What happened

1. **Verified the API model first**: ActiveCampaign v3 needs TWO credentials - an account-specific API URL + an API Key - sent via the `Api-Token` header, base `<API_URL>/api/3`, verify `GET /api/3/users/me`.
2. **Opened `www.activecampaign.com/login/`** → user signed in **in the automated window**; landed on `https://selrai.activehosted.com/app/agent`. Captured the account subdomain `selrai` from the host.
3. **Opened `https://selrai.activehosted.com/app/settings/developer`.** The **API Access** section showed both:
   - **URL**: `https://selrai.api-us1.com` (26-char field - the account-specific base, region `api-us1`). Not secret.
   - **Key**: a 72-char hex value (secret). Captured to the clipboard via its Copy button / readonly field.
   Both are shown persistently (not one-time), so re-reading later is fine.
4. **Verify + store.** `GET /api/3/users/me` → 200 (admin / rodolfo@selrai.com.au). Wrote `~/.config/activecampaign/credentials.env` (mode 600) with both `ACTIVECAMPAIGN_API_URL` and `ACTIVECAMPAIGN_API_KEY`, scrubbed Playwright snapshots.
5. **End-to-end check.** Lists ("Master Contact List", id 3), tags (0); created a contact (id 2) → read it back → deleted it (HTTP **200**) → confirmed gone (404). Read + write confirmed.

## Gotchas this run surfaced (now in the SKILL)

- **Two credentials, account-specific base URL** (`https://<account>.api-us1.com`) - both read from Settings → Developer; a wrong/region-mismatched URL breaks everything.
- **`Api-Token` header** (the key value), not Authorization.
- **Write bodies wrap in the entity key** (`{"contact":{...}}`).
- **DELETE returns 200** (not 204).
- **`/contacts` POST errors on duplicate email** - use `/contact/sync` to upsert.
- **Campaigns/automations send real email** - confirm with the user.

## Verification facts

- `Api-Token` header + URL `https://selrai.api-us1.com` → 200; key ~72 hex.
- Create contact → contact.id; delete → 200; subsequent GET → 404.
- Reads carry `meta.total`; one default list ("Master Contact List").
