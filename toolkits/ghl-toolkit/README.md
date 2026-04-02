# GHL Toolkit for Claude Code

Control your entire GoHighLevel CRM with natural language. Contacts, pipelines, conversations, calendars, social media, email, appointments, and more.

Just talk to Claude Code like a human and it handles the GHL API for you.

## Don't have GHL yet?

Get a GoHighLevel account through our agency for **$25/month USD**:

**https://buy.stripe.com/8x27sNbwvbXE1zM2Ry0Ny0c**

This gives you a full GHL sub-account with CRM, pipelines, calendars, conversations, social planner, funnels, and more. Once you have your account, come back here for setup.

---

## Setup (5 minutes)

### Step 1: Run the installer

```bash
cd ghl-toolkit
bash setup.sh
```

This copies everything to the right places automatically.

### Step 2: Get your GHL credentials

The installer creates a file you need to edit. Open it:

```bash
open ~/.claude/projects/-Users-$(whoami)/secrets/ghl.env
```

You need to fill in 4 things:

| Field | Where to find it |
|-------|-----------------|
| `GHL_API_KEY` | GHL > Settings > Business Profile > scroll to "API Key" > copy it |
| `GHL_LOCATION_ID` | Look at your GHL URL: `app.gohighlevel.com/v2/location/THIS_PART/...` |
| `GHL_LOGIN_EMAIL` | The email you use to log into GHL |
| `GHL_LOGIN_PASSWORD` | Your GHL password |

The other fields (`GHL_PIPELINE_ID`, `GHL_BASE_URL`, `GHL_API_VERSION`) can be filled in later. Claude will help you find your pipeline ID.

### Step 3: Test it

```bash
bash test.sh
```

If you see all `[pass]`, you're done. Open Claude Code and start talking to your CRM.

---

## What you can do

Once set up, just ask Claude Code in plain English:

- "Search my contacts for Sarah"
- "Show me all open opportunities"
- "Send an SMS to contact ID xyz saying we'll follow up Monday"
- "What's on my discovery call calendar this week?"
- "Create a draft social media post for LinkedIn and Instagram"
- "List my email templates"
- "Move this opportunity to the Proposal Sent stage"
- "Add a note to this contact"
- "Show me my pipeline stages"

Claude figures out which GHL API to call, handles auth, and returns clean results.

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/ghl-crm/SKILL.md` | Teaches Claude how to use the GHL API (quirks, endpoints, safety rules) |
| `skills/ghl-browser/SKILL.md` | Teaches Claude to automate GHL's web UI when the API can't do something |
| `scripts/ghl` | Bash script that wraps 25+ GHL API endpoints into simple commands |
| `secrets/ghl.env.template` | Your credentials template |
| `settings-permissions.md` | Optional: auto-approve GHL tool calls so Claude doesn't ask permission each time |
| `setup.sh` | One-command installer |
| `test.sh` | Verifies everything is working |

## After setup: let Claude populate your data

Once your API key works, ask Claude Code:

> "Read my GHL pipelines and update the ghl-crm skill file with my pipeline and stage IDs"

Claude will call the API, get your real pipeline data, and write it into the skill file so it has your stage IDs for future operations.

Do the same for calendars:

> "Get my GHL calendars and update the skill file with my calendar IDs"

---

## Optional: auto-approve GHL tools

By default, Claude Code asks permission before calling GHL tools. To skip the approval prompts, add the entries from `settings-permissions.md` to your `~/.claude/settings.local.json`.

## Optional: browser automation + 2FA

Some GHL operations can only be done in the web UI (creating pipeline stages, social media re-auth, workflow editing). The `ghl-browser` skill teaches Claude to use Playwright MCP to automate these. See the skill file for setup instructions.

If GHL triggers 2FA during browser login, the skill auto-retrieves the code via Gmail MCP. This requires the **Gmail MCP server** connected in your Claude Code config (available as a cloud MCP at claude.ai).

---

## Troubleshooting

**"ghl: command not found"**
The bash helper isn't in your PATH. Use the full path: `~/.claude/projects/-Users-$(whoami)/scripts/ghl`

**API returns 401**
Your `GHL_API_KEY` is wrong or expired. Get a fresh one from GHL Settings > Business Profile.

**API returns 422**
Your `GHL_LOCATION_ID` is wrong. Double-check it from your GHL URL.

**Claude doesn't know about GHL**
Make sure the skills are in `~/.claude/skills/ghl-crm/` and `~/.claude/skills/ghl-browser/`. Run `bash test.sh` to verify.
