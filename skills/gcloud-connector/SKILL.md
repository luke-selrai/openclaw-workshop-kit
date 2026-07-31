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

- **Phase 1 - Install & Auth (autonomous via Playwright + CLI hybrid).** Claude installs the `gcloud` CLI, drives the OAuth sign-in inside a Playwright MCP browser (via `gcloud auth login --no-launch-browser` - Playwright walks the user through Google sign-in, auto-clicks Allow on the consent screen, DOM-extracts the verification code Google returns on the success page, and pipes it back to gcloud's stdin), then mints a least-privilege service account named `claude-assistant` on the user's chosen GCP project via gcloud CLI hooks (no further Playwright needed - gcloud has first-class commands for SA creation, role binding, and key creation), writes the key file to `~/.config/gcloud-connector/key.json`, switches the active CLI identity to the service account, and verifies via `gcloud config get-value account` that the active identity is a service-account email. The user's only manual moments are signing in to Google once and any 2FA challenge.
- **Phase 2 - Use Tools.** Once the connector is configured, you shell out to `gcloud` (and `bq`, `gsutil`) via Bash to answer questions and make changes. Common operations covered: BigQuery, Cloud Storage, Cloud Run, Compute Engine, App Engine.

> **Never ships user-token credentials.** Google Cloud's default `gcloud auth login` flow stores a session token tied to the user's Google account in `~/.config/gcloud/credentials.db`. That token has whatever permissions the user has across all their GCP projects (typically Owner on at least one) and refreshes automatically. This SKILL refuses to ship those user-token credentials - Step 10's identity check verifies `gcloud config get-value account` returns a service-account email (`*.iam.gserviceaccount.com`), and aborts cleanly if it returns a user-format email. The user signs in interactively only because gcloud needs to authenticate a human to authorise the SA creation; once the service account is minted, all programmatic access flows through it via the JSON key file.

> **This is for local laptop setup only.** Server/VM provisioning lives in [claude-cloud-kit](https://github.com/selrai-company/claude-cloud-kit).

**Which phase to run** - Before any tool call, check whether the gcloud CLI is installed and active as a service account. Run:

```bash
gcloud config get-value account 2>&1
```

- Output ends in `.iam.gserviceaccount.com` → SA-active. Go to Phase 2.
- Output is a user-format email (e.g., `user@gmail.com`, `user@company.com`) → user-token active. Run Phase 1 from Step 5 to mint a service account and switch the active identity.
- Output is `(unset)` or empty → no auth at all. Run Phase 1 from the appropriate step.
- Exit code 127 (`gcloud: command not found`) → CLI not installed. Run Phase 1 from Step 3.

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

Claude installs the `gcloud` CLI, drives the OAuth sign-in via Playwright MCP (capturing the verification code from Google's consent success page), then uses gcloud CLI hooks to mint a least-privilege service account, bind a built-in role, create a JSON key, switch the active identity, and verify. The user's only role is signing in to Google when prompted (and only the first time - the persistent Playwright profile keeps the session for future runs) and approving any 2FA challenge.

> **Reasoning model.** Each step describes a *goal*. Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` for the sign-in flow; via `gcloud` CLI invocations for the SA management flow. Match elements by visible labels and `aria-label` attributes - Google's sign-in and consent UIs evolve and selector paths drift.

> **Why hybrid Playwright + CLI** (different shape from AWS PR #244 and Azure PR #245). gcloud has first-class CLI hooks for service-account creation, role binding, and key creation - `gcloud iam service-accounts create`, `gcloud projects add-iam-policy-binding`, `gcloud iam service-accounts keys create ... --key-file=<path>` write directly to a known path. AWS Console requires Playwright DOM-extract because the IAM Create access key modal shows the secret only once in the UI; Azure Portal requires Playwright DOM-extract because Certificates & secrets shows the value only once in the UI. GCP Console *also* shows JSON keys only on download, but the `gcloud iam service-accounts keys create` CLI command writes the key directly to a path - bypassing the download dance entirely. Playwright is therefore confined to Step 4 (sign-in + DOM-extract verification code), and the rest of Phase 1 is CLI.

### Step 1 - Orient the user and ask read-only vs read-and-write

Tell the user, in one short message:

> "I'll connect your Google Cloud now. First - do you want me to just **read** your Google Cloud (list resources, view costs, browse buckets), or do you want me to also be able to **make changes** for you (deploy services, modify resources, run BigQuery jobs)? Read-only is safer to start."

Wait for their answer. Remember it - this controls Step 7's role assignment.

- **Read-only** → bind the basic role `roles/viewer` (project-scoped). Covers list/get/describe for all GCP resources.
- **Read + write** → bind the basic role `roles/editor` (project-scoped). Covers create/update/delete on most resources, but excludes IAM management (cannot grant roles to other principals) and project-level admin actions (cannot delete the project, change billing, etc.) - the IAM-management exclusion is the safety net.

> **Why not `roles/owner`.** `Owner` includes `resourcemanager.projects.setIamPolicy`, which lets the service account grant itself any role on the project - defeating the purpose of running as a scoped non-user identity. `Editor` blocks that escalation path while still allowing all resource-management operations. Google [explicitly recommends](https://cloud.google.com/iam/docs/best-practices) against using basic roles in production and prefers predefined or custom roles, but for the workshop's "single-user laptop demo" pattern the basic roles are pragmatic.

### Step 2 - Check if `gcloud` is already installed and active as a service account

Silently run:

```bash
gcloud --version 2>&1
```

If it errors with "command not found" (exit 127), continue to Step 3 to install. If it prints a version string, probe authentication state:

```bash
gcloud config get-value account 2>&1
```

- Output ends in `.iam.gserviceaccount.com` → connector is already configured. Skip to Phase 2.
- User-format email → user-token active. Run Phase 1 from Step 5 to mint a service account.
- `(unset)` or empty → no auth. Continue to Step 4.

### Step 3 - Install Google Cloud CLI cross-platform

Tell the user: *"I'm going to install a small tool I need to talk to Google Cloud - this takes about a minute."*

Silently detect the user's OS and run the install command:

**macOS (Homebrew):**

```bash
brew install --cask google-cloud-sdk
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
```

If Homebrew is not installed, fall back to the Google-published curl installer:

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Linux (any distro):**

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

The installer creates `~/google-cloud-sdk/` and adds its `bin/` directory to `~/.bashrc` / `~/.zshrc`. The `exec -l $SHELL` re-execs the shell so `gcloud` is on PATH for the rest of the session.

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

### Step 4 - Sign in to Google (autonomous via Playwright)

Tell the user, in one short message:

> "I'm going to open Google Cloud sign-in in your browser - please sign in with your Google account. About a minute."

Run `gcloud auth login --no-launch-browser` in the background, capturing stdout to a temp file:

```bash
rm -f /tmp/gcloud-auth.log
gcloud auth login --no-launch-browser --update-adc > /tmp/gcloud-auth.log 2>&1 &
GCLOUD_PID=$!
```

`--no-launch-browser` instructs gcloud to print a URL to stdout and wait for the user to paste back a verification code. `--update-adc` also stores Application Default Credentials (used by client libraries) at the same time, so we don't need a separate `gcloud auth application-default login` later.

Read the printed URL from the log:

```bash
sleep 1
AUTH_URL="$(grep -oE 'https://accounts\.google\.com/[^[:space:]]+' /tmp/gcloud-auth.log | head -1)"
```

Navigate Playwright to the URL:

```
mcp__playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Sign-in form** ("Sign in with Google", email input) → wait silently with `mcp__playwright__browser_wait_for({ text: "Google Cloud SDK" })` (or the consent screen heading). The user signs in; the Playwright persistent profile remembers them next time.
- **2FA / Security challenge** ("2-Step Verification", "Verify it's you", Authenticator app prompt) → wait silently. The 2FA action happens on the user's phone or hardware key.
- **Account picker** (multiple Google accounts signed in) → wait for the user to pick the correct account, OR if obvious from context, click the most-recently-used row.
- **Consent screen** ("Google Cloud SDK wants to access your Google Account", with a list of scopes) → click **Allow** via DOM-extract:

  ```js
  () => {
    const btns = Array.from(document.querySelectorAll('button, [role="button"]'));
    const target = btns.find(b => /^(allow|continue)$/i.test((b.innerText||'').trim()));
    if (target) { target.scrollIntoView({block:'center'}); target.click(); return { clicked: true }; }
    return { clicked: false };
  }
  ```

After consent, Google redirects to a success page with a heading like *"Sign in to the gcloud CLI"* and a verification code displayed prominently. DOM-extract the code:

```js
() => {
  // Google's verification code is typically a long base64-ish string
  // (40-100 chars, alphanumeric + / + + + -). It appears in a copyable
  // input or code element, often near a "Copy" button.
  const all = Array.from(document.querySelectorAll('input, code, textarea, pre'));
  for (const el of all) {
    const text = (el.value || el.innerText || '').trim();
    if (text.length >= 40 && /^[A-Za-z0-9_/.+-]+$/.test(text)) {
      return text;
    }
  }
  return null;
}
```

**Validation (silent).** Verification code should be at least 40 characters of base64-ish content. If extraction returns null, click the **Copy** button next to the code (some Google success-page layouts only render the code into the DOM after the user clicks Copy), re-snapshot, and re-extract.

Pipe the captured code to gcloud's stdin:

```bash
echo "<verification_code>" >> /tmp/gcloud-auth-input
# Or directly via process substitution if gcloud is still in foreground
```

(Implementation detail: the cleanest pattern is to start gcloud with stdin connected to a fifo, `mkfifo /tmp/gcloud-stdin`, then `echo "<code>" > /tmp/gcloud-stdin` after extraction.)

Wait for gcloud to print success:

```bash
for i in $(seq 1 30); do
  if grep -q 'You are now logged in as' /tmp/gcloud-auth.log; then break; fi
  sleep 1
done
```

If the loop times out, fall back to Step 4b below.

**Step 4b - System-browser fallback** (when Playwright DOM-extract fails or `--no-launch-browser` is unreliable on the user's gcloud version): just run `gcloud auth login` (no flags). This opens the user's default browser, the user signs in there, gcloud captures via localhost callback. We don't drive Playwright, but the auth still completes. Less consistent with the AWS/Azure pattern, but reliable.

### Step 5 - Pick a project

Run:

```bash
gcloud projects list --format=json
```

Parse the JSON array:

- **One project** → set it automatically and continue.
  ```bash
  gcloud config set project <project-id>
  ```
- **Multiple projects** → ask the user once: *"You have a few Google Cloud projects. Which one would you like me to use?"* Show the project names. After they pick:
  ```bash
  gcloud config set project <chosen-project-id>
  ```
- **Zero projects** → tell the user: *"Your Google Cloud account doesn't have a project yet. Please create one at console.cloud.google.com - it's free. Tell me when it's done."* Wait, then re-run Step 5.

Capture the chosen project ID into a shell variable for Steps 6-9.

### Step 6 - Find or create the "claude-assistant" service account

Probe whether the SA already exists:

```bash
SA_EMAIL="claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts describe "$SA_EMAIL" --format=json 2>&1
```

- Exit 0 → SA exists. Skip to Step 7 (idempotent re-run; role and key still need to be checked / created).
- `NOT_FOUND` error → create it:

  ```bash
  gcloud iam service-accounts create claude-assistant \
    --display-name="Claude Assistant" \
    --description="Programmatic access for the Claude AI assistant" \
    --project="$PROJECT_ID"
  ```

The service account email follows the format `claude-assistant@<project-id>.iam.gserviceaccount.com`. Capture it.

### Step 7 - Bind the role on the project

Bind `roles/viewer` (read-only) or `roles/editor` (read-and-write) per Step 1's choice:

```bash
ROLE="roles/viewer"  # or "roles/editor" based on Step 1
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="$ROLE" \
  --condition=None
```

This is idempotent - if the binding already exists, gcloud returns the current policy unchanged.

> **Defense-in-depth: refuse `roles/owner`.** Before binding, check that the SA does NOT already have `roles/owner` on the project (could happen on idempotent re-runs after a prior Phase 1 run accidentally picked Owner):
>
> ```bash
> EXISTING_ROLES="$(gcloud projects get-iam-policy "$PROJECT_ID" --format=json | jq -r ".bindings[] | select(.members[] == \"serviceAccount:${SA_EMAIL}\") | .role")"
> if echo "$EXISTING_ROLES" | grep -qE 'roles/(owner|resourcemanager\.projectIamAdmin)'; then
>   echo "REFUSE: SA has Owner or projectIamAdmin role - privilege escalation risk"
>   gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
>     --member="serviceAccount:${SA_EMAIL}" \
>     --role="roles/owner"
>   # Then re-add the desired role
> fi
> ```

### Step 8 - Create a JSON key file

```bash
mkdir -p ~/.config/gcloud-connector
gcloud iam service-accounts keys create ~/.config/gcloud-connector/key.json \
  --iam-account="$SA_EMAIL"
chmod 600 ~/.config/gcloud-connector/key.json
```

> **Why CLI key creation, not Console download capture.** GCP Console's "Add Key → Create new key → JSON" flow triggers a browser download to the user's default download directory. Capturing that download via Playwright MCP is awkward (the MCP wrapper doesn't expose `page.on('download')` directly, and the download path varies by OS + Chrome profile). `gcloud iam service-accounts keys create --key-file=<path>` writes the key directly to a known path - much cleaner than the download dance. This is the principal reason GCP's autonomous Phase 1 is hybrid (CLI for SA management) rather than full Playwright drive (like AWS / Azure).

> **10-key limit.** GCP allows up to 10 active keys per service account. If `keys create` errors with `RESOURCE_EXHAUSTED`, list existing keys and delete the oldest:
>
> ```bash
> gcloud iam service-accounts keys list --iam-account="$SA_EMAIL" --format=json
> gcloud iam service-accounts keys delete "<oldest-key-id>" --iam-account="$SA_EMAIL"
> ```

### Step 9 - Activate the service account + write credentials env file

Switch the active gcloud identity to the service account:

```bash
gcloud auth activate-service-account "$SA_EMAIL" \
  --key-file=~/.config/gcloud-connector/key.json \
  --project="$PROJECT_ID"
```

This adds the SA to the `gcloud auth list` and sets it as active. Future `gcloud` calls run as the SA, not the user.

Write a small env file for downstream tools that read `GOOGLE_APPLICATION_CREDENTIALS` (Python google-cloud SDK, Node `@google-cloud/*` packages, Terraform GCP provider, etc.):

```bash
cat > ~/.config/gcloud-connector/credentials.env <<EOF
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud-connector/key.json"
export GCLOUD_PROJECT="$PROJECT_ID"
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
EOF
chmod 600 ~/.config/gcloud-connector/credentials.env
```

> **Why a separate file (not `~/.zshrc`).** Same reasoning as the QuickBooks / Azure connectors: isolating GCP credentials in their own file keeps them out of the user's globally-sourced shell config. Phase 2 prefixes every `gcloud` (and SDK) invocation with `set -a && source ~/.config/gcloud-connector/credentials.env && set +a`. The JSON key file's path is the only secret in this env file, but it still benefits from chmod 600 - anything that can read it can find the key.

### Step 10 - Verify the active identity (REFUSE if user-format)

Tell the user: *"Let me just double-check everything is talking to Google Cloud correctly."*

Silently run:

```bash
ACTIVE_ACCOUNT="$(gcloud config get-value account 2>&1)"
case "$ACTIVE_ACCOUNT" in
  *@*.iam.gserviceaccount.com) echo "OK: signed in as service account" ;;
  *@*)                          echo "REFUSE: still on user-format identity ($ACTIVE_ACCOUNT)" ; exit 1 ;;
  '(unset)'|'')                 echo "FAIL: no active account" ; exit 1 ;;
  *)                            echo "UNKNOWN account format: $ACTIVE_ACCOUNT" ; exit 1 ;;
esac
```

- **`*@*.iam.gserviceaccount.com`** → success. Continue.
- **User-format email** (`*@gmail.com`, `*@company.com`, etc.) → REFUSE. The `gcloud auth activate-service-account` call silently failed or didn't switch the active context. Re-run Step 9. If it persists, check `gcloud auth list` to see the available identities and explicitly run `gcloud config set account "$SA_EMAIL"`.
- **No active account** → run Step 9 again.
- **Unknown format** → log silently for diagnostics, retry.

Also verify the role binding via API:

```bash
gcloud projects get-iam-policy "$PROJECT_ID" --format=json \
  | jq -r ".bindings[] | select(.members[] == \"serviceAccount:${SA_EMAIL}\") | .role"
```

The output should include `roles/viewer` or `roles/editor` matching Step 1's choice. If it includes `roles/owner` or `roles/resourcemanager.projectIamAdmin`, REFUSE - see Step 7's defense-in-depth note.

**Live API verify.** Run a read-only smoke call to confirm the credentials actually work end-to-end:

```bash
gcloud projects describe "$PROJECT_ID" --format=json | jq -r '.name, .projectId'
```

If this returns the project name + ID, the SA is authenticated and the role binding has propagated. If it returns `PERMISSION_DENIED`, wait 30 seconds (eventual consistency on role propagation) and retry. If it returns `UNAUTHENTICATED`, the SA activation didn't take - re-run Step 9.

### Step 11 - Success message

Tell the user, in one short message:

> "All done - your Google Cloud is now connected. I can help with things like *'show me my Cloud Storage buckets'*, *'list my Compute Engine VMs'*, or *'run a BigQuery query against [dataset]'*. Give it a try!"

Save to memory that the gcloud CLI is installed and authenticated as a service account, so on the next use you go straight to Phase 2.

---

## PHASE 2 - Use Tools

Once the connector is configured, shell out to `gcloud` (and `bq`, `gsutil`) via Bash. **Every Phase 2 command must be prefixed with the credentials source line** so `GOOGLE_APPLICATION_CREDENTIALS` is set for SDK-based tools:

```bash
set -a && source ~/.config/gcloud-connector/credentials.env && set +a && gcloud <command>
```

For brevity, the recipes below omit the prefix - but you must include it in every actual Bash invocation.

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
gcloud iam service-accounts describe "claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"

# List role bindings on the SA
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="value(bindings.role)"
```

> **The minted SA cannot manage IAM** because Step 1's `roles/editor` (or `roles/viewer`) excludes `iam.*.setIamPolicy` and `resourcemanager.projects.setIamPolicy`. To rotate keys, change roles, or delete the SA, the user must sign in to the Console as themselves (or run gcloud as the user identity). This is the safety net.

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

The SA minted in Phase 1 is `claude-assistant@<project-id>.iam.gserviceaccount.com`. To rotate, revoke, or audit it:

```bash
# Show the SA
gcloud iam service-accounts describe "claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"

# List role bindings on the SA
gcloud projects get-iam-policy "$PROJECT_ID" --format=json \
  | jq ".bindings[] | select(.members[] | contains(\"claude-assistant\"))"

# List the SA's keys (you cannot read the values - only metadata)
gcloud iam service-accounts keys list --iam-account="claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"

# Rotate: create a new key, then delete the old one after switching
gcloud iam service-accounts keys create ~/.config/gcloud-connector/key-new.json \
  --iam-account="claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"
mv ~/.config/gcloud-connector/key-new.json ~/.config/gcloud-connector/key.json
gcloud auth activate-service-account --key-file=~/.config/gcloud-connector/key.json

# Delete the SA entirely (revokes all access)
gcloud iam service-accounts delete "claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"
```

> **Key rotation cadence.** GCP keys do not expire by default. Best practice is to rotate every 90 days. Re-running Phase 1 mints a fresh key (and the prior key remains active until manually deleted via `gcloud iam service-accounts keys delete`).

---

## Application Default Credentials

Step 9 wrote `GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud-connector/key.json` into the credentials env file. This satisfies ADC for:

- Python `google-cloud-*` client libraries (BigQuery, Storage, Pub/Sub, etc.)
- Node `@google-cloud/*` packages
- Go `cloud.google.com/go/*` modules
- Terraform `google` provider
- gcloud itself for some flows

If a tool reports "Could not automatically determine credentials", source the env file:

```bash
set -a && source ~/.config/gcloud-connector/credentials.env && set +a
```

Then re-run the tool. The env var is the universal contract.

---

## Auth & Session

```bash
# Check who is signed in (Phase 2 sanity)
gcloud auth list

# Show the active SA's email
gcloud config get-value account

# Switch active accounts (if both user and SA are listed)
gcloud config set account "claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"

# Switch projects
gcloud config set project "<other-project-id>"

# List configured projects
gcloud projects list

# Log out the SA (revokes the activated credentials, NOT the underlying key file)
gcloud auth revoke "claude-assistant@${PROJECT_ID}.iam.gserviceaccount.com"
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `gcloud: command not found` | Shell needs restart - `exec -l $SHELL` or open a new terminal, or use the Step 3 PATH alias |
| `ERROR: Reauthentication failed` | Long-lived SA key invalidated or the underlying key was deleted in Console - re-run Phase 1 from Step 8 to mint a fresh key |
| `ERROR: PERMISSION_DENIED` | The SA doesn't have the role for that operation. If user picked Read-only and now wants to write, run Phase 1 from Step 7 to swap to `roles/editor`. |
| `ERROR: The project property is set to the empty string` | `gcloud config set project <project-id>` |
| `ERROR: Billing account not enabled` | Project needs billing - link at console.cloud.google.com/billing |
| `quota exceeded`, `limit reached` | Hit a project quota. Wait or request quota increase in Console. |
| `Could not automatically determine credentials` | Source the credentials env file: `set -a && source ~/.config/gcloud-connector/credentials.env && set +a` |
| `RESOURCE_EXHAUSTED: Maximum number of keys` | 10-key limit - list and delete oldest via `gcloud iam service-accounts keys list/delete` |
| Auth works but a specific API fails | The API may not be enabled on the project - `gcloud services enable <api-name>` (e.g., `bigquery.googleapis.com`, `storage.googleapis.com`) |

When an error occurs, say:

> "No problem - let me try a different way."

Then diagnose and fix. Never show raw error messages to the user - translate them into plain English.

---

## Behaviour Guidelines (Phase 2)

- **Always run `gcloud config get-value account` first** at the start of a session to confirm the active identity is `*@*.iam.gserviceaccount.com` (not user-format). If user-format, run Phase 1 from Step 9 - the SKILL should never operate on user-token credentials.
- **Confirm before destructive actions** - deleting buckets, stopping/deleting VMs, removing IAM bindings, deleting service accounts.
- **Project context matters** - `gcloud config get-value project` before running commands. If the SA has access to multiple projects (rare), switch with `gcloud config set project <id>`.
- **Auth errors** → for SA creds, re-run Phase 1 from Step 8 to mint a fresh key. Never recommend `gcloud auth login` from Phase 2 - that would put the user identity back as active and undermine the SA-only design.
- **`gcloud not found`** → restart shell or reinstall via Phase 1 Step 3.
- **Region/zone** - for resource creation, ask the user or default to `australia-southeast1` if user is Australian, otherwise `us-central1`. Always confirm before creating compute resources.
- **API enablement** - many APIs are off by default on new projects. If an operation fails with `SERVICE_DISABLED`, run `gcloud services enable <api>.googleapis.com` and retry.
- **Never echo or log credentials** - the JSON key file's contents must never appear in any output visible to the user.
- **One step at a time** - for Phase 2, less strict than Phase 1; users running `gcloud … list` queries don't need step-by-step narration.
- **Role boundary awareness** - if the user asks Claude to manage IAM (grant roles, create users, change project ownership), explain plainly: "Your Google Cloud connection is set up to be safer - it can read and operate resources but can't change permission settings. To do that, please sign in to console.cloud.google.com directly." Do not attempt to escalate.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer follows `aws-connector` and `azure-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting GCP auth or permission errors
- **aws-connector** / **azure-connector**: Sibling cloud-CLI connectors - same Playwright-driven scoped-identity-mint pattern (the cloud trio)
- **stripe-connector** / **github-connector** / **quickbooks-connector**: Sibling autonomous-Phase-1 connectors - closest reference shapes for the Playwright-drives-the-provider-console pattern
