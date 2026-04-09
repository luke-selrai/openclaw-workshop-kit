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

### Step 1: Check if already installed

```bash
aws --version
```

If this returns a version number, skip to Step 3 (credentials). If "command not found", continue.

### Step 2: Install AWS CLI

Detect the user's OS first:

```bash
uname -s
```

**macOS (Homebrew):**
```bash
brew install awscli
```

**macOS (without Homebrew):**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
rm AWSCLIV2.pkg
```

**Linux (x86_64):**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

**Linux (ARM):**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

**Windows (winget):**
```powershell
winget install Amazon.AWSCLI
```

**Windows (MSI installer):**
Download from https://awscli.amazonaws.com/AWSCLIV2.msi and run the installer.

### Step 3: Verify installation

```bash
aws --version
```

If this returns `aws-cli/2.x.x`, installation is complete.

---

## Part 2 — Credentials

### Step 4: Get AWS credentials

The user needs an **Access Key ID** and **Secret Access Key**. Ask:

> "Do you already have AWS access keys? If not, I can help you create them."

**If they need to create keys:**
1. Go to https://console.aws.amazon.com/iam/
2. Click **Users** → select your user (or create one)
3. Click **Security credentials** tab
4. Click **Create access key**
5. Select **Command Line Interface (CLI)**
6. Copy the Access Key ID and Secret Access Key

> **Important:** The secret key is only shown once. Save it securely.

### Step 5: Configure credentials

```bash
aws configure
```

This prompts for four values:
- **AWS Access Key ID** — paste the key
- **AWS Secret Access Key** — paste the secret
- **Default region name** — e.g. `ap-southeast-2` (Sydney), `us-east-1` (Virginia)
- **Default output format** — enter `json`

If the user doesn't know their region, help them pick one:

| Location | Region code |
|---|---|
| Sydney | `ap-southeast-2` |
| Singapore | `ap-southeast-1` |
| US East (Virginia) | `us-east-1` |
| US West (Oregon) | `us-west-2` |
| London | `eu-west-2` |
| Frankfurt | `eu-central-1` |
| Tokyo | `ap-northeast-1` |

### Step 6: Verify

```bash
aws sts get-caller-identity
```

This should return the user's account ID, user ARN, and user ID. If it works, setup is complete.

---

## Part 3 — Common Operations

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

## Part 4 — SSO Login (Alternative to Access Keys)

If the user's organisation uses AWS SSO (IAM Identity Center):

```bash
aws configure sso
```

This prompts for:
- **SSO start URL** — provided by their IT admin (e.g. `https://my-company.awsapps.com/start`)
- **SSO region** — the region where SSO is configured
- **Account and role** — selected from a list after browser sign-in

After setup, log in with:
```bash
aws sso login --profile <profile-name>
```

---

## Part 5 — Auth & Session

```bash
# Check who is signed in
aws sts get-caller-identity

# Check current config
aws configure list

# Switch profiles
export AWS_PROFILE=other-profile

# List configured profiles
aws configure list-profiles

# Clear credentials (remove from config files)
# Credentials are stored in ~/.aws/credentials
# Config is stored in ~/.aws/config
```

---

## Part 6 — Troubleshooting

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

---

## Behaviour Guidelines

- **Always run `aws sts get-caller-identity` first** at the start of a session to confirm the user is signed in.
- **Confirm before destructive actions** — deleting buckets, terminating instances, removing IAM users.
- **Region context matters** — always check `aws configure get region` before running commands.
- **Auth errors** → `aws configure` for access keys, `aws sso login` for SSO.
- **aws not found** → restart shell or reinstall.
- **Never echo or log secret keys** — they should only be entered via `aws configure`.
