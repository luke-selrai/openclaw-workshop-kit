import argparse
import datetime
import json
import os
from pathlib import Path
import secrets
import shlex
import stat
import subprocess
import urllib.error
import urllib.parse
import urllib.request


class BootstrapError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        fp.close()
        raise BootstrapError("REDIRECT_REQUIRES_REVIEW")


def localUrl(value):
    parsed = urllib.parse.urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1")
            or parsed.username or parsed.password or parsed.path not in ("", "/")
            or parsed.query or parsed.fragment or not parsed.port):
        raise BootstrapError("EXPLICIT_LOCAL_URL_REQUIRED")
    return value.rstrip("/")


def composeRead(compose_dir, arguments):
    result = subprocess.run(
        ["docker", "compose", *arguments], cwd=compose_dir,
        capture_output=True, text=True, timeout=45,
    )
    if result.returncode:
        raise BootstrapError("LOCAL_PREFLIGHT_FAILED")
    return result.stdout.strip()


def preflight(compose_dir, url):
    port = urllib.parse.urlsplit(url).port
    binding = composeRead(compose_dir, ["port", "server", "3000"])
    if binding != f"127.0.0.1:{port}":
        raise BootstrapError("LOCAL_BINDING_NOT_VERIFIED")
    probe = r'''
const {Client} = require('pg');
const {TWENTY_CURRENT_VERSION:version} = require('./dist/engine/core-modules/upgrade/constants/twenty-current-version.constant.js');
const client = new Client({connectionString:process.env.PG_DATABASE_URL});
(async () => {
  await client.connect();
  await client.query('BEGIN READ ONLY');
  const result = await client.query('SELECT (SELECT count(*) FROM core."user")::int AS users, (SELECT count(*) FROM core.workspace)::int AS workspaces, (SELECT count(*) FROM core."apiKey")::int AS keys');
  await client.query('ROLLBACK');
  await client.end();
  process.stdout.write(JSON.stringify({version, urlMatches:(process.env.SERVER_URL || '').replace(/\/$/, '') === process.argv[1], ...result.rows[0]}));
})().catch(() => { process.exitCode = 1; });
'''
    result = json.loads(composeRead(compose_dir, ["exec", "-T", "server", "node", "-e", probe, url]))
    if result.get("version") != "2.38.0" or result.get("urlMatches") is not True:
        raise BootstrapError("LOCAL_VERSION_OR_URL_NOT_VERIFIED")
    for field in ("users", "workspaces", "keys"):
        if type(result.get(field)) is not int or result[field] != 0:
            raise BootstrapError("EXISTING_INSTANCE_USE_RESUME_ROUTE")


class Client:
    def __init__(self, url):
        self.url = localUrl(url)
        self.token = None
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(self, path, payload=None):
        headers = {"Origin": self.url}
        body = None
        if payload is not None:
            body = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        request = urllib.request.Request(self.url + path, data=body, headers=headers)
        try:
            with self.opener.open(request, timeout=120) as response:
                if response.status != 200:
                    raise BootstrapError("HTTP_REQUEST_FAILED")
                data = json.load(response)
        except urllib.error.HTTPError as error:
            error.close()
            raise BootstrapError("HTTP_REQUEST_FAILED") from None
        except (urllib.error.URLError, ValueError):
            raise BootstrapError("HTTP_REQUEST_FAILED") from None
        if not isinstance(data, dict):
            raise BootstrapError("SERVER_REJECTED_REQUEST_USE_NORMAL_ONBOARDING")
        if data.get("errors"):
            codes = []
            for error in data["errors"]:
                if not isinstance(error, dict):
                    continue
                extensions = error.get("extensions")
                if not isinstance(extensions, dict):
                    continue
                code = extensions.get("code")
                if code in ("INVALID_INPUT", "BAD_USER_INPUT", "FORBIDDEN", "FORBIDDEN_EXCEPTION", "UNAUTHENTICATED", "GRAPHQL_VALIDATION_FAILED", "SIGNUP_DISABLED", "USER_ALREADY_EXISTS", "INTERNAL_SERVER_ERROR") and code not in codes:
                    codes.append(code)
            raise BootstrapError("SERVER_REJECTED_REQUEST: " + (",".join(codes) or "UNCLASSIFIED"))
        return data

    def mutation(self, query, variables, field):
        try:
            data = self.request("/metadata", {"query": query, "variables": variables})
        except BootstrapError as error:
            raise BootstrapError(str(error) + "; operation=" + field) from None
        result = data.get("data", {}).get(field)
        if not isinstance(result, dict) or not result:
            raise BootstrapError("UNEXPECTED_SERVER_RESPONSE")
        return result


def required(data, field):
    value = data.get(field)
    if not isinstance(value, str) or not value:
        raise BootstrapError("UNEXPECTED_SERVER_RESPONSE")
    return value


def privateWrite(path, contents):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(contents)
        output.flush()
        os.fsync(output.fileno())


def rejectedOwner(state_dir, url, email):
    directory_stat = state_dir.lstat()
    if (not stat.S_ISDIR(directory_stat.st_mode)
            or stat.S_IMODE(directory_stat.st_mode) != 0o700
            or directory_stat.st_uid != os.getuid()
            or sorted(path.name for path in state_dir.iterdir()) != ["owner.json"]):
        raise BootstrapError("REJECTED_SIGNUP_STATE_NOT_VERIFIED")
    owner_path = state_dir / "owner.json"
    owner_stat = owner_path.lstat()
    if (not stat.S_ISREG(owner_stat.st_mode)
            or stat.S_IMODE(owner_stat.st_mode) != 0o600
            or owner_stat.st_uid != os.getuid()):
        raise BootstrapError("REJECTED_SIGNUP_STATE_NOT_VERIFIED")
    with owner_path.open() as source:
        owner = json.load(source)
    password = owner.get("password")
    if (owner.get("url") != url or owner.get("email") != email
            or not isinstance(password, str) or len(password) != 52
            or not password.endswith("aA1!")
            or any(character not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-" for character in password[:48])):
        raise BootstrapError("REJECTED_SIGNUP_OWNER_NOT_VERIFIED")
    return password[:48]


def bootstrap(args):
    url = localUrl(args.url)
    state_dir = Path(args.state_dir).expanduser()
    env_file = Path(args.env_file).expanduser()
    if os.path.lexists(env_file):
        raise BootstrapError("EXISTING_CREDENTIALS_USE_RESUME_ROUTE")
    password = None
    if args.resume_rejected_signup:
        password = rejectedOwner(state_dir, url, args.email)
    elif os.path.lexists(state_dir):
        raise BootstrapError("EXISTING_CREDENTIALS_USE_RESUME_ROUTE")
    preflight(args.compose_dir, url)
    client = Client(url)
    config = client.request("/client-config")
    if config.get("isMultiWorkspaceEnabled") is not False:
        raise BootstrapError("UNSUPPORTED_LOCAL_CONFIGURATION")
    if (config.get("isEmailVerificationRequired") is not False
            or config.get("captcha", {}).get("provider")
            or config.get("authProviders", {}).get("password") is not True
            or config.get("billing", {}).get("isBillingEnabled") is not False):
        raise BootstrapError("COMPLETE_NORMAL_VERIFICATION_OR_SIGNUP")
    if args.resume_rejected_signup:
        privateWrite(state_dir / "owner-retry.json", json.dumps({"url": url, "email": args.email, "password": password}))
    else:
        state_dir.parent.mkdir(parents=True, exist_ok=True)
        state_dir.mkdir(mode=0o700)
        password = secrets.token_urlsafe(32) + "aA1!"
        privateWrite(state_dir / "owner.json", json.dumps({"url": url, "email": args.email, "password": password}))
    sign_up = client.mutation(
        "mutation($email:String!,$password:String!){signUp(email:$email,password:$password){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
        {"email": args.email, "password": password}, "signUp",
    )
    client.token = required(sign_up["tokens"]["accessOrWorkspaceAgnosticToken"], "token")
    workspace = client.mutation(
        "mutation($input:SignUpInNewWorkspaceInput){signUpInNewWorkspace(input:$input){workspace{id} loginToken{token}}}",
        {"input": {"displayName": args.workspace}}, "signUpInNewWorkspace",
    )
    privateWrite(state_dir / "workspace.json", json.dumps({"id": required(workspace["workspace"], "id")}))
    auth = client.mutation(
        "mutation($loginToken:String!,$origin:String!){getAuthTokensFromLoginToken(loginToken:$loginToken,origin:$origin){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
        {"loginToken": required(workspace["loginToken"], "token"), "origin": url}, "getAuthTokensFromLoginToken",
    )
    client.token = required(auth["tokens"]["accessOrWorkspaceAgnosticToken"], "token")
    client.mutation("mutation($input:ActivateWorkspaceInput!){activateWorkspace(data:$input){id}}", {"input": {}}, "activateWorkspace")
    role_input = {
        "label": "Claude connector read only",
        "canReadAllObjectRecords": True,
        "canUpdateAllObjectRecords": False,
        "canSoftDeleteAllObjectRecords": False,
        "canDestroyAllObjectRecords": False,
        "canUpdateAllSettings": False,
        "canAccessAllTools": False,
        "canBeAssignedToUsers": False,
        "canBeAssignedToAgents": False,
        "canBeAssignedToApiKeys": True,
    }
    role = client.mutation(
        "mutation($input:CreateRoleInput!){createOneRole(createRoleInput:$input){id}}",
        {"input": role_input}, "createOneRole",
    )
    expires_at = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30)).isoformat()
    key = client.mutation(
        "mutation($input:CreateApiKeyInput!){createApiKey(input:$input){id}}",
        {"input": {"name": "Claude local connector", "expiresAt": expires_at, "roleId": required(role, "id")}}, "createApiKey",
    )
    key_id = required(key, "id")
    privateWrite(state_dir / "key.json", json.dumps({"id": key_id, "role_id": role["id"], "expires_at": expires_at}))
    token = client.mutation(
        "mutation($apiKeyId:UUID!,$expiresAt:String!){generateApiKeyToken(apiKeyId:$apiKeyId,expiresAt:$expiresAt){token}}",
        {"apiKeyId": key_id, "expiresAt": expires_at}, "generateApiKeyToken",
    )
    client.token = required(token, "token")
    privateWrite(state_dir / "api-key.json", json.dumps({"token": client.token}))
    client.request("/rest/companies?limit=1")
    client.request("/rest/people?limit=1")
    env_file.parent.mkdir(parents=True, exist_ok=True)
    privateWrite(env_file, "TWENTY_BACKEND_URL=" + shlex.quote(url) + "\nTWENTY_API_KEY=" + shlex.quote(client.token) + "\nTWENTY_DEPLOY_TARGET=self-host\nTWENTY_DEPLOY_BACKEND_HOST=local\n")
    print("CONNECTED_READ_ONLY; credentials saved privately; key expires in 30 days")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--compose-dir", required=True)
    parser.add_argument("--email", required=True)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--state-dir", default="~/.claude/twenty-local-owner")
    parser.add_argument("--env-file", default="~/.claude/twenty-connector.env")
    parser.add_argument("--resume-rejected-signup", action="store_true")
    args = parser.parse_args()
    try:
        bootstrap(args)
    except BootstrapError as error:
        print(str(error))
        return 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print("BOOTSTRAP_STOPPED; preserve private state and use normal onboarding to resume")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
