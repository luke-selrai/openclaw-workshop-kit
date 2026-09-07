import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import time


POLICY = "arn:aws:iam::aws:policy/ReadOnlyAccess"


class ConnectionError(Exception):
    pass


def privateWrite(path, value):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(value)
        output.flush()
        os.fsync(output.fileno())


def privateRead(path):
    details = path.lstat()
    if not stat.S_ISREG(details.st_mode) or details.st_mode & 0o077:
        raise ConnectionError("PRIVATE_STATE_NOT_VERIFIED")
    return path.read_text()


def cleanEnvironment(environment):
    child = dict(environment)
    for name in list(child):
        if name.startswith("AWS_"):
            del child[name]
    child.update({"AWS_PAGER": "", "AWS_CLI_AUTO_PROMPT": "off", "AWS_EC2_METADATA_DISABLED": "true", "AWS_MAX_ATTEMPTS": "1"})
    return child


def operationRegion(arguments, default_region):
    remaining = []
    selected = None
    position = 0
    while position < len(arguments):
        argument = arguments[position]
        if argument == "--region" or argument.startswith("--region="):
            if selected is not None:
                raise ConnectionError("DUPLICATE_OPERATION_REGION_NOT_ALLOWED")
            if argument == "--region":
                position += 1
                if position >= len(arguments):
                    raise ConnectionError("VALID_OPERATION_REGION_REQUIRED")
                selected = arguments[position]
            else:
                selected = argument.split("=", 1)[1]
            if not re.fullmatch(r"[a-z]{2}(?:-[a-z]+)+-\d", selected):
                raise ConnectionError("VALID_OPERATION_REGION_REQUIRED")
        else:
            remaining.append(argument)
        position += 1
    if selected is None:
        selected = default_region
    return remaining, selected


def cloud(arguments, environment, profile, region, decode=True):
    arguments, region = operationRegion(arguments, region)
    command = ["aws", *arguments, "--profile", profile, "--region", region, "--no-cli-pager", "--output", "json"]
    try:
        result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=120, umask=0o077)
    except subprocess.TimeoutExpired:
        raise ConnectionError("AWS_REQUEST_TIMEOUT_PRESERVE_STATE") from None
    if result.returncode:
        category = "UNCLASSIFIED"
        for code in ("AccessDenied", "EntityAlreadyExists", "LimitExceeded", "InvalidClientTokenId", "ExpiredToken", "NoSuchEntity", "SignatureDoesNotMatch", "ServiceFailure"):
            if code in result.stderr:
                category = code.upper()
                break
        raise ConnectionError("AWS_" + category + "_PRESERVE_STATE")
    if not decode:
        return result.stdout
    if not result.stdout.strip():
        return {}
    return json.loads(result.stdout)


def originalFiles(environment):
    paths = {
        "AWS_CONFIG_FILE": str(Path(environment.get("AWS_CONFIG_FILE", "~/.aws/config")).expanduser().absolute()),
        "AWS_SHARED_CREDENTIALS_FILE": str(Path(environment.get("AWS_SHARED_CREDENTIALS_FILE", "~/.aws/credentials")).expanduser().absolute()),
    }
    hashes = {}
    for value in paths.values():
        path = Path(value)
        if path.is_symlink():
            raise ConnectionError("ORIGINAL_SYMLINK_REQUIRES_REVIEW")
        if path.exists():
            hashes[value] = hashlib.sha256(path.read_bytes()).hexdigest()
        else:
            hashes[value] = None
    return {"paths": paths, "hashes": hashes, "profile": environment.get("AWS_PROFILE"), "default_profile": environment.get("AWS_DEFAULT_PROFILE")}


def provisioningEnvironment(environment, original):
    for name, value in environment.items():
        if value and (name.startswith("AWS_ENDPOINT_URL") or name in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN", "AWS_SECURITY_TOKEN", "AWS_WEB_IDENTITY_TOKEN_FILE", "AWS_ROLE_ARN", "AWS_CONTAINER_CREDENTIALS_FULL_URI", "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI")):
            raise ConnectionError("AUTH_OR_ENDPOINT_OVERRIDE_REQUIRES_REVIEW")
    config_path = Path(original["paths"]["AWS_CONFIG_FILE"])
    if config_path.exists():
        parser = configparser.RawConfigParser()
        parser.read_string(config_path.read_text())
        for section in parser.sections():
            if parser.has_option(section, "endpoint_url") or parser.has_option(section, "services"):
                raise ConnectionError("CONFIG_ENDPOINT_OVERRIDE_REQUIRES_REVIEW")
            if parser.get(section, "cli_history", fallback="disabled").strip().lower() == "enabled":
                raise ConnectionError("CLI_HISTORY_ENABLED_REQUIRES_REVIEW")
    child = cleanEnvironment(environment)
    child.update(original["paths"])
    return child


def savedState(directory):
    details = directory.lstat()
    if not stat.S_ISDIR(details.st_mode) or details.st_mode & 0o077:
        raise ConnectionError("PRIVATE_DIRECTORY_NOT_VERIFIED")
    attempt = json.loads(privateRead(directory / "attempt.json"))
    if (not re.fullmatch(r"\d{12}", attempt["account"])
            or not re.fullmatch(r"claude-connector-[a-f0-9]{16}", attempt["user"])
            or not re.fullmatch(r"[a-z]{2}(?:-[a-z]+)+-\d", attempt["region"])
            or attempt["arn"] != "arn:aws:iam::" + attempt["account"] + ":user/" + attempt["user"]):
        raise ConnectionError("SAVED_IDENTITY_NOT_VERIFIED")
    return attempt


def keyValues(directory, attempt):
    key = json.loads(privateRead(directory / "key.json"))["AccessKey"]
    if (key.get("UserName") != attempt["user"] or key.get("Status") != "Active"
            or not re.fullmatch(r"AKIA[A-Z0-9]{16}", key.get("AccessKeyId", ""))
            or not re.fullmatch(r"[A-Za-z0-9/+=]{40}", key.get("SecretAccessKey", ""))):
        raise ConnectionError("SAVED_KEY_NOT_VERIFIED")
    return key


def runtimeFiles(directory, attempt, allow_missing):
    key = keyValues(directory, attempt)
    values = {
        "credentials": "[default]\naws_access_key_id = " + key["AccessKeyId"] + "\naws_secret_access_key = " + key["SecretAccessKey"] + "\n",
        "config": "[default]\nregion = " + attempt["region"] + "\noutput = json\ncli_history = disabled\n",
    }
    for name, value in values.items():
        path = directory / name
        if os.path.lexists(path):
            if privateRead(path) != value:
                raise ConnectionError("SAVED_RUNTIME_FILES_DIFFER_PRESERVE_STATE")
        elif allow_missing:
            privateWrite(path, value)
        else:
            raise ConnectionError("PARTIAL_SETUP_USE_FINISH")


def runtimeEnvironment(environment, directory):
    child = cleanEnvironment(environment)
    child["AWS_SHARED_CREDENTIALS_FILE"] = str(directory / "credentials")
    child["AWS_CONFIG_FILE"] = str(directory / "config")
    return child


def verifyRemote(attempt, environment, profile, key_id):
    identity = cloud(["sts", "get-caller-identity"], environment, profile, attempt["region"])
    if identity.get("Arn") != attempt["arn"] or identity.get("Account") != attempt["account"]:
        raise ConnectionError("EXACT_CONNECTOR_IDENTITY_NOT_VERIFIED")
    user = cloud(["iam", "get-user", "--user-name", attempt["user"]], environment, profile, attempt["region"])["User"]
    if user.get("Arn") != attempt["arn"] or user.get("UserName") != attempt["user"]:
        raise ConnectionError("REAL_USER_READ_NOT_VERIFIED")
    if {tag["Key"]: tag["Value"] for tag in user.get("Tags", [])}.get("claude-connector") != attempt["user"]:
        raise ConnectionError("USER_OWNERSHIP_NOT_VERIFIED")
    policies = cloud(["iam", "list-attached-user-policies", "--user-name", attempt["user"]], environment, profile, attempt["region"])
    if [policy["PolicyArn"] for policy in policies.get("AttachedPolicies", [])] != [POLICY]:
        raise ConnectionError("READ_ONLY_POLICY_NOT_VERIFIED")
    for operation, field in (("list-user-policies", "PolicyNames"), ("list-groups-for-user", "Groups")):
        result = cloud(["iam", operation, "--user-name", attempt["user"]], environment, profile, attempt["region"])
        if result.get(field) != []:
            raise ConnectionError("UNEXPECTED_ADDITIONAL_PERMISSIONS")

    keys = cloud(["iam", "list-access-keys", "--user-name", attempt["user"]], environment, profile, attempt["region"])
    metadata = keys.get("AccessKeyMetadata", [])
    if len(metadata) != 1 or metadata[0].get("AccessKeyId") != key_id or metadata[0].get("Status") != "Active" or metadata[0].get("UserName") != attempt["user"]:
        raise ConnectionError("EXACT_SINGLE_ACTIVE_KEY_NOT_VERIFIED")


def finish(directory, environment, allow_missing):
    attempt = savedState(directory)
    original = json.loads(privateRead(directory / "original.json"))
    if originalFiles(environment) != original:
        raise ConnectionError("ORIGINAL_CONFIGURATION_CHANGED_PRESERVE_STATE")
    for stage in ("user", "policy", "key"):
        if privateRead(directory / (stage + ".started")) != "started" or privateRead(directory / (stage + ".complete")) != "complete":
            raise ConnectionError("PROVISIONING_INCOMPLETE_PRESERVE_STATE")
    runtimeFiles(directory, attempt, allow_missing)
    try:
        verifyRemote(attempt, runtimeEnvironment(environment, directory), "default", keyValues(directory, attempt)["AccessKeyId"])
    finally:
        if originalFiles(environment) != original:
            raise ConnectionError("ORIGINAL_CONFIGURATION_CHANGED_PRESERVE_STATE")
    expected = json.dumps({"arn": attempt["arn"], "policy": POLICY})
    manifest = directory / "connection.json"
    if os.path.lexists(manifest):
        if privateRead(manifest) != expected:
            raise ConnectionError("OWNERSHIP_MANIFEST_DIFFERS")
    elif allow_missing:
        privateWrite(manifest, expected)
    else:
        raise ConnectionError("PARTIAL_SETUP_USE_FINISH")
    return attempt


def setup(args, environment):
    directory = Path(args.directory).expanduser().absolute()
    if directory.resolve() == (Path.home() / ".aws").resolve():
        raise ConnectionError("DEFAULT_AWS_DIRECTORY_NOT_ALLOWED")
    if os.path.lexists(directory):
        raise ConnectionError("EXISTING_STATE_USE_CHECK_OR_REVIEW")
    match = re.fullmatch(r"arn:aws:(?:iam|sts)::(\d{12}):(?:user|assumed-role)/[A-Za-z0-9+=,.@_/-]+", args.expected_arn)
    if not match or not re.fullmatch(r"[A-Za-z0-9_.-]+", args.profile) or not re.fullmatch(r"[a-z]{2}(?:-[a-z]+)+-\d", args.region):
        raise ConnectionError("EXPLICIT_NONROOT_PROFILE_IDENTITY_AND_REGION_REQUIRED")
    original = originalFiles(environment)
    human_env = provisioningEnvironment(environment, original)
    identity = cloud(["sts", "get-caller-identity"], human_env, args.profile, args.region)
    if identity.get("Arn") != args.expected_arn or identity.get("Account") != match[1]:
        raise ConnectionError("PROVISIONING_IDENTITY_MISMATCH")
    user = "claude-connector-" + secrets.token_hex(8)
    attempt = {"account": match[1], "user": user, "arn": "arn:aws:iam::" + match[1] + ":user/" + user, "region": args.region, "profile": args.profile, "provisioning_arn": args.expected_arn}
    directory.parent.mkdir(parents=True, exist_ok=True)
    directory.mkdir(mode=0o700)
    privateWrite(directory / "original.json", json.dumps(original))
    privateWrite(directory / "attempt.json", json.dumps(attempt))
    def provision(stage, arguments):
        privateWrite(directory / (stage + ".started"), "started")
        result = cloud(arguments, human_env, args.profile, args.region)
        if stage == "user" and result.get("User", {}).get("Arn") != attempt["arn"]:
            raise ConnectionError("CREATED_USER_IDENTITY_NOT_VERIFIED")
        if stage == "key":
            privateWrite(directory / "key.json", json.dumps(result))
            keyValues(directory, attempt)
        privateWrite(directory / (stage + ".complete"), "complete")
        return result
    try:
        provision("user", ["iam", "create-user", "--user-name", user, "--tags", "Key=claude-connector,Value=" + user])
        provision("policy", ["iam", "attach-user-policy", "--user-name", user, "--policy-arn", POLICY])
        provision("key", ["iam", "create-access-key", "--user-name", user])
        for number in range(4):
            try:
                finish(directory, environment, True)
                break
            except ConnectionError as error:
                if str(error) not in ("AWS_INVALIDCLIENTTOKENID_PRESERVE_STATE", "AWS_ACCESSDENIED_PRESERVE_STATE", "AWS_NOSUCHENTITY_PRESERVE_STATE") or number == 3:
                    raise
                time.sleep(5)
    finally:
        if originalFiles(environment) != original:
            raise ConnectionError("ORIGINAL_CONFIGURATION_CHANGED_PRESERVE_STATE")
    print("CONNECTED_READ_ONLY; dedicated user verified; original configuration unchanged")


def operationArguments(arguments):
    if arguments[:1] == ["--"]:
        arguments = arguments[1:]
    if len(arguments) < 2 or arguments[0].startswith("-"):
        raise ConnectionError("AWS_OPERATION_REQUIRED")
    if arguments[0] in ("configure", "login", "logout", "sso", "sso-oidc", "help"):
        raise ConnectionError("CREDENTIAL_OR_CONFIGURATION_COMMAND_NOT_ALLOWED")
    if arguments[0] == "sts" and arguments[1] != "get-caller-identity":
        raise ConnectionError("CREDENTIAL_OR_CONFIGURATION_COMMAND_NOT_ALLOWED")
    protected = ("--profile", "--endpoint-url", "--no-sign-request", "--no-verify-ssl", "--ca-bundle", "--debug")
    for argument in arguments:
        option = argument.split("=", 1)[0]
        if option.startswith("--") and "--region".startswith(option) and option != "--region":
            raise ConnectionError("USE_FULL_REGION_OPTION")
        if option.startswith("--") and any(flag.startswith(option) for flag in protected):
            raise ConnectionError("RUNTIME_OVERRIDE_NOT_ALLOWED")
    return arguments


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="~/.config/aws-connector")
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("setup")
    create.add_argument("--profile", required=True)
    create.add_argument("--expected-arn", required=True)
    create.add_argument("--region", default="ap-southeast-2")
    commands.add_parser("finish")
    commands.add_parser("check")
    run = commands.add_parser("run")
    run.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if os.name != "posix":
            raise ConnectionError("SCOPED_HELPER_REQUIRES_POSIX_PRIVATE_FILES_USE_CONSOLE_ROUTE")
        environment = dict(os.environ)
        if args.command == "setup":
            setup(args, environment)
        else:
            directory = Path(args.directory).expanduser().absolute()
            if args.command == "run":
                arguments = operationArguments(args.arguments)
            attempt = finish(directory, environment, args.command == "finish")
            if args.command == "run":
                print(cloud(arguments, runtimeEnvironment(environment, directory), "default", attempt["region"], False), end="")
            else:
                print("CONNECTED_READ_ONLY; real IAM user read verified; original configuration unchanged")
    except ConnectionError as error:
        print(str(error))
        return 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, configparser.Error):
        print("AWS_SETUP_STOPPED_PRESERVE_PRIVATE_STATE")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
