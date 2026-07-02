---
name: higgsfield-connector
description: "Connect and operate Higgsfield (cinematic AI image + video generation) through the official Higgsfield CLI (`higgsfield`, npm `@higgsfield/cli`, https://higgsfield.ai/cli). Instructions-only - no MCP server, no plugin, no token pasted into any config. Phase 1 installs the CLI and runs `higgsfield auth login`: a browser device-login that prints a `higgsfield.ai/device?code=…` URL; Claude drives a Playwright browser to it, the user approves, and the token is saved to a local credentials file (`~/.config/higgsfield/credentials.json`, mode 0600) - never in `~/.claude.json`. Phase 2 generates images and videos via `higgsfield generate` (create/cost/wait/get/list), browses models (`model list/get`), uploads inputs (`upload`), trains face-faithful characters (`soul-id`), and runs Marketing Studio / product-photoshoot flows. Generation is credit-based and asynchronous. Use this skill when the user asks to set up Higgsfield, generate AI video or image ad creative, animate a product image into video, create cinematic shots, or render social-video variations."
allowed-tools: Bash, Read, Write, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - higgsfield
    - ai-video
    - video-generation
    - image-generation
    - cinematic
    - soul-id
    - cli
  pairs-with:
    - skill: ad-creative
      reason: Write ad copy / concepts with ad-creative, then render them as Higgsfield cinematic video or image ads
    - skill: social-content
      reason: Turn social post ideas into Higgsfield-rendered mobile-first video/image creative
    - skill: hyperframes-cli
      reason: Sibling media-generation CLI - Higgsfield for cinematic AI gen, HyperFrames for programmatic/templated React video
    - skill: playwright-skill
      reason: The Playwright MCP browser drives the Higgsfield device-login approval screen
---

# Higgsfield Connector

> **Install pattern:** CLI-based (first-party CLI + device-login OAuth), like `google-chat-connector` (`gws`), `quickbooks-connector` (`qbo`), and `notion-connector` (`ntn`). Not a hosted-MCP or plugin connector.

## Overview

This skill connects and operates **Higgsfield** - a cinematic AI image + video generation platform - through its official CLI, `higgsfield` (npm package `@higgsfield/cli`, https://higgsfield.ai/cli; binary aliases `higgsfield`, `higgs`, `hf`). Two phases:

- **Phase 1 - Install & Log in (autonomous via Playwright).** Claude installs the CLI and runs `higgsfield auth login` - a browser **device login**. The CLI prints a `https://higgsfield.ai/device?code=…` URL and waits; Claude drives a Playwright browser to that URL, the user approves, and the token is saved to a local credentials file (`~/.config/higgsfield/credentials.json`, mode `0600`). **No token in `~/.claude.json`, no API key to paste.**
- **Phase 2 - Operate.** Claude runs `higgsfield` commands to generate images/videos, estimate credit cost, poll async jobs, browse models, upload inputs, train Soul character references, and run Marketing Studio flows.

The only manual moment for the user is approving the login in the browser.

**Generation is credit-based and asynchronous.** Every generation spends credits (check `higgsfield account status` for balance; `higgsfield generate cost …` to estimate before spending). Jobs run async - submit and poll, or use `--wait` to block.

### Why the CLI

- **No secret pasted into shared config.** The token lives in a local `0600` credentials file the CLI manages, not as a Bearer line in `~/.claude.json`.
- **First-party + grounded.** Everything below was verified live against `@higgsfield/cli` v0.1.40 (real `--help` + a live image generation smoke).

### What this skill does NOT use

- No `claude mcp add` / MCP server, no Claude Code plugin, no manual API-key entry.

## Security rules

- **Never echo the token.** `higgsfield auth token` prints the raw access token - do not run it in a way that surfaces the value to the user, and never paste it into chat. `higgsfield auth logout` deletes the local token.
- The credentials file (`~/.config/higgsfield/credentials.json`) is a secret: never read it back into chat, never commit or sync it.
- Never print `~/.claude.json`.

## Communication rules (non-technical user)

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work; the user only approves the login in the browser. Every message:

- **You drive, not them.** The only thing you ask is "please approve the sign-in in the window I opened."
- **Plain English only.** No jargon - never say CLI, npm, OAuth, device code, token, API, terminal, JSON, credits-API. The browser window is "a sign-in window I opened"; the connection is "your Higgsfield connection". (You *may* say "credits" - users understand that.)
- **Narrate at action boundaries** (start / need-you / done). **Short messages** (≤8 lines). **Never show raw errors** - translate to plain English.
- **Always state credit cost before generating** (see Behaviour Guidelines).

## PHASE 0 - Resume check (silent)

```bash
command -v higgsfield >/dev/null 2>&1 && higgsfield --version   # installed?
higgsfield account status                                       # logged in? → "email - plan, N credits"
```

- `account status` prints `email - plan, N credits` → **already connected.** Skip to Phase 2. (Optionally greet with the credit balance.)
- `higgsfield` missing, or `account status` returns `Error: Not authenticated. Hint: Run: hf auth login` → run Phase 1.

## PHASE 1 - Install & Log in (autonomous via Playwright)

### Step 1 - Orient the user

> "I'll connect your Higgsfield now so I can generate video and image creative for you. I'll open a sign-in window in a moment - just approve it there and I'll handle the rest. About a minute."

### Step 2 - Install the CLI (silent)

```bash
npm install -g @higgsfield/cli      # binary: higgsfield (aliases: higgs, hf)
higgsfield --version                 # confirm, e.g. "higgsfield 0.1.40 …"
```

- **`EACCES` / `EPERM`** on global install → translate ("your computer needs a small permission fix"), apply `first-run-setup` guidance (or a Node version manager), retry once.

### Step 3 - Log in (browser device flow, Playwright-driven)

`higgsfield auth login` is a **blocking** device login. **Captured output shape (v0.1.40):**

```
Opening browser for authentication...
If browser does not open, visit: https://higgsfield.ai/device?code=<CODE>
Waiting for approval...
```

Drive it:

1. **Start login in the background** (it blocks, polling, until approval) and capture the `https://higgsfield.ai/device?code=…` URL it prints:
   ```bash
   higgsfield auth login > /tmp/hf_login.out 2>&1 &     # backgrounded; it polls for approval
   ```
   Read `/tmp/hf_login.out`, extract the `higgsfield.ai/device?code=…` URL.
2. **Open the URL in Playwright:**
   ```
   mcp__playwright__browser_navigate({ url: <device_url> })
   mcp__playwright__browser_snapshot()
   ```
   - **Not signed in** (redirects to `higgsfield.ai/auth/sign-in?...`) → tell the user *once*: *"Please sign in to your Higgsfield account in the window I opened - I'll wait."* Then `browser_wait_for` the device-approval screen.
   - **Signed in** → an approval screen for the device code. Click the **Approve / Confirm** button (re-snapshot to get the ref; verify the on-screen code matches the one in the printed URL).
3. **Confirm completion.** On approval the backgrounded `auth login` prints `Successfully authenticated.` and exits 0. Verify:
   ```bash
   higgsfield account status      # → "email - plan, N credits"
   ```

If `account status` still errors, re-run Step 3 once. If it persists, surface in plain English and stop.

> **Team billing (optional).** If the user works under a team workspace, `higgsfield workspace list` / `workspace set <id>` selects it; `workspace status` shows the current one; `workspace unset` returns to the personal account.

### Success message

> "All done - your Higgsfield is connected! You've got **N credits**. You can ask me to 'make a cinematic product video', 'turn this photo into a 5-second video ad', or 'generate 3 image variations for a social ad'. (Each generation uses a few credits - I'll always tell you the cost first.)"

## PHASE 2 - Operate (verified `@higgsfield/cli` v0.1.40)

Top-level commands: `account`, `auth`, `generate`, `model`, `upload`, `soul-id`, `workspace`, `marketing-studio`, `marketplace-cards`, `product-photoshoot`, `version`. Global flags: `--json` (raw JSON), `--no-color`.

### Account & credits

| Command | Description |
|---|---|
| `higgsfield account status` | Email, plan, available **credits** |
| `higgsfield account transactions [--size 50]` | Recent credit transactions |

### Discover models - `higgsfield model`

```bash
higgsfield model list                 # all models (image / video / text)
higgsfield model list --video         # filter: --image | --video | --text
higgsfield model get nano_banana_2    # a model's params, defaults, media type (job_set_type)
```

Models are referenced by their **job_set_type** (the left column of `model list`), e.g. `nano_banana_2` (Nano Banana Pro), `flux_2`, `seedream_v4_5`, `cinematic_studio_2_5`, plus video models (`model list --video`). Always `model get <type>` to learn a model's accepted `--params` before composing a non-trivial generation.

### Generate - `higgsfield generate` (alias `gen`) - the core

```bash
# Estimate FIRST (no job created, no credits spent):
higgsfield generate cost <job_set_type> --prompt "..." [--param value]...

# Create a job. Params are --name value. Media flags accept a UUID (upload id or job id)
# OR a local file path (auto-uploaded): --image --start-image --end-image --video --audio.
higgsfield generate create <job_set_type> --prompt "..." [--param value]... [media flags]
higgsfield generate create <job_set_type> --prompt "..." --image ./photo.png --wait    # block + print result URL(s)
higgsfield generate create <video_model> --prompt "..." --wait --wait-timeout 20m --wait-interval 5s

# Poll an existing job:
higgsfield generate wait <job_id> [--timeout 10m] [--interval 3s] [--quiet]
higgsfield generate get  <job_id> [--json]
higgsfield generate list [--image|--video|--text] [--size 20] [--json]
```

- **`--wait`** on `create` blocks until the job finishes and prints the **result URL(s)** - the simplest path. Without `--wait`, `create` returns a job id; poll with `generate wait`/`get`.
- **Media inputs auto-upload**: pass a local path to `--image` etc. and the CLI uploads it for you (no separate `upload` step needed). For image→video, pass the source image to a video model's `--image`/`--start-image`.

**Captured response shape** (`generate get <id> --json`, live 2026-06-08):
```json
{
  "id": "…", "status": "completed", "display_name": "Nano Banana Pro",
  "job_set_type": "nano_banana_2",
  "result_url": "https://…cloudfront.net/…/hf_….png",
  "created_at": 1780915353.5,
  "params": { "prompt": "…", "width": 2048, "height": 2048, "aspect_ratio": "1:1",
              "resolution": "2k", "batch_size": 1, "input_images": [], "input_image": null }
}
```
`status` progresses to `completed`; the output is at `result_url` (a public CloudFront URL - download with `curl`/browser). `generate list` returns an array of these.

### Upload inputs - `higgsfield upload`

```bash
higgsfield upload create ./input.png      # → an upload UUID for reuse across generations
higgsfield upload list [--image|--video] [--size 50]
```
(Optional - `generate`'s media flags already auto-upload local paths. Use `upload` when reusing the same asset across many jobs.)

### Soul characters (face-faithful identity) - `higgsfield soul-id`

```bash
higgsfield soul-id create --name Alice --soul-2 --image <id1> --image <id2> --image <id3> --image <id4> --image <id5>
higgsfield soul-id wait <soul_id>     # training is async
higgsfield soul-id list / get <soul_id>
```
Trains a reusable character reference from 3-5 images, usable in Soul image models (e.g. `text2image_soul_v2`, `soul_cinematic`).

### Higher-level enhanced flows

- `higgsfield product-photoshoot …` - brand-quality product image generation with mode-specific prompt enhancement.
- `higgsfield marketing-studio …` - Marketing Studio assets.
- `higgsfield marketplace-cards …` - marketplace product cards via backend prompt enhancement.

Run `higgsfield <command> --help` to see each one's parameters before use.

## Prompt-to-command mapping

| What the user says | Command |
|---|---|
| "Connect / set up Higgsfield" | **Run Phase 1** |
| "How many credits do I have?" | `higgsfield account status` |
| "What models can I use?" / "video models?" | `higgsfield model list [--video]` → `model get <type>` for params |
| "Make a cinematic product photo of X" | `generate cost` → **CONFIRM cost** → `generate create <image_model> --prompt "…" --wait` |
| "Turn this photo into a video ad" | `generate cost <video_model> --image ./photo.png …` → **CONFIRM** → `generate create … --image ./photo.png --wait` |
| "Generate 3 variations" | `model get` (check a `batch_size`/count param) or run N creates → **CONFIRM total cost** |
| "Is that contract/photo still generating?" / "check job X" | `generate get <id>` (or `generate wait <id>`) |
| "Show my recent generations" | `generate list [--image|--video]` |
| "Make a character from these photos" | `soul-id create --name … --image …×3-5` → `soul-id wait` |
| "Brand product shoot" | `product-photoshoot --help` → **CONFIRM** → run |
| "Disconnect Higgsfield" | `higgsfield auth logout` |

## Error Handling (Phase 2)

Diagnose and respond in plain English; never show raw errors.

| Error | What to say | Fix |
|---|---|---|
| `Not authenticated. Hint: Run: hf auth login` | "Your Higgsfield connection needs a quick refresh - one moment." | Re-run Phase 1 Step 3 |
| Insufficient credits | "You're out of Higgsfield credits for that - you'd need to top up your plan to generate more." | User tops up; offer a cheaper/smaller model meanwhile |
| `Error: NSFW content detected` (at `cost`/`create`) | "Higgsfield's content rules won't allow generating from that image - for example, photos of children are blocked." | Platform input-safety guardrail. **Do not** try to bypass it (re-crop, reword, switch models). Surface plainly and stop; suggest a different (e.g. adult / product) source if appropriate |
| `Unknown model …. Run: … model list` | (silent) | `higgsfield model list` to get the right `job_set_type` |
| Bad/missing param | "That model needs a different setting - let me check what it accepts." | `higgsfield model get <type>` then reformat the call |
| Job failed / timed out on `wait` | "That generation didn't complete - let me retry it." | `generate get <id>` to inspect; retry once with a longer `--timeout` |

## Scope Limitations

**Can** (verified): generate images & videos from text and/or input media (auto-uploaded local files), estimate credit cost, poll async jobs, browse the model catalog + params, upload/reuse media, train Soul character refs, run Marketing Studio / product-photoshoot / marketplace-card flows, select a team workspace.

**Cannot / constraints:**
- **Credit-gated** - every generation spends credits; nothing is free. No bypass.
- **Async only** - generation is submit-and-poll (use `--wait` to block).
- **No token in any shared config** - by design (local `0600` credentials file).
- Output is delivered as a **result URL** (CloudFront); the CLI does not edit/host beyond that - download the asset to use it elsewhere.
- Video length / resolution caps are model-specific - check `model get <type>`.

## Behaviour Guidelines (Phase 2)

- **Always estimate and state the credit cost before generating.** Run `generate cost …` and tell the user (e.g. *"This will use 2 credits - you have 8. Go ahead?"*) before `generate create`. Confirm before any multi-job / batch run (state the **total**).
- **Check the balance** (`account status`) when credits look low, and surface it.
- **Discover before composing** - `model list` / `model get <type>` to get the real `job_set_type` and accepted params before a non-trivial generation; don't guess param names.
- **Prefer `--wait`** for single jobs (simplest); for long video jobs use a generous `--wait-timeout`.
- **Never echo the token** or read the credentials file into chat.
- **Present outputs as the result URL** (and offer to download). Don't dump raw JSON - summarise (model, status, link).

## Related Skills

- **ad-creative** - write the ad copy/concept, then render it here as Higgsfield video/image creative
- **social-content** - turn social posts into Higgsfield mobile-first video/image ads
- **hyperframes-cli** - sibling media CLI; Higgsfield for cinematic AI gen, HyperFrames for programmatic/templated video
- **playwright-skill** - drives the Higgsfield device-login approval screen
- **first-run-setup** - conversational-bootstrap pattern Phase 1 follows
