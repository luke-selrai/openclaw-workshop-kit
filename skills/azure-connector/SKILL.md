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

> **This is for local laptop setup only.** Server provisioning (Azure VMs) lives in [claude-cloud-kit](https://github.com/luke-selrai/claude-cloud-kit).

---

## Part 1 — Installation

### Step 1: Check if already installed

```bash
az --version
```

If this returns a version number, skip to Step 3 (authentication). If "command not found", continue.

### Step 2: Install Azure CLI

Detect the user's OS first:

```bash
uname -s
```

**macOS (Homebrew):**
```bash
brew install azure-cli
```

**Linux (Ubuntu/Debian):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Linux (RHEL/Fedora/CentOS):**
```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
sudo dnf install -y azure-cli
```

**Windows (winget):**
```powershell
winget install Microsoft.AzureCLI
```

**Windows (MSI installer):**
Download from https://aka.ms/installazurecliwindowsx64 and run the installer.

### Step 3: Verify installation

```bash
az --version
```

If this returns `azure-cli 2.x.x`, installation is complete.

---

## Part 2 — Authentication

### Step 4: Log in

```bash
az login
```

**This opens a browser.** The user signs in with their Microsoft account and grants access.

If the browser does not open automatically, the command will print a URL and a device code. Tell the user:
> "A link and a code appeared in the terminal. Open the link in your browser, enter the code, and sign in with your Microsoft account."

If running in a headless/remote environment:
```bash
az login --use-device-code
```

### Step 5: Set default subscription

List available subscriptions:
```bash
az account list --output table
```

If the user has multiple subscriptions, help them pick the right one:
```bash
az account set --subscription "<subscription-id-or-name>"
```

If the list is empty, they need to create a subscription at https://portal.azure.com.

### Step 6: Verify

```bash
az account show
```

This should show the logged-in user and active subscription. If both appear, setup is complete.

---

## Part 3 — Common Operations

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

## Part 4 — Service Principal (for Automation)

For automated scripts or CI/CD, create a service principal instead of using user login:

```bash
az ad sp create-for-rbac --name "my-automation" --role contributor --scopes /subscriptions/<subscription-id>
```

This outputs `appId`, `password`, and `tenant`. Use them to log in non-interactively:

```bash
az login --service-principal -u <appId> -p <password> --tenant <tenant>
```

> **Store the password securely** — it is only shown once.

---

## Part 5 — Auth & Session

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

## Part 6 — Troubleshooting

| Problem | Fix |
|---|---|
| `az: command not found` | Shell needs restart — open a new terminal |
| `Please run 'az login' to setup account` | Not signed in — run `az login` |
| `The subscription could not be found` | Wrong subscription — run `az account list` and `az account set` |
| `AuthorizationFailed` | User doesn't have permission on this resource — check role assignments in Azure Portal |
| `InteractionRequired` | MFA or Conditional Access required — complete the browser prompt |
| `AADSTS50076` | MFA required — sign in via browser and complete MFA |
| `No subscriptions found` | Account has no Azure subscriptions — create one at portal.azure.com |
| Browser doesn't open on login | Use `az login --use-device-code` instead |
| `Certificate verification failed` | Corporate proxy — try `az config set core.ssl_verification=false` (temporary) or configure proxy cert |

---

## Part 7 — Playwright Fallback

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
- **Subscription context matters** — always check `az account show --query 'name'` before running commands, to avoid operating on the wrong subscription.
- **Auth errors** → `az login` or `az login --use-device-code`.
- **az not found** → restart shell or reinstall.
- **Location/region** — if the user is in Australia, default to `australiaeast`. Always confirm before creating resources.
