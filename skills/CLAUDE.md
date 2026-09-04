# Connector SKILLs - authoring reference

This is the canonical reference for authoring a connector SKILL in this
directory. It covers two things:

1. **The description template** - how a connector's frontmatter `description` is
   written. Applies to **every** connector here, whatever its install shape. The
   general description rules it sits on top of apply to every skill in the kit,
   connector or not.
2. **The four install patterns** the `*-connector` SKILLs have converged on.
   Pattern 0 (built-in claude.ai connector) is listed first because it is now
   the default route for most of the catalogue; Patterns 1-3 are what a
   connector falls back to when no directory listing exists, or what it keeps
   alongside Pattern 0 to cover a gap the built-in can't reach.

If you are authoring or reviewing a new connector, write the description from
the template first, then read the per-pattern reference SKILL this doc points
to.

Pattern 0 sits *above* the shapes below rather than replacing them. A connector
whose vendor is in the claude.ai directory runs Pattern 0 as its default route
and keeps its original shape as the fallback (or as the route-by-need branch for
the reach the built-in doesn't have) - so "which pattern" is often two answers,
not one.

If a connector does not fit one of the four patterns below
(CLI-based: `gws`, `gh` (github-connector is CLI-first by design and deliberately
does **not** route to a built-in connector), `qbo`, `notion` (`ntn`); direct REST: `ghl`, `myob`, `servicem8`, `cliniko`, `deputy`, `starshipit`, `pipedrive`, `asana`, `freshbooks` (OAuth2-fronted), `trello` (key+token; Power-Up form is manual), `clickup` (raw-token header), `brevo` (`api-key` header), `kit` (formerly ConvertKit; `X-Kit-Api-Key` header), `activecampaign` (`Api-Token` header + per-account base URL); first-party stdio:
`hubspot`, `paypal`, `slack`, `square`, `stripe`, `shopify`, `xero` (Xero's
official server on a Custom Connection, launched from a pinned global install
by absolute `node` path - never `npx`, which hangs on a cold cache - with the
built-in Xero connector layered in front for the read-only headline numbers),
`voice-transcription`, `whatsapp`, `wordpress`; vendor-hosted custom connector:
`meta-business-suite` - Meta's official Ads endpoint `https://mcp.facebook.com/ads`,
added through **Add custom connector** rather than a directory listing), it has
its own shape and is out of scope for the *install patterns* below - see the
SKILL itself. The description template in the next section still applies to
them, Pattern 0 included.

## The connector description template ("Template B")

**Scope, in two layers.** The canonical two-sentence description shape - third
person; sentence 1 = what it does with the distinctive keyword front-loaded;
sentence 2 = "Use when…"; 150-250 target, 500 ceiling - applies to **every skill
in the kit**, connector or not. Template B, below, is the connector-specific
instantiation of that shape: it fixes the wording for the connect-and-
authenticate case and adds the already-connected trigger predicate. Everything
under [Rules](#rules) and [Fact-parity](#fact-parity-when-rewriting-an-existing-description)
is general; the template block and its slot table are connector-only.

**Template B applies to every connector in this directory**, including the
CLI-based and direct-REST ones that fall outside the four install patterns.

A connector's `name` and `description` are the only parts of it loaded into
every attendee session, before they type a word - and the description is
essentially all of that weight. It is **trigger text, not a runbook**. Two
failure modes it must avoid:

- **Budget.** Per Anthropic's skills guidance and observed Claude Code
  behaviour, the whole skill listing is budgeted at roughly 1% of the context
  window, and descriptions are shortened or dropped when that is exceeded -
  without an error. So an oversized description can strip *other* skills'
  triggers, silently. Treat the exact figure as a working assumption, not a
  contract, and stay well under it.
- **Body-skipping.** A description that reads as a complete procedure gets acted
  on directly and the body is never opened, so the phase logic and error
  handling are skipped. This is the suspected cause of connector re-install
  misfires.

### The template

> Connect **\[Vendor]** to Claude by installing and authenticating its
> **\[MCP server | CLI | API credentials]**. Use when the user asks to set up or
> connect **\[Vendor]**, or wants **\[Vendor]** work (**\[domain nouns]**) and
> the connection isn't in place yet.

For a Pattern 0 connector, sentence 1 says *switching on*, not *installing*,
because nothing is installed:

> Connect **\[Vendor]** to Claude by switching on its built-in connector**\[, or
> by \<the kit's route>]**. Use when the user asks to set up or connect
> **\[Vendor]**, or wants **\[Vendor]** work (**\[domain nouns]**) and
> **\[Vendor]** isn't connected yet.

Optional final sentence, only where it genuinely routes later work away from a
re-install:

> Once connected, **\[Vendor]** runs directly through **\[tools | CLI | credentials]**.

### Filling the slots, by connector shape

The `[Vendor]` and `[domain nouns]` slots are the same for every shape. What
changes is what you install, what "the connection isn't in place yet" is
replaced by, and what the routing sentence points at.

**Do not leave "the connection isn't in place yet" as-is.** It is a stand-in.
Replace that whole clause with the connector's real already-connected signal,
negated. Replace the clause; do not nest one inside the other.

| Row | MCP (hosted or stdio) | CLI (`gws`, `ntn`, `gh`) | Raw API / direct REST | Built-in connector (Pattern 0) |
|---|---|---|---|---|
| **What you install** | "its MCP server" - name the vendor's own where it is the vendor's, e.g. "Intuit's official MCP server" | "the `<cli>` CLI" | "its API credentials" | nothing is installed - it is switched on: "by switching on its built-in connector" |
| **Replaces "the connection isn't in place yet"** | "\<Vendor> isn't connected yet" | "the `<cli>` CLI isn't signed in yet" | "the credentials aren't in place yet" | "\<Vendor> isn't connected yet" |
| **Routing sentence** | "runs directly through the `mcp__<server>__*` tools" | "runs directly through the `<cli>` CLI" | "runs directly against the vendor's API with the stored credentials" | "runs through the `mcp__claude_ai_<Name>__*` tools" |

The built-in column is a full column, not a footnote: a Pattern 0 skill's
sentence 1 is "Connect \<Vendor> to Claude by switching on its built-in
connector", and a **both**-fate skill names both routes in one clause -
"…by switching on its built-in connector or \<the kit's route>" - with the
routing sentence naming both tool surfaces. The predicate is the same either
way ("\<Vendor> isn't connected yet"), because the skill's Phase 0 decides at
that level: it accepts *either* a live built-in connection or a working kit
route as "connected".

For the plugin-marketplace pattern the signal is the plugin, not a server:
"the `<name>` plugin isn't installed yet".

### The don't-reinstall guard is a predicate, not a prohibition

Write the guard as part of the **trigger condition** - "…and the connection
isn't in place yet" - never as a prohibition ("do NOT run if already
installed"). A prohibition is instruction text that has to be read and obeyed;
a predicate simply stops the skill matching once the connection exists.

The predicate you name must be the connector's **real** already-connected
signal - the same one its Phase 0 resume-check tests (see
[Cross-cutting: Phase 0 resume-check](#cross-cutting-phase-0-resume-check)
below). Do not invent a nicer-sounding one. Concretely: a registered
`mcpServers.<service>` entry, a CLI that is installed and authed, a credentials
file at a documented path, or plugin skills/tools present in the session.

Match the resume-check's **strength**, too. Most Phase 0 checks are
registration **plus** a smoke call - a server that is registered but failing to
connect is *not* connected, and the SKILL has a re-auth path for exactly that
state. A description predicate that tests registration alone ("no `<server>`
server is registered yet") would suppress the trigger in that state. Phrase it
at the level the resume-check actually decides at: "\<Vendor> isn't connected
yet".

### Rules

- **Third person.** "Connect Xero to Claude…", never "I connect" or "You can
  use this to…".
- **Sentence 1 = what it does**, with the distinctive keyword (the vendor name)
  front-loaded.
- **Sentence 2 = "Use when…"**, listing genuinely distinct trigger branches -
  one phrasing per branch, in vocabulary users actually type. Synonym-padding
  ("connect / hook up / link / integrate") is an anti-pattern, not thoroughness.
- **Target 150-250 characters.** Hard ceiling 500. Anything over 250 needs a
  written justification in the PR (recognised reasons: many genuinely distinct
  trigger surfaces, or disambiguation from a sibling connector). These are the
  spec's limits, not the frontmatter validator's - the validator only rejects
  above 1,024 chars, which is how 2,000-char descriptions shipped here
  unchallenged. Do not treat 1,024 as the budget.
- **Connectors are connecting-only.** The description must not claim the skill
  operates the vendor. If the body *does* contain operating guidance, use the
  optional routing sentence to say where that work goes once connected - do not
  delete the body guidance, and do not let the description lie about it.
- **No procedure in the description.** Commands, flags, file paths, timeouts,
  redirect URIs, DOM steps, phase numbers and error branches belong in the body.
  The one carve-out is the routing sentence, which may name a tool namespace
  (`mcp__<server>__*`) or a CLI binary - that is routing, not procedure.

### Fact-parity when rewriting an existing description

Order matters: **port first, then rewrite.**

1. Decompose the old description into atomic operative facts (commands, flags,
   package names, paths, timeouts, permission modes, fallback logic, smoke
   steps, prerequisites, ordering constraints).
2. For each, either locate it in the body (record the line number) or port it
   into the body.
3. Only then replace the description.

No operative fact is deleted - only relocated. No body content is deleted. If
the old description contradicts the body, the body wins and the claim is dropped
from the description rather than copied forward.

## Which pattern do I use?

```
Is there a claude.ai directory listing for this vendor?
├── yes → Pattern 0: Built-in claude.ai connector   (app list in Pattern 0 below)
│         └── Does the built-in cover the whole job?
│             ├── yes ("basic")  → Pattern 0 is the route; the skill's original
│             │                    shape stays in full as Phase 1-alt
│             └── no  ("both")   → Pattern 0 for the everyday half, PLUS the
│                                  skill's own pattern below for the gap, chosen
│                                  by a route-by-need table
└── no
    └── Is there an official Claude Code plugin in the marketplace?
        ├── yes → Pattern 3: Plugin-marketplace        (reference: telegram-connector)
        └── no
            └── Is the SaaS server hosted (the vendor publishes an MCP URL)?
                ├── yes
                │   └── Does the auth flow use OAuth (consent screen)?
                │       ├── yes → Pattern 1: Hosted-OAuth      (reference: linear-connector)
                │       └── no  → Pattern 2: Hosted-bearer-PAT (reference: monday-connector)
                └── no  → out of scope; see the per-connector SKILL
```

**Two vendors are exempt from the first question by design: GitHub and Vercel.**
Both are CLI-first (`gh`, `vercel`) because the command line is where Claude does
its best work with them - repos, pull requests, checks, deploys - and a built-in
connector would be a worse tool for the same job. Do not route either of them to
a built-in connector, and say so in one line in the SKILL so a later author does
not "fix" it.

If both an OAuth flow and a Personal Access Token surface exist for the same
vendor, prefer Pattern 1 (Hosted-OAuth) and keep the PAT as a fallback inside
that SKILL. `linear-connector` does this - see Step 3B there.

## Cross-cutting: Phase 0 resume-check

Every connector SKILL begins with the same Phase 0 check: "is this already
installed?" The shape is identical across all 11 SKILLs and lives once here so
new connectors do not re-derive it.

**Pattern 0 adds a step in front of it, it does not replace it.** Where a
built-in connector exists, Phase 0 asks `claude mcp list` for a `claude.ai
<Name>` line *first*, and only falls through to the check below when there is no
such line. A working kit-route connection still wins over setting the built-in up
on top of it.

Read `~/.claude.json`, look for a `mcpServers.<service>` entry, and decide:

- **Found** → skip Phase 1 entirely, run a single smoke tool call to verify the
  connection still works, report success.
- **Not found** → run Phase 1.

The exact "is it configured?" predicate varies by pattern:

| Pattern | What "configured" looks like in `~/.claude.json` |
|---|---|
| Built-in connector | nothing in this file at all - the connection is account-level. The signal is a `claude.ai <Name>: … ✔ Connected` line from `claude mcp list`, plus `mcp__claude_ai_<Name>__*` tools in the session |
| Hosted-OAuth | `mcpServers.<service>` entry with `type: "http"` (token is stored by the MCP runtime, not in this file) |
| Hosted-bearer-PAT | `mcpServers.<service>` entry with `headers.Authorization` (HTTP) **or** `env.<TOKEN>` (local npx) |
| Plugin-marketplace | Skill presence (e.g. `Telegram:configure`), tool presence (`mcp__plugin_<service>_*`), or `claude plugin list \| grep <name>@claude-plugins-official` - there is no `mcpServers` entry for plugins |

For the plugin-marketplace pattern specifically, also check that the plugin's
own state files (e.g. `~/.claude/plugins/telegram-connector/access.json`)
exist and are populated before declaring the connector "ready".

## Cross-cutting: Playwright MCP install contingency

Patterns 1 and 2 both drive a browser via the Playwright MCP server. If the
SKILL author can't reach `mcp__playwright__*` or
`mcp__plugin_playwright_playwright__*` tools, install Playwright first:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

The `--user-data-dir` flag is mandatory - it gives the Playwright browser a
persistent profile so user logins survive across sessions. Workshop attendees
should never have to re-login to the same site twice; that friction is one of
the top complaints when Playwright MCP is installed without it.

After install, ask the user to close and reopen Claude Code once so the new
MCP surface reconciles, then retry. This is identical across hosted-OAuth and
hosted-bearer-PAT and lives once here.

Pattern 3 (plugin-marketplace) does not need Playwright unless the plugin
itself uses it (e.g. `telegram-connector` drives Telegram Web through it).

---

## Pattern 0 - Built-in claude.ai connector

**When it fits:** the vendor has a listing in Claude's own connector directory
(claude.ai → Customize → Connectors → Browse, mirrored at
`https://claude.com/connectors/<slug>`). Connections made there are
**account-level**: the user connects once, on claude.ai web or the desktop app,
and the connector is available everywhere on that account - Claude Code
included - with no install, no server registration, and no credential the skill
ever touches.

Pattern 0 is the default route wherever a listing exists. It replaces nothing:
the skill's original install path stays in the file, retitled, as the fallback.

**Which connectors are on it.** CORE-367 gave every catalogue app one of three
fates. Two of them use Pattern 0:

- **basic** - the built-in does the whole job; the kit's own route survives only
  as Phase 1-alt:
  `airtable`, `atlassian`, `calendly`, `canva`, `clickup`, `gusto`, `jotform`,
  `linear`, `monday`, `notion`, `pandadoc`, `slack`, `square`, `stripe`,
  `trello`.
- **both** - built-in first, the kit's route for a named gap:
  `activecampaign`, `asana`, `brevo`, `docusign`, `google-workspace` (Gmail,
  Google Calendar and Google Drive are three separate listings; `google-chat`
  has none and folds into this skill), `hubspot`, `klaviyo`, `mailchimp`,
  `myob`, `outlook` (Microsoft 365), `paypal`, `pipedrive`, `shopify`,
  `wordpress`, `xero`.

Everything else in the catalogue is **custom** and stays on Patterns 1-3 or its
own shape. Two caveats worth carrying:

- **The directory display name is not always the skill name.** Mailchimp is
  listed as **Intuit Mailchimp** at slug `intuit-mailchimp` - the bare
  `mailchimp` slug returns "This connector doesn't exist" - so the
  `claude mcp list` line reads `claude.ai Intuit Mailchimp` and the tools are
  `mcp__claude_ai_Intuit_Mailchimp__*`. Match on the *directory* name, always.
  The other renamed ones, checked on the public mirror 2026-09-04: Atlassian is
  **Atlassian Rovo** (`claude.ai Atlassian Rovo`, `mcp__claude_ai_Atlassian_Rovo__*`),
  WordPress is **WordPress.com** (`mcp__claude_ai_WordPress_com__*`), monday.com
  is **Monday** (`mcp__claude_ai_Monday__*`), DocuSign is **Docusign**.
- **`quickbooks` is region-split.** The built-in at `claude.ai/directory/quickbooks`
  is verified live but covers US books; Australian and other non-US books run the
  kit's own route, so that SKILL carries a pointer rather than a Pattern 0 phase.

### The mechanics, verified live (2026-09-02)

Everything below was checked on a real machine. Do not soften or embellish it.

- **Auth precondition.** Built-in connectors only appear in a Claude Code
  session that is signed in with a claude.ai account. `claude auth status`
  prints JSON; the field that matters is `"authMethod": "claude.ai"`. Any other
  value - API key, Bedrock, Vertex - means built-in connectors will not appear
  in that session. Two kill-switches do the same thing:
  `disableClaudeAiConnectors: true` in `~/.claude/settings.json`, and the
  environment setting `ENABLE_CLAUDEAI_MCP_SERVERS=false`.
- **Detection.** `claude mcp list` prints built-in connectors one per line with
  a `claude.ai` prefix:

  ```
  claude.ai Notion: https://mcp.notion.com/mcp - ✔ Connected
  claude.ai Microsoft 365: https://microsoft365.mcp.claude.com/mcp - ✔ Connected
  claude.ai Slack: https://mcp.slack.com/mcp - ! Needs authentication
  ```

  `✔ Connected` = ready. `! Needs authentication` = the connector is on the
  account but its sign-in has lapsed; the row on claude.ai/customize/connectors
  shows **Reconnect**. No `claude.ai <Name>` line at all = not connected on this
  account, or the auth precondition above failed. There is **no `--json` flag**.
  The line is `claude.ai <display name>`, the display name verbatim (read from
  the CLI's own naming code, 2.1.259: a second connector with the same display
  name gets ` (2)` appended). Match the whole display name. The exact check is
  `claude mcp get "claude.ai <Name>"`, which prints `Status: ✔ Connected`,
  `Status: ! Needs authentication`, or `No MCP server named …` followed by the
  names that do exist.
- **Tool namespace.** `mcp__claude_ai_<Name>__<tool>`, where `<Name>` is the
  directory display name with every character that is not a letter, digit,
  underscore or hyphen turned into an underscore, runs of underscores collapsed,
  case kept. That is the CLI's own rule (2.1.259), and it is the same rule that
  turns the `claude.ai ` prefix into `claude_ai_`. So `Microsoft 365` →
  `Microsoft_365`, `WordPress.com` → `WordPress_com`, `Atlassian Rovo` →
  `Atlassian_Rovo`, `Intuit Mailchimp` → `Intuit_Mailchimp`, `Monday` → `Monday`.
  Verified live: `mcp__claude_ai_Microsoft_365__get_me`,
  `mcp__claude_ai_Notion__notion-search`, `mcp__claude_ai_Dropbox__list_folder`. These tools are frequently *deferred* in
  a session, so a SKILL should say "call one read tool from the
  `mcp__claude_ai_<Name>__*` namespace" rather than hard-coding a tool name it
  has not verified.
- **Deep links.** `https://claude.ai/directory/<slug>` is the connector's own
  page - name, Verified badge, a **Connect to Claude** button, the tool list, the
  connector URL. `https://claude.ai/directory/connectors/<slug>` redirects to it.
  Verify a slug against the public mirror `https://claude.com/connectors/<slug>`
  (fetchable without login) before writing it into a SKILL; a 404 there means
  "slug unknown", not "not listed". The universal fallback when the slug is
  unknown is `https://claude.ai/customize/connectors` → **Browse** → search the
  app's name → **Connect**. Non-directory servers go in through **Add custom
  connector** (name + server URL, then the vendor's own sign-in); the
  `?modal=add-custom-connector&…` prefill link is unverified - do not rely on it.
- **No programmatic enablement exists, on any plan.** Every path ends with a
  human pressing **Connect to Claude** and completing the vendor's sign-in in a
  browser already signed in to claude.ai. Nothing a SKILL does replaces that
  click, and a SKILL that implies otherwise is wrong.
- **Which browser.** The user's own everyday browser - that is where they are
  signed in to claude.ai and usually to the vendor. Open the deep link with
  `open` (Mac), `xdg-open` (Linux) or `start "" <url>` (Windows). This is a
  deliberate exception in SKILLs whose *custom* path carries the "never open the
  participant's own browser" rule: that rule exists because the custom path reads
  secrets off the page in a driven browser, and the built-in path reads nothing.
  Where the two rules meet in one file, say so in one line. Never drive this
  sign-in with Playwright.
- **Restart semantics.** A running session fetches its claude.ai connector list
  once, at start, and keeps it (2.1.259 memoises the fetch for the life of the
  process). `claude mcp list` and `claude mcp get` start a fresh process, so they
  show a connector the moment the Connect completes - even from inside a session
  that still has no tools for it. So the list is the *account* check and the
  session's own tool list is the *session* check. List passes, namespace absent
  from the session → the session started before the Connect: quit and reopen
  Claude Code once, then re-run Phase 0. Never send the user to restart because
  the list line is missing: a missing line means the Connect did not complete.
- **Local-entry precedence.** A server registered locally with `claude mcp add`
  at the same URL takes precedence and *hides* the built-in one (`/mcp` shows it
  as hidden). A machine that previously ran the kit's custom path may carry such
  an entry under `mcpServers.<x>` in `~/.claude.json`. If it works, leave it and
  say so; if it is broken, prefer the built-in and remove the local entry only
  with the user's explicit OK.
- **Plan and org caveats.** Assume a paid Claude plan (the public docs conflict;
  plan for paid). On Team or Enterprise an admin must enable the connector for
  the organisation first, and connectors only work in private projects - a member
  without rights sees **Request** where the SKILL expects **Connect**. That is an
  admin gate, not a failure: say so and stop, rather than falling back to the
  kit's route to get past it. Free accounts get one custom connector.
- **Surfaces without a shell.** In claude.ai chat or the desktop app there is no
  `claude` command to run. The pattern still works: skip the command checks, hand
  the user the deep link and the click sequence, and prove the result by calling
  one of the connector's tools.
- **VS Code is the CLI.** The VS Code extension bundles the same binary (its
  2.1.259 copy is byte-identical to the standalone CLI) and reads the same
  `~/.claude/settings.json`, and the docs list Terminal, VS Code and JetBrains
  sessions together as "Claude Code fetches them from claude.ai". Everything
  above holds there. Two differences: the extension does not put `claude` on
  PATH, so `command not found` means treat it as the no-shell case; and "quit
  and reopen" there is **Developer: Reload Window** from the Command Palette.
- **Directory Read/Write badges lag reality.** Microsoft 365 and HubSpot were
  both mislabelled at the time of writing. Never route on the badge; route on the
  per-app facts, and probe live where the facts say "verify".

### The canonical block

Every Pattern 0 SKILL carries the same two sections, in the same order, with the
same step numbers - **Phase 0 - Is \<Vendor> already connected?** and
**Phase 1 - Switch on the built-in \<Vendor> connector**. The full text with its
slots (`<Vendor>`, `<Name>`, `<slug>`, `<smoke>`) lives *in each SKILL*, not
here: the wording is adapted to the SKILL's voice, and the routing facts it
carries are per-app. Read a shipped example - `stripe-connector` for the plain
basic shape, `outlook-connector` for the both shape with an interview - rather
than copying from this doc.

What must not vary is the step list:

**Phase 0**, run silently, acting on the first step that answers:

1. `claude mcp list` → look for a line starting `claude.ai <Name>`. `✔ Connected`
   → skip to Phase 2, proving it with one read first. `! Needs authentication` →
   send the user to claude.ai/customize/connectors to press **Reconnect**, then
   re-check. No line → continue.
2. The SKILL's own existing resume check (the `mcpServers.<x>` entry, the CLI
   sign-in, the credentials file). Present and smoke-passing → keep using it and
   skip to Phase 2. Never set the built-in up on top of a working connection.
3. Nothing found → Phase 1.

No shell available → skip steps 1-2 and prove the result at Phase 1 step 5.

**Phase 1**, six steps:

1. **Check the session can see built-in connectors** - the auth precondition and
   the two kill-switches. Failing → say in one line that this copy of Claude is
   signed in a different way, and run Phase 1-alt instead.
2. **Open the connector page for them** - narrate first, then open
   `https://claude.ai/directory/<slug>` in their own browser. Page won't load →
   `https://claude.ai/customize/connectors` → Browse → search → Connect.
3. **Wait.** Hands off while they sign in. Never ask for a password, a code, or a
   screenshot of the sign-in.
4. **Verify** with `claude mcp list` (or `claude mcp get "claude.ai <Name>"`).
   This is the account check and it is always current, so no restart belongs
   here. `! Needs authentication` means Reconnect; no line at all means the
   Connect never completed, so back to step 2.
5. **Prove it** with one real read through the connector. Fetch the
   `mcp__claude_ai_<Name>__*` namespace first (it is usually deferred). Namespace
   absent from this session although step 4 passed → the session started before
   the Connect: quit and reopen Claude Code once (VS Code: Developer: Reload
   Window), then re-run Phase 0. Only a real answer counts; a tool error is not
   "connected".
6. **Hand off** in two lines: it is connected, and three things they can ask for
   now.

Plus the Team/Enterprise **Request**-instead-of-**Connect** branch, which stops
rather than falling back.

### Route by need

A **both**-fate SKILL puts a short table between Phase 0 and Phase 1 mapping
what the user wants to do onto built-in vs the kit's route, and connects only
what that table selects. The rule behind it is Harvey's: *if the extra config is
not needed we should not burden the user with it.* Concretely:

- Everyday reads and writes the built-in covers → built-in, and stop there.
- The named gaps only → the kit's route, in addition.
- Both routes can coexist on one machine. Never tear one down to set the other
  up.
- Say in one line what is *not* being connected and why, so the user can ask for
  it later.

### Interview first, for the wide apps

Google Workspace, Microsoft 365 and Xero span so many surfaces that connecting
"all of it" is the wrong default. Those SKILLs ask before they open anything:

1. **One** question, in plain English: what do they want Claude to do with
   \<Vendor>? Offer the surfaces as examples ("read and send email? your
   calendar? files in Drive? edit a spreadsheet you already have?").
2. If they under-specify ("connect my email"), double-check the adjacent surfaces
   once, in the same message: *"Just email, or your calendar and files too?"* For
   Google, also ask whether the team uses Google Chat.
3. Route each named need through the SKILL's route-by-need table. Connect only
   what they named.

One question, then act. An interview that becomes a questionnaire is the failure
mode this rule exists to prevent.

### Structure of a Pattern 0 SKILL

| Fate | Sections, in order |
|---|---|
| **basic** | Phase 0 (built-in check, then the SKILL's own resume check) → **Phase 1** (built-in) → **Phase 1-alt - The kit's own route (only when the built-in can't be used)**, the original flow kept in full → Phase 2 (operate) |
| **both** | Phase 0 → *interview* (wide apps only) → **Route by need** table → **Phase 1** (built-in) → the kit's route under its original title and content → Phase 2 (operate) |

Phase 1-alt is a retitling, not a rewrite: the original steps stay, prefaced by
one short paragraph naming when it runs - the session can't see built-in
connectors, the listing is missing on the user's account, or the user explicitly
wants the local server. Phase 2 gains one line saying that through the built-in
the tools are `mcp__claude_ai_<Name>__*` and through the kit's route they are
whatever the SKILL already documents, plus a note wherever the two surfaces
differ materially.

**Fact-parity applies here as everywhere.** No operative fact is deleted, only
relocated. Sections get retitled and reordered; they do not get dropped.

---

## Pattern 1 - Hosted-OAuth

**Reference SKILL:** [linear-connector](linear-connector/SKILL.md) - uses this
pattern in its post-#198 form, plus a Personal API key fallback in Step 3B.

**Other SKILLs on this pattern:** [atlassian-connector](atlassian-connector/SKILL.md),
[calendly-connector](calendly-connector/SKILL.md),
[canva-connector](canva-connector/SKILL.md),
[jotform-connector](jotform-connector/SKILL.md).

> All five of those vendors are now in the claude.ai directory, so Pattern 0 is
> their default route and this pattern is what their Phase 1-alt runs. Pattern 1
> is still the right shape for any new hosted-OAuth connector with no listing,
> and it is still the fallback these SKILLs fall back *to*.

**When it fits:** the vendor publishes a hosted MCP URL (e.g. `https://mcp.linear.app/mcp`)
and authentication is OAuth - the user sees a consent screen.

**Registration command:**

```bash
claude mcp add <server> <url> --transport http --scope user
```

**Tool-pair contract.** After registration and a Claude Code reconciliation,
two tools appear in the deferred-tool surface:

- `mcp__<server>__authenticate()` - returns the OAuth start URL.
- `mcp__<server>__complete_authentication({ callback_url })` - submits the
  post-redirect URL captured from the browser.

These are runtime artifacts produced by Claude Code from the server's
well-known OAuth metadata - there is no `claude mcp authenticate` CLI verb
(see [#200](https://github.com/selrai-company/claude-workshop-kit/issues/200)
and the `audit-skills.mjs` anti-pattern guard).

**Deferred-tool reconciliation timing.** The `authenticate` /
`complete_authentication` pair only appears after the runtime has reconciled
the new server. If the tools are not visible immediately after `claude mcp
add`, ask the user to close and reopen Claude Code once, then retry. Do not
proceed by guessing the OAuth URL - that defeats the contract.

**Playwright redirect-and-capture sub-flow:**

1. Call `mcp__<server>__authenticate()` and open the returned URL inside the
   Playwright MCP browser.
2. Snapshot to detect login state. If the user is signed out, narrate ("sign
   in to <service>") and `browser_wait_for` the consent screen.
3. Auto-click **Allow** (or its vendor-specific equivalent - "Authorize",
   "Approve").
4. Wait for the redirect to a `localhost` / `127.0.0.1` callback URL.
5. Capture `window.location.href` via `browser_evaluate` **before** the tab
   closes.
6. Pass that URL to `mcp__<server>__complete_authentication({ callback_url })`.
7. Close the browser and verify with one `mcp__<server>__*` smoke call.

**Resume / re-auth on token expiry.** If a smoke call fails with an auth
error, re-run the `authenticate` / `complete_authentication` pair - do not
re-register the server. The MCP runtime owns token storage; the SKILL never
reads or writes it directly.

**Common branches** (vendor-specific; document inside the SKILL, not here):

- Workspace picker after consent (`atlassian-connector` Step 4a).
- Admin-block / no-access interstitial (`atlassian-connector`, `canva-connector`).
- Personal API key fallback when OAuth is admin-blocked (`linear-connector`
  Step 3B - drives the SaaS settings page, captures the key from the DOM,
  re-registers the entry with an `Authorization: Bearer` header).

---

## Pattern 2 - Hosted-bearer-PAT

**Reference SKILL:** [monday-connector](monday-connector/SKILL.md) - cleanest
deep-link-based token capture flow.

**Other SKILLs on this pattern:** [airtable-connector](airtable-connector/SKILL.md).

> `github-connector` used to sit here. It moved to the `gh` CLI - the command
> line is how Claude works best with repos, pull requests and checks - and the
> token-mint flow went with it. GitHub is one of the two Pattern 0 exemptions;
> see the note under the decision tree.

**When it fits:** the vendor publishes a hosted MCP URL (or a local stdio
server), and authentication is a Personal Access Token captured from a
settings page - there is no OAuth consent surface for this MCP.

**Registration command (HTTP hosted):**

```bash
claude mcp add <server> <url> --transport http \
  --header "Authorization: Bearer <token>" --scope user
```

**Registration command (local stdio):**

```bash
claude mcp add <server> --scope user -- npx -y <package> --env <SERVICE>_TOKEN="<token>"
```

`monday-connector` supports both shapes; the choice is vendor-driven.

**Playwright token-mint sub-flow:**

1. Navigate to the SaaS's "create token" deep link (e.g.
   `airtable.com/create/tokens`, the workspace `/admin/integrations/api`
   page on monday.com).
2. Snapshot to detect login state. If signed out, narrate and wait for the
   user to authenticate.
3. Walk the create-token UI: name the token, tick the required scopes, scope
   to "all bases / all data" (or vendor equivalent).
4. Click **Create**.
5. Read the freshly minted token from the DOM via `browser_evaluate` - match
   it with a regex sized to the vendor's token shape (e.g. `pat[A-Za-z0-9]+`
   for Airtable, JWT-shape for monday.com).
6. If the token is masked, click the reveal/show control first, re-snapshot,
   re-read.
7. Hand the token to `claude mcp add` with the appropriate header / env flag.
8. Close the browser and verify with one `mcp__<server>__*` smoke call.

**Token-permission scoping.** This is the bulk of each SKILL's value and is
vendor-specific - Airtable has four data + schema scopes, GitHub has
read-vs-write tiers, monday.com has optional `--read-only` /
`--enable-dynamic-api-tools` flags (mutually exclusive). Document the scope
choice inside the SKILL.

**Token-expiry / rotation.** Most providers do not expire PATs by default.
For those that do, surface the expiry choice during the mint walk and document
re-mint as the resume path (the SKILL re-runs Phase 1; the registration
command overwrites the prior entry).

**Conversational fallback.** Some vendors (notably GitHub) require the user
to copy a token from a notification dialog that the page does not expose to
the DOM. In that case, fall back to asking the user to paste the token; that
is a small leak (the token transits the transcript) and an accepted
trade-off - call it out in the SKILL.

**Direct-config fallback.** If `claude mcp add` fails for any reason, write
directly to `~/.claude.json`, merging into the `mcpServers` object:

```jsonc
// HTTP hosted
{ "type": "http", "url": "...", "headers": { "Authorization": "Bearer ..." } }

// Local stdio
{ "command": "npx", "args": [...], "env": { "<SERVICE>_TOKEN": "..." } }
```

---

## Pattern 3 - Plugin-marketplace

**Reference SKILL:** [telegram-connector](telegram-connector/SKILL.md) -
the canonical reference for this shape.

**Other SKILLs on this pattern:** [imessage-connector](imessage-connector/SKILL.md).

> `notion-connector` previously used this pattern (via the
> `notion@claude-plugins-official` plugin) but **moved to a CLI-based connector**
> (the official `ntn` CLI) so the OAuth token lives in the OS keychain rather
> than a Bearer header in `~/.claude.json`. See `notion-connector/SKILL.md` and
> the CLI-based list at the top of this doc.

**When it fits:** the vendor (or Anthropic) publishes an official Claude Code
plugin in `claude-plugins-official`. The plugin owns the OAuth handshake (or
local-permission grant) internally; the SKILL just orchestrates install +
permission prompts + verify.

**Install command:**

```bash
claude plugin install <name>@claude-plugins-official
```

**Verify install:**

```bash
claude plugin list | grep <name>@claude-plugins-official
```

Three signals to check, in order of strength:

1. **Skill presence** - e.g. `Telegram:configure`, `Telegram:access` appear in
   the available-skills list.
2. **Tool presence** - `mcp__plugin_<service>_*` tools appear in the deferred
   surface.
3. **Registry presence** - `claude plugin list` shows the
   `<name>@claude-plugins-official` line.

If the registry shows the plugin but the skills/tools are not visible, ask the
user to close and reopen Claude Code once so the surface reconciles. This is
the plugin equivalent of the deferred-tool reconciliation in Pattern 1.

**OAuth choreography (when the plugin uses it).** Some plugins launch OAuth
automatically the first time the user invokes one of the plugin's skills - the
SKILL does **not** call `authenticate` directly. The user signs in, picks a
workspace, clicks Allow; the plugin captures the callback. Subsequent
invocations reuse the stored token.

**Restart-the-chat semantics.** Plugin-installed skills and tools become
visible after the runtime reconciles. If the user invokes a `<plugin>:*` skill
that is not yet visible, treat that as the reconciliation contingency - close
and reopen, do not retry-loop.

**Re-auth path.** Re-running `claude plugin install <name>@claude-plugins-official`
re-triggers the plugin's OAuth flow. Use this on token expiry rather than
attempting to refresh the token from the SKILL.

**Plugin-managed state.** Some plugins maintain state files outside
`~/.claude.json`:

- `telegram-connector` writes `access.json` (allowlist) and `.env` (bot token,
  via clipboard transit so the token never lands in a tool return).
- `imessage-connector` reads `~/Library/Messages/chat.db` directly and replies
  via AppleScript - there is no token; the dependency is macOS Full Disk
  Access permission, granted via System Settings.

These are out-of-band from `claude plugin install`; the SKILL's Phase 1 must
walk the user through them.

---

## Token handling

| Pattern | Where the secret lives | Can it appear in a tool return? |
|---|---|---|
| Built-in connector | the user's claude.ai account, server-side - the SKILL handles no credential at any point | No - there is nothing to echo. Say so in the SKILL |
| Hosted-OAuth | MCP runtime token store (Claude Code internal) | No - never visible to the SKILL |
| Hosted-bearer-PAT | `mcpServers.<service>.headers.Authorization` in `~/.claude.json` | DOM read via `browser_evaluate` - must use clipboard-transit or careful regex extraction; never echoed back |
| Plugin-marketplace | Plugin-internal state (varies); for Telegram, `.env` / `access.json` written via clipboard-transit | No - same clipboard-transit rule when applicable |

Never echo a captured token in a narration line, a tool return value, or a
log file. The Pattern-2 reference SKILLs read the token, hand it to `claude
mcp add`, and discard it from the working set - copy that shape.

## Communication rules

These are identical across all 11 SKILLs and live in each SKILL's "Voice" or
"Communication" section. Restate the user-facing rules in your SKILL; do not
link out for them. Briefly: plain English, no jargon (`MCP`, `npx`, `bash`,
`JSON` are banned in user-facing text), narrate at action boundaries, never
echo credentials.

## See also

- [SKILLS-LIST.md](SKILLS-LIST.md) - the full skill index with tier and category.
- [quickbooks-connector/SKILL.md](quickbooks-connector/SKILL.md) - worked example of the
  description template on a connector with a large post-connect operating surface.
- [stripe-connector/SKILL.md](stripe-connector/SKILL.md) - Pattern 0 reference, basic shape.
- [outlook-connector/SKILL.md](outlook-connector/SKILL.md) - Pattern 0 reference, both shape with the interview and a route-by-need table.
- [linear-connector/SKILL.md](linear-connector/SKILL.md) - Pattern 1 reference.
- [monday-connector/SKILL.md](monday-connector/SKILL.md) - Pattern 2 reference.
- [telegram-connector/SKILL.md](telegram-connector/SKILL.md) - Pattern 3 reference.
- [#198](https://github.com/selrai-company/claude-workshop-kit/issues/198) - the Phase 1 Step 3 rewrite that grounded Pattern 1.
- [#199](https://github.com/selrai-company/claude-workshop-kit/issues/199) - this doc's tracking issue.
- [#200](https://github.com/selrai-company/claude-workshop-kit/issues/200) - anti-pattern audit guard for the deprecated `claude mcp authenticate` / `WWW-Authenticate: Bearer` claims.
