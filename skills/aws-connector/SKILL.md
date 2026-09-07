---
name: aws-connector
description: "Connect AWS to Claude by installing the `aws` CLI and setting it up with its own limited-access sign-in. Use when the user asks to set up or connect AWS, or wants AWS work (S3 buckets, EC2 instances, Lambda functions, DynamoDB tables, bills, CloudWatch logs) and the `aws` CLI isn't signed in with that limited-access sign-in yet, or is still on the account's owner login. Once connected, AWS runs directly through the `aws` CLI."
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
      reason: Sibling cloud-CLI connector - same Playwright-driven IAM-user-mint pattern
    - skill: azure-connector
      reason: Sibling cloud-CLI connector - same Playwright-driven service-principal-mint pattern
---

# AWS Connector

## Overview

Connect through AWS CLI v2. Preserve the user's existing profiles, credentials, and default configuration. A fresh read-only setup can reuse an explicitly selected existing human credential context to create one uniquely named connector-owned IAM user and one key; the connector then uses its own private credentials/config files. It creates no billable resources or billing configuration.

**Phase 0:** if `~/.config/aws-connector/connection.json` exists, run `python3 scripts/connect.py check` from this skill's directory. Success requires the exact saved IAM user/account, a real `iam get-user` read, the expected ReadOnlyAccess attachment with no groups/inline policies, exactly the saved active key, and preservation of the current personal configuration during the check. Ordinary changes to unrelated profiles or human credentials since setup do not invalidate this isolated connection. A saved file or any arbitrary IAM-user ARN alone is insufficient.

If `~/.config/aws-connector/console-connection.json` exists instead, follow the Console reference's verification using its dedicated files; do not run the CLI provisioning helper against Console-created state. If no connector-owned state exists, an already-working explicitly intended AWS profile may still provide existing-access reads. Record that as existing access, preserve it, and do not claim fresh onboarding. When the user requests a new limited identity, continue with the isolated setup below. Partial connector state uses its recovery reference, not another user/key creation. Root credentials are never imported into the connector, replaced, or deleted.

This skill is for a local laptop. Server provisioning belongs to claude-cloud-kit.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work; the user handles a sign-in or security challenge only when the existing authorized session cannot complete it. Every message during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to the AWS Console in the browser window I just opened" and (if challenged) "please approve the security check on your phone."
- **Plain English only.** No jargon. Never say CLI, binary, PATH, env var, IAM, root, ARN, access key, secret access key, region, MFA, OAuth, sts, JSON, MCP, DOM, Playwright, terminal, or policy name. If you must refer to a technical thing, name it plainly: "the AWS tool I need", "your browser", "a special AWS user account I'll set up for you", "your Amazon sign-in", "a security check".
- **Tell them what is about to happen.** Before any action: "I'm going to set up AWS for you - this takes about three minutes."
- **React to success and failure warmly.** Good: "That worked - your AWS is now connected." Bad: "InvalidClientTokenId."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the access key ID or secret access key** back to the user. Both are stored locally; never include them in any output visible to the user.

---

## PHASE 1 - Install and connect

### Step 1 - Confirm the intended account and scope

Use account and scope already established in the conversation. For a fresh workshop connection, default to read-only. Ask about additional scope only when a requested operation needs writes and the conversation has not established its authorization. Do not repeat an answered question.

The scoped helper attaches AWS-managed `ReadOnlyAccess`. This is broad read access across the chosen account, not a custom policy limited to the smoke-test user. It does not grant writes. If the user later requests writes, select appropriate permissions for that operation separately; do not automatically attach PowerUserAccess, AdministratorAccess, or modify unrelated identities to complete setup.

### Step 2 - Check the CLI and existing sign-in

Run `aws --version`. If missing, use Step 3. Otherwise identify the intended existing profile and confirm its `aws sts get-caller-identity --profile <intended-profile> --output json --no-cli-pager` result privately, returning only account/ARN classification, never access keys. An IAM user or authorized assumed-role session can provision the new identity if it has the required IAM permissions. Root is not accepted by the helper.

On macOS/Linux, for an already authorized existing profile, proceed directly to Step 5 without opening a browser. The scoped helper relies on POSIX private-file permissions; on Windows use the Console route with verified owner-only file access. An expired SSO/session login can use its ordinary login flow under the user's authorization; preserve all profiles and defer any unavoidable security challenge to the user. If no usable provisioning context exists, use Step 4's Console route.

### Step 3 - Install AWS CLI v2 cross-platform

Tell the user: *"I'm going to install a small tool I need to talk to AWS - this takes about a minute."*

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

> **Windows PATH note.** winget appends to the user PATH but the current shell may not see it until a fresh terminal. Resolve the binary directly for the rest of this session if `aws --version` still 127s after install - derived from PR #238's defensive-path-handling pattern:
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

If the current tool process cannot find AWS after installation, resolve the installed executable and prepend its directory to PATH only for the commands the harness runs. Verify that exact executable. Do not ask the attendee to restart a terminal or edit their shell configuration.

### Step 4 - Console fallback when no CLI provisioning login exists

Use an isolated browser in the intended AWS account. When the user is doing other work, preserve their everyday browser, native keyboard input and clipboard. Navigate to the IAM console and complete normal sign-in; the user handles any security challenge the harness cannot complete. Existing account access is sufficient; this route does not require creating a new AWS billing account.

For the normal Console workflow and private capture requirements, read [references/console-setup.md](references/console-setup.md). Create a new uniquely named identity, never adopt a namesake or change its permissions. If the available browser cannot save the one-time secret privately without returning it into chat or unprotected artifacts, report that precise capture gate before creating a key. Do not ask the user to paste a key into chat. This reference completes and verifies the Console route; do not then run Step 5 and create a second identity.

### Step 5 - Create the isolated read-only connector

Read [references/scoped-setup.md](references/scoped-setup.md). From this skill's directory, run `python3 scripts/connect.py setup --profile <intended-profile> --expected-arn <verified-human-ARN> --region <chosen-region>`. The existing intended login authorizes provisioning; all resulting operations use the dedicated connector files. The helper creates a unique tagged IAM user, attaches ReadOnlyAccess, creates one key with automatic CLI retries disabled, saves it privately and verifies the connection. No default credential/config file is overwritten or profile activated.

IAM permission, organization policy, session/MFA and quota errors are real prerequisites, not reasons to use another account, broaden permissions, delete keys, or repeat creation. Preserve partial resources and files. If key creation succeeded but verification failed, the reference's `finish` command can retry reads and complete only missing local runtime files; it never creates another user/key or changes policy.

### Step 6 - Verify and report the actual scope

For the scoped CLI route, run `python3 scripts/connect.py check` from the actual caller. The helper verifies exact identity and a real IAM read, scope, and preservation of the current personal configuration during that operation. For the Console route, perform its reference's equivalent verification with the dedicated credential/config paths. Report: “Your AWS read-only connection is ready, and your existing setup is unchanged.” Record fresh identity creation separately from adoption of existing access. Keep account/key ownership and teardown status without exposing credentials.

---

## PHASE 2 - Use Tools

For the scoped CLI connector, run `python3 scripts/connect.py run -- <service> <operation> <arguments>` from this skill's directory. It verifies the saved identity/scope, clears inherited AWS overrides only in the child process, and selects the connector's private credentials/config files and region. This wrapper avoids changing the user's shell or default AWS files. For each recipe below, replace the leading `aws` with `python3 scripts/connect.py run --`. Console-created connections use the same service commands within their reference's isolated child environment instead.

The initial connection is read-only. Write recipes require the user's requested operation and suitable separately reviewed permissions; do not attempt them as onboarding tests. Existing-access sessions that explicitly retained a prior profile must continue using that exact profile and distinguish that route from the isolated connector.

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

# List policies for the exact saved connector-owned username
aws iam list-attached-user-policies --user-name <saved-connector-user>
```

The dedicated user has ReadOnlyAccess. Key rotation, policy changes or teardown are separately authorized administration using the intended provisioning context and exact owned user/key identifiers. They are never authentication-error recovery or a reason to switch to root.

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

#### CloudWatch (Logs & Metrics)

```bash
# List log groups
aws logs describe-log-groups --query 'logGroups[].logGroupName'

# Tail a log group (last 10 minutes)
aws logs tail /aws/lambda/my-function --since 10m

# List alarms in ALARM state
aws cloudwatch describe-alarms --state-value ALARM --query 'MetricAlarms[].AlarmName'
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

Use the saved region unless the requested operation needs another. For one operation, pass exactly one full `--region <region-code>` or `--region=<region-code>` option. The wrapper validates and normalizes it to a single effective region; it does not rewrite either AWS config file. Identity/scope checks still use the saved connector context.

```bash
python3 scripts/connect.py run -- ec2 describe-instances --region us-east-1
```

Do not use `aws configure set region` or export profile/region variables in the user's shell. A Console-created connection passes the same per-operation region flag in its isolated child environment.

---

## Existing SSO session

When the intended existing profile uses IAM Identity Center, preserve that profile and its account/role selection. If its session expired, renew only that named profile with `aws sso login --profile <intended-profile> --no-browser`, then drive the emitted verification URL in the isolated browser. AWS documents that `--no-browser` prevents launching the default browser. The user handles an unavoidable security challenge. Confirm the exact account/ARN again before provisioning.

An authorized SSO role may provision the dedicated read-only identity through Step 5. If the user requests existing SSO access instead, retain that exact named profile for each operation and record existing access rather than fresh limited-identity setup. Do not silently choose this alternative after a denied provisioning operation.

New Identity Center configuration is separately authorized profile maintenance: use a new named profile in a dedicated configuration file and preserve existing configuration/default selectors. Do not run an unscoped interactive `aws configure sso` or ask a nontechnical attendee to fill terminal prompts as connector onboarding.

---

## Auth & Session

For scoped CLI state, use `python3 scripts/connect.py check` to verify the saved identity, scope and key while preserving the current personal configuration. Completed connections remain usable after unrelated profile changes or human credential rotation; provisioning and partial recovery retain their stricter original-snapshot check. For partial state, use the scoped recovery reference. Do not use `configure`, credential exports or global profile changes through the wrapper; it refuses those operations.

For the Console route, repeat its saved identity/read proof in its dedicated child environment. For an explicitly retained existing-profile route, use `aws sts get-caller-identity --profile <intended-profile>` privately; every subsequent operation keeps that same explicit profile. An expired session uses only its normal scoped login flow. Credential replacement and profile maintenance require their own reviewed authorization and never overwrite the user's defaults as troubleshooting.

---

## Troubleshooting and behavior

- Start with `scripts/connect.py check` for connector-owned state. For partial setup, read the saved stage names privately and follow [scoped recovery](references/scoped-setup.md). Never print the key file, credentials file or command stderr containing credentials.
- Authentication failures preserve the current key and context. Retry only permitted reads or normal session login; never regenerate keys automatically. A timed-out create request may have succeeded remotely.
- Permission or quota failures require the exact missing permission or limit to be understood. Preserve all existing policies and keys; neither “oldest” nor “never used” proves a key is safe to delete.
- Root/unexpected identity is a verification failure. Preserve the user's original files and inspect the selected context; do not delete credentials or silently accept another IAM user.
- Use the chosen region and isolated wrapper for each operation. Existing profiles are never globally switched.
- Destructive work, paid resources and billing changes require the user's actual authorization and are outside the read-only setup. Cost Explorer or other potentially chargeable APIs are not smoke tests.
- If a requested IAM operation exceeds the connection's scope, explain the precise limitation and use separately authorized administration only when requested. Do not escalate the connector's own role as recovery.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer follows `github-connector` and `stripe-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting AWS auth or permission errors
- **gcloud-connector** / **azure-connector**: Sibling cloud-CLI connectors - same Playwright-driven user-mint pattern
- **stripe-connector** / **github-connector** / **quickbooks-connector**: Sibling autonomous-Phase-1 connectors - closest reference shapes for the Playwright-drives-the-provider-console pattern this skill follows
