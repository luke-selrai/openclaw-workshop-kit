# Higgsfield Connector - Install Walkthrough

> **Status: fully captured, 2026-06-08 against rodolfo@selrai.com.au's Higgsfield account** (`@higgsfield/cli` v0.1.40). Phase 1 (install + device login) plus **both** a Phase 2 image-generation smoke **and** an image-to-video smoke were run live end-to-end. The login was approved in a Playwright browser; a `nano_banana_2` image was generated (2 credits) and a `seedance1_5` image-to-video clip was generated (2.4 credits, 4.05s MP4), with real response shapes captured. The platform's input content-safety guardrail (`Error: NSFW content detected`) was also observed live.

This walkthrough documents the default path: Phase 0 → Phase 1 → a Phase 2 smoke. Single-mode skill (CLI device-login OAuth; no API-key path).

**Pre-conditions:** Node + npm on PATH; internet to `higgsfield.ai`; Playwright MCP reachable; a Higgsfield account.

---

## Step 0 - Resume check

```bash
$ command -v higgsfield && higgsfield --version
$ higgsfield account status
Error: Not authenticated.
Hint: Run: hf auth login
```
→ not connected - run Phase 1. (When already connected, `account status` prints `email - plan, N credits` and you skip to Phase 2.)

---

## Step 1 - Welcome

> "I'll connect your Higgsfield now so I can generate video and image creative for you. I'll open a sign-in window in a moment - just approve it there and I'll handle the rest. About a minute."

---

## Step 2 - Install the CLI

```bash
$ npm install -g @higgsfield/cli
added 1 package
$ higgsfield --version
higgsfield 0.1.40 (9aa6f1f…) built 2026-05-12T11:19:03Z
```
Binary: `higgsfield` (aliases `higgs`, `hf`).

---

## Step 3 - Log in (device flow, Playwright-driven) - captured live

```bash
$ higgsfield auth login > /tmp/hf_login.out 2>&1 &     # blocks, polling, until approval
# /tmp/hf_login.out:
Opening browser for authentication...
If browser does not open, visit: https://higgsfield.ai/device?code=<CODE>
Waiting for approval...
```

Drive the printed URL in Playwright:
```
mcp__playwright__browser_navigate({ url: "https://higgsfield.ai/device?code=<CODE>" })
```
- **Captured 2026-06-08:** the device URL redirected to `https://higgsfield.ai/auth/sign-in?rp=%2Fdevice%3Fcode%3D<CODE>` (not signed in). The user signed in; the device-approval screen then appeared and was approved.
- On approval the backgrounded command completed:
```
Successfully authenticated.
```
- Token saved to `~/.config/higgsfield/credentials.json` (mode `0600`) - **not** in `~/.claude.json`.

Verify:
```bash
$ higgsfield account status
rodolfo@selrai.com.au - free plan, 10 credits
```

---

## Step 4 - Success message

> "All done - your Higgsfield is connected! You've got **10 credits**. You can ask me to 'make a cinematic product video', 'turn this photo into a 5-second video ad', or 'generate 3 image variations for a social ad'. (Each generation uses a few credits - I'll always tell you the cost first.)"

---

## Phase 2 sample - image generation (captured live, 2 credits)

```bash
# 1) Estimate cost first
$ higgsfield generate cost nano_banana_2 --prompt "a single red cube on a plain white background, minimal product photo"
2 credits

# (Claude confirms: "This will use 2 credits - you have 10. Go ahead?")

# 2) Generate, blocking until done → prints the result URL
$ higgsfield generate create nano_banana_2 \
    --prompt "a single red cube on a plain white background, minimal product photo" --wait
https://d8j0ntlcm91z4.cloudfront.net/user_…/hf_20260608_104233_bbd02f1f-….png

# 3) Balance dropped by exactly the estimate
$ higgsfield account status
rodolfo@selrai.com.au - free plan, 8 credits
```

**Captured response shape** (`generate get <id> --json`):
```json
{
  "id": "bbd02f1f-…", "status": "completed", "display_name": "Nano Banana Pro",
  "job_set_type": "nano_banana_2",
  "result_url": "https://…cloudfront.net/…/hf_….png",
  "created_at": 1780915353.5,
  "params": { "prompt": "…", "width": 2048, "height": 2048, "aspect_ratio": "1:1",
              "resolution": "2k", "batch_size": 1, "input_images": [], "input_image": null }
}
```

`generate list` returns an array of these objects. For video, swap in a video model (`higgsfield model list --video`) and pass a source image via `--image`/`--start-image` for image-to-video; use a generous `--wait-timeout`.

---

## Verified live 2026-06-08

- Auth: device login (`auth login`) → browser approval (Playwright) → `Successfully authenticated.` → `account status` shows email/plan/credits.
- `model list --image` returns the full image catalog (Nano Banana Pro, FLUX.2, Seedream, Cinematic Studio, …).
- `generate cost nano_banana_2` → `2 credits` (matched actual spend).
- `generate create … --wait` → result URL; `generate get/list --json` → the shape above.
- Credits decremented as estimated on every job.

**Image-to-video smoked live too** (`seedance1_5`, image-to-video): `generate cost
seedance1_5 --image <photo> … --duration 4 --resolution 480p` → `2.4 credits`;
`generate create … --image <photo> --wait --wait-timeout 12m` → a 4.05s MP4 (H.264+AAC,
864×496) at the result URL. So the full async **video** path (cost → create → poll →
MP4) is verified end-to-end, not just images.

**Input content safety (captured 2026-06-08).** Higgsfield enforces a content filter on
**input media** - `generate cost`/`create` return `Error: NSFW content detected` and refuse
to proceed (e.g. when the source image is of a minor). This is the platform's guardrail;
do not attempt to bypass it (re-cropping, rewording, switching models). Surface it plainly
and stop. Adults / products pass normally.

**Not exercised** (free plan, limited credits): `soul-id` training and the Marketing Studio /
product-photoshoot / marketplace-card flows - documented from `--help` + `model`/`--help`
contracts, not live-smoked.

---

## Failure modes

| Failure | Cause | Fix |
|---|---|---|
| `npm install -g` EACCES/EPERM | global-install permissions | `docs/start/setup.md` Step 0 / Node version manager; retry once |
| device URL stays on sign-in | user not signed in to Higgsfield | prompt once: "please sign in in the window I opened" |
| `Not authenticated` on a Phase 2 call | token missing/expired | re-run `higgsfield auth login` |
| `Insufficient credits` | balance too low | top up; offer a cheaper model meanwhile |
| `Unknown model …` | wrong `job_set_type` | `higgsfield model list` to get the exact type |
