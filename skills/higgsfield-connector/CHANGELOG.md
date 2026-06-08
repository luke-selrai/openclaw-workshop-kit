# Changelog — higgsfield-connector

All notable changes to this skill, oldest at the bottom.

## [0.1.0] — 2026-06-08

Initial release. CLI-based connector for **Higgsfield** (cinematic AI image +
video generation) via the official `@higgsfield/cli` (binary `higgsfield`,
aliases `higgs`/`hf`). Instructions-only — device-login OAuth, token in a local
`0600` credentials file (`~/.config/higgsfield/credentials.json`), nothing in
`~/.claude.json`.

**Live-grounded + smoked 2026-06-08 against rodolfo@selrai.com.au's Higgsfield**
(`@higgsfield/cli` v0.1.40). The entire command surface was enumerated from real
`higgsfield --help` output (not the marketing page), and Phase 1 + an image
generation were run end-to-end.

### Added

- `SKILL.md` — Phase 0 resume check (`account status`), Phase 1 Playwright-driven
  device login (`auth login` → browser approval; captured the real
  `higgsfield.ai/device?code=…` flow), Phase 2 command reference grounded in v0.1.40:
  `account` (status/transactions), `model` (list/get), `generate`
  (cost/create/wait/get/list — async jobs, `--wait`, media flags that auto-upload
  local paths), `upload`, `soul-id`, `workspace`, and the enhanced
  `marketing-studio` / `marketplace-cards` / `product-photoshoot` flows. Includes
  the captured `generate get --json` response shape and credit-cost behaviour.
- `examples/install-walkthrough.md` — fully captured: device login via Playwright,
  plus a live `nano_banana_2` image generation (cost estimate `2 credits` →
  `generate create --wait` → result URL → balance 10 → 8).
- `scripts/verify-cli.sh` — re-runnable health check (`higgsfield --version` +
  `account status` reachability; exit 0 ok / 1 not-authenticated / 2 not-installed).
- `CHANGELOG.md` — this file.

### Verified live

- Device login → `Successfully authenticated.` → `account status` (email/plan/credits).
- `model list --image` full catalog; `generate cost` matched actual spend (2 credits);
  `generate create --wait` → CloudFront result URL; `generate get/list --json` shapes.

### Not live-smoked (free plan, 10 credits)

- Video generation, `soul-id` training, and Marketing Studio / product-photoshoot /
  marketplace-card flows — documented from `--help` contracts; a follow-up smoke with
  credits would lift evidence on those paths.

### Why

Higgsfield was already recommended inside the `ad-creative` skill's generative-tools
catalog but not installable/automatable. The official CLI makes it a clean,
leak-safe CLI connector (same shape as `notion-connector`/`qbo`) — the natural
automation companion to `ad-creative` and `social-content` (write the copy → render
the cinematic video/image).
