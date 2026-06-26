# Known Issue, Stripe: Login Behaves Differently in Agent Mode

**Status:** Known limitation
**Affects:** stripe-connector (login step only)
**Symptom:** Running `stripe login` inside Claude Code does not open a browser, instead it prints JSON output with a URL

---

## What Is Happening

The Stripe CLI detects whether it is running in an interactive terminal (TTY) or in an automated/agent context (non-TTY). Inside Claude Code, it is treated as **non-TTY**.

In non-TTY mode, `stripe login` outputs JSON instead of opening a browser:

```json
{
  "browser_url": "https://dashboard.stripe.com/stripecli/confirm_auth?t=...",
  "next_step": "stripe login --complete '...'"
}
```

This is normal and expected, it is not an error.

---

## How to Log In (Agent Mode)

Your assistant handles this automatically when you run the Stripe connector setup. If you need to do it manually:

**Step 1:** Run `stripe login` and copy the `browser_url` from the output.

**Step 2:** Open that URL in your browser and click **Allow access** when prompted.

**Step 3:** Copy the full `next_step` command from the JSON output and run it in the terminal:
```bash
stripe login --complete '<poll-url-from-next_step>'
```

**Step 4:** Verify the login worked:
```bash
stripe config --list
```

---

## Why the Browser Did Not Open

The Stripe CLI only opens a browser automatically when it detects a real interactive terminal session. Since Claude Code runs commands in a subshell, the CLI skips the browser-open step and gives you the URL instead. This is intentional Stripe CLI behaviour, not a bug.

---

## Related

- Connector docs: `skills/stripe-connector/SKILL.md`
- General troubleshooting: `docs/troubleshoot.md`
