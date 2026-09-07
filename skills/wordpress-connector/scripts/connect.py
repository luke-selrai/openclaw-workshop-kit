import argparse
import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import sys
from urllib.parse import urlsplit


VERSION = "0.4.0"
PACKAGE = "@automattic/mcp-wordpress-remote"


class SetupError(Exception):
    pass


def privateDirectory(path):
    details = path.lstat()
    if not stat.S_ISDIR(details.st_mode) or details.st_uid != os.getuid() or details.st_mode & 0o077:
        raise SetupError("PRIVATE_DIRECTORY_REQUIRED")


def privateFile(path):
    details = path.lstat()
    if not stat.S_ISREG(details.st_mode) or details.st_uid != os.getuid() or details.st_nlink != 1 or details.st_mode & 0o077:
        raise SetupError("PRIVATE_REGULAR_FILE_REQUIRED")
    return path.read_text()


def createFile(path, value):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(value)
        output.flush()
        os.fsync(output.fileno())


def siteUrl(value):
    parsed = urlsplit(value)
    if not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or re.search(r"[\s\\]", value):
        raise SetupError("VALID_SITE_URL_REQUIRED")
    if parsed.scheme != "https" and not (parsed.scheme == "http" and parsed.hostname in ("localhost", "127.0.0.1", "::1")):
        raise SetupError("HTTPS_REQUIRED_EXCEPT_EXPLICIT_LOOPBACK_SITE")
    if "/wp-admin" in parsed.path or "/wp-json" in parsed.path or "/wp-login.php" in parsed.path or ".." in parsed.path:
        raise SetupError("SITE_BASE_URL_REQUIRED")
    return value.rstrip("/")


def stateFile(directory):
    privateDirectory(directory)
    state = json.loads(privateFile(directory / "capture.json"))
    if not re.fullmatch(r"wp-capture-[a-f0-9]{24}", state["capture_name"]):
        raise SetupError("CAPTURE_NAME_NOT_VERIFIED")
    siteUrl(state["site"])
    if state["server_name"] != "wordpress-" + state["capture_name"][-12:] or state["application_name"] != "Claude Assistant " + state["capture_name"][-12:]:
        raise SetupError("OWNED_CAPTURE_IDENTITY_NOT_VERIFIED")
    return state


def artifactPath(state, kind):
    return Path(state["output_dir"]) / (state["capture_name"] + "-" + kind + ".json")


def artifactPayload(state, kind, reported):
    expected = artifactPath(state, kind)
    if not reported.is_absolute() or reported != expected or reported.parent.resolve(strict=True) != Path(state["output_dir"]):
        raise SetupError("REPORTED_ARTIFACT_DIFFERS_FILES_PRESERVED")
    privateDirectory(reported.parent)
    text = privateFile(reported)
    if len(text) > 16384:
        raise SetupError("CAPTURE_SCHEMA_NOT_VERIFIED")
    return json.loads(text)


def prepare(directory, site, output_dir):
    site = siteUrl(site)
    if os.path.lexists(directory):
        raise SetupError("EXISTING_STATE_PRESERVED_RESUME_ONLY")
    privateDirectory(output_dir)
    output_dir = output_dir.resolve(strict=True)
    name = "wp-capture-" + secrets.token_hex(12)
    state = {"site": site, "output_dir": str(output_dir), "capture_name": name, "server_name": "wordpress-" + name[-12:], "application_name": "Claude Assistant " + name[-12:]}
    directory.parent.mkdir(parents=True, exist_ok=True)
    directory.mkdir(mode=0o700)
    createFile(directory / "capture.json", json.dumps(state))
    for kind in ("probe", "password"):
        createFile(artifactPath(state, kind), "")
    template = (Path(__file__).parent / "capture.js").read_text()
    function = template.replace("__EXPECTED_PROFILE__", json.dumps(site + "/wp-admin/profile.php")).replace("__APPLICATION_NAME__", json.dumps(state["application_name"]))
    createFile(directory / "capture-function.js", function)
    print(json.dumps({"probe_file": str(artifactPath(state, "probe")), "password_file": str(artifactPath(state, "password")), "function_file": str(directory / "capture-function.js"), "server_name": state["server_name"]}))


def acceptProbe(directory, reported):
    state = stateFile(directory)
    payload = artifactPayload(state, "probe", reported)
    if not isinstance(payload, dict) or set(payload) != {"probe"} or payload["probe"] is not True:
        raise SetupError("PUBLIC_PROBE_NOT_VERIFIED")
    createFile(directory / "probe.complete", "complete")
    reported.unlink()
    print("PRIVATE_CAPTURE_PROBE_VERIFIED")


def credentialPayload(state, payload):
    if not isinstance(payload, dict) or set(payload) != {"profile_url", "username", "password"}:
        raise SetupError("CAPTURE_SCHEMA_NOT_VERIFIED")
    if not all(isinstance(value, str) for value in payload.values()):
        raise SetupError("CAPTURE_SCHEMA_NOT_VERIFIED")
    profile = urlsplit(payload["profile_url"])
    expected = urlsplit(state["site"] + "/wp-admin/profile.php")
    if (profile.scheme, profile.netloc, profile.path) != (expected.scheme, expected.netloc, expected.path) or profile.query or profile.fragment:
        raise SetupError("PROFILE_SITE_NOT_VERIFIED")
    password = re.sub(r"\s", "", payload["password"])
    if not re.fullmatch(r"[a-zA-Z0-9]{24}", password) or not payload["username"] or len(payload["username"]) > 60 or re.search(r"[\x00-\x1f\x7f:]", payload["username"]):
        raise SetupError("CAPTURE_SCHEMA_NOT_VERIFIED")
    return {"WP_API_URL": state["site"] + "/wp-json/mcp/mcp-adapter-default-server", "WP_API_USERNAME": payload["username"], "WP_API_PASSWORD": password}


def acceptCapture(directory, reported):
    state = stateFile(directory)
    if privateFile(directory / "probe.complete") != "complete":
        raise SetupError("PUBLIC_PROBE_REQUIRED")
    credential = credentialPayload(state, artifactPayload(state, "password", reported))
    destination = directory / "credentials.json"
    if os.path.lexists(destination):
        if json.loads(privateFile(destination)) != credential:
            raise SetupError("EXISTING_CREDENTIALS_DIFFER_PRESERVED")
    else:
        createFile(destination, json.dumps(credential))
    reported.unlink()
    print("PRIVATE_CREDENTIALS_SAVED")


def credentials(directory):
    state = stateFile(directory)
    saved = json.loads(privateFile(directory / "credentials.json"))
    if not isinstance(saved, dict) or set(saved) != {"WP_API_URL", "WP_API_USERNAME", "WP_API_PASSWORD"}:
        raise SetupError("SAVED_CREDENTIALS_NOT_VERIFIED")
    expected = credentialPayload(state, {"profile_url": state["site"] + "/wp-admin/profile.php", "username": saved["WP_API_USERNAME"], "password": saved["WP_API_PASSWORD"]})
    if saved != expected:
        raise SetupError("SAVED_CREDENTIALS_NOT_VERIFIED")
    return state, saved


def readConfig(path):
    if path.is_symlink():
        raise SetupError("CLAUDE_CONFIG_SYMLINK_REQUIRES_REVIEW")
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict) or not isinstance(data.get("mcpServers", {}), dict):
        raise SetupError("CLAUDE_CONFIG_SCHEMA_REQUIRES_REVIEW")
    return data


def registrationEntry(directory):
    return {"type": "stdio", "command": sys.executable, "args": [str(Path(__file__).resolve()), "--directory", str(directory), "run"], "env": {}}


def register(directory, node, environment):
    state, _ = credentials(directory)
    if environment.get("CLAUDE_CONFIG_DIR"):
        raise SetupError("CUSTOM_CLAUDE_CONFIG_REQUIRES_REVIEW")
    node = node.resolve(strict=True)
    if not node.is_file() or not os.access(node, os.X_OK):
        raise SetupError("ABSOLUTE_NODE_EXECUTABLE_REQUIRED")
    bridge = directory / "runtime" / "node_modules" / "@automattic" / "mcp-wordpress-remote"
    metadata = json.loads((bridge / "package.json").read_text())
    if metadata.get("name") != PACKAGE or metadata.get("version") != VERSION or not (bridge / "dist" / "proxy.js").is_file():
        raise SetupError("PINNED_BRIDGE_NOT_VERIFIED")
    launch = {"node": str(node), "bridge": str(bridge / "dist" / "proxy.js")}
    launch_path = directory / "launch.json"
    if os.path.lexists(launch_path):
        if json.loads(privateFile(launch_path)) != launch:
            raise SetupError("EXISTING_LAUNCH_DIFFERS_PRESERVED")
    else:
        createFile(launch_path, json.dumps(launch))
    config_path = Path.home() / ".claude.json"
    before = readConfig(config_path).get("mcpServers", {})
    name = state["server_name"]
    expected = registrationEntry(directory)
    if name in before:
        if before[name] != expected:
            raise SetupError("EXISTING_SERVER_DIFFERS_PRESERVED")
    else:
        command = ["claude", "mcp", "add", "--transport", "stdio", "--scope", "user", name, "--", expected["command"], *expected["args"]]
        result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise SetupError("REGISTRATION_FAILED_PRIVATE_STATE_PRESERVED")
    after = readConfig(config_path).get("mcpServers", {})
    for old_name, value in before.items():
        if after.get(old_name) != value:
            raise SetupError("OTHER_REGISTRATION_CHANGED_REVIEW_NO_RESTORE")
    if after.get(name) != expected:
        raise SetupError("REGISTRATION_NOT_VERIFIED")
    print("REGISTERED; caller tool discovery and real WordPress read still required")


def launchCommand(directory, environment):
    _, saved = credentials(directory)
    launch = json.loads(privateFile(directory / "launch.json"))
    bridge = directory / "runtime" / "node_modules" / "@automattic" / "mcp-wordpress-remote" / "dist" / "proxy.js"
    if launch["bridge"] != str(bridge) or not Path(launch["node"]).is_absolute():
        raise SetupError("SAVED_LAUNCH_NOT_VERIFIED")
    child = dict(environment)
    for name in list(child):
        if name.startswith(("WP_", "OAUTH_", "WOO_", "LOG_")) or name in ("JWT_TOKEN", "CUSTOM_HEADERS", "NODE_OPTIONS", "NODE_TLS_REJECT_UNAUTHORIZED"):
            del child[name]
    child.update(saved)
    child.update({"OAUTH_ENABLED": "false", "LOG_LEVEL": "0", "LOG_TO_STDERR": "false", "WP_MCP_CONFIG_DIR": str(directory / "auth")})
    return [launch["node"], launch["bridge"]], child


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="~/.config/wordpress-connector")
    commands = parser.add_subparsers(dest="command", required=True)
    prepare_command = commands.add_parser("prepare")
    prepare_command.add_argument("--site", required=True)
    prepare_command.add_argument("--output-dir", required=True)
    for name in ("accept-probe", "accept-capture"):
        command = commands.add_parser(name)
        command.add_argument("--artifact", required=True)
    register_command = commands.add_parser("register")
    register_command.add_argument("--node", required=True)
    commands.add_parser("check")
    commands.add_parser("run")
    args = parser.parse_args()
    try:
        if os.name != "posix":
            raise SetupError("VERIFIED_PRIVATE_FILE_SUPPORT_REQUIRED")
        directory = Path(args.directory).expanduser().absolute()
        if args.command == "prepare":
            prepare(directory, args.site, Path(args.output_dir))
        elif args.command == "accept-probe":
            acceptProbe(directory, Path(args.artifact))
        elif args.command == "accept-capture":
            acceptCapture(directory, Path(args.artifact))
        elif args.command == "register":
            register(directory, Path(args.node), dict(os.environ))
        elif args.command == "check":
            state, _ = credentials(directory)
            print(json.dumps({"private_credentials_valid": True, "server_name": state["server_name"], "live_connection_proven": False}))
        else:
            command, environment = launchCommand(directory, dict(os.environ))
            log_path = directory / "bridge-stderr.log"
            if not os.path.lexists(log_path):
                createFile(log_path, "")
            privateFile(log_path)
            descriptor = os.open(log_path, os.O_WRONLY | os.O_APPEND | os.O_NOFOLLOW)
            os.dup2(descriptor, 2)
            os.close(descriptor)
            os.umask(0o077)
            os.execve(command[0], command, environment)
    except SetupError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print("WORDPRESS_SETUP_STOPPED_PRIVATE_STATE_PRESERVED", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
