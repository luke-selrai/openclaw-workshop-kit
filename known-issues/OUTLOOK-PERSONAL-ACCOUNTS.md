# Known Issue — Outlook: Personal Microsoft Accounts Not Supported by CLI

**Status:** Known limitation
**Affects:** outlook-connector
**Symptom:** `m365 login` fails or returns no data for accounts ending in `@outlook.com`, `@hotmail.com`, or `@live.com`

---

## What Is Happening

The PnP CLI for Microsoft 365 (`m365`) is designed for **enterprise and organisational Microsoft 365 accounts** (work/school accounts). It does not support personal Microsoft accounts.

If your email address is:
- `@outlook.com`
- `@hotmail.com`
- `@live.com`
- `@msn.com`

...the CLI will either fail to authenticate or successfully connect but return empty results because the Microsoft Graph API endpoints used by `m365` require an organisational tenant.

---

## How to Tell Which Account Type You Have

- **Work/school account:** Your email is on a custom domain (e.g. `you@yourcompany.com`) and was set up by an IT admin or created via a Microsoft 365 Business/Enterprise plan.
- **Personal account:** You created the account yourself at outlook.com or hotmail.com.

---

## Workaround: Playwright Browser Automation

For personal Microsoft accounts, your assistant falls back to **Playwright browser automation** — controlling a real browser to read and send emails, view the calendar, and interact with OneDrive.

Just tell your assistant what you need:

> "Read my last 5 emails from my Outlook account."
> "Show me my calendar for this week."
> "Send an email to [person] from my Outlook."

Your assistant will open a browser, navigate to [outlook.live.com](https://outlook.live.com), and complete the task directly from the interface — no CLI required.

---

## What Works vs. What Does Not

| Feature | Work/school account (CLI) | Personal account (Playwright) |
|---|---|---|
| Read emails | ✅ | ✅ |
| Send emails | ✅ | ✅ |
| View calendar | ✅ | ✅ |
| Create calendar events | ✅ (with Calendars.ReadWrite) | ✅ |
| OneDrive files | ✅ | ✅ |
| Teams messages | ✅ | ⚠️ Limited |
| SharePoint | ✅ | ✗ Not available |

---

## Related

- Connector docs: `skills/outlook-connector/SKILL.md`
- Playwright skill: `skills/playwright-skill/SKILL.md`
- General troubleshooting: `docs/TROUBLESHOOTING.md`
