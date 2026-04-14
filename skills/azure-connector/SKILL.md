---
name: azure-connector
description: Install and configure the Azure CLI (az) on the user's laptop. Use this skill when the user asks to set up Azure, connect Microsoft Azure, use Azure Storage, App Service, Key Vault, or any Azure service locally. Handles installation, authentication, and subscription setup conversationally.
allowed-tools: Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - azure
    - microsoft
    - cloud
    - storage
    - app-service
    - installer
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting Azure auth or permission errors
    - skill: outlook-connector
      reason: Both use Microsoft ecosystem — Azure CLI can complement M365 workflows
    - skill: gcloud-connector
      reason: Similar pattern — local CLI connector for a cloud provider
---

# Azure CLI Connector

## Overview

This skill does two things:
1. **Installs** the Azure CLI (`az`) on the user's computer (one-time setup)
2. **Operates** the CLI — interacting with Azure services (Storage, App Service, VMs, Key Vault, etc.)

> **This is for local laptop setup only.** This skill connects your laptop to Azure so you can interact with your account. Server provisioning (spinning up Azure VMs) is a separate topic — ask your assistant if you need that.

---

## Part 1 — Installation

Guide conversationally — one step at a time:

### Step 1: Check if already installed

Run `az --version`. If it returns a version number, say:
> "Azure is already installed on your computer. Let me check if you're signed in."

Skip to Part 2.

If "command not found", say:
> "We need to install the Azure command-line tool first. This will take about a minute."

### Step 2: Install based on OS

Detect OS with `uname -s` (or check if PowerShell is available for Windows).

**macOS — say:**
> "I'm going to install the Azure tool using Homebrew."

```bash
brew install azure-cli
```

If Homebrew is not installed, say:
> "I'll need you to install Homebrew first. Run this command, then let me know when it's done."

**Linux (Ubuntu/Debian) — say:**
> "I'm going to download and install the Azure tool."

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Linux (RHEL/Fedora/CentOS):**
```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
sudo dnf install -y azure-cli
```

**Windows — say:**
> "I'm going to install the Azure tool now. You'll see some progress in the terminal."

```powershell
winget install Microsoft.AzureCLI
```

If winget is unavailable, say:
> "I'll need you to download the installer. Open this link in your browser: https://aka.ms/installazurecliwindowsx64 — then run it and click through the steps. Let me know when it's done."

### Step 3: Verify

Run `az --version`. If it works, say:
> "That worked! Azure is installed. Now let's sign you in."

If it still fails after install, say:
> "The terminal needs a refresh. Please close this terminal and open a new one, then tell me to continue."

---

## Part 2 — Authentication

### Step 4: Log in

Say:
> "I'm going to sign you in to Azure now. A browser window will open — sign in with your Microsoft account."

```bash
az login
```

**If the browser opens** — wait for the user to sign in. After success, say:
> "You're signed in. Let me check which subscriptions you have."

**If the browser does not open** — say:
> "A link and a code appeared in the terminal. Open the link in your browser, enter the code, and sign in with your Microsoft account."

**If running headless or browser is blocked:**
```bash
az login --use-device-code
```

Say:
> "Open this link on any device: https://microsoft.com/devicelogin — then enter this code: [code]. Sign in with your Microsoft account."

### Step 5: Set default subscription

Run:
```bash
az account list --output table
```

**If one subscription** — set it automatically and say:
> "You have one subscription. I've set it as your default."

```bash
az account set --subscription "<subscription-id>"
```

**If multiple subscriptions** — say:
> "You have a few subscriptions. Which one would you like to use as your default?"

Show the list and let the user pick, then:
```bash
az account set --subscription "<their-choice>"
```

**If no subscriptions** — say:
> "You don't have an Azure subscription yet. You'll need to create one at https://portal.azure.com. Would you like me to help you with that?"

Use Playwright to guide them through the portal if needed.

### Step 6: Verify

Run:
```bash
az account show --output table
```

If it shows the account and subscription, say:
> "That worked! You're connected to Azure with the [subscription name] subscription. Your Azure is ready to go."

---

## Part 3 — What to Try First

After setup, suggest simple tasks:

> "Want to try something? Here are a few things I can do with your Azure:"

```
"Show me my Azure resource groups."
"What web apps do I have running?"
"List my storage accounts."
```

Say:
> "Start with something simple. Once you're comfortable, I can help with more complex tasks like deploying apps or managing secrets."

---

## Part 4 — Common Operations

### Storage (Blob)

```bash
# List storage accounts
az storage account list --query '[].name' --output table

# List containers in a storage account
az storage container list --account-name <account-name> --output table

# Upload a file
az storage blob upload --account-name <account-name> --container-name <container> --file ./local-file.csv --name file.csv

# Download a file
az storage blob download --account-name <account-name> --container-name <container> --name file.csv --file ./local-file.csv

# List blobs in a container
az storage blob list --account-name <account-name> --container-name <container> --output table
```

### App Service (Web Apps)

```bash
# List web apps
az webapp list --query '[].{Name:name, State:state, URL:defaultHostName}' --output table

# Create a web app
az webapp up --name <app-name> --resource-group <rg> --runtime "NODE:20-lts"

# View logs
az webapp log tail --name <app-name> --resource-group <rg>

# Restart
az webapp restart --name <app-name> --resource-group <rg>
```

### Virtual Machines

```bash
# List VMs
az vm list --output table

# Start a VM
az vm start --name <vm-name> --resource-group <rg>

# Stop a VM (deallocate to stop billing)
az vm deallocate --name <vm-name> --resource-group <rg>

# SSH into a VM
az ssh vm --name <vm-name> --resource-group <rg>
```

### Key Vault (Secrets)

```bash
# List vaults
az keyvault list --query '[].name' --output table

# Get a secret
az keyvault secret show --vault-name <vault-name> --name <secret-name> --query 'value' --output tsv

# Set a secret
az keyvault secret set --vault-name <vault-name> --name <secret-name> --value "secret-value"
```

### Resource Groups

```bash
# List resource groups
az group list --output table

# Create a resource group
az group create --name <rg-name> --location australiaeast
```

---

## Part 5 — Service Principal (for Automation)

If the user needs automated/non-interactive access (CI/CD, scripts), say:
> "For automation, I'll create a service account that can sign in without a browser."

```bash
az ad sp create-for-rbac --name "my-automation" --role contributor --scopes /subscriptions/<subscription-id>
```

This outputs `appId`, `password`, and `tenant`. Say:
> "Save these three values somewhere safe — especially the password, which is only shown once."

To log in with a service principal:
```bash
az login --service-principal -u <appId> -p <password> --tenant <tenant>
```

---

## Part 6 — Auth & Session

```bash
# Check who is signed in
az account show

# List all accounts/subscriptions
az account list --output table

# Switch subscriptions
az account set --subscription "<subscription-id-or-name>"

# Log out
az logout

# Log back in (browser)
az login

# Log in with device code (headless)
az login --use-device-code

# Check current defaults
az config get
```

---

## Part 7 — Troubleshooting

| Problem | Fix |
|---|---|
| `az: command not found` | Shell needs restart — open a new terminal |
| `Please run 'az login' to setup account` | Not signed in — run `az login` |
| `The subscription could not be found` | Wrong subscription — run `az account list` and `az account set` |
| `AuthorizationFailed` | User doesn't have permission — check role assignments in Azure Portal |
| `InteractionRequired` | MFA or Conditional Access required — complete the browser prompt |
| `AADSTS50076` | MFA required — sign in via browser and complete MFA |
| `No subscriptions found` | No Azure subscription — create one at portal.azure.com |
| Browser doesn't open on login | Use `az login --use-device-code` instead |
| `Certificate verification failed` | Corporate proxy issue — contact IT or try `az config set core.ssl_verification=false` temporarily |

When an error occurs, say:
> "No problem — let me try a different way."

Then diagnose and fix. Never show raw error messages to the user — translate them into plain English.

---

## Part 8 — Playwright Fallback

Use Playwright when:
- The browser does not open automatically during `az login`
- The user needs help navigating the Azure Portal (e.g. creating a subscription, granting roles, managing resources)

### Auth fallback
```
Navigate to the URL printed by az login (or https://microsoft.com/devicelogin)
Enter the device code → sign in → complete MFA if required
```

### Portal navigation
```
Navigate to: https://portal.azure.com
Help the user find: Subscriptions, Resource groups, IAM, or resource creation
```

Always try the CLI command first. Only switch to Playwright if the CLI returns an error or the user needs help in the portal.

---

## Behaviour Guidelines

- **Always run `az account show` first** at the start of a session to confirm the user is signed in.
- **Confirm before destructive actions** — deleting resource groups, deallocating VMs, removing secrets.
- **Subscription context matters** — always check `az account show --query 'name'` before running commands.
- **Auth errors** → `az login` or `az login --use-device-code`.
- **az not found** → restart shell or reinstall.
- **Location/region** — if the user is in Australia, default to `australiaeast`. Always confirm before creating resources.
- **One step at a time** — do not dump all instructions at once. Say what to do, wait, then give the next step.
