---
name: aws-connector
description: "Install and operate the AWS connector autonomously. Drives console.aws.amazon.com end-to-end inside a Playwright MCP browser: navigates to IAM, finds or creates a least-privilege IAM user named 'claude-assistant' with the right managed policy attached (ReadOnlyAccess for read-only access, PowerUserAccess for read-and-write — never AdministratorAccess), creates an access key for that user, DOM-extracts the access key ID and secret access key from the post-create modal (AWS shows the secret once and never again), and writes ~/.aws/credentials + ~/.aws/config autonomously. The user's only manual moments are signing in to the AWS Console once and approving any MFA prompt their account requires. Never mints root access keys — verifies post-install via sts:GetCallerIdentity that the keys belong to an IAM user (arn:aws:iam::*:user/*), not the root account (arn:aws:iam::*:root), and refuses to ship root credentials. Read and operate AWS services via the aws CLI (S3, EC2, Lambda, DynamoDB, IAM read-side, Cost Explorer, CloudWatch). Use this skill when the user asks to set up AWS, connect Amazon Web Services, or interact with S3 buckets, EC2 instances, Lambda functions, DynamoDB tables, AWS bills, or CloudWatch logs. On first use run Phase 1 to install + create the IAM user + mint access keys + verify before attempting any tool calls."
allowed-tools: mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - aws
    - amazon
    - s3
    - ec2
    - lambda
    - cli
    - cloud
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting AWS auth or permission errors
    - skill: gcloud-connector
      reason: Sibling cloud-CLI connector — same Playwright-driven IAM-user-mint pattern
    - skill: azure-connector
      reason: Sibling cloud-CLI connector — same Playwright-driven service-principal-mint pattern
---

# AWS Connector

## Overview

This skill lets you read and operate a user's AWS account on their behalf via the **`aws` CLI v2**. It has two phases:

- **Phase 1 — Install & Auth (autonomous via Playwright).** Claude installs the `aws` CLI, drives the entire AWS Console flow inside a Playwright MCP browser (find or create an IAM user named "claude-assistant" with the right managed policy attached, create an access key for that user, DOM-extract the credentials from the post-create modal), writes `~/.aws/credentials` and `~/.aws/config`, and verifies via `sts:GetCallerIdentity`. The user's only manual moments are signing in to the AWS Console once and approving any MFA prompt. Everything else — IAM user discovery / creation, policy attachment, access key creation, credential extraction — is autonomous.
- **Phase 2 — Use Tools.** Once the connector is configured, you shell out to `aws` via Bash to answer questions and make changes. Common operations covered: S3, EC2, Lambda, DynamoDB, IAM read-side, Cost Explorer.

> **Never mints root access keys.** AWS strongly recommends against root user access keys — they have unrestricted permission and cannot be permission-restricted. This SKILL refuses to ship root credentials. Step 10's identity check verifies the access key belongs to an IAM user, not the root user, and aborts cleanly if the ARN is `arn:aws:iam::*:root`. The user signs in with root only because they may not yet have an IAM admin user; once an IAM user is minted, all programmatic access flows through it.

> **This is for local laptop setup only.** Server provisioning (EC2/Lightsail) lives in [claude-cloud-kit](https://github.com/selrai-company/claude-cloud-kit).

**Which phase to run** — Before any tool call, check whether the AWS CLI is installed and authenticated. Run:

```bash
aws sts get-caller-identity --output json 2>&1
```

- Exit code 0 with a JSON `Arn` field → authenticated. **Verify the Arn is an IAM user**, not root:
  - `arn:aws:iam::*:user/*` → IAM user (good). Go to Phase 2.
  - `arn:aws:iam::*:root` → Root credentials (bad). Run Phase 1 from Step 5 to mint an IAM user and replace the credentials.
- Exit code 253 (`Unable to locate credentials`) or 127 (`command not found`) → run Phase 1 from the appropriate step.
- Other errors → translate, diagnose, run Phase 1 if needed.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to the AWS Console once. Every message during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to the AWS Console in the browser window I just opened" and (if challenged) "please approve the security check on your phone."
- **Plain English only.** No jargon. Never say CLI, binary, PATH, env var, IAM, root, ARN, access key, secret access key, region, MFA, OAuth, sts, JSON, MCP, DOM, Playwright, terminal, or policy name. If you must refer to a technical thing, name it plainly: "the AWS tool I need", "your browser", "a special AWS user account I'll set up for you", "your Amazon sign-in", "a security check".
- **Tell them what is about to happen.** Before any action: "I'm going to set up AWS for you — this takes about three minutes."
- **React to success and failure warmly.** Good: "That worked — your AWS is now connected." Bad: "InvalidClientTokenId."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the access key ID or secret access key** back to the user. Both are stored locally; never include them in any output visible to the user.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude installs the `aws` CLI, drives the AWS Console end-to-end via Playwright MCP to mint a least-privilege IAM user with appropriately-scoped permissions and create an access key, writes the credentials autonomously, and verifies via `sts:GetCallerIdentity` that the keys belong to that IAM user (not root). The user's only role is signing in to the AWS Console when prompted (and only the first time — the persistent Playwright profile keeps the session for future runs) and approving any MFA challenge.

> **Reasoning model.** Each step describes a *goal* (e.g., "find the Create user button on the IAM Users page and click it"). Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_fill_form`. Match elements by visible labels and `aria-label` attributes — AWS Console UI evolves frequently and selector paths drift between region-specific deployments.

> **Why we mint a fresh IAM user instead of reusing root.** AWS publishes [explicit guidance](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#lock-away-credentials) that root user access keys should be locked away and not used for everyday tasks. Root identity has unrestricted permission over the entire account (including billing and account closure) and cannot be permission-restricted by any IAM policy. Programmatic access for an automated agent like Claude must flow through a permission-scoped IAM user that the user can revoke with one click in the IAM Console. The post-mint identity check in Step 10 enforces this — if the keys we just minted belong to root for any reason (e.g., the user accidentally created the key on the root user's Security credentials page mid-flow), the SKILL refuses to write them and re-runs Step 5.

### Step 1 — Orient the user and ask read-only vs read-and-write

Tell the user, in one short message:

> "I'll connect your AWS now. First — do you want me to just **read** your AWS (list servers, view costs, browse buckets), or do you want me to also be able to **make changes** for you (start servers, deploy code, modify resources)? Read-only is safer to start."

Wait for their answer. Remember it — this controls Step 6's policy attach. Default for the workshop demo flow is read-and-write (so they can ask Claude to actually do things), but read-only is the safer first step.

- **Read-only** → attach the AWS-managed policy `arn:aws:iam::aws:policy/ReadOnlyAccess`. Covers list/describe/get for all services including Cost Explorer.
- **Read + write** → attach the AWS-managed policy `arn:aws:iam::aws:policy/PowerUserAccess`. Covers everything except IAM/Organizations/Account management — the IAM exclusion is the safety net so the minted user cannot create new IAM users, attach broader policies to itself, or escalate privilege.

> **Why not AdministratorAccess.** `AdministratorAccess` includes `iam:*`, which would let the minted user grant itself any policy or create new IAM users. That defeats the purpose of running as a non-root identity — if `claude-assistant` ever leaks its key, it could re-grant itself everything. `PowerUserAccess` blocks that escalation path while still allowing all service-side operations.

### Step 2 — Check if `aws` is already installed and authenticated

Silently run:

```bash
aws --version 2>&1
```

If it errors with "command not found" (exit 127), continue to Step 3 to install. If it prints a version string, probe authentication state:

```bash
aws sts get-caller-identity --output json 2>&1
```

- Exit 0 with valid JSON → parse `.Arn`. If it matches `arn:aws:iam::*:user/*`, the connector is already configured with an IAM user — skip to Phase 2. If it matches `arn:aws:iam::*:root`, run Phase 1 from Step 5 to mint a non-root user (the existing root creds get replaced in Step 9).
- Exit 253 (`Unable to locate credentials`) → continue to Step 4 to set up credentials.

### Step 3 — Install AWS CLI v2 cross-platform

Tell the user: *"I'm going to install a small tool I need to talk to AWS — this takes about a minute."*

Silently detect the user's OS and run the install command:

**macOS (Intel or Apple Silicon):**

```bash
brew install awscli
```

If Homebrew is not installed, fall back to Amazon's official PKG installer:

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
rm /tmp/AWSCLIV2.pkg
```

**Linux (x86_64):**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
```

**Linux (ARM64):**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
```

**Windows (Git Bash):**

```bash
winget install --id Amazon.AWSCLI --accept-package-agreements --accept-source-agreements
```

> **Windows PATH note.** winget appends to the user PATH but the current shell may not see it until a fresh terminal. Resolve the binary directly for the rest of this session if `aws --version` still 127s after install — derived from PR #238's defensive-path-handling pattern:
>
> ```bash
> AWS_BIN="$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages/" -name 'aws.exe' 2>/dev/null | head -1)"
> alias aws="\"$AWS_BIN\""
> ```

If winget is unavailable, fall back to the MSI installer:

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.msi" -o "$TEMP/AWSCLIV2.msi"
msiexec.exe //i "$TEMP\\AWSCLIV2.msi" //quiet //norestart
```

Verify:

```bash
aws --version 2>&1
```

If the verify command still errors after install (`command not found` even with brew/winget on PATH), tell the user plainly: *"The terminal needs a refresh — please close this window, open a new one, then say 'ready'."* Wait, then retry.

### Step 4 — Open the AWS Console and confirm a logged-in session

Tell the user, in one short message:

> "Opening a browser window for you — please sign in to AWS when it appears (and approve any security check). I'll do the rest. About two minutes."

Call:

```
mcp__playwright__browser_navigate({ url: "https://console.aws.amazon.com/iam/home" })
```

If the user is signed out, AWS redirects to `signin.aws.amazon.com/signin?...`. Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see the IAM dashboard with a "Users" link in the left navigation) → continue to Step 5.
- **Sign-in form** (root user email input, or "Sign in as" page with IAM/root toggle) → poll silently with `browser_wait_for({ text: "IAM dashboard" })` (or "Identity and Access Management"). Do not ask the user to confirm; detect login completion yourself.
- **MFA challenge** (text like "Authentication code", "MFA device", "Verify your identity") → poll silently. The MFA action happens on the user's phone or hardware key; the SKILL just waits for the post-MFA IAM dashboard to load. AWS root accounts are required to have MFA since 2024-09 — this is now the default flow, not an edge case.

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

> **Sign in as IAM user vs root.** AWS's sign-in form has two modes — root user (default, email + password) and IAM user (account ID/alias + IAM username + password). For first-time installs the user signs in as root because they don't yet have an IAM admin user. The persistent Playwright profile remembers their choice for next time. Either path works for this SKILL — what matters is that the resulting IAM Console session has permission to create an IAM user and attach managed policies (root has this; an IAM user with `IAMFullAccess` or `AdministratorAccess` also has this).

### Step 5 — Find or create the "claude-assistant" IAM user

The IAM dashboard has a **Users** link in the left navigation panel. Click it via `browser_click` matching the visible label, OR navigate directly:

```
mcp__playwright__browser_navigate({ url: "https://us-east-1.console.aws.amazon.com/iam/home#/users" })
```

`browser_wait_for({ text: "Create user" })`. Take a snapshot.

The Users page shows a search box and a list of existing IAM users. Search for `claude-assistant`:

- **User exists** → click into the user's detail page. Skip to Step 7.
- **User does not exist** → click the **Create user** button. AWS opens a 3-step wizard.

**Wizard step 1 of 3 — Specify user details.** Locate the "User name" input and type `claude-assistant` via `browser_type` or `browser_fill_form`. **Leave the "Provide user access to the AWS Management Console" checkbox UNCHECKED** — this user is for programmatic access only; granting it Console password access is unnecessary attack surface. Click **Next**.

**Wizard step 2 of 3 — Set permissions.** Three radio options:

- "Add user to group"
- "Copy permissions"
- **"Attach policies directly"** — pick this one via `browser_click`.

A list of AWS managed policies appears with a search/filter input. Type the policy name (`ReadOnlyAccess` or `PowerUserAccess` from Step 1's choice) into the filter. The matching row appears with a checkbox on the left. Check the box via `browser_click`. Click **Next**.

**Wizard step 3 of 3 — Review and create.** AWS shows a summary: user name `claude-assistant`, no Console access, the policy from the previous step. Click **Create user**.

Post-create, AWS redirects to the user's detail page at `https://us-east-1.console.aws.amazon.com/iam/home#/users/claude-assistant`. Continue to Step 6.

> **Robustness note.** This wizard layout reflects the AWS Console's IAM UI as of 2025–2026. AWS has reshaped the Create user flow at least twice in the last two years. If the wizard step names or button labels differ, snapshot, reason about the current layout, and adapt — the goal is "create a user named claude-assistant with [policy] attached and no Console password". The find-existing-user path is more stable; the create-new-user wizard is the path most likely to need maintenance.

### Step 6 — Verify the policy attachment (idempotent re-runs)

If `claude-assistant` already existed (Step 5's find-existing branch), the user's existing managed policies may differ from what the user wants this run. Open the **Permissions** tab on the user's detail page. List the attached managed policies via `browser_evaluate`:

```js
() => {
  const rows = Array.from(document.querySelectorAll('tr, [role="row"]'));
  return rows
    .map(r => (r.innerText || '').trim())
    .filter(t => /AWS managed/i.test(t) && /(ReadOnlyAccess|PowerUserAccess|AdministratorAccess)/i.test(t))
    .slice(0, 10);
}
```

- **The desired policy from Step 1 is already attached** → skip to Step 7.
- **A different policy from Step 1's choice is attached** → click **Add permissions → Attach policies directly**, attach the desired policy, then **separately** detach the prior policy (e.g., if the user is switching from read-only to read-and-write, attach `PowerUserAccess` and detach `ReadOnlyAccess`). Don't leave both attached — AWS evaluates the union, but having two managed policies on the user makes the intent ambiguous.
- **`AdministratorAccess` is attached** → narrate once: *"I noticed your AWS user has admin access. Want me to scope it down to a safer level?"* If yes, attach the policy from Step 1 and detach `AdministratorAccess`. If no, continue with the current setup (the user has a reason).

### Step 7 — Create an access key for the IAM user

On the user's detail page, click the **Security credentials** tab. Scroll to the **Access keys** section.

> **Two-key limit.** AWS allows a maximum of 2 active access keys per IAM user. If 2 keys already exist, the user is mid-rotation or has an old key lying around. Identify any key with a "Last used: Never" status or a creation date older than 90 days, and delete it via `browser_click` on its row's Actions menu → **Delete** before creating a new one.

Click **Create access key**. AWS opens a 2-step modal:

**Modal step 1 of 2 — Access key best practices & alternatives.** AWS shows several use-case radio options (e.g., "Application running on AWS compute service", "Application running outside AWS", "Local code", "Third-party service", "Command Line Interface (CLI)"). Pick **"Command Line Interface (CLI)"**. Below the options is a confirmation checkbox: *"I understand the above recommendation and want to proceed to create an access key."* Check it. Click **Next**.

**Modal step 2 of 2 — Set description tag (optional).** Leave the tag blank (or set it to `claude-assistant-cli` for traceability). Click **Create access key**.

### Step 8 — DOM-extract the access key ID and secret access key

The post-create modal displays both values. **AWS shows the secret exactly once** — if you navigate away or close the modal without capturing it, the user has to delete the key and create another one.

The secret may be masked behind a **Show** toggle. If so, click it first.

Read both values via `browser_evaluate`:

```js
() => {
  const out = { access_key_id: null, secret_access_key: null };
  const allText = Array.from(document.querySelectorAll('input, code, span, pre, td')).map(e => ({ el: e, text: (e.value || e.innerText || '').trim() }));
  for (const { text } of allText) {
    // Access key ID: starts with AKIA, 20 chars total, alphanumeric uppercase
    if (/^AKIA[A-Z0-9]{16}$/.test(text) && !out.access_key_id) {
      out.access_key_id = text;
    }
    // Secret access key: 40 chars, base64-ish (alphanumeric + / + +)
    if (/^[A-Za-z0-9/+]{40}$/.test(text) && !out.secret_access_key) {
      out.secret_access_key = text;
    }
  }
  return out;
}
```

**Validation (silent).** Access key ID must match `^AKIA[A-Z0-9]{16}$` (20 chars, starts with `AKIA`). Secret access key must be exactly 40 characters of base64-ish content. If either fails the shape check, click the **Show** toggle on the secret and re-extract; if it still fails, fall back to the **Download .csv file** button which AWS provides for exactly this case — read the CSV via `browser_evaluate` parsing the download response, OR ask the user to paste both values once.

After successful extraction, click **Done** to dismiss the modal so the secret is no longer visible on screen.

### Step 9 — Write `~/.aws/credentials` and `~/.aws/config`

Silently create the AWS credentials directory and write both files. Use `chmod 600` on the credentials file so other users on the system can't read it.

```bash
mkdir -p ~/.aws

cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = <access_key_id from Step 8>
aws_secret_access_key = <secret_access_key from Step 8>
EOF
chmod 600 ~/.aws/credentials

cat > ~/.aws/config <<EOF
[default]
region = us-east-1
output = json
EOF
chmod 600 ~/.aws/config
```

> **Why `us-east-1` as default.** It's the historical default region (where IAM, Organizations, and other global services have their primary endpoints), it's where most AWS Console URLs default to, and it's never wrong for read operations on global services. Users in other regions (Sydney, Singapore, London, Frankfurt, Tokyo, etc.) can override per-command with `--region <region>` or globally with `aws configure set region <region>`. The Common Operations section below documents the regional reference table.

> **Why a credentials file (not env vars).** `~/.aws/credentials` is the canonical AWS CLI auth source — it persists across shells without needing `~/.zshrc` plumbing, and the AWS SDK in any language picks it up by default. Setting `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars works too but is more brittle (each shell needs the export, subprocesses inherit only if explicitly passed). The credentials file is the single source of truth for both the CLI and the SDKs.

> **Existing credentials.** If `~/.aws/credentials` already has a `[default]` profile from a prior install or a different IAM identity, **back it up** to `~/.aws/credentials.backup` before overwriting. Never silently destroy existing creds.

### Step 10 — Verify the connection (REFUSE if root)

Tell the user: *"Let me just double-check everything is talking to AWS correctly."*

Silently run:

```bash
aws sts get-caller-identity --output json
```

- Exit 0 with valid JSON → parse the `Arn` field.
- Any other exit → diagnose and retry from Step 7 (regenerate access key) or Step 9 (rewrite credentials file).

**Critical: verify the ARN is an IAM user, not root.**

```bash
ARN="$(aws sts get-caller-identity --query Arn --output text)"
case "$ARN" in
  arn:aws:iam::*:user/claude-assistant) echo "OK: IAM user claude-assistant" ;;
  arn:aws:iam::*:user/*)                echo "OK: IAM user (different name)" ;;
  arn:aws:iam::*:root)                  echo "REFUSE: root credentials" ; exit 1 ;;
  *)                                    echo "UNKNOWN ARN: $ARN" ; exit 1 ;;
esac
```

- **`arn:aws:iam::*:user/claude-assistant`** → success. The keys we just minted belong to the IAM user we created. Continue.
- **`arn:aws:iam::*:user/<other-name>`** → an IAM user, just not the one we created. Acceptable (e.g., the user already had a named IAM user from before). Continue.
- **`arn:aws:iam::*:root`** → REFUSE. Delete `~/.aws/credentials` immediately:

  ```bash
  rm ~/.aws/credentials
  ```

  Tell the user: *"I noticed I accidentally got admin-level access. Let me set up a safer account for you instead — one moment."* Re-navigate Playwright back to the IAM Users page and walk Step 5 again, this time explicitly creating the user (not extracting keys from a root session that happened to be on the Security credentials page).

- **Unknown ARN shape** → log silently for diagnostics, retry from Step 5.

### Step 11 — Success message

Tell the user, in one short message:

> "All done — your AWS is now connected. I can help with things like *'show me my S3 buckets'*, *'what's running in my AWS account?'*, or *'what's my AWS bill this month?'*. Give it a try!"

Save to memory that the aws CLI is installed and authenticated, so on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools

Once the connector is configured, shell out to `aws` via Bash to answer questions and make changes.

### What to Try First

After setup, suggest simple tasks:

> "Want to try something? Here are a few things I can do with your AWS:"

```
"Show me my S3 buckets."
"What's running in my AWS account?"
"List my EC2 instances."
"What's my AWS bill this month?"
```

Start with read-only queries to confirm the connection works end-to-end.

### Common Operations

#### S3 (Storage)

```bash
# List buckets
aws s3 ls

# List files in a bucket
aws s3 ls s3://bucket-name/

# Download a file
aws s3 cp s3://bucket-name/file.csv ./file.csv

# Upload a file
aws s3 cp ./local-file.csv s3://bucket-name/

# Sync a folder
aws s3 sync ./local-folder/ s3://bucket-name/folder/
```

#### EC2 (Virtual Machines)

```bash
# List instances
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

# Start an instance
aws ec2 start-instances --instance-ids i-1234567890abcdef0

# Stop an instance
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
```

#### Lambda (Serverless Functions)

```bash
# List functions
aws lambda list-functions --query 'Functions[].FunctionName'

# Invoke a function
aws lambda invoke --function-name my-function --payload '{}' /tmp/output.json
```

#### DynamoDB

```bash
# List tables
aws dynamodb list-tables

# Scan a table (first 10 items)
aws dynamodb scan --table-name my-table --max-items 10
```

#### IAM (Users & Permissions, read-side)

```bash
# List users
aws iam list-users --query 'Users[].UserName'

# Get current user info
aws sts get-caller-identity

# List the policies attached to claude-assistant (the user this SKILL minted)
aws iam list-attached-user-policies --user-name claude-assistant
```

> **The `claude-assistant` user cannot manage IAM** because Step 1's `PowerUserAccess` (or `ReadOnlyAccess`) policy excludes `iam:*` write operations. To rotate keys, change policies, or delete the user, sign in to the AWS Console as root or as a user with `IAMFullAccess` and do it there. This is the safety net — the minted user cannot escalate or modify its own permissions.

#### Cost Explorer

```bash
# Current-month cost
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u -d "+1 month" +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics UnblendedCost

# Daily cost for the last 7 days
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "-7 days" +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost
```

### Region Reference

| Location | Region code |
|---|---|
| Sydney | `ap-southeast-2` |
| Singapore | `ap-southeast-1` |
| US East (Virginia) | `us-east-1` |
| US West (Oregon) | `us-west-2` |
| London | `eu-west-2` |
| Frankfurt | `eu-central-1` |
| Tokyo | `ap-northeast-1` |

To set the default region permanently:

```bash
aws configure set region <region-code>
```

To use a different region for one command:

```bash
aws s3 ls --region ap-southeast-2
```

---

## SSO Login (Alternative — for Organizations with IAM Identity Center)

If the user's organisation uses AWS IAM Identity Center (formerly AWS SSO) instead of long-lived access keys, skip Phase 1 and use SSO:

> "Your company uses a different sign-in method. I'll set that up instead."

```bash
aws configure sso
```

This prompts for:

- **SSO start URL** — usually `https://<company>.awsapps.com/start`
- **SSO region** — the region the company's Identity Center is in
- **Account and role** — a browser opens; user signs in, picks an account and role from the list

After setup, log in (and re-login when the session expires, typically every 8 hours):

```bash
aws sso login --profile <profile-name>
```

> **When to use SSO vs IAM user.** SSO is preferred when the organisation has IAM Identity Center configured (typical for mid-size companies). The session is short-lived (no long-lived access key on disk), tied to the user's corporate identity, and auto-revokes on offboarding. The Phase 1 IAM-user-mint flow is for individual / small-team accounts that don't have Identity Center set up. Both can coexist in `~/.aws/config` as separate profiles.

---

## Auth & Session

```bash
# Check who is signed in
aws sts get-caller-identity

# Check current config
aws configure list

# Switch profiles
export AWS_PROFILE=other-profile

# List configured profiles
aws configure list-profiles

# Reconfigure credentials interactively
aws configure
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `aws: command not found` | Shell needs restart — open a new terminal, or use the Step 3 PATH alias |
| `Unable to locate credentials` | Run Phase 1 from Step 9 (rewrite `~/.aws/credentials`) |
| `An error occurred (InvalidClientTokenId)` | Access key was deleted in IAM Console — run Phase 1 from Step 7 to mint a fresh one |
| `An error occurred (SignatureDoesNotMatch)` | Secret key is wrong (probably a copy-paste error from a fallback path) — re-run Step 7-9 |
| `An error occurred (AccessDenied)` | The minted IAM user does not have permission for that operation. If the user originally picked Read-only and now wants to make changes, run Phase 1 from Step 6 to swap the policy to PowerUserAccess. |
| `Could not connect to the endpoint URL` | Wrong region — set with `aws configure set region <region-code>` |
| `An error occurred (ExpiredToken)` | SSO session expired — run `aws sso login` |
| `The security token included in the request is invalid` | Long-lived credentials — re-run Phase 1 from Step 7. Short-lived (SSO) — run `aws sso login`. |

When an error occurs, say:

> "No problem — let me try a different way."

Then diagnose and fix. Never show raw error messages to the user — translate them into plain English.

---

## Behaviour Guidelines (Phase 2)

- **Always run `aws sts get-caller-identity` first** at the start of a session to confirm the user is signed in and the ARN is an IAM user (not root).
- **Confirm before destructive actions** — deleting buckets, terminating instances, removing IAM users, rolling back deployments. Summarise what you are about to do and wait for the user's OK.
- **Region context matters** — always check `aws configure get region` before running commands that vary by region (S3 buckets, EC2 instances, Lambda functions). Pass `--region` explicitly if the operation needs to target a different region from the default.
- **Auth errors** → for long-lived creds, run Phase 1 from Step 7. For SSO, run `aws sso login`.
- **`aws not found`** → restart shell or reinstall via Phase 1 Step 3.
- **Never echo or log secret keys** — they should only ever exist in `~/.aws/credentials` (or in SSO temporary credentials, which the CLI manages).
- **Cost-explorer awareness** — `ce get-cost-and-usage` returns blended numbers by default. When the user asks about their bill, prefer `--metrics UnblendedCost` (what they actually pay) and present in their currency. AWS bills in USD by default.
- **One step at a time** — do not dump all instructions at once. Say what to do, wait, then give the next step. (For Phase 2 this is less strict than Phase 1; users running list/describe queries don't need step-by-step narration.)
- **IAM user limit** — `claude-assistant` cannot manage IAM. If the user asks Claude to "give me admin access" or "create a new user", explain plainly: "Your AWS user is set up to be safer — it can read and operate AWS but can't change account-level settings. To do that, please sign in to AWS Console directly." Do not attempt to escalate.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer follows `github-connector` and `stripe-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting AWS auth or permission errors
- **gcloud-connector** / **azure-connector**: Sibling cloud-CLI connectors — same Playwright-driven user-mint pattern
- **stripe-connector** / **github-connector** / **quickbooks-connector**: Sibling autonomous-Phase-1 connectors — closest reference shapes for the Playwright-drives-the-provider-console pattern this skill follows
