---
name: azure-connector
description: "Install and operate the Azure connector autonomously. Drives portal.azure.com end-to-end inside a Playwright MCP browser: navigates to Microsoft Entra ID, finds or creates a least-privilege app registration named 'claude-assistant', DOM-extracts the Application (client) ID and Directory (tenant) ID from the Overview blade, mints a client secret on Certificates & secrets and DOM-extracts the secret value (Azure shows it once and never again), navigates to the user's subscription, assigns a built-in role (Reader for read-only, Contributor for read-and-write, never Owner), persists credentials to ~/.config/azure-connector/credentials.env, runs az login --service-principal to switch the CLI identity off the user account, and verifies via az account show that the resulting identity is servicePrincipal type (not user). The user's only manual moments are signing in to portal.azure.com once and approving any MFA prompt their account requires. Never ships user-token credentials, verifies post-install that az account show reports user.type=servicePrincipal, refuses to keep credentials if it reports user.type=user. Read and operate Azure services via the az CLI (Storage, App Service, VMs, Key Vault, Resource Groups, etc.). Use this skill when the user asks to set up Azure, connect Microsoft Azure, or interact with Azure Storage, App Service, Key Vault, virtual machines, or resource groups. On first use run Phase 1 to install + create the service principal + assign role + verify before attempting any tool calls."
allowed-tools: mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - azure
    - microsoft
    - cloud
    - storage
    - app-service
    - cli
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Azure auth or permission errors
    - skill: aws-connector
      reason: Sibling cloud-CLI connector, same Playwright-driven user-mint pattern
    - skill: gcloud-connector
      reason: Sibling cloud-CLI connector, same Playwright-driven service-account-mint pattern
    - skill: outlook-connector
      reason: Both use Microsoft ecosystem, Azure CLI can complement M365 workflows
---

# Azure Connector

## Overview

This skill lets you read and operate a user's Azure subscription on their behalf via the **`az` CLI**. It has two phases:

- **Phase 1, Install & Auth (autonomous via Playwright).** Claude installs the `az` CLI, drives the entire Azure Portal flow inside a Playwright MCP browser (find or create an Entra ID app registration named "claude-assistant", DOM-extract the Application (client) ID and Directory (tenant) ID, mint a client secret, assign a built-in role on the subscription, switch the CLI identity to the service principal), persists credentials to `~/.config/azure-connector/credentials.env`, and verifies via `az account show` that the active identity is `servicePrincipal` type. The user's only manual moments are signing in to `portal.azure.com` once and approving any MFA prompt. Everything else, app registration, secret mint, role assignment, identity switch, is autonomous.
- **Phase 2, Use Tools.** Once the connector is configured, you shell out to `az` via Bash to answer questions and make changes. Common operations covered: Storage, App Service, Virtual Machines, Key Vault, Resource Groups.

> **Never ships user-token credentials.** Azure CLI's default `az login` flow stores a session token tied to the user's Microsoft account, that token has whatever permissions the user has across all their tenants and subscriptions, including potentially Owner / Global Administrator. This SKILL refuses to ship those user-token credentials. Step 11's identity check verifies `az account show` reports `user.type = servicePrincipal`, and aborts cleanly if it reports `user.type = user`. The user signs in interactively only because the Portal needs to authenticate a human to drive the app-registration flow; once the service principal is minted, all programmatic access flows through it.

> **This is for local laptop setup only.** Server provisioning (Azure VMs) lives in [claude-cloud-kit](https://github.com/selrai-company/claude-cloud-kit).

**Which phase to run**, Before any tool call, check whether the Azure CLI is installed and authenticated as a service principal. Run:

```bash
az account show --output json 2>&1
```

- Exit code 0 with valid JSON → parse `.user.type`.
  - `servicePrincipal` → connector is configured. Go to Phase 2.
  - `user` → user-token credentials. Run Phase 1 from Step 5 to mint a service principal and replace the active identity.
- Exit code 1 with "Please run 'az login'" → no auth at all. Run Phase 1 from the appropriate step.
- Exit code 127 (`az: command not found`) → CLI not installed. Run Phase 1 from Step 3.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous, Claude does the work, the user only signs in to Azure once. Every message during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to Azure in the browser window I just opened" and (if challenged) "please approve the security check on your phone."
- **Plain English only.** No jargon. Never say CLI, binary, PATH, env var, Entra, tenant, subscription ID, app registration, service principal, client ID, client secret, RBAC, role assignment, MFA, OAuth, MCP, DOM, Playwright, terminal, or policy name. If you must refer to a technical thing, name it plainly: "the Azure tool I need", "your browser", "a special Azure account I'll set up for you", "your Microsoft sign-in", "a security check".
- **Tell them what is about to happen.** Before any action: "I'm going to set up Azure for you, this takes about three minutes."
- **React to success and failure warmly.** Good: "That worked, your Azure is now connected." Bad: "AADSTS50076."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem, let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the client secret, tenant ID, or client ID** back to the user. All three are stored locally; never include them in any output visible to the user.

---

## PHASE 1, Install & Auth (autonomous via Playwright)

Claude installs the `az` CLI, drives the Azure Portal end-to-end via Playwright MCP to mint a least-privilege service principal with appropriately-scoped role assignment and create a client secret, writes the credentials autonomously, switches the CLI identity to the service principal via `az login --service-principal`, and verifies via `az account show` that the active identity is `servicePrincipal` type. The user's only role is signing in to the Portal when prompted (and only the first time, the persistent Playwright profile keeps the session for future runs) and approving any MFA challenge.

> **Reasoning model.** Each step describes a *goal* (e.g., "find the New registration button on the App registrations blade and click it"). Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_fill_form`. Match elements by visible labels and `aria-label` attributes, Azure Portal UI evolves frequently and `#view/...` URL routing changes between Portal versions.

> **Why we mint a service principal instead of reusing the user's `az login` token.** A user's interactive `az login` session inherits all permissions the user holds across every Microsoft Entra tenant and Azure subscription they have access to, typically Owner or Global Administrator on at least one. That token then sits on disk in `~/.azure/msal_token_cache.json`, is automatically refreshed for ~90 days, and any process that reads that cache (a malicious npm package, a misconfigured CI runner, a leaked dev container) can act as the user across all those scopes. A service principal is permission-scoped to exactly the role assignments we give it on exactly the subscription we choose, can be revoked with one click in the Portal, and never inherits the user's other permissions. The post-mint identity check in Step 11 enforces this, if `az account show` reports `user.type = user` after we ran `az login --service-principal`, that means the SP login silently failed and we're still on the user identity; the SKILL refuses to leave that state.

### Step 1, Orient the user and ask read-only vs read-and-write

Tell the user, in one short message:

> "I'll connect your Azure now. First, do you want me to just **read** your Azure (list resources, view costs, browse storage), or do you want me to also be able to **make changes** for you (start VMs, deploy code, modify resources)? Read-only is safer to start."

Wait for their answer. Remember it, this controls Step 8's role assignment.

- **Read-only** → assign the built-in role `Reader` (subscription-scoped). Covers list/get/show for all Azure resources.
- **Read + write** → assign the built-in role `Contributor` (subscription-scoped). Covers everything except role assignments and policy management, the role-assignment exclusion is the safety net so the minted service principal cannot grant itself broader permissions or assign roles to other principals.

> **Why not `Owner`.** `Owner` includes `Microsoft.Authorization/*/Write`, which would let the service principal create new role assignments, including granting itself any role on any resource. That defeats the purpose of running as a scoped non-user identity, if the service principal ever leaks its secret, it could escalate to administrative control of the entire subscription. `Contributor` blocks that escalation path while still allowing all resource-management operations.

### Step 2, Check if `az` is already installed and authenticated as a service principal

Silently run:

```bash
az --version 2>&1
```

If it errors with "command not found" (exit 127), continue to Step 3 to install. If it prints a version string, probe authentication state:

```bash
az account show --output json 2>&1
```

- Exit 0 with valid JSON → parse `.user.type`. If `servicePrincipal`, the connector is already configured, skip to Phase 2. If `user`, run Phase 1 from Step 5 to mint a service principal (the active identity gets replaced in Step 10).
- Exit 1 with "Please run 'az login'" → continue to Step 4.

### Step 3, Install Azure CLI cross-platform

Tell the user: *"I'm going to install a small tool I need to talk to Azure, this takes about a minute."*

Silently detect the user's OS and run the install command:

**macOS (Intel or Apple Silicon):**

```bash
brew install azure-cli
```

If Homebrew is not installed, install it first via `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`, then retry. If Homebrew install fails on a corporate laptop (common), fall back to the [Microsoft-published macOS installer](https://learn.microsoft.com/cli/azure/install-azure-cli-macos).

**Linux (Debian/Ubuntu):**

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Linux (RHEL/Fedora/CentOS):**

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
sudo dnf install -y azure-cli
```

**Windows (Git Bash):**

```bash
winget install --id Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements
```

> **Windows PATH note.** winget appends to the user PATH but the current shell may not see it until a fresh terminal. Resolve the binary directly for the rest of this session if `az --version` still 127s after install, derived from PR #238's defensive-path-handling pattern:
>
> ```bash
> AZ_BIN="$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages/" -name 'az.cmd' 2>/dev/null | head -1)"
> alias az="\"$AZ_BIN\""
> ```

If winget is unavailable, fall back to the MSI installer from `https://aka.ms/installazurecliwindowsx64`.

Verify:

```bash
az --version 2>&1
```

If the verify command still errors after install (`command not found` even with brew/winget on PATH), tell the user plainly: *"The terminal needs a refresh, please close this window, open a new one, then say 'ready'."* Wait, then retry.

### Step 4, Open the Azure Portal and confirm a logged-in session

Tell the user, in one short message:

> "Opening a browser window for you, please sign in to Azure when it appears (and approve any security check). I'll do the rest. About two minutes."

Call:

```
mcp__playwright__browser_navigate({ url: "https://portal.azure.com" })
```

If the user is signed out, Azure redirects to `login.microsoftonline.com`. Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see the Azure Portal home with a "Microsoft Azure" header and a left-side service navigation panel) → continue to Step 5.
- **Sign-in form** ("Pick an account" or email input) → poll silently with `browser_wait_for({ text: "Microsoft Azure" })`. Do not ask the user to confirm; detect login completion yourself.
- **MFA challenge** ("Approve sign-in request", "Enter the code shown", "Authenticator app") → poll silently. Microsoft Entra typically requires MFA; this is the default flow, not an edge case.
- **Tenant picker** (multiple tenants visible, happens for users who are guests in other organisations) → click the tenant the user wants the connector tied to. If unclear which one, ask the user once: *"You have access to a few Azure organisations. Which one would you like me to use?"*

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 5, Find or create the "claude-assistant" app registration

Navigate to Microsoft Entra ID → App registrations:

```
mcp__playwright__browser_navigate({ url: "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade" })
```

`browser_wait_for({ text: "App registrations" })`. Take a snapshot.

The blade shows a list of existing app registrations with a search/filter input. Search for `claude-assistant`:

- **App exists** → click into the app's Overview blade. Skip to Step 6.
- **App does not exist** → click the **+ New registration** button. Azure opens the registration form.

**Registration form fields:**

- **Name** → type `claude-assistant` via `browser_type` or `browser_fill_form`.
- **Supported account types** → leave the default ("Accounts in this organizational directory only, Single tenant"). The service principal only needs to operate within this user's tenant.
- **Redirect URI** → leave blank. Service principals authenticated via client secret don't need a redirect URI.

Click **Register**. Azure redirects to the new app's Overview blade.

> **Robustness note.** This blade layout reflects the Azure Portal's Entra ID UI as of 2025-2026. Microsoft has reshaped the App registrations create form at least once in the last two years (it used to be a 2-step wizard; it's currently a single form). If the form fields differ, snapshot and adapt, the goal is "create an app registration named claude-assistant, single-tenant, no redirect URI". The find-existing-app path is more stable; the create-new-app form is the path most likely to need maintenance.

### Step 6, DOM-extract the Application (client) ID and Directory (tenant) ID

The Overview blade displays both values in the "Essentials" section near the top. They appear as text labelled "Application (client) ID" and "Directory (tenant) ID", each followed by a UUID. Both are copyable but not masked, Azure considers these identifiers public, not secret (unlike the client secret in Step 7).

Read both via `browser_evaluate`:

```js
() => {
  // UUID v4 shape: 8-4-4-4-12 hex chars
  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const out = { client_id: null, tenant_id: null };
  // Walk DOM looking for elements labelled with "Application (client) ID" or "Directory (tenant) ID"
  const labels = Array.from(document.querySelectorAll('*')).filter(el => {
    const t = (el.innerText || '').trim();
    return /Application \(client\) ID|Directory \(tenant\) ID/i.test(t) && t.length < 50;
  });
  for (const label of labels) {
    const which = /client/i.test(label.innerText) ? 'client_id' : 'tenant_id';
    if (out[which]) continue;
    // Walk up to find a parent containing both the label and the UUID value
    let candidate = label.parentElement;
    for (let depth = 0; depth < 6 && candidate; depth++) {
      const txt = (candidate.innerText || '').trim();
      const lines = txt.split('\n').map(s => s.trim()).filter(Boolean);
      const uuid = lines.find(l => UUID_RE.test(l));
      if (uuid) { out[which] = uuid; break; }
      candidate = candidate.parentElement;
    }
  }
  return out;
}
```

**Validation (silent).** Both must match the UUID v4 regex. If either fails, re-snapshot, the Essentials section may have collapsed; click the "Show more" toggle if present and retry.

### Step 7, Mint a client secret on Certificates & secrets

Navigate to the Certificates & secrets blade. The Overview blade has a left-nav link labelled "Certificates & secrets", click it via `browser_click`, OR navigate directly:

```
mcp__playwright__browser_navigate({ url: "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/<client_id>" })
```

(Substitute `<client_id>` from Step 6.)

`browser_wait_for({ text: "Client secrets" })`. Take a snapshot.

The blade has tabs: **Certificates**, **Client secrets**, **Federated credentials**. Click **Client secrets** tab if not already selected. Click **+ New client secret**.

A right-side panel opens with two fields:

- **Description** → type `claude-assistant-cli`
- **Expires** → pick a value. The default is "180 days" (~6 months); leave it as default. (For long-lived workshop demos, "365 days" or "Custom" with a 24-month expiry is acceptable. The SKILL re-runs Phase 1 to rotate when the secret nears expiry.)

Click **Add**. Azure redirects back to the Client secrets list with the new secret showing **two columns of interest**:

- **Value**, the actual secret string. **Azure shows this value exactly once**, once you navigate away from this page or refresh, the Value column shows only the masked stub `•••••••••...` and there is no recovery path. You must DOM-extract before navigating.
- **Secret ID**, a UUID for this credential. Not the secret itself.

The Value column may be masked behind a "Copy to clipboard" button (a clipboard icon next to the value). The secret string is in the DOM regardless of the masking; read it via `browser_evaluate`:

```js
() => {
  // Azure client secret value: 40 chars, base64url-ish (alphanumeric + ~ . _ -)
  // Examples: "abc123XYZ.~_-9876543210AbCdEfGhIjKlMnOpQrSt"
  const SECRET_RE = /^[A-Za-z0-9~._-]{30,50}$/;
  const all = Array.from(document.querySelectorAll('input, code, span, td, div'));
  for (const el of all) {
    const text = (el.value || el.innerText || '').trim();
    // Skip obviously-non-secret content (UUIDs, dates, descriptions)
    if (/^[0-9a-f-]{36}$/i.test(text)) continue; // UUID
    if (/\d{4}-\d{2}-\d{2}/.test(text)) continue; // date
    if (text.includes('claude-assistant')) continue; // description
    if (SECRET_RE.test(text)) return text;
  }
  return null;
}
```

**Validation (silent).** Client secret should match `[A-Za-z0-9~._-]{30,50}` (typically 40 characters of base64url-ish content). If extraction returns `null`, click the clipboard icon next to the Value column to reveal it (some Portal versions only render the value after the user clicks Copy), re-snapshot, and re-extract.

**Conversational fallback**, if two extract attempts don't surface a valid secret (e.g., Microsoft has moved the value to a clipboard-only widget on this account), narrate once: *"I'm having trouble reading the security key automatically, could you paste it for me? It starts with a mix of letters and numbers."* Wait for the user to paste, validate the shape, and continue. The secret transits the transcript in this fallback path; that's an accepted trade-off documented in [skills/CLAUDE.md](../CLAUDE.md) Pattern 2 → "Conversational fallback".

### Step 8, Pick a subscription and assign the role

Navigate to Subscriptions:

```
mcp__playwright__browser_navigate({ url: "https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBlade" })
```

`browser_wait_for({ text: "Subscriptions" })`. Take a snapshot.

The blade lists all subscriptions the signed-in user has access to:

- **One subscription** → click into it. Capture the Subscription ID (UUID format) from the Overview blade.
- **Multiple subscriptions** → ask the user once: *"You have a few Azure subscriptions. Which one would you like me to use?"* Show the names. Click into the chosen one.
- **Zero subscriptions** → tell the user: *"Your Azure account doesn't have a subscription yet. Please create one at portal.azure.com, Microsoft offers a free tier with $200 of credit. Tell me when it's done."*

On the chosen subscription's blade, click **Access control (IAM)** in the left nav, then **+ Add → Add role assignment**. Azure opens a 4-step wizard:

**Wizard step 1, Role.** A list of built-in roles appears with a search/filter input. Filter for `Reader` (read-only path) or `Contributor` (read-and-write path) per Step 1's choice. Pick the row labelled exactly that name (not "Storage Blob Reader" or "Reader (Privileged)" etc.). Click **Next**.

**Wizard step 2, Members.** "Assign access to" radio: pick **User, group, or service principal**. Click **+ Select members**, search for `claude-assistant` in the right-side search panel, click the matching row to select, click **Select** to close the panel. Click **Next**.

**Wizard step 3, Conditions.** Skip, leave the default ("Allow user to assign all roles" / "No conditions"). Click **Next**.

**Wizard step 4, Review + assign.** Confirm: role = Reader/Contributor, scope = this subscription, assigned to = `claude-assistant`. Click **Review + assign**.

Azure shows a notification toast: *"Role assignment added"*. The role propagates within ~30 seconds, the SP can authenticate immediately but resource queries may briefly return AuthorizationFailed during propagation.

Capture the Subscription ID for the credentials file.

### Step 9, Save the credentials (silent)

Silently write `~/.config/azure-connector/credentials.env`:

```bash
mkdir -p ~/.config/azure-connector
cat > ~/.config/azure-connector/credentials.env <<EOF
AZURE_CLIENT_ID="<client_id from Step 6>"
AZURE_CLIENT_SECRET="<client_secret from Step 7>"
AZURE_TENANT_ID="<tenant_id from Step 6>"
AZURE_SUBSCRIPTION_ID="<subscription_id from Step 8>"
EOF
chmod 600 ~/.config/azure-connector/credentials.env
```

Never echo any of the four values back to the user.

> **Why a separate file (not `~/.zshrc`).** Same reasoning as the QuickBooks connector: isolating Azure credentials keeps them out of the user's globally-sourced shell config. Every Phase 1 and Phase 2 az invocation prefixes with `set -a && source ~/.config/azure-connector/credentials.env && set +a` to load them just for that subprocess. Bash subshells don't auto-source `~/.zshrc`, so a global-export approach would silently fail in many invocation contexts.

### Step 10, Switch the CLI identity to the service principal

The default `az` identity (if any) is the user account from `az login`. We need to switch to the service principal so subsequent `az` calls run as the scoped identity, not the user. Run:

```bash
set -a && source ~/.config/azure-connector/credentials.env && set +a
az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" \
  --output json
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
```

`az login --service-principal` overwrites the active login context; the user's previous interactive session is replaced (it can be restored later with `az login`).

### Step 11, Verify the active identity (REFUSE if user-type)

Tell the user: *"Let me just double-check everything is talking to Azure correctly."*

Silently run:

```bash
az account show --output json
```

Parse the JSON. Critical: verify `.user.type == "servicePrincipal"`.

```bash
USER_TYPE="$(az account show --query 'user.type' --output tsv)"
case "$USER_TYPE" in
  servicePrincipal) echo "OK: signed in as service principal" ;;
  user)             echo "REFUSE: still on user identity" ; exit 1 ;;
  *)                echo "UNKNOWN identity type: $USER_TYPE" ; exit 1 ;;
esac
```

- **`servicePrincipal`** → success. Continue.
- **`user`** → REFUSE. The `az login --service-principal` call silently failed (most likely cause: AAD propagation delay where the new app registration isn't yet visible to the auth endpoint, or a typo'd client secret). Wait 30 seconds, retry Step 10. If still failing, fall back to checking `az ad sp show --id "$AZURE_CLIENT_ID"`, if the SP exists, the secret is wrong (re-mint via Step 7). If the SP does not exist, the app registration is missing or in a different tenant (re-run from Step 5).
- **Unknown type** → log silently for diagnostics, retry from Step 10.

**Also verify the role assignment took.** Run:

```bash
az role assignment list \
  --assignee "$AZURE_CLIENT_ID" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID" \
  --output json
```

The result should include exactly one entry with `roleDefinitionName` matching the role from Step 1 (`Reader` or `Contributor`). If the role list is empty, the role assignment in Step 8 didn't propagate, wait 30 seconds and re-check; if still empty, re-run Step 8.

> **Defense-in-depth check.** If the role assignment list shows `Owner` or `User Access Administrator` (privilege-escalation roles), REFUSE. The SKILL's job is to mint a scoped service principal, if a higher-privilege assignment slipped through (e.g., from a prior Phase 1 run that picked Owner), narrate: *"I noticed the connection has more access than I planned. Let me scope it down."* Detach the over-broad role assignment via `az role assignment delete --assignee <client_id> --role Owner --scope /subscriptions/<subscription_id>` and re-run Step 8 to attach the correct role.

### Step 12, Success message

Tell the user, in one short message:

> "All done, your Azure is now connected. I can help with things like *'show me my resource groups'*, *'what web apps do I have running?'*, or *'list my storage accounts'*. Give it a try!"

Save to memory that the az CLI is installed and authenticated as a service principal, so on the next use you go straight to Phase 2.

---

## PHASE 2, Use Tools

Once the connector is configured, shell out to `az` via Bash to answer questions and make changes. **Every Phase 2 command must be prefixed with the credentials source line** so the env vars are available if the SP token needs refresh:

```bash
set -a && source ~/.config/azure-connector/credentials.env && set +a && az <command>
```

For brevity, the recipes below omit the prefix, but you must include it in every actual Bash invocation.

### What to Try First

After setup, suggest simple tasks:

> "Want to try something? Here are a few things I can do with your Azure:"

```
"Show me my Azure resource groups."
"What web apps do I have running?"
"List my storage accounts."
"What's my Azure spending this month?"
```

Start with read-only queries to confirm the connection works end-to-end.

### Common Operations

#### Storage (Blob)

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

#### App Service (Web Apps)

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

#### Virtual Machines

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

#### Key Vault (Secrets)

```bash
# List vaults the SP has access to
az keyvault list --query '[].name' --output table

# Get a secret (requires Key Vault Reader or Secrets User role on the vault — separate from subscription-scoped Reader/Contributor)
az keyvault secret show --vault-name <vault-name> --name <secret-name> --query 'value' --output tsv

# Set a secret (requires Key Vault Secrets Officer role)
az keyvault secret set --vault-name <vault-name> --name <secret-name> --value "secret-value"
```

> **Key Vault role boundary.** Key Vault uses a separate RBAC scope from the subscription. Even with `Contributor` at subscription level, the SP needs Key Vault-specific roles (`Key Vault Reader`, `Key Vault Secrets User`, `Key Vault Secrets Officer`) to read/write secrets within a vault. If a Key Vault command returns `Forbidden`, the user needs to assign the appropriate role on the specific vault, narrate once and walk them to the vault's Access control (IAM) blade.

#### Resource Groups

```bash
# List resource groups
az group list --output table

# Create a resource group
az group create --name <rg-name> --location australiaeast

# Delete a resource group (and all resources in it)
az group delete --name <rg-name> --yes --no-wait
```

> **Resource group delete is async.** `--no-wait` returns immediately while Azure deletes resources in the background. Confirm with the user before deletion, it's irreversible.

#### Cost Management

```bash
# Current-month cost (Cost Management requires the SP to have Cost Management Reader role on the subscription — assign separately if needed)
az consumption usage list --start-date $(date -u +%Y-%m-01) --end-date $(date -u +%Y-%m-%d) --output table
```

> **Cost Management role boundary.** The default `Reader` and `Contributor` roles do NOT include Cost Management read access. To query costs, also assign `Cost Management Reader` on the subscription via Step 8's wizard (the user can re-run Phase 1 to pick a different role, or assign it manually in the Portal).

### Region Reference

| Location | Region code |
|---|---|
| Sydney | `australiaeast` |
| Singapore | `southeastasia` |
| US East | `eastus` |
| US West | `westus2` |
| London | `uksouth` |
| Frankfurt | `germanywestcentral` |
| Tokyo | `japaneast` |

To set a default region per-resource-group:

```bash
az group create --name <rg-name> --location <region>
```

There is no global default region in `az` config, region is set per-resource at creation time.

---

## Service Principal Lifecycle

The SP minted in Phase 1 is named `claude-assistant`. To rotate, revoke, or audit it:

```bash
# Show the SP
az ad sp show --id "$AZURE_CLIENT_ID" --output table

# List role assignments on the SP
az role assignment list --assignee "$AZURE_CLIENT_ID" --output table

# List the SP's secrets (you cannot read the values — only metadata + IDs)
az ad app credential list --id "$AZURE_CLIENT_ID" --output table

# Add a new secret (e.g. for rotation)
az ad app credential reset --id "$AZURE_CLIENT_ID" --display-name "claude-assistant-rotated-$(date +%Y%m%d)" --years 1

# Delete the SP entirely (revokes all access)
az ad sp delete --id "$AZURE_CLIENT_ID"
```

> **The minted SP cannot manage Entra ID or roles** because Step 1's `Contributor` (or `Reader`) role excludes role assignments and Entra app management. To rotate the SP's secret, change its role, or delete it, the user must sign in to the Portal as themselves (or as an admin), the SP cannot do it on its own. This is the safety net.

---

## SSO Login (Alternative, for Organizations with Hybrid Identity)

If the user's organisation requires interactive sign-in for compliance reasons (and policy disallows long-lived service-principal secrets), skip Phase 1's secret-mint step and use device-code flow:

```bash
az login --use-device-code
```

This prints a code and a URL. The user signs in on any device and pastes the code; the resulting session lives in `~/.azure/msal_token_cache.json` and refreshes automatically for ~90 days.

> **When to use device-code vs service principal.** Service principal (Phase 1's default) is preferred for unattended automation, short to set up, no token-refresh dance, never expires until rotated. Device-code flow is required when the org's Conditional Access policy disallows secret-based service principal sign-in (rare but possible, typically signalled by AADSTS50011 or AADSTS500011 errors during Step 10). Both can coexist in `az`, device-code creates a profile under the user's account, service principal under the SP's account; switch via `az account set --subscription <sub-id>` and the user.type follows.

---

## Auth & Session

```bash
# Check who is signed in (Phase 2 sanity)
az account show

# Show the active service principal's role assignments
az role assignment list --assignee "$AZURE_CLIENT_ID" --output table

# Switch subscriptions (if the SP has access to multiple)
az account set --subscription "<subscription-id-or-name>"

# List configured profiles
az account list --output table

# Log out (clears the token cache; re-run Step 10 to log back in)
az logout
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `az: command not found` | Shell needs restart, open a new terminal, or use the Step 3 PATH alias |
| `Please run 'az login'` | Long-lived SP creds gone, run Phase 1 from Step 10 to re-login |
| `Insufficient privileges to complete the operation` | The SP doesn't have the role for that operation. If user picked Read-only and now wants to write, run Phase 1 from Step 8 to swap the role to Contributor. |
| `AuthorizationFailed` | Role assignment hasn't propagated yet (eventual consistency), wait 30 seconds and retry. If persistent, check `az role assignment list --assignee $AZURE_CLIENT_ID` |
| `AADSTS7000215: Invalid client secret` | Secret expired or mistyped, re-run Phase 1 from Step 7 to mint a fresh one |
| `AADSTS700016: Application not found in directory` | App registration deleted or in wrong tenant, re-run Phase 1 from Step 5 |
| `AADSTS50076: MFA required` | Conditional Access policy requires MFA for the SP, switch to device-code flow (`az login --use-device-code`) |
| `Subscription not found` | Wrong subscription ID in credentials, run `az account list` and update `AZURE_SUBSCRIPTION_ID` |
| `Certificate verification failed` | Corporate proxy issue, contact IT or try `az config set core.ssl_verification=false` temporarily |

When an error occurs, say:

> "No problem, let me try a different way."

Then diagnose and fix. Never show raw error messages to the user, translate them into plain English.

---

## Behaviour Guidelines (Phase 2)

- **Always run `az account show` first** at the start of a session to confirm the active identity is `servicePrincipal` (not `user`). If it's `user`, run Phase 1 from Step 10, the SKILL should never operate on user-token credentials.
- **Confirm before destructive actions**, deleting resource groups, deallocating VMs, removing secrets, deleting service principals.
- **Subscription context matters**, `az account show --query 'id'` before running commands. If the SP has access to multiple subscriptions and the active one is wrong, switch with `az account set --subscription <id>`.
- **Auth errors** → for SP creds, re-run Phase 1 from Step 7 to rotate the secret. For device-code flow, run `az login --use-device-code`.
- **`az not found`** → restart shell or reinstall via Phase 1 Step 3.
- **Region/location**, for resource creation, default to `australiaeast` if user is Australian, otherwise default to `eastus`. Always confirm before creating resources.
- **Never echo or log credentials**, `AZURE_CLIENT_SECRET`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and the SP token must never appear in any output visible to the user.
- **One step at a time**, for Phase 2, this is less strict than Phase 1; users running list/show queries don't need step-by-step narration.
- **Role boundary awareness**, if the user asks Claude to manage Entra ID (create users, assign Global Administrator), explain plainly: "Your Azure connection is set up to be safer, it can read and operate Azure resources but can't change identity or role settings. To do that, please sign in to portal.azure.com directly." Do not attempt to escalate.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer follows `aws-connector` and `github-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Azure auth or permission errors
- **aws-connector** / **gcloud-connector**: Sibling cloud-CLI connectors, same Playwright-driven scoped-identity-mint pattern (the cloud trio)
- **outlook-connector**: Sibling Microsoft-ecosystem connector, both use Microsoft accounts; the Azure tenant and the M365 tenant are typically the same
- **stripe-connector** / **github-connector** / **quickbooks-connector**: Sibling autonomous-Phase-1 connectors, closest reference shapes for the Playwright-drives-the-provider-console pattern this skill follows
