# Accounts & Logins — Everything You Need to Create

**Set these up before or at the workshop. All links are included. Most are free.**

This is your complete done-for-you list. Work through it top to bottom.

---

## Priority 1 — Required Before the Workshop

### 1. Google Account (Gmail)

You almost certainly have one already. If not:

1. Go to: [accounts.google.com/signup](https://accounts.google.com/signup)
2. Fill in your name, choose an email address ending in `@gmail.com`
3. Set a password and verify your phone number
4. Done — this gives you Gmail + Google Calendar + Google Drive in one account

> **Already have one?** Make sure you know the email address and password. You will need to click "Allow" in a Google login screen during setup.

✅ Done when: You can log in at [gmail.com](https://gmail.com)

---

### 2. Claude Account (Claude Max)

1. Go to: [claude.ai](https://claude.ai)
2. Click **Continue with Google** — sign in with the Google account from Step 1
3. Once logged in, go to **Settings → Billing**
4. Click **Upgrade Plan** → choose **Claude Max** ($100 USD/month)
5. Enter your card details

> **Why Claude Max?** The standard free plan does not include Claude Code — the version that runs on your computer and automates tasks.

✅ Done when: You see "Max" next to your plan in Settings → Billing

---

### 3. GitHub Account

GitHub is where the workshop kit is stored. You need an account to download it.

1. Go to: [github.com/signup](https://github.com/signup)
2. Enter your email, choose a username and password
3. Verify your email address (check your inbox)
4. Done — the free plan is all you need

> **What is GitHub?** It's like Google Drive for code and documents. Your workshop kit lives at `github.com/selrai-company/claude-workshop-kit` — free and public.

✅ Done when: You can log in at [github.com](https://github.com)

---

## Priority 2 — Set Up at the Workshop

These get connected during the setup wizard. Just have the accounts ready.

### 4. Phone Messaging — Telegram, WhatsApp, or iMessage

> **Software required:** Telegram, WhatsApp, and iMessage integrations all require **Bun** (a JavaScript runtime) installed on your computer. This is separate from Node.js. It is installed during the main workshop setup — no action needed before the workshop.

Your AI assistant can send you phone notifications when it finishes tasks or needs a decision. Pick whichever app you already use — you only need one.

#### Telegram

1. Download Telegram on your phone: [telegram.org](https://telegram.org)
   - iPhone: App Store → search "Telegram"
   - Android: Play Store → search "Telegram"
2. Open the app and sign up with your phone number
3. Verify with the SMS code sent to your phone
4. Done — no desktop app needed (though you can install one too)

> **What you will do at the workshop:** Search for `@BotFather` inside Telegram, create a bot, and give your assistant the bot token. Your assistant guides you through this step by step.

✅ Done when: Telegram is installed on your phone and you can open it

#### WhatsApp

1. Make sure WhatsApp is up to date on your phone
2. That's it — your assistant will show you a QR code to scan at the workshop

> **What you will do at the workshop:** Your assistant shows a QR code. You scan it with WhatsApp (Settings > Linked Devices > Link a Device). Done.

✅ Done when: WhatsApp is installed and up to date on your phone

#### iMessage (Mac Only)

1. No download or signup required — iMessage is built into macOS and iOS
2. You just need a Mac running Claude Code (iMessage channel is macOS only)

> **What you will do at the workshop:** Grant Full Disk Access to your terminal, install the iMessage plugin, and text yourself. Your assistant guides you through this step by step.

✅ Done when: You have a Mac with Messages working (it already is if you use iMessage)

---

### 5. Workshop Kit — Download on the Day

You will run this command at the workshop. It downloads everything automatically:

```bash
git clone https://github.com/selrai-company/claude-workshop-kit.git ~/workshop-kit
```

No GitHub login required to download — the repo is public.

---

## Priority 3 — Connect After the Workshop

These are the most useful next connections. Each one is optional but recommended.

### Google OAuth — Connects Gmail + Calendar

When you run the Gmail or Calendar connection commands, a browser window will open automatically. You just:

1. See the Google login screen
2. Click your email address
3. Click **Allow** on the permissions screen
4. Done — Claude can now access Gmail and Calendar

```bash
# Install Google Workspace tool
npm install -g @googleworkspace/cli

# Sign in to your Google account
gws auth login
```

> No extra account needed — just your existing Google account.

---

### Notion Account (Optional)

If you use Notion for notes or documentation:

1. Go to: [notion.so](https://www.notion.so)
2. Click **Get Notion free** → sign up with Google
3. Connect at the workshop: `claude mcp add notion npx @anthropic-ai/notion-mcp`

---

### GoHighLevel CRM (Optional — Paid)

If you want your assistant to manage your sales pipeline and contacts:

1. Go to: [gohighlevel.com](https://www.gohighlevel.com)
2. Start a 14-day free trial
3. Plans: $97-$297 USD/month after trial
4. Get your API key from Settings → Integrations → API Keys
5. Tell your assistant: "Connect my GHL account — my API key is [key]"

---

### HubSpot CRM (Optional — Free Tier Available)

If you want your assistant to manage HubSpot contacts, deals, companies, and notes:

1. Go to: [hubspot.com](https://www.hubspot.com) → click **Get HubSpot free**
2. Sign up with Google or email — the free CRM plan is all you need to get started
3. Once your account is set up, tell your assistant: "Help me connect my HubSpot account."
4. Your assistant will guide you through creating a **Private App** (a limited-permission access key) inside HubSpot Settings

> **Paid plans?** The connector works on all HubSpot plans including free. Paid plans unlock more CRM features, but the connection itself is free.

> For the full guide, see [docs/HUBSPOT-SETUP.md](HUBSPOT-SETUP.md)

---

### GitHub (as a Connector — Optional)

This is separate from the GitHub account you use to download the workshop kit. This connects Claude to your **actual repositories** so it can read issues, pull requests, code, and CI status.

1. You already have a GitHub account (Priority 1 Step 3)
2. No extra signup needed — your assistant walks you through creating a **Personal Access Token** (PAT) with the right permissions
3. Tell your assistant: "Help me connect my GitHub account so you can read my repos."

> **Read-only or read-write?** Your assistant will ask which you prefer during setup. Read-only is safer to start — you can upgrade later.

> For the full guide, see [docs/GITHUB-SETUP.md](GITHUB-SETUP.md)

---

### Square (Optional — Free)

If you take payments through Square and want your assistant to read sales, orders, customers, and invoices:

1. Go to: [squareup.com](https://squareup.com) and sign in (or create a free account)
2. No extra setup before the workshop — your assistant handles everything
3. Tell your assistant: "Help me connect my Square account."
4. A browser sign-in to Square's server takes about 30 seconds — no token or API key needed

> **Note:** Square's Claude connector is in beta. It works well for everyday reads; occasional retries may be needed.

> For the full guide, see [docs/SQUARE-SETUP.md](SQUARE-SETUP.md)

---

### CircleCI (Optional — Free Tier)

If you use CircleCI for testing or deployments and want your assistant to check build status and logs:

1. Go to: [circleci.com](https://circleci.com) → sign in with GitHub (uses your existing account)
2. The free tier covers most individual and small-team use cases
3. Tell your assistant: "Help me connect my CircleCI account."
4. Your assistant will guide you through creating a **Personal API Token** in CircleCI Settings

> For the full guide, see [docs/CIRCLECI-SETUP.md](CIRCLECI-SETUP.md)

---

## Account Summary

| Account | Cost | When to Create | Link |
|---|---|---|---|
| Google (Gmail) | Free | Before workshop | [accounts.google.com/signup](https://accounts.google.com/signup) |
| Claude Max | $100 USD/mo | Before workshop | [claude.ai](https://claude.ai) |
| GitHub | Free | Before workshop | [github.com/signup](https://github.com/signup) |
| Telegram | Free | Before workshop (phone) | [telegram.org](https://telegram.org) |
| WhatsApp | Free | Before workshop (phone) | [whatsapp.com](https://www.whatsapp.com) |
| Notion | Free | After workshop | [notion.so](https://www.notion.so) |
| GoHighLevel | $97-297 USD/mo | After workshop | [gohighlevel.com](https://www.gohighlevel.com) |
| HubSpot | Free / paid | After workshop | [hubspot.com](https://www.hubspot.com) |
| GitHub (connector) | Free | After workshop | Uses existing GitHub account |
| Square | Free | After workshop | [squareup.com](https://squareup.com) |
| CircleCI | Free tier | After workshop | [circleci.com](https://circleci.com) |

**Before the workshop: 4 accounts (3 free + Claude Max)**
**Total pre-workshop cost: $100 USD/month (~$155 AUD)**

---

## Passwords — Save These Somewhere Safe

Before the workshop, make sure you have saved:

- ✅ Google email address + password
- ✅ Claude Max login (same as Google if you used "Continue with Google")
- ✅ GitHub username + password
- ✅ Telegram or WhatsApp installed on your phone

A password manager (like 1Password or the built-in Apple/Google one) is the best place to save these.

---

*Claude Code Workshop — selrai.com.au*
