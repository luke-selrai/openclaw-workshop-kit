import argparse
import contextlib
import http.server
import importlib.util
import io
import json
from pathlib import Path
import re
import stat
import tempfile
import threading
import unittest
from unittest.mock import patch


script = Path(__file__).resolve().parents[1] / "scripts" / "bootstrap_local.py"
spec = importlib.util.spec_from_file_location("bootstrap_local", script)
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class FixtureHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self, payload, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())

    def do_GET(self):
        self.server.calls.append((self.path, None, self.headers.get("Authorization")))
        if self.path == "/client-config":
            if self.server.redirect:
                self.send_response(302)
                self.send_header("Location", self.server.url + "/unexpected")
                self.end_headers()
                return
            self.respond(self.server.config)
        elif self.headers.get("Authorization") != "Bearer fixture-key-private":
            self.respond({}, 401)
        elif self.server.read_failure:
            self.respond({"error": "fixture-key-private"}, 403)
        else:
            self.respond({"data": {"objects": [], "companies": []}})

    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.server.calls.append((self.path, payload, self.headers.get("Authorization")))
        query = payload["query"]
        responses = {
            "signUp": {"tokens": {"accessOrWorkspaceAgnosticToken": {"token": "fixture-owner-private"}}},
            "signUpInNewWorkspace": {"workspace": {"id": "workspace-id"}, "loginToken": {"token": "fixture-login-private"}},
            "getAuthTokensFromLoginToken": {"tokens": {"accessOrWorkspaceAgnosticToken": {"token": "fixture-workspace-private"}}},
            "activateWorkspace": {"id": "workspace-id"},
            "createOneRole": {"id": "role-id"},
            "createApiKey": {"id": "key-id"},
            "generateApiKeyToken": {"token": "fixture-key-private"},
        }
        for name, response in responses.items():
            if "{" + name + "(" in query:
                if name == "signUp" and not re.fullmatch(r".{8,50}", payload["variables"]["password"]):
                    self.respond({"errors": [{"message": "Password too weak", "extensions": {"code": "INVALID_INPUT"}, "path": ["signUp"]}]})
                    return
                if name == self.server.reject:
                    self.respond({"errors": [{"message": "verification required fixture-owner-private"}]})
                else:
                    self.respond({"data": {name: response}})
                return
        self.respond({"errors": [{"message": "unknown operation"}]})


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
        self.server.url = "http://127.0.0.1:" + str(self.server.server_port)
        self.server.calls = []
        self.server.reject = None
        self.server.redirect = False
        self.server.read_failure = False
        self.server.config = {
            "isMultiWorkspaceEnabled": False,
            "isEmailVerificationRequired": False,
            "captcha": {"provider": None},
            "authProviders": {"password": True},
            "billing": {"isBillingEnabled": False},
        }
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.args = argparse.Namespace(
            url=self.server.url, compose_dir=self.directory,
            state_dir=self.directory / "state", env_file=self.directory / "twenty.env",
            email="owner@example.test", workspace="Local fixture",
            resume_rejected_signup=False,
        )

    def tearDown(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()
        self.temp.cleanup()

    def runBootstrap(self):
        output = io.StringIO()
        with patch.object(bootstrap, "preflight"), contextlib.redirect_stdout(output):
            bootstrap.bootstrap(self.args)
        return output.getvalue()

    def testNormalFlowStoresPrivateReadOnlyConnection(self):
        output = self.runBootstrap()
        self.assertIn("CONNECTED_READ_ONLY", output)
        owner = json.loads((self.args.state_dir / "owner.json").read_text())
        self.assertEqual(owner["email"], self.args.email)
        self.assertGreater(len(owner["password"]), 40)
        self.assertLessEqual(len(owner["password"]), 50)
        self.assertNotIn(owner["password"], output)
        self.assertNotIn("fixture-", output)
        self.assertEqual(stat.S_IMODE(self.args.state_dir.stat().st_mode), 0o700)
        for file in self.args.state_dir.iterdir():
            self.assertEqual(stat.S_IMODE(file.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.args.env_file.stat().st_mode), 0o600)
        self.assertIn("fixture-key-private", self.args.env_file.read_text())
        mutations = []
        for path, payload, authorization in self.server.calls:
            if payload:
                mutations.append((payload, authorization))
        self.assertEqual(len(mutations), 7)
        self.assertIsNone(mutations[0][1])
        self.assertEqual(mutations[1][1], "Bearer fixture-owner-private")
        self.assertEqual(mutations[3][1], "Bearer fixture-workspace-private")
        role = mutations[4][0]["variables"]["input"]
        self.assertTrue(role.pop("canReadAllObjectRecords"))
        self.assertTrue(role.pop("canBeAssignedToApiKeys"))
        role.pop("label")
        self.assertTrue(all(value is False for value in role.values()))
        key_input = mutations[5][0]["variables"]["input"]
        self.assertEqual(key_input["roleId"], "role-id")
        self.assertEqual(mutations[6][0]["variables"]["expiresAt"], key_input["expiresAt"])
        self.assertEqual(self.server.calls[-2][0], "/rest/companies?limit=1")
        self.assertEqual(self.server.calls[-1][0], "/rest/people?limit=1")

    def testVerificationAndBillingGuardsPrecedeSignup(self):
        cases = [
            ("isEmailVerificationRequired", True),
            ("isEmailVerificationRequired", None),
            ("captcha", {"provider": "TURNSTILE"}),
            ("authProviders", {"password": False}),
            ("billing", {"isBillingEnabled": True}),
            ("isMultiWorkspaceEnabled", True),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                original = self.server.config[field]
                self.server.config[field] = value
                with self.assertRaises(bootstrap.BootstrapError):
                    self.runBootstrap()
                self.assertFalse(self.args.state_dir.exists())
                self.server.config[field] = original
        self.assertTrue(all(call[1] is None for call in self.server.calls))

    def testExistingStateOrEnvIsNeverReplaced(self):
        for target in (self.args.env_file, self.args.state_dir):
            with self.subTest(target=target):
                target.write_text("retained-secret")
                with self.assertRaisesRegex(bootstrap.BootstrapError, "EXISTING_CREDENTIALS"):
                    self.runBootstrap()
                self.assertEqual(target.read_text(), "retained-secret")
                target.unlink()
        self.assertEqual(self.server.calls, [])

    def testDanglingSymlinkIsNotFollowed(self):
        self.args.env_file.symlink_to(self.directory / "missing")
        with self.assertRaisesRegex(bootstrap.BootstrapError, "EXISTING_CREDENTIALS"):
            self.runBootstrap()
        self.assertEqual(self.server.calls, [])

    def testGraphqlRejectionStopsWithoutEchoOrRetry(self):
        self.server.reject = "signUpInNewWorkspace"
        with self.assertRaises(bootstrap.BootstrapError) as caught:
            self.runBootstrap()
        self.assertNotIn("fixture-", str(caught.exception))
        self.assertTrue((self.args.state_dir / "owner.json").exists())
        self.assertFalse(self.args.env_file.exists())
        self.assertEqual(len(self.server.calls), 3)
        with self.assertRaisesRegex(bootstrap.BootstrapError, "EXISTING_CREDENTIALS"):
            self.runBootstrap()
        self.assertEqual(len(self.server.calls), 3)

    def testReadFailureRetainsKeyButDoesNotClaimConnection(self):
        self.server.read_failure = True
        with self.assertRaises(bootstrap.BootstrapError):
            self.runBootstrap()
        self.assertTrue((self.args.state_dir / "api-key.json").exists())
        self.assertFalse(self.args.env_file.exists())

    def savedRejectedOwner(self):
        self.args.state_dir.mkdir(mode=0o700)
        owner = {"url": self.args.url, "email": self.args.email, "password": "A" * 48 + "aA1!"}
        bootstrap.privateWrite(self.args.state_dir / "owner.json", json.dumps(owner))
        self.args.resume_rejected_signup = True
        return owner

    def testResumeRepairsOnlyKnownRejectedPasswordAndPreservesOriginal(self):
        original = self.savedRejectedOwner()
        before = (self.args.state_dir / "owner.json").read_bytes()
        output = self.runBootstrap()
        self.assertIn("CONNECTED_READ_ONLY", output)
        self.assertEqual((self.args.state_dir / "owner.json").read_bytes(), before)
        retry = json.loads((self.args.state_dir / "owner-retry.json").read_text())
        self.assertEqual(retry["password"], original["password"][:48])
        self.assertEqual(self.server.calls[1][1]["variables"]["password"], retry["password"])
        self.assertEqual(stat.S_IMODE((self.args.state_dir / "owner-retry.json").stat().st_mode), 0o600)
        self.assertNotIn(retry["password"], output)

    def testResumeRequiresCurrentAuthoritativeEmptyPreflight(self):
        self.savedRejectedOwner()
        with patch.object(bootstrap, "preflight", side_effect=bootstrap.BootstrapError("EXISTING_INSTANCE_USE_RESUME_ROUTE")):
            with self.assertRaisesRegex(bootstrap.BootstrapError, "EXISTING_INSTANCE"):
                bootstrap.bootstrap(self.args)
        self.assertEqual(self.server.calls, [])
        self.assertEqual(list(self.args.state_dir.iterdir()), [self.args.state_dir / "owner.json"])

    def testResumeRejectsPartialStateAndNeverOverwritesRetry(self):
        self.savedRejectedOwner()
        for name in ("workspace.json", "api-key.json", "owner-retry.json", "unexpected.txt"):
            target = self.args.state_dir / name
            bootstrap.privateWrite(target, "preserved-fixture")
            with self.subTest(name=name), self.assertRaisesRegex(bootstrap.BootstrapError, "STATE_NOT_VERIFIED"):
                self.runBootstrap()
            self.assertEqual(target.read_text(), "preserved-fixture")
            target.unlink()
        self.assertEqual(self.server.calls, [])

    def testResumeRejectsDifferentOwnerUrlAndPasswordShape(self):
        original = self.savedRejectedOwner()
        for field, value in (("email", "different@example.test"), ("url", "http://localhost:4000"), ("password", "A" * 48), ("password", "A" * 52)):
            changed = dict(original)
            changed[field] = value
            (self.args.state_dir / "owner.json").write_text(json.dumps(changed))
            with self.subTest(field=field, value=value), self.assertRaisesRegex(bootstrap.BootstrapError, "OWNER_NOT_VERIFIED"):
                self.runBootstrap()
        self.assertEqual(self.server.calls, [])

    def testResumeRejectionCannotBeRetriedAutomatically(self):
        self.savedRejectedOwner()
        self.server.reject = "signUp"
        with self.assertRaisesRegex(bootstrap.BootstrapError, "operation=signUp"):
            self.runBootstrap()
        call_count = len(self.server.calls)
        with self.assertRaisesRegex(bootstrap.BootstrapError, "STATE_NOT_VERIFIED"):
            self.runBootstrap()
        self.assertEqual(len(self.server.calls), call_count)

    def testDeployedPasswordLimitAndSanitizedRejection(self):
        client = bootstrap.Client(self.args.url)
        with self.assertRaisesRegex(bootstrap.BootstrapError, "INVALID_INPUT; operation=signUp") as caught:
            client.mutation("mutation($email:String!,$password:String!){signUp(email:$email,password:$password){tokens{accessOrWorkspaceAgnosticToken{token}}}}", {"email": self.args.email, "password": "A" * 48 + "aA1!"}, "signUp")
        self.assertNotIn("Password too weak", str(caught.exception))
        self.assertNotIn("A" * 48, str(caught.exception))

    def testRedirectIsNotFollowed(self):
        self.server.redirect = True
        with self.assertRaisesRegex(bootstrap.BootstrapError, "REDIRECT"):
            self.runBootstrap()
        self.assertEqual(len(self.server.calls), 1)
        self.assertFalse(self.args.state_dir.exists())

    def testRemoteAmbiguousAndCredentialUrlsAreRejected(self):
        for url in ("https://crm.example.test", "http://0.0.0.0:3000", "http://localhost", "http://localhost:3000/a", "http://user:secret@localhost:3000", "http://localhost:3000?next=a"):
            with self.subTest(url=url), self.assertRaises(bootstrap.BootstrapError):
                bootstrap.localUrl(url)

    def testPreflightRequiresEmptyMatchingVersionAndUrl(self):
        valid = {"version": "2.38.0", "urlMatches": True, "users": 0, "workspaces": 0, "keys": 0}
        cases = [(None, None), ("version", "2.39.0"), ("urlMatches", False), ("users", 1), ("workspaces", 1), ("keys", 1), ("users", None)]
        for field, value in cases:
            result = dict(valid)
            if field:
                result[field] = value
            with self.subTest(field=field), patch.object(bootstrap, "composeRead", side_effect=["127.0.0.1:3000", json.dumps(result)]):
                if field:
                    with self.assertRaises(bootstrap.BootstrapError):
                        bootstrap.preflight(self.directory, "http://localhost:3000")
                else:
                    bootstrap.preflight(self.directory, "http://localhost:3000")

    def testPreflightRejectsExposedOrAdditionalBindings(self):
        for binding in ("0.0.0.0:3000", "[::]:3000", "127.0.0.1:3000\n0.0.0.0:3000", "127.0.0.1:4000"):
            with self.subTest(binding=binding), patch.object(bootstrap, "composeRead", return_value=binding) as read:
                with self.assertRaisesRegex(bootstrap.BootstrapError, "BINDING"):
                    bootstrap.preflight(self.directory, "http://localhost:3000")
                self.assertEqual(read.call_count, 1)


if __name__ == "__main__":
    unittest.main()
