---
name: higgsfield-connector
description: "Connect Higgsfield to Claude by installing and authenticating the `higgsfield` CLI. Use when the user asks to set up Higgsfield, or wants cinematic AI image or video generation (ad creative, product shots, photo-to-video, social variations) and the `higgsfield` CLI isn't signed in yet. Once connected, Higgsfield runs directly through the `higgsfield` CLI."
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
      reason: The Playwright MCP browser drives the Higgsfield browser sign-in and approval screens
---

# Higgsfield Connector

> **Install pattern:** CLI-based (first-party CLI + browser OAuth), like `google-chat-connector` (`gws`), `quickbooks-connector` (`qbo`), and `notion-connector` (`ntn`). Not a hosted-MCP or plugin connector.

## Overview

This skill connects and operates **Higgsfield** - a cinematic AI image + video generation platform - through its official CLI, `higgsfield` (npm package `@higgsfield/cli`, https://higgsfield.ai/cli; binary aliases `higgsfield`, `higgs`, `hf`). Two phases:

- **Phase 1 - Install & Log in (autonomous via Playwright).** Claude installs the CLI and runs `higgsfield auth login`. Keep that process running while Claude opens its exact printed sign-in URL in a browser for the intended Higgsfield account and completes the sign-in and approval steps. The CLI manages the local credentials; the browser flow depends on the installed version. **No token in `~/.claude.json`, no API key to paste.**
- **Phase 2 - Operate.** Claude runs `higgsfield` commands to generate images/videos, estimate credit cost, poll async jobs, browse models, upload inputs, train Soul character references, and run Marketing Studio flows.

Claude handles the browser steps its available tools support; ask the user only for sign-in or approval steps that require their input.

**Generation is credit-based and asynchronous.** Every generation spends credits (check `higgsfield account status` for balance; `higgsfield generate cost …` to estimate before spending). Jobs run async - submit and poll, or use `--wait` to block.

### Why the CLI

- **No secret pasted into shared config.** The token lives in a local `0600` credentials file the CLI manages, not as a Bearer line in `~/.claude.json`.
- **First-party + grounded.** Phase 2 commands were verified against v0.1.40 (real `--help` + a live image generation smoke). Login was also observed on v1.1.24: it opens a Clerk OAuth URL with a local callback, rather than the older device-code page. Check the installed version's help when behaviour differs. The [official CLI guide](https://higgsfield.ai/cli) documents browser sign-in; the [official CLI repository](https://github.com/higgsfield-ai/cli) documents account and workspace commands.

### What this skill does NOT use

- No `claude mcp add` / MCP server, no Claude Code plugin, no manual API-key entry.

## Security rules

- **Never echo the token.** `higgsfield auth token` prints the raw access token - do not run it in a way that surfaces the value to the user, and never paste it into chat. `higgsfield auth logout` deletes the local token.
- The credentials file (`~/.config/higgsfield/credentials.json`) is a secret: never read it back into chat, never commit or sync it.
- Never print `~/.claude.json`.

## Communication rules (non-technical user)

The user is a non-technical business owner. Claude does the installation, navigation, and verification; the user supplies any sign-in or approval input the available tools cannot complete. Every message:

- **You drive, not them.** When user input is needed, name the exact short step, such as "please sign in in the window I opened."
- **Plain English only.** No jargon - never say CLI, npm, OAuth, device code, token, API, terminal, JSON, credits-API. The browser window is "a sign-in window I opened"; the connection is "your Higgsfield connection". (You *may* say "credits" - users understand that.)
- **Narrate at action boundaries** (start / need-you / done). **Short messages** (≤8 lines). **Never show raw errors** - translate to plain English.
- **Always state credit cost before generating** (see Behaviour Guidelines).

## PHASE 0 - Resume check (silent)

```bash
command -v higgsfield >/dev/null 2>&1 && higgsfield --version   # installed?
higgsfield account status                                       # verify the actual account and credits
```

- `account status` succeeds with the intended account/workspace and credit balance → **already connected.** Skip to Phase 2. Output wording can vary by version; do not require one exact sentence.
- `higgsfield` missing → install in Phase 1. `Not authenticated` or `Session expired` → run Step 3 without reinstalling.
- `No workspace selected` → run `higgsfield workspace list`. If that read requires authentication, run Step 3; otherwise select the intended workspace as described below, then retry `account status`. This error alone proves neither a connected account nor invalid credentials.
- Other errors → investigate the actual failure; do not restart authentication indiscriminately. These checks must run in the skill caller's environment. Its Higgsfield account is independent of the Claude login and another terminal's configuration.

## PHASE 1 - Install & Log in (autonomous via Playwright)

### Step 1 - Orient the user

> "I'll connect your Higgsfield now so I can generate video and image creative for you. I'll open a sign-in window in a moment - just approve it there and I'll handle the rest. About a minute."

### Step 2 - Install the CLI (silent)

```bash
npm install -g @higgsfield/cli      # binary: higgsfield (aliases: higgs, hf)
higgsfield --version                 # confirm, e.g. "higgsfield 0.1.40 …"
```

- **`EACCES` / `EPERM`** on global install → translate ("your computer needs a small permission fix"), install via a Node version manager rather than a global sudo install (see `docs/start/setup.md` Step 0), retry once.

### Step 3 - Log in (browser sign-in, Playwright-driven)

1. **Start and retain the login process.** Check `higgsfield auth login --help`. When the user needs their everyday browser left untouched, use a documented browser-suppression option if available; otherwise, on macOS, follow [the verified process-local opener capture](references/background-login.md) before starting login. It automatically captures the opener for the verified 1.1.24 binary without changing browser defaults. For unverified binaries or other platforms, verify a supported isolation method before starting an auto-opening login under that constraint. Run the chosen login command in the harness's persistent terminal/background-task facility. Retain its task/session ID and read its output while it waits; do not impose a short timeout or launch a bare shell `&` job that may die when the tool returns. If capturing output to a file is necessary, use a unique temporary file with owner-only permissions, not a shared fixed `/tmp/hf_login.out` path. Do not expose the full sign-in URL in user-facing messages.
2. **Open the exact URL emitted by this running process.** Use its private opener capture when following the background route, otherwise its printed URL. Preserve every query parameter; do not construct a device URL or reuse a URL from a previous attempt. Use an isolated browser session on the same computer as the CLI, or a session already signed in to the intended Higgsfield account. On the normal auto-opening route, do not approve a different account in the everyday browser.
   - **Current browser callback flow (observed v1.1.24):** the printed URL starts `https://clerk.higgsfield.ai/oauth/authorize?...` and redirects to Higgsfield sign-in/consent. The observed callback was `http://localhost:8765/callback`, with a listener at `127.0.0.1:8765`; use the callback issued by the running CLI, not a hardcoded port. Keep the process alive through sign-in, consent, and the browser's callback. Do not substitute a callback URL or manually submit an authorization code.
   - **Older device flow (observed v0.1.40):** only if the CLI actually prints `https://higgsfield.ai/device?code=…`, open that URL and approve the displayed device code after checking it matches. Do not wait for a device-code screen during the current callback flow.
   - Drive the available browser tools through the visible sign-in and consent screens, checking the intended Higgsfield account before approval. Ask once for any input only the user can provide, then continue from the resulting screen. If no browser tool is available, open the emitted URL with an available browser-opening tool and give the user the exact short sign-in step.
3. **Confirm completion in the same caller environment.** Wait for the retained login task to finish successfully, then run `higgsfield account status`. A signed-in website or successful login exit alone is not a working connection. If the read reports `No workspace selected`, run `higgsfield workspace list`, select the intended workspace with `higgsfield workspace set <id>`, and retry `account status`. Preserve a working selection; if several workspaces remain plausible, ask which to use rather than choosing a billing account arbitrarily. If the account identity is not included in the status output, use the confirmed browser identity and selected workspace alongside the successful credit-balance read. Do not generate anything as a connection test.

If login expires or the process exits before its callback, end only that attempt if still running, restart once, and open its newly printed URL. If the read specifically reports `Not authenticated` or `Session expired`, retry login once. For workspace-selection or other errors, resolve that reported condition instead of repeating sign-in. If the retry still fails, explain the specific blocker in plain English; do not claim success.

> **Team billing (optional).** `higgsfield workspace list` / `workspace set <id>` selects a team workspace; `workspace status` shows the current one. Older versions support `workspace unset` to return to the personal account; check installed help and verify `account status` afterwards rather than assuming an unset workspace works on every version.

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
- **playwright-skill** - drives the Higgsfield browser sign-in and approval screens
- **orientation** - conversational-bootstrap pattern Phase 1 follows
