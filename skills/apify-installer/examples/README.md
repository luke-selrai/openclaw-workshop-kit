# apify-installer, install-flow screencast

This folder shows what a successful run of the apify-installer skill looks like end-to-end.

## What's in here

- `apify-installer-demo.mp4` (~2.5 MB, 1:30, 720p / 30fps), a clip from a real install run on 2026-05-29. The clip captures the **Playwright-fallback path** (the harder of the two install paths the skill supports), not the simpler default-browser path, because the fallback is the interesting demonstration for anyone debugging.
- `apify-installer-poster.jpg`, a poster frame for the video.

## What you're watching

The clip starts mid-install, just after the skill decides that the default-browser `apify login --method=console` callback isn't going to land (Wayland's `xdg-open` doesn't actually launch a browser on this machine). From there:

1. The skill narrates the decision to fall back to Playwright.
2. It launches `apify login --method=console` again, this time leaving the OAuth state URL ready to be opened in the Playwright-controlled browser instead of the system default.
3. The Playwright window navigates to the Apify Console OAuth URL, Apify happens to redirect through a Google sign-in for this account, and the email field pre-fills from a prior session.
4. The user completes Google sign-in inside the Playwright window. Apify mints a token server-side and POSTs it back to `http://localhost:<port>/...`.
5. The skill's polling loop on `~/.apify/auth.json` picks up the new token, hardens the file to mode `600`, and writes the shared `~/.claude/apify.env` file used by the three sibling apify-* skills.

The only human moment in the whole flow is step 4 (the actual sign-in). Everything else, the install of `apify-cli` and `@apify/mcpc`, the launch of the CLI, the Playwright fallback decision, the auth-file write, the env-file provisioning, the smoke test, is autonomous.

## What success looks like

By the end of the clip:

- `~/.apify/auth.json` exists, mode `600`, contains a real Apify API token.
- `~/.claude/apify.env` exists with `APIFY_TOKEN=...` ready for the three sibling skills to source.
- `apify info` passes its smoke test.

If you re-run any of the sibling skills (`apify-competitor-intelligence`, `apify-content-analytics`, `apify-market-research`) on a machine in this state, they skip their Step 0 dispatch and go straight to running Actors.

## What's deliberately NOT in here

- The simpler **default-browser path** (where `apify login --method=console` opens the user's normal browser and the localhost callback lands without any Playwright involvement). That path is the happy default; this clip is the more interesting fallback.
- The `apify-cli` and `@apify/mcpc` npm-install moment at the very start of a fresh install. That part of the flow is identical to any other `npm install -g` and didn't add information.
- Any moment where a token is visible on screen as plain text. The skill's design keeps the token in files (`~/.apify/auth.json`, `~/.claude/apify.env`), never in `ps` output or narration. The transient OAuth `localCliToken` parameter visible in the terminal URL is the CLI's single-use session nonce, it expires the moment the callback completes and is not the Apify API token.

## When to re-watch this

- Debugging an installer regression, the clip is the reference shape for what the flow should look like.
- Verifying a code change to the Playwright-fallback path didn't break anything user-visible.
- Onboarding a teammate who needs to understand the hybrid CLI-callback + Playwright-DOM design before touching the skill body.
