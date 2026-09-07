# Scoped read-only setup

This helper supports macOS/Linux and commercial AWS accounts. Windows private ACL setup and other AWS partitions use the Console route; do not weaken private-file checks or change accounts to pass.

Use this route when a fresh read-only identity is authorized inside an existing intended AWS account. It does not test new AWS billing-account signup. Resolve the profile, exact provisioning ARN and region from the conversation and the intended profile's identity read. Run the helper from this skill directory with `setup --profile <name> --expected-arn <ARN> --region <region>`. The optional top-level `--directory` chooses a new connector directory; otherwise it uses `~/.config/aws-connector`.

The human context needs `iam:CreateUser`, `iam:TagUser`, `iam:AttachUserPolicy`, and `iam:CreateAccessKey` on the intended new identity, plus ordinary identity verification. An authorized IAM user or assumed-role session can provide it. Root is refused. Missing IAM permissions, service control policies, session/MFA restrictions and quotas are possible gates; no billing/card requirement is inferred from them. Do not modify the existing context to overcome a denial.

The helper verifies the explicit provisioning ARN/account before any mutation, refuses unexpected environment credentials or endpoint overrides and enabled AWS CLI history, snapshots the original config/credentials file hashes and profile selectors, and creates a mode-700 directory exclusively. It creates a random `claude-connector-<16 hex>` IAM user with a matching ownership tag, attaches `arn:aws:iam::aws:policy/ReadOnlyAccess`, and creates one key. An existing-name collision stops; it never adopts or changes that identity. No Console password, groups, inline policies, billable resources or billing setup is created.

AWS CLI automatic retries are disabled with `AWS_MAX_ATTEMPTS=1`. Every mutating step has a private `.started` marker and `.complete` marker. The one-time key response is captured directly into a mode-600 file, not a tool response. The helper writes dedicated mode-600 `credentials` and `config` files. `run` clears inherited `AWS_*` variables in the child process, sets only these two file paths, and explicitly selects `default` within this private store. The user's own default profile/files remain intact.

Verification uses the new key for exact STS account/ARN and an actual `iam get-user` read of the new tagged user. Attached policies must be exactly ReadOnlyAccess, with no groups or inline policies; exactly one active access key must match the saved key. CLI command history is disabled in the dedicated runtime config. If history is enabled in the original config, the helper stops before provisioning; do not change that config or create a key until a separately reviewed private provisioning context is available. AWS-managed ReadOnlyAccess is broad account read access and evolves over time; it is not a narrow custom policy or a guarantee that every service operation will succeed. Organization/resource policies can still deny access. Write access is a separate scope decision.

## Preserve and finish partial state

`setup` refuses any existing connector directory, even after failure. Read the latest `.started` without `.complete` to locate the uncertain mutation. Preserve its files and cloud resources. A timeout at `create-access-key` may mean AWS created a key whose one-time secret was not received; do not repeat key creation, delete an old key, or erase local evidence. Review exact owned remote state using the original intended profile. Never use a namesake elsewhere as recovery.

If user/policy/key creation completed and the key is privately saved, run `python3 scripts/connect.py finish`. It requires completed stage markers, matching private key/user/account, expected runtime-file contents and unchanged original files. It creates only missing local runtime/manifest files; valid existing files remain unchanged. Its cloud operations are reads only. It does not activate another profile, create users/keys, or attach/detach policies. Then run `check` and a real read from the actual caller. Short bounded retries during setup repeat only verification reads for propagation; an unresolved failure preserves state.

If the user intentionally changed their original configuration after setup, the original-context guard stops for review. Do not overwrite the user's changes or refresh the recorded baseline automatically just to pass. Use separately reviewed maintenance for that case.

For downstream use, `python3 scripts/connect.py run -- iam get-user --user-name <saved-user>` uses the isolated store. A full per-operation `--region <value>` or `--region=<value>` selects one validated region for that operation without changing saved configuration; duplicate regions and abbreviations are refused. Identity/scope verification retains the saved region. It rejects credential-export/session commands and profile, endpoint, debug or signing overrides, including abbreviated global flags. The wrapper replaces an exported credential environment file, keeping secrets and AWS environment overrides out of the calling shell. Save account/ownership/teardown evidence; keep keys in private files and authorized secret storage, never in transcripts.

## Offline regression checks

From the repository root, run `python3 -m unittest discover -s skills/aws-connector/tests -v`. All AWS responses, credentials, files and failure cases are synthetic; the test replaces subprocess execution and never contacts AWS.

## Primary references

- [AWS configuration files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) and [environment variable precedence](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html): dedicated shared credentials/config files and credential overrides.
- [Create user](https://docs.aws.amazon.com/cli/latest/reference/iam/create-user.html): names and ownership tags.
- [ReadOnlyAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/ReadOnlyAccess.html): managed policy and actual scope.
- [Create access key](https://docs.aws.amazon.com/cli/latest/reference/iam/create-access-key.html): one-time secret and user selection.
- [CLI retries](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-retries.html): maximum-attempt configuration.

- [SSO login](https://docs.aws.amazon.com/cli/latest/reference/sso/login.html): explicit profile and supported `--no-browser` behavior.
