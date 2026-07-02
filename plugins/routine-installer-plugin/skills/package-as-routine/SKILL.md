---
name: package-as-routine
description: Package one or more of the user's local skills, automations, or processes into a working Remote Routine on claude.ai/code/routines so it runs on a schedule in the cloud. Reach for this (NOT the built-in /schedule) whenever the thing being scheduled depends on the user's own tools, CLIs, sign-ins, or MCP servers. Those fail under a plain /schedule because the cloud sandbox starts clean and cannot see local credentials; this skill is what makes them actually run. It works out what the routine needs by introspecting the target's own files and the user's MCP config, generates the setup.sh and .mcp.json the sandbox needs, scaffolds the GitHub repo, then drives the claude.ai/code/routines UI end-to-end in a Playwright MCP browser to create the environment, stage the setup script and secrets, create the routine, and fire a verification run. Triggered by /package-as-routine, "package my <name> skill as a routine", "schedule my <name> skill", "turn my <name> skill or process into a routine", "put my <name> on a routine", "run my <name> on a schedule in the cloud", "automate my <name> so it runs when my computer is off", "make a routine from <name>", "deploy <name> to claude.ai routines". Use the built-in /schedule instead only for self-contained one-off prompt tasks that need no local tools or credentials.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, RemoteTrigger, mcp__playwright__*, mcp__plugin_playwright_playwright__*, mcp__playwright-iso__*
---

# package-as-routine

You drive the end-to-end packaging of a local Claude Code skill (or several) into a working Remote Routine on claude.ai/code/routines. From Phase 9 onward you **drive the claude.ai/code/routines UI yourself in a Playwright MCP browser** - you do not hand the user a list of clicks. This is the default and the point: the workshop pitch is "ask Claude and it does the whole thing." The user's only manual moments are signing in to claude.ai once in the Playwright window, and answering the occasional confirmation. Narrate at action boundaries so the flow stays followable, but you are the one navigating, typing, and clicking.

## Browser autonomy - drive Playwright, never the user's own browser

Per the workshop skill-autonomy rule: every UI step from Phase 9 on is performed by YOU inside the **Playwright MCP browser** (`mcp__playwright__*`, or the plugin/iso variants if that is what is connected). NEVER use Claude-in-Chrome, NEVER open or instruct the user to use their own default browser, NEVER ask the user to "go to claude.ai and click…". The user signs in once in the Playwright window (the persistent profile keeps the session for next time); everything else is yours.

If no Playwright MCP server is connected at Phase 9, say so plainly and fall back to the manual hand-off path (Appendix A) - but the Playwright path is the default and what the demo shows.

## Trust the helper scripts. Do NOT inline equivalent logic.

Every helper script under `scripts/` is **MANDATORY** when this skill says to call it. Sonnet has a documented tendency to skip past explicit script invocations and regenerate equivalent logic inline from memory - this causes silent regressions (JSON env-var truncation, helper-script bypass, missing the GHL response envelope, etc.). The helpers exist because each one solves a known footgun that inline logic re-introduces.

When this skill says "run `scripts/<name>.py`", you MUST shell out to that script. You may NOT:

- Read the file and reason about what it would output.
- Re-implement its logic in your head and emit the result.
- Skip it because "the user can just paste their creds directly."

If a helper errors, surface the error and ask the user - do not work around it silently.

## Inputs

The slash command may have passed one or more skill names. Look at `$ARGUMENTS`:

- Empty → ask the user; you'll run `discover_skills.py` shortly.
- One name → that's the skill to package.
- Multiple names (space-separated) → multi-skill routine; package them all into one repo.

## Working paths

| Purpose | Path |
|---|---|
| Plugin scripts | `${CLAUDE_PLUGIN_ROOT}/skills/package-as-routine/scripts/` (the skill invokes them as `scripts/<name>` relative to the plugin) |
| Connector library (optional accelerator) | set `ROUTINE_CONNECTORS_DIR` to a folder of connectors if you have one; if it is unset the resolution ladder handles every dependency |
| Scratch work for this packaging run | `~/.claude/routine-installer/<routine-slug>/` (create on demand) |
| Final repo (local) | `~/.claude/routine-installer/<routine-slug>-repo/` |

The `<routine-slug>` is the user-chosen routine name (derived from the skill if only one, else asked).

## The flow

### Phase 0 - confirm what we're packaging

If no skill name was supplied:

1. Run `scripts/discover_skills.py`. This script is **MANDATORY** - it reads the user's standard skill paths plus Selr's own product locations and emits a JSON list. Do not list skills from memory or guess paths.
2. Show the user the list (truncate to the top ~20 by alphabetical order; tell them how many were skipped).
3. Ask which skill(s) to package - accept multiple.

If a skill name was supplied via `$ARGUMENTS`:

1. Still run `discover_skills.py` to resolve the path. Confirm a match exists.
2. If multiple skills with the same name exist (e.g., a workshop-kit copy and a source-of-truth copy), ask the user which path is the right source.

State which skill(s) you're packaging and ask: "What should the routine be called?" Default to the skill name (e.g. `morning-brief`) but accept overrides. Slugify for the repo name.

Create the scratch folder: `~/.claude/routine-installer/<routine-slug>/`.

### Phase 1 - introspect each skill

For each selected skill:

1. Run `scripts/introspect_skill.py <skill-path> > <scratch>/<skill-name>.manifest.json`. **MANDATORY.**
2. Read the JSON output.

Then merge the per-skill manifests into one union manifest (write to `<scratch>/manifest.json`):

- `mcp_servers`: union of all server names
- `clis`: union of all CLI names
- `env_vars`: union
- `asset_paths`: union (kept for informational purposes; assets ship with the skill folders verbatim)
- `script_files`: union with original skill name prefix
- `name`: the routine slug
- `path`: the scratch folder

### Phase 2 - confirm the connections (plain English, catch omissions only)

The introspection is regex-based, so it can over-detect. **Use your own judgment first** - read the skill and silently drop anything that obviously isn't a real dependency (a brand named only in prose, a tool mentioned but never invoked). Do NOT show the user a raw dependency dump or ask them to validate it or hunt for false positives. Cleaning the list is your job, not theirs.

Then tell the user, in plain English, which **services** you'll connect to the cloud so the routine works up there. The ONLY purpose of this step is to catch a service the detector missed - nothing else.

Rules for what you show:
- List ONLY things that need a real connection: the MCP servers, and any CLIs that are not already built into the sandbox. **Skip the base tools** (`python3`, `node`, `npx`, `bash`, `sh`, `jq`, `curl`, `wget`, `git`) and **never mention** assets, script files, file names, the words "MCP" / "CLI", or the detector itself. The user does not care and will not understand.
- Translate each internal name to a friendly name plus what it is for. Known examples: `gws` → "Google Workspace (your email and calendar)", `ghl` → "GoHighLevel (your CRM contacts)", `notion` → "Notion". For a tool you do not recognise, give a short plain description of what it appears to do.

Phrase it like this:

> Here's what I'll connect to the cloud so your morning brief works there:
> - Google Workspace - your Gmail and Calendar
> - GoHighLevel - your CRM contacts
>
> Is there anything else this uses that I've missed? If not, I'll set it all up.

Ask ONLY that one question - "anything I've missed?". Do NOT ask them to confirm, approve, or correct what is already listed; do NOT ask about env-var names, setup scripts, or config. If they name a missing service, add it to `<scratch>/manifest.json` and re-write the file. Otherwise just continue - a non-answer or "looks good" means proceed.

### Phase 3 - resolve each dependency (you do the work, not the user)

Run `scripts/map_deps_to_connectors.py <scratch>/manifest.json --out <scratch>/resolution.json`. **MANDATORY.**

The `--out` flag writes the REAL resolution (which contains secret MCP header values) to the gitignored scratch file. What the script prints to your screen is **redacted** - secret values appear as `<redacted:N chars>`. This is deliberate: real credentials must never enter the chat. Read the redacted stdout to understand the structure; the next step reads the real values from the `--out` file. Do NOT `cat <scratch>/resolution.json` - that would dump the real secrets into the conversation.

The resolution JSON has:

- `matched_connectors`: dependencies that are already set up as connectors in the user's connector library (a fast path when it exists). Each has `dep_name`, `connector_path`, `detect_passed` (true if the user is signed in locally), `has_routine_export`, `has_routine_restore`.
- `unmatched_clis`: tools the skill uses that the library didn't already know about. These are still connectors - you resolve them with the ladder below.
- `base_tools`: tools the sandbox already has (python3, node, npx, bash, jq, curl, wget, git). Nothing to do.
- `mcp_servers`: HTTP and stdio MCPs from `~/.claude.json` filtered to those the skill uses. HTTP entries have an `env_var_headers` list (which header values need to move to env vars).
- `unknown_mcps`: MCPs the skill names but that aren't in `~/.claude.json` yet. Resolve with the ladder, don't block.

**The connector library is an optional accelerator, not the source of truth.** A connector library may not exist on this machine - that is completely fine and expected (set `ROUTINE_CONNECTORS_DIR` to point at one if you have it). When a dependency is already in the library with routine scripts, use it. For everything else, resolve it YOURSELF with the ladder below. The user is non-technical: figuring this out is your job, not theirs. Never abort with "I can't proceed," and never ask the user a technical question.

**Resolution ladder - for each tool not already handled by the library (and any matched connector missing routine scripts), work top to bottom. Do as much as you can silently; only involve the user at the very bottom, in plain English.**

1. **How to install it in the sandbox.** Run `which <tool>` and follow the real binary: under `node_modules/<pkg>/` means an npm package (`npm install -g <pkg>`); a pipx venv means `pipx install <pkg>`; a Homebrew path means it won't exist in the Linux sandbox, so find the apt/npm/curl equivalent.

2. **How it signs in (credentials).** Prefer the tool's OWN export command over copying raw files: try `<tool> auth export`, `<tool> auth print-access-token`, `<tool> config ...`, or check `<tool> --help` for an export/print command. Only if there is no export command, look at the real config locations (`~/.config/<tool>/`, `~/.<tool>/`) and take a file that is actually portable. NEVER ship an encrypted file (e.g. `*.enc`) or a device-bound cache (`token_cache*`): those are tied to this machine's keychain and will silently fail in the cloud. The portable value becomes one env var the user pastes once (Phase 9, via clipboard, never echoed).

   **Stop at the first approach that round-trips - do NOT escalate.** Once an export command gives you a credential that passes the round-trip test below, that IS the credential: ship it and move on. Do not then go "deeper" by also reading the OS keychain, copying `*.enc` files, or transplanting an encryption key - that is more fragile AND it can trigger an operating-system permission prompt (see the third trap). The export command already decrypts internally; reproducing its encrypted state by hand is unnecessary work that makes the setup worse.

   Three traps that have bitten real runs:
   - **Exports may MASK secrets.** Some export commands print placeholders (e.g. `gws auth export` shows an 11-char `***********` instead of the real 35-char client secret). If a field looks suspiciously short or low-entropy, look for an unmasked flag (`--unmasked`, `--show-secrets`, `--plaintext`) and use it. A masked credential authenticates locally but fails in the cloud with "invalid secret".
   - **ALWAYS round-trip-test the restore before shipping it.** Replay the exact sandbox restore locally in a throwaway dir (e.g. `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=/tmp/x GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws auth status`) with ONLY the exported file present, then make one real API call. This is the cheapest way to catch a masked export, a device-bound file, or a keyring mismatch before it reaches the cloud. Use a temp config dir so you never touch the user's real keychain.
   - **Never run a command that triggers an OS keychain / permission prompt.** Reading the user's keychain directly - e.g. macOS `security find-generic-password`, `security unlock-keychain`, or a Linux Secret Service / `secret-tool` call - pops an OS dialog the (non-technical) user does not expect, and is a blocker for an unattended run. It is also unnecessary: if `<tool> auth export` works, use that (it decrypts via the tool itself, no prompt). Concretely for `gws`: use `gws auth export --unmasked` (the portable ADC JSON of client_id + client_secret + refresh_token, delivered base64) and STOP - do NOT `security find-generic-password -s gws-cli` to transplant the raw `.encryption_key` + `credentials.enc`. Both authenticate in the cloud, but only the keychain route triggers a macOS prompt.

   **JSON / quoted credentials → deliver as base64.** The routine's env-var field is `.env` format and chokes on embedded double-quotes, so a raw JSON credential (e.g. Google ADC) will not survive it - even compacted to one line. Base64-encode the credential into the env var (`base64 | tr -d '\n'`, name it `<TOOL>_..._B64`) and have the restore step `base64 -d` it back to the file the CLI expects. Simple single-token credentials (a PIT, an API key) go in plain.

3. **If neither applies, research the connector.** Use what you know about that specific tool, and a quick web/doc check if needed, to find where its credentials live and how to get a portable copy. This is your job - do not hand it to the user.

4. **Last resort only: one plain-English question.** No jargon, ever. The user cannot answer technical questions and should never be asked one.
   - Do NOT ask: "Where does the JSON config for your gws OAuth live?" / "What env var holds the token?"
   - DO ask, in their world: "I need to connect your Google account so this can run in the cloud - are you signed in to Google on this computer right now?" or "I couldn't set up <tool> on my own. In one sentence, what do you use <tool> for?"

Record what you resolved for each tool (install line + how its credentials are obtained) so Phase 5 (setup.sh) and Phase 9 (paste the secrets) can use it.

**`unknown_mcp` servers:** don't ask a technical question. Check whether it's a connector the user enabled in claude.ai, research how it's configured, and resolve it. Only ask the user in plain English if you genuinely cannot.

**Matched connectors where `detect_passed` is false** (the user isn't signed in to that tool locally): tell them in plain English which account to sign into and offer to help, e.g. "I need you signed in to Google on this computer first - want me to open that for you?" Then re-run the resolver. Do not show them CLI commands unless they ask.

### Phase 4 - generate `.mcp.json` and the env-var manifest

Run `scripts/generate_mcp_json.py <scratch>/resolution.json --out <scratch>/mcp-bundle.json`. **MANDATORY.**

The `--out` flag writes the REAL bundle (env-var values are secrets) to the gitignored scratch file. Stdout is **redacted** - env-var `value` fields show as `<redacted:N chars>`, but the `mcp_json` portion (placeholders only, no secrets) prints in full. Do NOT `cat <scratch>/mcp-bundle.json`. The bundle has two top-level fields:

- `mcp_json` - the `.mcp.json` content (with `${ENV_VAR}` substitution for user-specific headers). No secrets; safe to display.
- `env_vars` - list of `{name, value, purpose}` records the user must paste into the routine env config. `value` is a real secret - never echo it; in Phase 9 you pipe it straight to the clipboard.

The default env-var names are sensible (`Authorization` -> `<SERVER>_TOKEN`, camelCase headers split, e.g. `locationId` -> `<SERVER>_LOCATION_ID`). **Use them. Do not ask the user to approve or rename them** - env-var naming is a technical detail a non-technical user cannot meaningfully answer, and choosing a sensible default is your job, not theirs.

The only exception: if the user has *already volunteered* a naming convention earlier in this conversation (e.g. they mentioned another routine that uses `GHL_PIT_TOKEN`), match it - write a `<scratch>/name-overrides.json` mapping `<server>.<header>` to the desired name and re-run `generate_mcp_json.py` with `--name-overrides`. Otherwise proceed with the defaults without comment.

Write the `mcp_json` field to `<scratch>/.mcp.json` (extract it from the `--out` bundle file, or copy the visible `mcp_json` from stdout since it has no secrets).

### Phase 5 - generate `setup.sh` and the credential-restore script

Run `scripts/generate_setup_sh.py <scratch>/resolution.json --setup-out <scratch>/setup.sh --restore-out <scratch>/restore-credentials.sh`. **MANDATORY.** Use `--setup-out` - do NOT pipe setup.sh through a shell redirect (`> setup.sh`), and never add `2>&1`: the script prints a one-line diagnostic to stderr, and a redirect (especially `2>&1`) captures that stray line into setup.sh. This produces TWO files:

- `setup.sh` - **install only** (CLIs, packages). Runs in the sandbox BEFORE Claude Code starts.
- `restore-credentials.sh` - **credential restore**. Runs INSIDE the agent session via a SessionStart hook (Phase 7 wires it into `.claude/settings.json`).

**Why the split is load-bearing (this caused a real first-run failure):** the routine's "Environment variables" are injected into the Claude Code **agent session**, NOT into the pre-launch setup script. A `setup.sh` that does `printf "$MY_SECRET" > creds` silently writes nothing - it hits the empty-variable branch, still exits 0, and shows "Ran setup script - Completed", while the agent then finds no credential and the skill fails or falls back to a degraded path. The restore MUST run where the env vars exist: the agent session. The SessionStart hook is exactly that. (`setup.sh` is still the right place to *install* a CLI - that needs no secrets.)

**For a ladder-resolved credential (no matched connector), write the decode into `restore-credentials.sh` yourself.** The generator leaves a placeholder when nothing matched. Append the decode command(s) the resolution found in Phase 3. For a base64-delivered JSON credential the pattern is:

```
mkdir -p "$HOME/.config/<tool>" && \
  printf '%s' "$<TOOL>_..._B64" | base64 -d > "$HOME/.config/<tool>/credentials.json" && \
  chmod 600 "$HOME/.config/<tool>/credentials.json" && \
  echo "[restore-credentials] <tool> restored ($(wc -c < "$HOME/.config/<tool>/credentials.json") bytes)"
```

Use `$HOME` (the sandbox agent runs as `HOME=/root`, while the repo is checked out elsewhere - `$HOME` lands it in the path the CLI reads). The script references env-var NAMES only, never secret values, so it is safe to commit.

**Do not ask the user to review or approve either script** - they cannot meaningfully evaluate a shell script, and asking is exactly the kind of technical question to avoid. If introspection shows the skill needs a system package the sandbox lacks (e.g. an `apt-get install -y` line), add it to `setup.sh` yourself. Say in one plain sentence that the setup is prepared, then move on - no question.

### Phase 6 - collect env vars from connectors

For each matched connector (in `resolution.json`) where `has_routine_export` is true:

1. Run `bash <connector-path>/routine-export.sh > <scratch>/<connector>.env`. **MANDATORY.** The output is one `KEY=value` line per env var, and the VALUE is a real credential. Redirect it to the scratch file; do NOT print it to the chat. Confirm only the key name and byte-length (e.g. `wc -c`), never the value.
2. Record each captured env var (name + which scratch file holds it) alongside the `env_vars` from Phase 4. Each connector var gets `purpose: "<connector-name> connector credential"`.

Also include any env vars the user named during MCP overrides.

You now have the full env-var manifest. Save the NAMES + purposes (not values) to `<scratch>/env-vars-manifest.json` for your own reference. The real values stay only in the `--out` bundle file and the connector `.env` files in scratch - never in chat.

### Phase 7 - scaffold the repo locally

Run `scripts/scaffold_repo.sh` with these arguments:

```
--target ~/.claude/routine-installer/<routine-slug>-repo
--setup-sh <scratch>/setup.sh
--mcp-json <scratch>/.mcp.json
--restore-sh <scratch>/restore-credentials.sh
--skill <path-to-skill-1> [--skill <path-to-skill-2> ...]
```

**MANDATORY.** Do not assemble the repo manually with `mkdir` and `cp` - `scaffold_repo.sh` enforces the canonical layout, makes the right files executable, writes a sensible default README, writes `.claude/settings.json` (which pre-approves the skill's tools so cloud runs never pause on a permission prompt), and does the initial git commit. Passing `--restore-sh` ships `restore-credentials.sh` into the repo and wires the **SessionStart hook** in `.claude/settings.json` so the credential decode runs in the agent context every run - without it, an env-var-delivered credential will not be restored (see Phase 5). Always pass it when Phase 5 produced a restore script.

Do not ask the user to review the repo contents - there is nothing for them to approve. State in one plain sentence that the routine package is built, and move on.

### Phase 8 - push to GitHub

This phase bit the first test hard: a wrong `gh` active account and a missing GitHub-App install cost ~130 messages of flailing. Run the pre-flight checks FIRST and fail fast with a clear instruction rather than guessing.

**Pre-flight (do all of this before `gh repo create`):**

1. **Confirm the active gh account.** Run `gh auth status`. If more than one account is listed, state explicitly which one is active and will own the repo, and confirm with the user. If they want a different one, `gh auth switch` first. (In the test, the active account had silently flipped overnight - this check catches that instantly.)
2. **Decide the owner.** Ask which org/user the repo lives under. Default to the active login from `gh api user --jq .login`.
3. **Warn about routine reachability up front.** State plainly: "claude.ai routines can only see a repo if the **Claude GitHub App** is installed on that owner account with access to the repo. A private repo on an owner without the App installed will be **invisible** in the routine repo-picker." Offer to verify before pushing: open `https://github.com/settings/installations` (for a user) or the org's installations page and check the Claude app is present with access. If it is not, the fix is a one-time install at `https://github.com/apps/claude/installations/new` - note that any GitHub 2FA / "Confirm access" gate there is user-only (you cannot clear it).

Only once the account + owner + App-reachability are settled, push:

```
cd <repo-path>
gh repo create <org>/<name> --private --source=. --remote=origin --push
```

**Behavioural rule for this phase (and Phase 9):** when something is missing or access fails - a repo not appearing, a 403, an empty dropdown - **investigate in the browser/CLI before offering the user a remediation choice.** Do not present a fix built on an unverified theory. The test's worst moments were jumping to AskUserQuestion with a wrong root cause; one investigation step would have avoided each.

If the user opts out of pushing now, leave the local repo intact and tell them how to push later: "Run `cd <repo-path> && gh repo create <org>/<name> --private --source=. --remote=origin --push` when ready."

### Phase 9 - drive the routines UI in a Playwright browser

**You drive this whole phase in the Playwright MCP browser.** Do not narrate clicks for the user to perform. The reasoning model is the same as the workshop connector skills: each step describes a GOAL - achieve it via `browser_snapshot` → reason from the live snapshot → `browser_click` / `browser_type` / `browser_select_option` / `browser_evaluate`. Match controls by their visible labels, not by hard-coded selectors; the routines UI changes. Re-snapshot after each meaningful action to confirm state changed before moving on. Never assert a button's colour or position you have not seen in a snapshot.

Tool names below use the `mcp__playwright__*` prefix; if the connected server is the plugin or iso variant, use that prefix instead (`mcp__plugin_playwright_playwright__*` / `mcp__playwright-iso__*`). Pick whichever Playwright server is actually connected and use it consistently.

#### 9.0 - open and sign in (one-time human moment)

Narrate once: *"Opening a browser window - please sign in to claude.ai when it appears. I'll do the rest."*

`browser_navigate({ url: "https://claude.ai/code/routines" })`, then `browser_snapshot()`. Reason from it:

- **Logged in** (you can see Environments / Routines UI) → continue.
- **Not logged in** (sign-in / login form) → do NOT ask the user to confirm step by step. Poll silently with `browser_wait_for({ text: "Routines" })` (or "Environments") until the signed-in UI appears. The persistent Playwright profile keeps the session for future runs, so this is usually a first-run-only step.
- If `browser_wait_for` times out (5+ min), check in once: *"Still on the sign-in page - anything I can help with?"*

#### 9a - create the environment

Goal: a new environment named `<routine-slug>-env`.

**There is no separate "Environments" page or nav item in this UI** (a `/code/environments` URL just parses as a session id - do not go there). The environment is created INLINE inside the routine form: click **"New routine"**, then on the form open the **Environment** dropdown (it reads "Default"), and click **"Add environment"** / **"New environment"** at the bottom. That opens the "New cloud environment" dialog with Name, Network access, Environment variables, and Setup script fields. Type the name via `browser_type` (the env NAME is not a secret). You will fill Network access (9c), the setup script (9d) and the env vars (9e) in this same dialog, then save it and select it back on the routine form.

Note: this dialog's env-vars field is the ONLY place secrets go - there is no separate masked secret store in the current UI. For a private single-user environment that is acceptable (only the owner can read it); the "visible to anyone using this environment" warning is about shared/team environments. Do not waste steps hunting for a separate secrets vault.

#### 9b - connect the repo

Goal: the GitHub Repository field set to `https://github.com/<org>/<name>` (or the owner/name picker selection). If the repo does not appear in a picker, this is the App-reachability issue from Phase 8 - stop and resolve it (do not guess); see the failure-modes table.

#### 9c - network access

Goal: the environment's **Network access** set to **Full** (the control is labelled "Network access" with options None / Trusted / Full / Custom; it may also appear as "Trusted Domains" in some builds). The default, **Trusted**, only allows package downloads and silently 0-bytes every HTTP MCP call (e.g. GHL) and every Google API call - so this step is load-bearing. A Custom allowlist is brittle for Google (token refresh, Gmail and Calendar sit on different hosts), so prefer **Full** for a private routine hitting the user's own accounts. Snapshot to confirm the setting changed.

#### 9c2 - make the routine run without permission prompts

Goal: the routine can use every tool its skill needs without pausing to ask. A scheduled run has no human to click "Allow", so a single permission prompt (typically the first MCP tool call, e.g. GHL) stalls the whole run. The scaffolded repo already ships `.claude/settings.json` that pre-approves the tools, which is the durable fix. As a backstop, on the routine's **Permissions** (or Behavior) tab choose the most permissive option available - "Allow all tools" / skip permission prompts / autonomous. Snapshot to confirm the setting changed. If there is no such control in the UI, the repo `.claude/settings.json` covers it - do not block on this.

#### 9d - paste the setup script (not a secret)

`setup.sh` contains no secrets (it is install-only placeholders), so you may set it directly. Read `<scratch>/setup.sh`, locate the "Setup script" field, and fill it. Prefer the paste pattern (9e) for reliability with large multi-line content, or `browser_evaluate` to set the textarea value and dispatch an `input` event so the UI registers it. Snapshot to confirm it landed.

The credential-restore script does NOT go in this field - it ships inside the repo (`.claude/restore-credentials.sh`) and runs via the SessionStart hook, so there is nothing extra to paste here for it.

#### 9e - add the env vars (secret-safe clipboard → paste)

This is the one place secrets touch the browser. **The secret value must never enter your context or a tool-call argument** - so do NOT read the value and `browser_type` it. Instead, put it on the OS clipboard from the scratch file (the value never returns to you) and paste it with a keystroke.

For each env var (do them one at a time; narrate the NAME only):

1. **Stage the value on the clipboard - never to stdout.** The pipe consumes the value; nothing returns to your context:

   - MCP env var: `python3 -c "import json,sys; [sys.stdout.write(v['value']) for v in json.load(open('<scratch>/mcp-bundle.json'))['env_vars'] if v['name']=='<NAME>']" | pbcopy`
   - Connector `.env` var: `cut -d= -f2- <scratch>/<connector>.env | tr -d '\n' | pbcopy`
   - **JSON / quoted / multi-line value → base64-encode it** (`... | base64 | tr -d '\n' | pbcopy`) and make sure the env var name ends `_B64` and the restore script (Phase 5) `base64 -d`s it. The `.env` field truncates at the first newline AND chokes on embedded double-quotes, so compacting JSON to one line is not enough - base64 is the robust fix. (`scripts/compact_json_secret.py` only removes newlines; use base64 when the value contains quotes.)

2. In the browser: click "Add variable" (or equivalent). **Type the NAME** via `browser_type` (the name is not a secret).

3. **Focus the VALUE field** (`browser_click` it) and **paste with a keystroke**: `browser_press_key("ControlOrMeta+v")`. This pastes the OS clipboard into the focused field without the value ever passing through you. (If that key form does not paste, fall back to `browser_evaluate` that reads `navigator.clipboard.readText()`, sets the field via its native value setter, dispatches an `input` event, and returns ONLY `text.length` - never the text.)

4. `browser_snapshot()` to confirm the value field is now populated (it renders masked / as dots - you confirm non-empty, you never read the value). Verify the byte-length matches what you staged if the UI shows a length.

5. Move to the next var. After the last one, clear the clipboard: `pbcopy < /dev/null`.

Never type or echo a secret value. Clipboard-and-paste only, sourced straight from the scratch file.

#### 9f - create the routine

Goal: a new routine bound to the env you just made. Set the routine **prompt** from the skill's description - for a single skill: `Run the <skill-name> skill.` Set it directly via `browser_type`; do not ask the user to approve or tweak it. If useful, mention in one plain sentence what it will do ("each run will produce your morning brief"), but do not gate on a reply.

**Model: ask the user which model to use** - this is one of the few real choices worth surfacing, but ask it in plain English with the tradeoff and a recommendation, never as raw jargon. Frame it like: "Which model should it use each day? Sonnet is faster and cheaper; Opus is the smartest but costs more. For a daily brief I'd suggest Sonnet." Set whichever they choose in the model field. If they have no preference, default to **Sonnet** for a frequently-running routine (cost). Confirm the choice in one line.

#### 9g - set the cron

If the user already told you when it should run (e.g. "7am every morning"), use that - do NOT re-ask. Only ask, in plain English, if no time was given. Convert to a cron expression in **UTC** (the platform applies its own offset; trusting local is brittle), and remember to account for the user's timezone when converting. Set it in the schedule field, and state the local time you scheduled (e.g. "set for 7:00am Brisbane") so they can sanity-check - phrase it in their timezone, not as a raw cron string.

#### 9h - save, disabled

Save the routine but leave it **disabled** - you will fire one manual run to verify before enabling. Snapshot to confirm it saved. **Capture the routine's trigger id now** - it appears in the page URL after save (`/code/routines/<trig_...>`) or on the routine page. You created this routine in the browser, so you have the id directly; record it for Phase 10. (Do not rely on the `RemoteTrigger` API to recover it later - see Phase 10.)

### Phase 10 - verify with one test run

**The run reaching "completed" is the pass signal.** If the routine runs end to end without erroring and without stalling on a permission prompt, then the repo, the connectors, the credentials and `setup.sh` all worked - that is exactly what this step proves. Do NOT try to hard-match the skill's specific output to "really" confirm it.

1. Tell the user, in one sentence, that you'll do a single test run now to prove it works, and that it will really run (for morning-brief, it sends the email to them). State it and fire - do not gate on a reply for a harmless self-test.
2. **Fire the run from the browser, and use the id you captured at 9h.** Click the routine's **"Run now"** button in the Playwright browser, then open the run session to watch it live via snapshots. **Do NOT use `RemoteTrigger list` to discover the id** - the `RemoteTrigger` API tracks a different set of triggers than the web UI and routinely does NOT list routines created in the browser (which is how this skill creates them). You already have the id from 9h; never ask the user for it. (`RemoteTrigger run/get` is a best-effort *secondary* signal only if the API happens to track this routine - the browser is the source of truth here.)
3. Poll to a terminal state - watch the session via `browser_snapshot` every ~30s, up to ~5 min (a large inbox or a slow model can push a real morning-brief run past 5 min, which is fine; keep waiting as long as the timer advances). **Completed without a permission prompt = success.** If it errored or stalled, open the session and read the logs to diagnose - do not guess. (A transient "too many requests" / weekly-usage-limit notice is an account cap, not a setup fault - say so plainly and let the user decide whether to top up and re-run; do not misattribute it to the routine.)
   - **One sanity glance: did the skill use its REAL dependencies, or a degraded fallback?** While watching the session, check that the credential-backed tools actually came up (e.g. the transcript shows gws authenticating and the calendar/contacts loading), not a fallback path. A run that reaches "completed" only because the skill fell back to a different tool when its real credential was missing (e.g. the Gmail connector because the `gws` CLI was unauthenticated) is **NOT a real pass** - the credential restore failed silently. Diagnose it (see the restore-failure row in failure modes) and re-run; do not enable the schedule on a fallback-only run. This is a coarse "did the right tools fire" glance, not an exact-output match - keep it loose.
4. **Do NOT hard-verify the exact side effect, and do NOT spin up a background watcher/poller.** The skill names its own output (subject lines, file names) and any string you guess will be wrong - e.g. searching the inbox for "Morning Brief" misses a "Morning Briefing" email. If you want extra reassurance, do at most ONE broad, best-effort check (e.g. "a self-sent email in the last few minutes," not an exact subject) and treat a miss as inconclusive, never as a failure. The run status from step 3 is the source of truth.
5. On success: tell the user plainly that it worked, then offer to switch on the daily schedule (you can flip the enable toggle in the Playwright UI, or they can). Do not enable the cron before the run verifies.
6. `browser_close()` when finished.

## What you must NOT do

- In Phase 2, do not show the user a raw dependency dump or ask them to validate/correct it. Clean the list yourself, then list the **services** in plain English and ask only "anything I've missed?" - the step exists to catch an omitted connector, nothing else.
- **Do not let the routine run prompt for permission.** A scheduled run has no human to click "Allow", so a single prompt stalls it. The scaffolded repo ships `.claude/settings.json` (auto-enables project MCP servers + allows every server in `.mcp.json` + base tools + bypass default) - make sure it shipped, and set the Permissions tab permissively as a backstop (Phase 9c2).
- **Do not put credential restore (decoding a secret env var into a file) in `setup.sh`.** The routine's env vars reach the agent session, not the pre-launch setup script, so it would silently write nothing. Credential restore goes in `restore-credentials.sh`, run by the SessionStart hook in agent context (Phase 5). `setup.sh` is for installing CLIs only.
- **Do not verify a run by hard-matching the skill's exact output or by spinning up a background watcher/poller.** The run reaching "completed" without a permission prompt is the pass signal. Any inbox/file check is loose and best-effort - a miss is inconclusive, never a failure (you will guess the wrong subject line).
- **Do not hand the user a list of UI clicks for Phase 9.** You drive the routines UI in the Playwright browser. The only thing you ask the user to do in the browser is sign in once (and clear any 2FA on their device). Everything else - navigate, type, click, paste, save, fire - is yours.
- **Do not use Claude-in-Chrome or the user's own browser for Phase 9.** Playwright MCP only. If no Playwright server is connected, fall back to Appendix A and say so.
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start the browser work, once when you need them (sign-in / a confirmation), once when each phase milestone lands (env created, secrets staged, routine saved, run fired). Do not go silent for minutes, and do not commentate every click.
- Do not invent connector folders or env var values from memory. Always read from the connector library (when `ROUTINE_CONNECTORS_DIR` is set) and `~/.claude.json`.
- **Do not run any command that triggers an OS keychain / permission prompt** (macOS `security find-generic-password` / `security unlock-keychain`, Linux `secret-tool` / Secret Service, etc.). It pops an unexpected dialog for a non-technical user and blocks unattended runs. If the tool's own `export`/`print` command works (it decrypts internally, no prompt), use that and stop - do not escalate to reading the keychain or transplanting encrypted state by hand.
- **Do not print, echo, `cat`, or type any real secret value into the chat.** Use the script `--out` files + `--redact` stdout, and pipe values to `pbcopy` straight from the scratch files. The only things about a secret that may appear in chat are its env-var NAME and byte-length.
- **Do not open or inspect the user's OTHER routines' environments** (in the browser or otherwise) to learn config. That screenshots their other secrets into context. If you need to know where a field goes in the UI, the steps are documented here - follow them or ask the user.
- Do not commit secrets to the repo. The whole point of the env-var mechanism is that secrets stay out of git. After scaffolding, the repo is secret-scanned; if a token ever appears in a tracked file, abort and start over.
- Do not push the repo to GitHub without running the Phase 8 pre-flight (confirm active `gh` account + owner + App reachability) and confirming org/visibility with the user.
- When something is missing or access fails, **investigate before offering the user a remediation choice.** Do not present fixes built on an unverified theory.
- **Do not ask the user to find, copy, or paste a routine URL or id.** You created the routine in the browser (Phase 9), so capture its trigger id from the page/URL at 9h. Do NOT rely on `RemoteTrigger list` to discover it - that API tracks a different trigger set than the web UI and usually will not show a UI-created routine.
- **Do not rabbit-hole on the auto-attached connectors.** After you create the routine, the platform re-attaches the account-default connectors (Gmail / Drive / Notion) with empty `permitted_tools`. This is expected and harmless - the routine reaches its tools through the repo `.mcp.json` + the CLIs in `setup.sh`, not these. Removing them in the form may not stick; note it in one line and move on.
- **Do not ask the user technical questions they cannot answer** (env-var names, setup.sh contents, config formats). Pick the sensible default and proceed; surface a choice only when it is a plain-English, real-world decision (what to package, what to call it, when it should run).
- Do not enable the cron on the routine before the manual Run verifies.

## Failure modes

| Symptom | Diagnose |
|---|---|
| `introspect_skill.py` errors with "SKILL.md not found" | The skill path is wrong. Re-run `discover_skills.py` to find the right one. |
| `map_deps_to_connectors.py` reports `unmatched_clis` | Resolve each one yourself with the Phase 3 ladder (how to install it + how to get a portable credential). Do not ask the user to confirm a CLI name - that is a technical question they cannot answer. |
| Routine run pauses on "Allow Claude to use `<tool>`?" | The repo's `.claude/settings.json` is missing or didn't pre-approve that tool. `scaffold_repo.sh` writes it with `enableAllProjectMcpServers: true`, an `allow` list for every MCP server in `.mcp.json` plus base tools, and `defaultMode: bypassPermissions`. Confirm the file shipped and lists the server. A scheduled run cannot answer a prompt, so this is mandatory, not optional. The Permissions-tab backstop (Phase 9c2) is the second line of defence. |
| Verification "fails" but the run completed | You hard-matched the skill's exact output (e.g. searched for "Morning Brief" but the email is "Morning Briefing"). The run reaching "completed" is the real pass signal - do not poll for an exact subject or filename, and never launch a background watcher. |
| HTTP MCP request returns 0 bytes inside the routine | Trusted Domains is set to "claude.ai only" (the default). Phase 9c missed. |
| Env var value got truncated, or a JSON credential won't parse in the sandbox | The `.env` field truncates at the first newline AND breaks on embedded double-quotes. For a JSON / quoted credential, deliver it **base64-encoded** (name it `_B64`) and `base64 -d` it in `restore-credentials.sh` - do not rely on `compact_json_secret.py` alone (it only removes newlines). |
| Routine session shows "command not found: gws" | setup.sh either didn't run or its install line was missing. Check the routine session logs at `claude.ai/code/routines/<id>`. (This is the INSTALL phase - separate from the credential restore below.) |
| Run completed but the skill used a fallback (e.g. Gmail connector instead of `gws`), or a credential-backed CLI is unauthenticated in the sandbox | The credential restore didn't run. Almost always: the restore was put in `setup.sh`, but the routine's env vars reach the AGENT session, NOT the pre-launch setup script - so it hit the empty-var branch and wrote nothing (still showed "Completed"). Fix: the decode must run in agent context. Confirm `restore-credentials.sh` shipped in the repo and that `.claude/settings.json` has a `SessionStart` hook running it (Phase 5 + 7 do this via `--restore-sh`). Re-run and confirm the transcript shows the credential restored. |
| Credential CLI fails in the sandbox with "invalid secret" / "client secret is invalid" (but works locally) | The export masked the secret (e.g. `gws auth export` prints an 11-char placeholder). Re-export with the unmasked flag (`--unmasked` / `--show-secrets`) and round-trip-test the restore in a throwaway config dir before re-shipping. |
| A macOS keychain / OS permission dialog popped up mid-setup | You ran a command that reads the OS keychain directly (e.g. `security find-generic-password -s gws-cli`) to transplant raw encrypted state. Don't - use the tool's own `export` command (decrypts internally, no prompt) and stop there. For `gws` that's `gws auth export --unmasked`, delivered base64. The keychain route is unnecessary when the export round-trips. |
| `RemoteTrigger list` / `get` doesn't show the routine you just created | The `RemoteTrigger` API tracks a different trigger set than the web UI and generally does not list UI-created routines. Don't use it to discover the id - use the id you captured at 9h and drive the test run + monitoring from the Playwright browser ("Run now" + snapshots). |
| `setup.sh` has a stray non-bash line at the top (e.g. "generate_setup_sh: wrote restore script to ...") | You redirected the generator with `> setup.sh 2>&1`, capturing its stderr diagnostic. Use `--setup-out <file>` instead of a redirect (Phase 5). |
| GHL MCP returns 0 contacts when there are clearly contacts | The skill is reading the wrong response path. The MCP envelope is `{success, status, data: {contacts: [...]}}` - access via `response["data"]["contacts"]`, not `response["contacts"]`. |
| Pushed repo doesn't appear in the routine repo-picker | The Claude GitHub App isn't installed on the repo's OWNER account (or lacks access to that private repo). Check `github.com/settings/installations` for the owner; install/grant at `github.com/apps/claude/installations/new`. 2FA / "Confirm access" gates there are user-only. This is the single biggest time-sink - check it during Phase 8 pre-flight, not after. |
| `gh repo create` pushes to the wrong account, or a repo "vanishes" | The `gh` active account differs from what you expect (it can flip between sessions). `gh auth status` shows the active one; `gh auth switch` changes it. Always confirm in Phase 8 pre-flight. |
| `generate_mcp_json.py` exits with "resolution contains redacted values" | You fed it a redacted resolution. Re-run `map_deps_to_connectors.py` with `--out <file>` and pass that real file to `generate_mcp_json.py`. |
| `browser_press_key("ControlOrMeta+v")` doesn't paste the value | The MCP build may not accept that chord. Fall back to a `browser_evaluate` that reads `navigator.clipboard.readText()`, sets the field via its native value setter, dispatches an `input` event, and returns only `text.length`. If clipboard-read is blocked, last resort is Appendix A (manual paste by the user) - never `browser_type` the secret. |
| No Playwright MCP server connected at Phase 9 | Use Appendix A (manual hand-off). Tell the user plainly that you'll guide them through the clicks because the browser automation isn't available this session. |

## Appendix A - manual UI hand-off (fallback only)

Use this **only** when no Playwright MCP server is connected, or browser automation fails partway and can't recover. It is NOT the default. Walk the user through claude.ai/code/routines one step at a time, waiting for "done" between steps:

1. Create environment `<routine-slug>-env`.
2. Connect repo `https://github.com/<org>/<name>`.
3. Network access → Full (or allowlist the hosts from `<scratch>/.mcp.json`).
4. Paste setup script: `pbcopy < <scratch>/setup.sh`, then "it's on your clipboard, paste into the Setup script field." (The credential-restore script ships inside the repo via the SessionStart hook - nothing to paste for it.)
5. For each env var: stage the value on the clipboard exactly as in Phase 9e step 1 (never echo it), then tell the user the NAME + purpose only and "value's on your clipboard, add a variable with this name and paste." One per message; clear the clipboard (`pbcopy < /dev/null`) after the last.
6. Create routine, select the env, set the prompt (`Run the <skill-name> skill.`) and the UTC cron, save **disabled**. On the Permissions tab choose the most permissive option so the run never prompts (the repo's `.claude/settings.json` already pre-approves the tools as the durable fix).
7. Verify per Phase 10: fire the run from the routine's **"Run now"** button (not `RemoteTrigger list`, which may not show a UI-created routine), treat "completed" as the pass signal, confirm the skill used its real tools (not a fallback), and do not hard-match the skill's exact output.

Even in the fallback, never print a secret value - clipboard only.
