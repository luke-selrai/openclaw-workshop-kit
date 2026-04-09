---
name: aws-connector
description: Install and configure the AWS CLI on the user's laptop. Use this skill when the user asks to set up AWS, connect Amazon Web Services, use S3, EC2, Lambda, DynamoDB, or any AWS service locally. Handles installation, credential setup, and verification conversationally.
allowed-tools: Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - aws
    - amazon
    - s3
    - ec2
    - lambda
    - installer
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting AWS auth or permission errors
    - skill: gcloud-connector
      reason: Similar pattern — local CLI connector for a cloud provider
---

# AWS CLI Connector

## Overview

This skill does two things:
1. **Installs** the AWS CLI on the user's computer (one-time setup)
2. **Operates** the CLI — interacting with AWS services (S3, EC2, Lambda, DynamoDB, etc.)

> **This is for local laptop setup only.** Server provisioning (EC2/Lightsail) lives in [claude-cloud-kit](https://github.com/luke-selrai/claude-cloud-kit).

---

## Part 1 — Installation

Guide conversationally — one step at a time:

### Step 1: Check if already installed

Run `aws --version`. If it returns a version number, say:
> "AWS is already installed on your computer. Let me check if you're signed in."

Skip to Part 2.

If "command not found", say:
> "We need to install the AWS command-line tool first. This will take about a minute."

### Step 2: Install based on OS

Detect OS with `uname -s` (or check if PowerShell is available for Windows).

**macOS — say:**
> "I'm going to install the AWS tool using Homebrew."

```bash
brew install awscli
```

If Homebrew is not installed, say:
> "I'll download the installer directly from Amazon instead."

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
rm AWSCLIV2.pkg
```

**Linux (x86_64) — say:**
> "I'm going to download and install the AWS tool from Amazon."

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

**Linux (ARM) — same message, different URL:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

**Windows — say:**
> "I'm going to install the AWS tool now. You'll see some progress in the terminal."

```powershell
winget install Amazon.AWSCLI
```

If winget is unavailable, say:
> "I'll need you to download the installer. Open this link in your browser: https://awscli.amazonaws.com/AWSCLIV2.msi — then run it and click through the steps. Let me know when it's done."

### Step 3: Verify

Run `aws --version`. If it works, say:
> "That worked! AWS is installed. Now let's connect it to your account."

If it still fails after install, say:
> "The terminal needs a refresh. Please close this terminal and open a new one, then tell me to continue."

---

## Part 2 — Credentials

### Step 4: Ask about existing credentials

Say:
> "Do you already have AWS access keys? These are like a username and password for the command line. They look like a long string of letters and numbers."

**If yes** → go to Step 5.

**If no or unsure** → say:
> "No problem. I'll help you create them. Open this link in your browser:"
> `https://console.aws.amazon.com/iam/`

Then guide step by step:
1. "Click **Users** in the left sidebar."
2. "Click on your username. If you don't see one, you may need to ask whoever manages your AWS account to create one for you."
3. "Click the **Security credentials** tab."
4. "Scroll down to **Access keys** and click **Create access key**."
5. "Select **Command Line Interface (CLI)** and click **Next**."
6. "Click **Create access key**."
7. "You'll see two values — an **Access Key ID** and a **Secret Access Key**. Copy both of them somewhere safe. The secret is only shown once."

If the user needs Playwright assistance navigating the console, use it.

### Step 5: Configure

Say:
> "Now I'm going to run the setup. It will ask you four things — I'll tell you what to enter for each one."

Run:
```bash
aws configure
```

Guide each prompt:
1. **AWS Access Key ID** → "Paste your Access Key ID here."
2. **AWS Secret Access Key** → "Paste your Secret Access Key here."
3. **Default region name** → "Which region are you closest to?" Help them pick:

| Location | Region code |
|---|---|
| Sydney | `ap-southeast-2` |
| Singapore | `ap-southeast-1` |
| US East (Virginia) | `us-east-1` |
| US West (Oregon) | `us-west-2` |
| London | `eu-west-2` |
| Frankfurt | `eu-central-1` |
| Tokyo | `ap-northeast-1` |

4. **Default output format** → "Type `json` and press Enter."

### Step 6: Verify

Run:
```bash
aws sts get-caller-identity
```

If it returns account info, say:
> "That worked! You're connected to AWS as [account/user]. Your AWS is ready to go."

If it fails, check the error and refer to the Troubleshooting section.

---

## Part 3 — What to Try First

After setup, suggest simple tasks:

> "Want to try something? Here are a few things I can do with your AWS:"

```
"Show me my S3 buckets."
"What's running in my AWS account?"
"List my EC2 instances."
```

Say:
> "Start with something simple. Once you're comfortable, I can help with more complex tasks like deploying apps or managing databases."

---

## Part 4 — Common Operations

### S3 (Storage)

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

### EC2 (Virtual Machines)

```bash
# List instances
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

# Start an instance
aws ec2 start-instances --instance-ids i-1234567890abcdef0

# Stop an instance
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
```

### Lambda (Serverless Functions)

```bash
# List functions
aws lambda list-functions --query 'Functions[].FunctionName'

# Invoke a function
aws lambda invoke --function-name my-function --payload '{}' output.json
```

### DynamoDB

```bash
# List tables
aws dynamodb list-tables

# Scan a table (first 10 items)
aws dynamodb scan --table-name my-table --max-items 10
```

### IAM (Users & Permissions)

```bash
# List users
aws iam list-users --query 'Users[].UserName'

# Get current user info
aws sts get-caller-identity
```

---

## Part 5 — SSO Login (Alternative to Access Keys)

If the user's organisation uses AWS SSO (IAM Identity Center), say:
> "Your company uses a different sign-in method. I'll set that up instead."

```bash
aws configure sso
```

This prompts for:
- **SSO start URL** — "Ask your IT admin for this. It looks like `https://my-company.awsapps.com/start`."
- **SSO region** — "Ask your IT admin which region your company's sign-in is in."
- **Account and role** — "A browser will open. Sign in, then pick your account and role from the list."

After setup, log in with:
```bash
aws sso login --profile <profile-name>
```

---

## Part 6 — Auth & Session

```bash
# Check who is signed in
aws sts get-caller-identity

# Check current config
aws configure list

# Switch profiles
export AWS_PROFILE=other-profile

# List configured profiles
aws configure list-profiles

# Reconfigure credentials
aws configure
```

---

## Part 7 — Troubleshooting

| Problem | Fix |
|---|---|
| `aws: command not found` | Shell needs restart — open a new terminal |
| `Unable to locate credentials` | Run `aws configure` to set up access keys |
| `An error occurred (InvalidClientTokenId)` | Access key is invalid or deleted — create a new one in IAM console |
| `An error occurred (SignatureDoesNotMatch)` | Secret key is wrong — run `aws configure` and re-enter it |
| `An error occurred (AccessDenied)` | User doesn't have permission — check IAM policies |
| `Could not connect to the endpoint URL` | Wrong region — run `aws configure` and set the correct region |
| `An error occurred (ExpiredToken)` | SSO session expired — run `aws sso login` |
| `The security token included in the request is invalid` | Credentials expired — re-run `aws configure` or `aws sso login` |

When an error occurs, say:
> "No problem — let me try a different way."

Then diagnose and fix. Never show raw error messages to the user — translate them into plain English.

---

## Behaviour Guidelines

- **Always run `aws sts get-caller-identity` first** at the start of a session to confirm the user is signed in.
- **Confirm before destructive actions** — deleting buckets, terminating instances, removing IAM users.
- **Region context matters** — always check `aws configure get region` before running commands.
- **Auth errors** → `aws configure` for access keys, `aws sso login` for SSO.
- **aws not found** → restart shell or reinstall.
- **Never echo or log secret keys** — they should only be entered via `aws configure`.
- **One step at a time** — do not dump all instructions at once. Say what to do, wait, then give the next step.
