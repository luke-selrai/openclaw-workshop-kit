# Known Issue — Jotform: Workspace Admin Required for First Install

**Status:** Known limitation
**Affects:** jotform-connector
**Symptom:** The OAuth sign-in fails, or the very first `list_forms` call returns `403 Forbidden`, for users who are not the admin of their Jotform workspace

---

## What Is Happening

Jotform's MCP server is an **OAuth app** that has to be installed onto a Jotform workspace before anyone on that workspace can use it. Jotform only allows a **workspace admin** to complete that first install. From the official [Jotform MCP README](https://github.com/jotform/mcp-server):

> "Only workspace admins can install the Jotform MCP app."

If you are a regular team member (not an admin) and you try to connect first, the OAuth flow either fails at the consent screen or appears to succeed but then every tool call comes back as `403 Forbidden` because the app was never authorized for the workspace.

This only affects the **first** connection. Once a workspace admin has installed and authorized the app once, other team members on that workspace can complete their own OAuth sign-in normally (subject to their individual Jotform permissions).

---

## How to Tell If This Is Your Problem

Your assistant will say something like:
> "The sign-in didn't quite stick."

Or:
> "Your connection is working, but your Jotform user doesn't have permission for that action."

And you know that **nobody else on your Jotform team has connected Jotform to Claude Code yet** — i.e. you are the first person in your workspace to try.

---

## How to Fix It

You do **not** need admin rights on your own computer — this is about your role inside Jotform.

1. Find out who the admin of your Jotform workspace is (usually whoever set up the Jotform account for your team)
2. Ask them to connect Jotform from **their** Claude Code first — they can follow [docs/JOTFORM-SETUP.md](../docs/JOTFORM-SETUP.md)
3. Once the admin confirms their connection is working, tell your assistant *"Help me connect my Jotform account"* and go through the sign-in yourself — it should now complete normally
4. If you hit a `403 Forbidden` on a specific form after connecting, that is a separate, per-form permission issue — ask the form owner to share it with you inside Jotform

---

## Current Skill Behaviour

The Phase 1 bootstrap in [skills/jotform-connector/SKILL.md](../skills/jotform-connector/SKILL.md) does **not** warn about the admin-only requirement upfront. The skill's 403 error handler does mention admin access generically, but only after the first sign-in has already failed — by which point a non-admin user has typically wasted a minute and is confused.

---

## Future Fix

Add an upfront note at the top of Phase 1 Step 1 along the lines of:

> "Quick check first: are you the admin of your Jotform workspace? If not, ask your admin to connect their Claude Code to Jotform first — Jotform only lets a workspace admin set this up the first time. Once they are done, I can connect you in under a minute."

The same caveat should also be added to [docs/JOTFORM-SETUP.md](../docs/JOTFORM-SETUP.md) under **What You Need Before Starting**.

---

## Related

- Connector docs: `skills/jotform-connector/SKILL.md`
- Setup guide: `docs/JOTFORM-SETUP.md`
- Upstream reference: https://github.com/jotform/mcp-server
- General troubleshooting: `docs/TROUBLESHOOTING.md`
