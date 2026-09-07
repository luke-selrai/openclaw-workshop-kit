---
name: gcloud-connector
description: "Connect Google Cloud to Claude by installing the `gcloud` CLI and setting it up with its own limited-access sign-in. Use when the user asks to set up or connect GCP, or wants Google Cloud work (BigQuery, Cloud Storage, Cloud Run, Compute Engine, App Engine) and the `gcloud` CLI isn't signed in with that limited-access sign-in yet, or is still on the user's personal Google login. Once connected, Google Cloud runs directly through the `gcloud` CLI."
allowed-tools: mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - gcp
    - google-cloud
    - gcloud
    - bigquery
    - cloud-storage
    - cli
    - cloud
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting gcloud auth or permission errors
    - skill: aws-connector
      reason: Sibling cloud-CLI connector - same Playwright-driven scoped-identity-mint pattern
    - skill: azure-connector
      reason: Sibling cloud-CLI connector - same Playwright-driven scoped-identity-mint pattern
---

# Google Cloud Connector

## Overview

This skill lets you read and operate a user's Google Cloud project on their behalf via the **`gcloud` CLI**. It has two phases:

- **Phase 1 - Install & Auth.** Reuse the intended existing human login for authorized provisioning with explicit account and project flags. Create a dedicated service account and private key, then activate it only in the connector's process-local `CLOUDSDK_CONFIG`. The user's original active account, project, configuration, and Application Default Credentials stay unchanged.
- **Phase 2 - Use Tools.** Source the connector environment inside each command's subshell, verify its exact saved identity and project, and operate within its assigned permissions.

> **Separate provisioning from operation.** A human login can authorize setup without becoming the connector's runtime identity. An unrelated service account in the default configuration is not evidence this connector is connected. Never adopt or change an existing `personal-assistant` account merely because it is available.

> **This is for local laptop setup only.** Server/VM provisioning lives in [claude-cloud-kit](https://github.com/selrai-company/claude-cloud-kit).

**Phase 0 — resume the exact saved connector.** Run the bundled helper from this skill's directory:

```bash
python3 scripts/connect.py check
```

- `CONNECTED_EXACT_SAVED_ACCOUNT_AND_PROJECT` → the saved key, dedicated configuration, exact account/project, and a real project read agree. Continue to Phase 2.
- Missing credentials → install the CLI if needed, then follow Phase 1. The global active identity alone does not decide this branch.
- Partial state, mismatched identity/project, legacy credentials without the ownership record, or authentication/endpoint overrides → preserve everything and inspect the specific state privately. Do not replace the key, adopt another account, remove bindings, or rerun provisioning automatically. A timed-out mutation may have completed.

The helper reads key contents privately and prints status only. It does not print tokens, key material, or configuration values.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work, the user only signs in to Google once. Every message during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to Google in the browser window I just opened" and (if challenged) "please approve the security check on your phone."
- **Plain English only.** No jargon. Never say CLI, binary, PATH, gcloud, IAM, project, service account, JSON key, role, OAuth, scope, MFA, ADC, MCP, DOM, Playwright, terminal. If you must refer to a technical thing, name it plainly: "the Google Cloud tool I need", "your browser", "a special Google Cloud account I'll set up for you", "your Google sign-in", "a security check".
- **Tell them what is about to happen.** Before any action: "I'm going to set up Google Cloud for you - this takes about three minutes."
- **React to success and failure warmly.** Good: "That worked - your Google Cloud is now connected." Bad: "PERMISSION_DENIED."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the JSON key file contents** back to the user. The key file is written to disk; never include any of its values in any output visible to the user.

---

## PHASE 1 - Install & Auth (autonomous via Playwright + CLI hybrid)

Reuse the account and setup scope already established in the conversation. For a fresh workshop test, provision a new unbilled project with a Viewer-only connection. Creating that project must be authorized; an ordinary request to use an existing project does not authorize creating a different one. No billing link, paid resource, or additional service API is part of connection setup.

### Step 1 - Choose the intended account and project

If the user already chose an account and requested a new test project, continue. Otherwise establish whether to use their existing project or create a new test project. Default the new test connection to read-only. For an existing project, retain the original read-only versus requested-write choice, but select only permissions needed for the requested work. Do not grant Editor just to complete the connection test.

### Step 2 - Check installation and existing login

Run `gcloud --version`, then inspect `gcloud auth list --format=json` privately to identify the intended saved human login. A working saved login skips browser authentication. Keep the current active account/project intact; use `--account="$HUMAN_ACCOUNT"` on provisioning commands rather than switching the default account. If the CLI is missing, continue to Step 3.

### Step 3 - Install Google Cloud CLI cross-platform

Tell the user: *"I'm going to install a small tool I need to talk to Google Cloud - this takes about a minute."*

Silently detect the user's OS and run the install command:

**macOS (Homebrew):**

```bash
brew install --cask google-cloud-sdk
GCLOUD_SDK_ROOT="$(brew --prefix)/share/google-cloud-sdk"
export PATH="$GCLOUD_SDK_ROOT/bin:$PATH"
hash -r
```

If Homebrew is not installed, fall back to the Google-published curl installer:

```bash
curl https://sdk.cloud.google.com | bash
GCLOUD_SDK_ROOT="$HOME/google-cloud-sdk"
export PATH="$GCLOUD_SDK_ROOT/bin:$PATH"
hash -r
```

**Linux (any distro):**

```bash
curl https://sdk.cloud.google.com | bash
GCLOUD_SDK_ROOT="$HOME/google-cloud-sdk"
export PATH="$GCLOUD_SDK_ROOT/bin:$PATH"
hash -r
```

The curl installer defaults to `~/google-cloud-sdk/`; if another install directory is selected, use that observed directory as `GCLOUD_SDK_ROOT`. These recipes update the current command shell without replacing it or sourcing interactive completion files. For a later Bash tool call, prepend the same SDK `bin/` directory again or invoke its `gcloud` binary by absolute path. During installation, defer `gcloud init` and sign-in to the connection steps below; PATH repair itself must preserve the active account and configuration. Continue only when the version check below succeeds.

**Windows (Git Bash / PowerShell):**

```bash
winget install --id Google.CloudSDK --accept-package-agreements --accept-source-agreements
```

> **Windows PATH note.** winget appends to the user PATH but the current shell may not see it until a fresh terminal. Resolve the binary directly for the rest of this session if `gcloud --version` still 127s after install - derived from PR #238's defensive-path-handling pattern:
>
> ```bash
> GCLOUD_BIN="$(find "$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk/bin" -name 'gcloud.cmd' 2>/dev/null | head -1)"
> alias gcloud="\"$GCLOUD_BIN\""
> ```

If winget is unavailable, fall back to the GoogleCloudSDKInstaller.exe download from `https://cloud.google.com/sdk/docs/install#windows`.

Verify:

```bash
gcloud --version 2>&1
```

If the verify command still errors after install (`command not found` even after the install script ran), tell the user plainly: *"The terminal needs a refresh - please close this window, open a new one, then say 'ready'."* Wait, then retry.

### Step 4 - Sign in only if the intended login is unavailable

Use the CLI's emitted authorization flow with a retained interactive process: `gcloud auth login "$HUMAN_ACCOUNT" --no-activate --no-launch-browser`. Keep its stdin attached using the harness's supported terminal session, open the exact printed URL in a browser signed into the intended Google account, and return the requested response to that same process. Drive browser actions when tools and authorization permit; involve the attendee only for an actual verification step the harness cannot complete.

Follow the current CLI prompt rather than assuming a fixed code-page layout. If the system-browser callback route is needed, retain `--no-activate` with `gcloud auth login "$HUMAN_ACCOUNT" --no-activate`. Do not use `--update-adc`, run `gcloud init`, or switch default configurations. Google's [login reference](https://docs.cloud.google.com/sdk/gcloud/reference/auth/login) documents that normal login activates the account unless `--no-activate` is supplied and that `--update-adc` overwrites existing ADC credentials.

### Step 5 - Provision the chosen connection

**New authorized test project:** read [references/new-project.md](references/new-project.md), then run the bundled helper with the intended existing human account and a fresh project ID. It preserves the original CLI configuration, creates a new project without setting it as default, enables IAM and Cloud Resource Manager, creates a new dedicated service account with Viewer, saves a private key without replacing files, and activates it in a separate CLI directory. It does not link billing or create paid resources.

**Existing chosen project:** preserve this route using [references/existing-project.md](references/existing-project.md). Scope every provisioning command to the explicit human account and project, create a new connector-owned identity rather than adopting a namesake, and use the same isolated runtime and private persistence contract. If ownership of prior connector files is uncertain, inspect and review it before continuing.

### Step 6 - Verify and report the actual scope

For a fully provisioned partial setup whose saved key is already activated in the isolated configuration, use the guarded `finish` command in [references/new-project.md](references/new-project.md). It verifies existing resources and completes only missing local files; preserve valid files already present. Never rerun `new-project` to finish.

The helper's success requires the exact saved service-account email and project in its dedicated configuration, a successful `projects describe`, and unchanged original configuration. Run `python3 scripts/connect.py check` from the actual caller runtime before saying the connector is ready.

For the new Viewer connection, say: “Your Google Cloud test space is connected. I can read its details, and your existing setup is unchanged.” Do not promise BigQuery jobs, deployments, writes, or access to unrelated projects from this test. If Google blocks project creation, IAM, or key creation through organization policy, preserve partial state and explain the specific gate. Do not change policy, remove older keys, delete privileged bindings, or link billing as recovery.

---

## PHASE 2 - Use Tools

Once the connector is configured, shell out to `gcloud` (and `bq`, `gsutil`) via Bash. **Every Phase 2 command must be prefixed with the credentials source line** so `GOOGLE_APPLICATION_CREDENTIALS` is set for SDK-based tools:

```bash
( set +x; source "$HOME/.config/gcloud-connector/credentials.env"; gcloud <command> --account="$GCLOUD_CONNECTOR_ACCOUNT" --project="$GCLOUD_PROJECT" --quiet )
```

For brevity, the recipes below omit this wrapper. Include it in every actual invocation, including region/configuration changes, key lifecycle work, and SDK commands. `CLOUDSDK_CONFIG` selects only the connector directory in that subshell. Use explicit account/project flags for gcloud and the saved project for bq; never export this state into the user’s global shell. The new test key is Viewer-only: write recipes are available only after a separately authorized operation has the required permissions and billing, if needed.

### What to Try First

After setup, suggest simple tasks:

> "Want to try something? Here are a few things I can do with your Google Cloud:"

```
"Show me my Cloud Storage buckets."
"What projects do I have?"
"List my Compute Engine VMs."
"Run a BigQuery query against [dataset]."
```

Start with read-only queries to confirm the connection works end-to-end.

### Common Operations

#### BigQuery

```bash
# List datasets
bq ls --project_id="$PROJECT_ID"

# List tables in a dataset
bq ls --project_id="$PROJECT_ID" "$PROJECT_ID:dataset_name"

# Run a query
bq query --use_legacy_sql=false 'SELECT * FROM `project.dataset.table` LIMIT 10'

# Show table schema
bq show --schema --format=prettyjson "$PROJECT_ID:dataset.table"
```

> BigQuery commands use the `bq` CLI which is bundled with the gcloud SDK and reads the same credentials.

#### Cloud Storage

```bash
# List buckets
gcloud storage ls

# List files in a bucket
gcloud storage ls gs://bucket-name/

# Download a file
gcloud storage cp gs://bucket-name/file.csv ./file.csv

# Upload a file
gcloud storage cp ./local-file.csv gs://bucket-name/

# Sync a folder
gcloud storage rsync ./local-folder gs://bucket-name/folder/
```

#### Cloud Run

```bash
# List services
gcloud run services list

# Describe a service (URL, env vars, latest revision)
gcloud run services describe SERVICE_NAME --region=REGION --format=json

# Deploy a service from source
gcloud run deploy SERVICE_NAME --source . --region=REGION

# View logs
gcloud run services logs read SERVICE_NAME --region=REGION --limit=50
```

#### Compute Engine

```bash
# List VMs
gcloud compute instances list

# Start a VM
gcloud compute instances start INSTANCE_NAME --zone=ZONE

# Stop a VM
gcloud compute instances stop INSTANCE_NAME --zone=ZONE

# SSH into a VM
gcloud compute ssh INSTANCE_NAME --zone=ZONE
```

#### App Engine

```bash
# Deploy
gcloud app deploy

# View logs
gcloud app logs tail
```

#### IAM (read-only on the SA itself)

```bash
# Show the SA's metadata
gcloud iam service-accounts describe "$GCLOUD_CONNECTOR_ACCOUNT"

# List role bindings on the SA
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${GCLOUD_CONNECTOR_ACCOUNT}" \
  --format="value(bindings.role)"
```

> **The new Viewer account cannot administer permissions or keys.** Authorized lifecycle work uses the intended human login with explicit account/project flags in its original configuration; normal connector operations stay in the isolated configuration.

### Region Reference

| Location | Region code |
|---|---|
| Sydney | `australia-southeast1` |
| Singapore | `asia-southeast1` |
| US Central (Iowa) | `us-central1` |
| US East (Virginia) | `us-east1` |
| US West (Oregon) | `us-west1` |
| London | `europe-west2` |
| Frankfurt | `europe-west3` |
| Tokyo | `asia-northeast1` |

To set a default region for Cloud Run, GKE, etc.:

```bash
gcloud config set compute/region <region-code>
gcloud config set compute/zone <region-code>-a
```

There is no global default region for all services - each service has its own default and most accept `--region` per-command.

---

## Service Account Lifecycle

Use the exact saved account and project from `connection.json` and `credentials.env`; do not infer ownership from an email suffix or partial name. The read-only lifecycle checks are `gcloud iam service-accounts describe "$GCLOUD_CONNECTOR_ACCOUNT"`, `gcloud projects get-iam-policy "$GCLOUD_PROJECT"`, and `gcloud iam service-accounts keys list --iam-account="$GCLOUD_CONNECTOR_ACCOUNT"`, scoped with the Phase 2 wrapper.

Rotation, revocation, role changes, and deletion are separate, explicitly requested lifecycle operations. Use the intended human login in its original configuration with explicit account/project flags when administration is required. Reserve a new private destination for a rotation key; test it in the isolated connector configuration before any separately authorized retirement of the prior key. Preserve unexpected roles and existing keys for review. Re-running setup is not rotation, and hitting the key limit is not permission to delete the oldest key.

---

## Application Default Credentials

Setup writes `GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud-connector/key.json` into the credentials env file. This satisfies ADC for:

- Python `google-cloud-*` client libraries (BigQuery, Storage, Pub/Sub, etc.)
- Node `@google-cloud/*` packages
- Go `cloud.google.com/go/*` modules
- Terraform `google` provider
- gcloud itself for some flows

If a tool reports "Could not automatically determine credentials", source the env file:

```bash
( set +x; source "$HOME/.config/gcloud-connector/credentials.env"; <SDK command> )
```

Then re-run the tool. The env var is the universal contract.

---

## Auth & Session

Start with `python3 scripts/connect.py check`. A saved service-account email alone does not prove authentication. Run all later reads inside the Phase 2 subshell; `gcloud auth list`, `gcloud config get-value account`, and `gcloud config get-value project` then refer to the dedicated connector configuration. Keep its account/project aligned with the saved manifest. A request to operate in another project requires explicit scope and access verification, not a default-project switch.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `gcloud: command not found` | Apply Step 3's SDK bin path in the current command shell or use the installed binary's absolute path; on Windows use its Step 3 path handling. Verify the version, then resume without changing the active account. |
| `ERROR: Reauthentication failed` | Verify the exact saved account/key and error privately; preserve existing files and inspect revocation or policy state before any explicitly authorized rotation |
| `ERROR: PERMISSION_DENIED` | Check the requested operation against the saved role. Viewer does not permit writes; arrange only the separately authorized permissions needed, preserving current bindings. |
| `ERROR: The project property is set to the empty string` | Check the saved project and source the connector environment inside the command subshell; preserve global defaults |
| `ERROR: Billing account not enabled` | That requested operation requires billing; report the gate. Connection setup does not link billing or enable paid services |
| `quota exceeded`, `limit reached` | Hit a project quota. Wait or request quota increase in Console. |
| `Could not automatically determine credentials` | Source the credentials env file: `( set +x; source "$HOME/.config/gcloud-connector/credentials.env"; <SDK command> )` |
| `RESOURCE_EXHAUSTED: Maximum number of keys` | List key metadata privately and preserve all keys; review ownership and any separately authorized retirement before retrying |
| Auth works but a specific API fails | Check the exact project and API. Setup enables IAM and Cloud Resource Manager only; enabling another API must belong to the separately authorized operation and use the intended provisioning identity |

When an error occurs, say:

> "No problem - let me try a different way."

Then diagnose and fix. Never show raw error messages to the user - translate them into plain English.

---

## Behaviour Guidelines (Phase 2)

- **Exact identity first** — run the Phase 0 helper check, then use the saved isolated configuration for every operation. Do not adopt an unrelated service account from the default configuration.
- **Destructive actions** — deleting resources, keys, service accounts, or bindings must be part of an explicitly authorized lifecycle operation; they are not automatic auth recovery.
- **Project context** — use the saved project explicitly. Preserve the user's original account, project, configuration files, and ADC.
- **Auth errors** — preserve partial state and existing keys. Diagnose the exact identity, key, and policy before an authorized repair; do not rerun key creation automatically.
- **`gcloud not found`** — apply Step 3's current-process SDK path repair before reinstalling.
- **Region/zone and API enablement** — choose these for the user's actual requested operation. New connection setup creates no compute resources and enables IAM and Cloud Resource Manager only.
- **Never echo or log credentials** - the JSON key file's contents must never appear in any output visible to the user.
- **One step at a time** - for Phase 2, less strict than Phase 1; users running `gcloud … list` queries don't need step-by-step narration.
- **Role boundary awareness** - if the user asks Claude to manage IAM (grant roles, create users, change project ownership), explain plainly: "Your Google Cloud connection is set up to be safer - it can read and operate resources but can't change permission settings. To do that, please sign in to console.cloud.google.com directly." Do not attempt to escalate.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer follows `aws-connector` and `azure-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting GCP auth or permission errors
- **aws-connector** / **azure-connector**: Sibling cloud-CLI connectors - same Playwright-driven scoped-identity-mint pattern (the cloud trio)
- **stripe-connector** / **github-connector** / **quickbooks-connector**: Sibling autonomous-Phase-1 connectors - closest reference shapes for the Playwright-drives-the-provider-console pattern
