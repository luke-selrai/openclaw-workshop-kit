import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time


class ConnectionError(Exception):
    pass


def requestStage(arguments):
    stages = {
        ("config", "list"): "CONFIG_READ",
        ("config", "get-value"): "IDENTITY_READ",
        ("config", "configurations", "list"): "CONFIGURATION_LIST",
        ("info",): "CONFIG_PATH_READ",
        ("auth", "list"): "LOGIN_LIST",
        ("auth", "activate-service-account"): "KEY_ACTIVATION",
        ("projects", "create"): "PROJECT_CREATE",
        ("projects", "describe"): "PROJECT_READ",
        ("projects", "get-iam-policy"): "ROLE_READ",
        ("projects", "add-iam-policy-binding"): "VIEWER_BINDING",
        ("services", "enable"): "CONNECTION_APIS_ENABLE",
        ("iam", "service-accounts", "create"): "SERVICE_ACCOUNT_CREATE",
        ("iam", "service-accounts", "describe"): "SERVICE_ACCOUNT_READ",
        ("iam", "service-accounts", "keys", "create"): "KEY_CREATE",
    }
    for prefix, stage in stages.items():
        if tuple(arguments[:len(prefix)]) == prefix:
            return stage
    return "CLI_REQUEST"


def failureReason(output):
    categories = (
        ("ORG_POLICY", r"organization.?policy|org.?policy|constraints/|disableserviceaccountkeycreation"),
        ("QUOTA", r"resource_exhausted|quota|maximum number of keys"),
        ("SERVICE_DISABLED", r"service_disabled|accessnotconfigured|api.{0,80}(not enabled|disabled|has not been used)"),
        ("AUTHENTICATION", r"unauthenticated|invalid_grant|reauthentication|invalid credentials"),
        ("PERMISSION", r"permission_denied|permission denied|does not have permission"),
        ("ALREADY_EXISTS", r"already_exists|already exists"),
        ("NOT_FOUND", r"not_found|not found"),
    )
    for category, pattern in categories:
        if re.search(pattern, output, re.IGNORECASE):
            return category
    return "UNCLASSIFIED"


def runCloud(arguments, environment, decode=True):
    stage = requestStage(arguments)
    command = ["gcloud", *arguments]
    if "--quiet" not in command:
        command.append("--quiet")
    try:
        result = subprocess.run(
            command, env=environment, capture_output=True,
            text=True, timeout=180, umask=0o077,
        )
    except subprocess.TimeoutExpired:
        raise ConnectionError("GCLOUD_" + stage + "_TIMEOUT_PRESERVE_AND_REVIEW") from None
    if result.returncode:
        reason = failureReason(result.stderr + "\n" + result.stdout)
        raise ConnectionError("GCLOUD_" + stage + "_" + reason + "_PRESERVE_AND_REVIEW")
    if decode:
        try:
            return json.loads(result.stdout)
        except ValueError:
            raise ConnectionError("GCLOUD_" + stage + "_INVALID_RESPONSE_PRESERVE_AND_REVIEW") from None
    return result.stdout.strip()


def privateWrite(path, value):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(value)
        output.flush()
        os.fsync(output.fileno())


def hasOverrides(config, environment):
    auth = config.get("auth", {})
    override_present = bool(config.get("api_endpoint_overrides"))
    for field in ("impersonate_service_account", "access_token_file", "credential_file_override", "disable_credentials"):
        if auth.get(field) not in (None, "", False, "false"):
            override_present = True
    for name, value in environment.items():
        if value and (name.startswith("CLOUDSDK_AUTH_") or name.startswith("CLOUDSDK_API_ENDPOINT_OVERRIDES_")):
            override_present = True
    return override_present


def originalContext(environment):
    config = runCloud(["config", "list", "--format=json"], environment)
    config_path = runCloud(["info", "--format=value(config.paths.global_config_dir)"], environment, False)
    active = runCloud(["config", "configurations", "list", "--filter=is_active:true", "--format=value(name)"], environment, False)
    if not config_path or not active or "\n" in active:
        raise ConnectionError("ORIGINAL_CONFIGURATION_NOT_VERIFIED")
    root = Path(config_path)
    paths = [root / "active_config", root / "application_default_credentials.json"]
    paths.extend(sorted((root / "configurations").glob("*")))
    hashes = {}
    for path in paths:
        if path.is_file():
            hashes[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "path": str(root), "configuration": active,
        "account": config.get("core", {}).get("account"),
        "project": config.get("core", {}).get("project"),
        "override_present": hasOverrides(config, environment), "configuration_hashes": hashes,
    }


def isolatedEnvironment(environment, directory):
    child = dict(environment)
    for name in list(child):
        if name.startswith("CLOUDSDK_") or name in ("GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT"):
            del child[name]
    child["CLOUDSDK_CONFIG"] = str(directory)
    return child


def keyIdentity(path, account, project):
    if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
        raise ConnectionError("PRIVATE_KEY_NOT_VERIFIED")
    key = json.loads(path.read_text())
    if (key.get("type") != "service_account" or key.get("client_email") != account
            or key.get("project_id") != project or not key.get("private_key")
            or not key.get("private_key_id")):
        raise ConnectionError("EXACT_CONNECTOR_KEY_NOT_VERIFIED")


def credentialValues(directory, account, project):
    return {
        "CLOUDSDK_CONFIG": str(directory / "cli"), "CLOUDSDK_ACTIVE_CONFIG_NAME": "default",
        "CLOUDSDK_CORE_ACCOUNT": account, "CLOUDSDK_CORE_PROJECT": project,
        "GCLOUD_CONNECTOR_ACCOUNT": account, "GCLOUD_PROJECT": project,
        "GOOGLE_CLOUD_PROJECT": project, "PROJECT_ID": project,
        "GOOGLE_APPLICATION_CREDENTIALS": str(directory / "key.json"),
    }


def verify(directory, environment):
    manifest_path = directory / "connection.json"
    if not manifest_path.is_file():
        raise ConnectionError("MISSING_OR_PARTIAL_CONNECTOR_USE_SETUP_REVIEW")
    manifest = json.loads(manifest_path.read_text())
    account = manifest["account"]
    project = manifest["project"]
    verifyIdentity(directory, environment, account, project)
    return manifest


def verifyIdentity(directory, environment, account, project):
    if not account.endswith("@" + project + ".iam.gserviceaccount.com"):
        raise ConnectionError("EXACT_CONNECTOR_ACCOUNT_NOT_VERIFIED")
    keyIdentity(directory / "key.json", account, project)
    env_file = directory / "credentials.env"
    if env_file.exists():
        if env_file.is_symlink() or env_file.stat().st_mode & 0o077:
            raise ConnectionError("SAVED_ENVIRONMENT_NOT_VERIFIED")
        values = {}
        for line in env_file.read_text().splitlines():
            parts = shlex.split(line)
            if len(parts) != 2 or parts[0] != "export" or "=" not in parts[1]:
                raise ConnectionError("SAVED_ENVIRONMENT_NOT_VERIFIED")
            name, value = parts[1].split("=", 1)
            if name in values:
                raise ConnectionError("SAVED_ENVIRONMENT_NOT_VERIFIED")
            values[name] = value
        if values != credentialValues(directory, account, project):
            raise ConnectionError("SAVED_ENVIRONMENT_NOT_VERIFIED")
    if (directory / "cli").is_symlink() or not (directory / "cli").is_dir():
        raise ConnectionError("EXACT_CONNECTOR_CONFIGURATION_NOT_VERIFIED")
    child = isolatedEnvironment(environment, directory / "cli")
    config = runCloud(["config", "list", "--format=json"], child)
    if hasOverrides(config, child):
        raise ConnectionError("ISOLATED_AUTH_OR_ENDPOINT_OVERRIDE_PRESENT_PRESERVE_AND_REVIEW")
    active = runCloud(["config", "get-value", "account"], child, False)
    active_project = runCloud(["config", "get-value", "project"], child, False)
    if active != account or active_project != project:
        raise ConnectionError("EXACT_CONNECTOR_CONFIGURATION_NOT_VERIFIED")
    result = runCloud(["projects", "describe", project, "--account=" + account, "--project=" + project, "--format=json"], child)
    if result.get("projectId") != project:
        raise ConnectionError("PROJECT_READ_NOT_VERIFIED")


def activateKey(directory, environment, account, project):
    key_path = directory / "key.json"
    key_hash = hashlib.sha256(key_path.read_bytes()).digest()
    child = isolatedEnvironment(environment, directory / "cli")
    command = ["auth", "activate-service-account", account, "--key-file=" + str(key_path), "--project=" + project, "--quiet"]
    for attempt in range(3):
        keyIdentity(key_path, account, project)
        if hashlib.sha256(key_path.read_bytes()).digest() != key_hash:
            raise ConnectionError("KEY_CHANGED_PRESERVE_AND_REVIEW")
        try:
            runCloud(command, child, False)
            return
        except ConnectionError as error:
            if str(error) != "GCLOUD_KEY_ACTIVATION_AUTHENTICATION_PRESERVE_AND_REVIEW" or attempt == 2:
                raise
            time.sleep(5)


def writeEnvironment(directory, account, project):
    lines = []
    for name, value in credentialValues(directory, account, project).items():
        lines.append("export " + name + "=" + shlex.quote(value))
    privateWrite(directory / "credentials.env", "\n".join(lines) + "\n")


def privateRecord(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
        raise ConnectionError("PARTIAL_STATE_NOT_VERIFIED_PRESERVE_AND_REVIEW")
    return path.read_text()


def finish(args, environment):
    directory = Path(args.directory).expanduser().absolute()
    if directory.is_symlink() or not directory.is_dir() or directory.stat().st_mode & 0o077:
        raise ConnectionError("PARTIAL_STATE_NOT_VERIFIED_PRESERVE_AND_REVIEW")
    attempt = json.loads(privateRecord(directory / "attempt.json"))
    original = json.loads(privateRecord(directory / "original.json"))
    for stage in ("project", "iam-api", "service-account", "viewer", "key"):
        for suffix in ("started", "complete"):
            if privateRecord(directory / (stage + "." + suffix)) != suffix:
                raise ConnectionError("PROVISIONING_INCOMPLETE_PRESERVE_AND_REVIEW")
    project = attempt["project"]
    account = attempt["account"]
    human_account = attempt["human_account"]
    if (not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", project)
            or account != "claude-assistant@" + project + ".iam.gserviceaccount.com"
            or "@" not in human_account or human_account.endswith(".gserviceaccount.com")):
        raise ConnectionError("PARTIAL_IDENTITY_NOT_VERIFIED_PRESERVE_AND_REVIEW")
    current = originalContext(environment)
    if current != original or current["override_present"]:
        raise ConnectionError("ORIGINAL_CONFIGURATION_CHANGED_PRESERVE_AND_REVIEW")
    keyIdentity(directory / "key.json", account, project)
    expected = {"account": account, "project": project, "role": "roles/viewer"}
    manifest_path = directory / "connection.json"
    if os.path.lexists(manifest_path) and json.loads(privateRecord(manifest_path)) != expected:
        raise ConnectionError("PARTIAL_IDENTITY_NOT_VERIFIED_PRESERVE_AND_REVIEW")
    env_path = directory / "credentials.env"
    if os.path.lexists(env_path):
        privateRecord(env_path)
    human_env = dict(environment)
    human_env["CLOUDSDK_CONFIG"] = original["path"]
    scope = ["--account=" + human_account, "--project=" + project, "--configuration=" + original["configuration"], "--quiet"]
    try:
        policy = runCloud(["projects", "get-iam-policy", project, "--format=json", *scope], human_env)
        roles = []
        for binding in policy.get("bindings", []):
            if "serviceAccount:" + account in binding.get("members", []):
                roles.append(binding.get("role"))
                if binding.get("condition"):
                    raise ConnectionError("UNEXPECTED_ROLE_BINDING_PRESERVE_AND_REVIEW")
        if roles != ["roles/viewer"]:
            raise ConnectionError("UNEXPECTED_ROLE_BINDING_PRESERVE_AND_REVIEW")
        verifyIdentity(directory, environment, account, project)
    finally:
        if originalContext(environment) != original:
            raise ConnectionError("ORIGINAL_CONFIGURATION_CHANGED_PRESERVE_AND_REVIEW")
    if not manifest_path.exists():
        privateWrite(manifest_path, json.dumps(expected))
    if not env_path.exists():
        writeEnvironment(directory, account, project)
    print("CONNECTED_VIEWER; existing key retained; original configuration unchanged")


def setup(args, environment):
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
        raise ConnectionError("VALID_NEW_PROJECT_ID_REQUIRED")
    if "@" not in args.account or args.account.endswith(".gserviceaccount.com"):
        raise ConnectionError("EXPLICIT_EXISTING_HUMAN_LOGIN_REQUIRED")
    directory = Path(args.directory).expanduser().absolute()
    if os.path.lexists(directory):
        raise ConnectionError("EXISTING_CONNECTOR_STATE_USE_CHECK_OR_REVIEW")
    original = originalContext(environment)
    if original["override_present"]:
        raise ConnectionError("AUTH_OR_ENDPOINT_OVERRIDE_PRESENT_REVIEW_WITHOUT_CHANGES")
    human_env = dict(environment)
    human_env["CLOUDSDK_CONFIG"] = original["path"]
    accounts = runCloud(["auth", "list", "--format=json"], human_env)
    if not any(account.get("account") == args.account for account in accounts):
        raise ConnectionError("INTENDED_HUMAN_LOGIN_NOT_AVAILABLE")
    directory.parent.mkdir(parents=True, exist_ok=True)
    directory.mkdir(mode=0o700)
    privateWrite(directory / "original.json", json.dumps(original))
    account = "claude-assistant@" + args.project + ".iam.gserviceaccount.com"
    privateWrite(directory / "attempt.json", json.dumps({"project": args.project, "account": account, "human_account": args.account}))
    scope = ["--account=" + args.account, "--project=" + args.project, "--configuration=" + original["configuration"], "--quiet"]

    def provision(stage, command, decode=True):
        privateWrite(directory / (stage + ".started"), "started")
        result = runCloud([*command, *scope], human_env, decode)
        privateWrite(directory / (stage + ".complete"), "complete")
        return result

    try:
        provision("project", ["projects", "create", args.project, "--name=" + args.name, "--no-enable-cloud-apis"], False)
        provision("iam-api", ["services", "enable", "iam.googleapis.com", "cloudresourcemanager.googleapis.com"], False)
        provision("service-account", ["iam", "service-accounts", "create", "claude-assistant", "--display-name=Claude Assistant", "--description=Dedicated workshop connector"], False)
        for attempt in range(7):
            try:
                result = runCloud(["iam", "service-accounts", "describe", account, "--format=json", *scope], human_env)
                if result.get("email") != account:
                    raise ConnectionError("SERVICE_ACCOUNT_NOT_VERIFIED")
                break
            except ConnectionError:
                if attempt == 6:
                    raise
                time.sleep(5)
        existing_policy = runCloud(["projects", "get-iam-policy", args.project, "--format=json", *scope], human_env)
        for binding in existing_policy.get("bindings", []):
            if "serviceAccount:" + account in binding.get("members", []):
                raise ConnectionError("UNEXPECTED_ROLE_BINDING_PRESERVE_AND_REVIEW")
        policy = provision("viewer", ["projects", "add-iam-policy-binding", args.project, "--member=serviceAccount:" + account, "--role=roles/viewer", "--condition=None", "--format=json"])
        roles = []
        for binding in policy.get("bindings", []):
            if "serviceAccount:" + account in binding.get("members", []):
                roles.append(binding.get("role"))
                if binding.get("condition"):
                    raise ConnectionError("UNEXPECTED_ROLE_BINDING_PRESERVE_AND_REVIEW")
        if roles != ["roles/viewer"]:
            raise ConnectionError("UNEXPECTED_ROLE_BINDING_PRESERVE_AND_REVIEW")
        key_path = directory / "key.json"
        if os.path.lexists(key_path):
            raise ConnectionError("EXISTING_KEY_PRESERVE_AND_REVIEW")
        provision("key", ["iam", "service-accounts", "keys", "create", str(key_path), "--iam-account=" + account], False)
        keyIdentity(key_path, account, args.project)
        cli_directory = directory / "cli"
        cli_directory.mkdir(mode=0o700)
        activateKey(directory, environment, account, args.project)
        privateWrite(directory / "connection.json", json.dumps({"account": account, "project": args.project, "role": "roles/viewer"}))
        for attempt in range(7):
            try:
                verify(directory, environment)
                break
            except ConnectionError:
                if attempt == 6:
                    raise
                time.sleep(5)
        writeEnvironment(directory, account, args.project)
    finally:
        if originalContext(environment) != original:
            raise ConnectionError("ORIGINAL_CONFIGURATION_CHANGED_PRESERVE_AND_REVIEW")
    print("CONNECTED_VIEWER; original configuration unchanged; billing not linked")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="~/.config/gcloud-connector")
    commands = parser.add_subparsers(dest="command", required=True)
    new_project = commands.add_parser("new-project")
    new_project.add_argument("--account", required=True)
    new_project.add_argument("--project", required=True)
    new_project.add_argument("--name", default="Claude workshop test")
    commands.add_parser("check")
    commands.add_parser("finish")
    args = parser.parse_args()
    try:
        if args.command == "new-project":
            setup(args, dict(os.environ))
        elif args.command == "finish":
            finish(args, dict(os.environ))
        else:
            original = originalContext(dict(os.environ))
            if original["override_present"]:
                raise ConnectionError("AUTH_OR_ENDPOINT_OVERRIDE_PRESENT_REVIEW_WITHOUT_CHANGES")
            directory = Path(args.directory).expanduser().absolute()
            if not (directory / "credentials.env").is_file():
                raise ConnectionError("MISSING_OR_PARTIAL_CONNECTOR_USE_SETUP_REVIEW")
            verify(directory, dict(os.environ))
            print("CONNECTED_EXACT_SAVED_ACCOUNT_AND_PROJECT")
    except ConnectionError as error:
        print(str(error))
        return 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print("SETUP_STOPPED_PRESERVE_PRIVATE_STATE_AND_REVIEW")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
