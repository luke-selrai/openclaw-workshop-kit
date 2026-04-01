# Outlook & Microsoft 365 Connector

**Built by Selr AI — selrai.com.au**

This connects your Microsoft Outlook account to your AI assistant. Once installed, your assistant can read and send emails, check your calendar, access OneDrive, work with Excel, browse Teams and SharePoint, use OneNote, and manage contacts.

No Azure account or app registration needed.

---

## What You Need

- Node.js installed (`node --version` to check)
- A Microsoft account (outlook.com, hotmail.com, or work/school Microsoft 365)

---

## Install — Pick Your Computer Type

**Windows:** Double-click `setup.bat` and follow the prompts.

**Mac:** Open Terminal, drag the `setup.sh` file into the window, press Enter.

---

## Manual Install (if scripts don't work)

Open your terminal/command window and run these two commands:

**Step 1 — Install:**
```
npm install -g @pnp/cli-microsoft365
```

**Step 2 — Sign in:**
```
m365 login --authType browser
```

A browser window will open — sign in with your Microsoft account and click Allow.

---

## Verify It Worked

```
m365 outlook mail list
```

If it shows your emails, you are connected.

---

## What to Say to Your Assistant

- "Show me my unread emails"
- "What meetings do I have this week?"
- "Find the invoice in my OneDrive"
- "Send an email to [name] about [topic]"
- "Show me the latest Teams messages"

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "m365 not found" | Close and reopen your terminal, then try again |
| Browser doesn't open | Run `m365 login` (without `--authType browser`) and use the code it shows |
| Wrong account connected | Run `m365 logout` then `m365 login --authType browser` |
| Work account — access denied | Ask your IT admin to approve the PnP Management Shell app |

---

*Built by Selr AI — selrai.com.au*
