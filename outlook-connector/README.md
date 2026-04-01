# Outlook & Microsoft 365 Connector

**Built by Selr AI — selrai.com.au**

Connects your Microsoft Outlook account to your AI assistant. Once installed, your assistant can read and send emails, check your calendar, access OneDrive, work with Excel, browse Teams and SharePoint, use OneNote, and manage contacts — all through plain English.

---

## What You Need

- Node.js version 20 or higher — check by typing `node --version`
- A Microsoft account (outlook.com, hotmail.com, or work/school Microsoft 365)
- An internet connection

---

## Install — Pick Your Computer Type

**Windows:** Double-click `setup.bat` and follow the prompts.

**Mac:** Open Terminal, drag the `setup.sh` file into the window, press Enter.

---

## Manual Install (if scripts don't work)

Open your terminal or command window and run these commands one at a time:

**Step 1 — Install the tool:**
```
npm install -g @pnp/cli-microsoft365
```

**Step 2 — Set up your Microsoft connection (one-time):**
```
m365 setup --interactive
```
A browser window will open — follow the steps and click Allow when asked.

**Step 3 — Sign in:**
```
m365 login --authType browser
```
A browser window will open — sign in with your Microsoft account and click Allow.

**Step 4 — Verify:**
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
- "Find the budget file in SharePoint"

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "m365 not found" after install | Close and reopen your terminal, then try again |
| Browser does not open during sign-in | Run `m365 login` instead — it shows a code. Go to `https://aka.ms/devicelogin`, enter the code, sign in |
| Wrong account connected | Run `m365 logout` then `m365 setup --interactive` then `m365 login --authType browser` |
| Work account — Teams or SharePoint access denied | Ask your IT admin to approve the connection during `m365 setup` |

---

*Built by Selr AI — selrai.com.au*
