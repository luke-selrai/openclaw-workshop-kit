import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("aws_connector", Path(__file__).resolve().parents[1] / "scripts" / "connect.py")
connector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(connector)
ACCOUNT = "123456789012"
HUMAN = "arn:aws:iam::" + ACCOUNT + ":user/qa-human"
KEY_ID = "AKIA" + "A" * 16
SECRET = "S" * 40


class FakeAws:
    def __init__(self, environment):
        self.environment = environment
        self.calls = []
        self.user = None
        self.policies = []
        self.keys = []
        self.groups = []
        self.inline = []
        self.failures = {}
        self.runtime_auth_failures = 0
        self.identity_override = None
        self.human_override = None
        self.tag_override = None

    def invoke(self, command, **options):
        environment = options["env"]
        self.calls.append((command, dict(environment), dict(options)))
        operation = tuple(command[1:3])
        runtime = environment["AWS_CONFIG_FILE"] != self.environment["AWS_CONFIG_FILE"]
        failure = self.failures.get(operation)
        if failure == "timeout":
            raise subprocess.TimeoutExpired(command, 120, output=SECRET)
        if failure:
            return subprocess.CompletedProcess(command, 1, "", failure + " " + SECRET)
        if runtime and self.runtime_auth_failures:
            self.runtime_auth_failures -= 1
            return subprocess.CompletedProcess(command, 1, "", "InvalidClientTokenId " + SECRET)
        arn = "arn:aws:iam::" + ACCOUNT + ":user/" + str(self.user)
        if operation == ("sts", "get-caller-identity"):
            if runtime:
                identity = self.identity_override or arn
            else:
                identity = self.human_override or HUMAN
            result = {"Arn": identity, "Account": ACCOUNT}
        elif operation == ("iam", "create-user"):
            self.user = command[command.index("--user-name") + 1]
            result = {"User": {"Arn": "arn:aws:iam::" + ACCOUNT + ":user/" + self.user}}
        elif operation == ("iam", "attach-user-policy"):
            self.policies.append(command[command.index("--policy-arn") + 1])
            result = {}
        elif operation == ("iam", "create-access-key"):
            self.keys.append({"UserName": self.user, "AccessKeyId": KEY_ID, "Status": "Active"})
            result = {"AccessKey": dict(self.keys[0], SecretAccessKey=SECRET)}
        elif operation == ("iam", "get-user"):
            result = {"User": {"Arn": arn, "UserName": self.user, "Tags": [{"Key": "claude-connector", "Value": self.tag_override or self.user}]}}
        elif operation == ("iam", "list-attached-user-policies"):
            result = {"AttachedPolicies": [{"PolicyArn": value} for value in self.policies]}
        elif operation == ("iam", "list-user-policies"):
            result = {"PolicyNames": self.inline}
        elif operation == ("iam", "list-groups-for-user"):
            result = {"Groups": self.groups}
        elif operation == ("iam", "list-access-keys"):
            result = {"AccessKeyMetadata": self.keys}
        elif operation == ("ec2", "describe-instances"):
            result = {"Reservations": []}
        else:
            raise AssertionError("Unexpected fixture operation: " + str(operation))
        return subprocess.CompletedProcess(command, 0, json.dumps(result), "")

    def mutations(self):
        return [tuple(command[1:3]) for command, _, _ in self.calls if command[2] in ("create-user", "attach-user-policy", "create-access-key")]


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / "original-config"
        self.credentials = self.root / "original-credentials"
        self.config.write_text("[profile human]\nregion = us-east-1\n")
        self.credentials.write_text("[human]\naws_access_key_id = synthetic-existing\naws_secret_access_key = synthetic-existing-secret\n")
        self.environment = {"PATH": "/synthetic/bin", "AWS_PROFILE": "keep-original", "AWS_CONFIG_FILE": str(self.config), "AWS_SHARED_CREDENTIALS_FILE": str(self.credentials)}
        self.baseline = connector.originalFiles(self.environment)
        self.directory = self.root / "connector"
        self.args = argparse.Namespace(directory=str(self.directory), profile="human", expected_arn=HUMAN, region="ap-southeast-2")
        self.aws = FakeAws(self.environment)
        self.process = patch.object(connector.subprocess, "run", side_effect=self.aws.invoke)
        self.process.start()
        self.addCleanup(self.process.stop)
        self.sleep = patch.object(connector.time, "sleep")
        self.sleep.start()
        self.addCleanup(self.sleep.stop)
        self.output = io.StringIO()
        self.capture = contextlib.redirect_stdout(self.output)
        self.capture.__enter__()
        self.addCleanup(self.capture.__exit__, None, None, None)

    def setupConnector(self):
        connector.setup(self.args, self.environment)

    def assertPreserved(self):
        self.assertEqual(connector.originalFiles(self.environment), self.baseline)
        self.assertNotIn(SECRET, self.output.getvalue())
        self.assertNotIn(KEY_ID, self.output.getvalue())

    def testFreshIdentityOneKeyReadAndPrivateArtifacts(self):
        self.setupConnector()
        self.assertEqual(self.aws.mutations(), [("iam", "create-user"), ("iam", "attach-user-policy"), ("iam", "create-access-key")])
        self.assertTrue((self.directory / "connection.json").exists())
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        for path in self.directory.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        for command, environment, options in self.aws.calls:
            self.assertEqual(environment["AWS_MAX_ATTEMPTS"], "1")
            self.assertEqual(options["umask"], 0o077)
            expected_profile = "human" if environment["AWS_CONFIG_FILE"] == str(self.config) else "default"
            self.assertEqual(command[command.index("--profile") + 1], expected_profile)
            self.assertNotIn("AWS_PROFILE", environment)
        self.assertIn(("iam", "get-user"), [tuple(call[0][1:3]) for call in self.aws.calls])
        self.assertPreserved()

    def testWrongProvisioningIdentityStopsBeforeStateOrMutation(self):
        self.aws.human_override = "arn:aws:iam::" + ACCOUNT + ":user/unrelated"
        with self.assertRaisesRegex(connector.ConnectionError, "PROVISIONING_IDENTITY_MISMATCH"):
            self.setupConnector()
        self.assertFalse(self.directory.exists())
        self.assertEqual(self.aws.mutations(), [])
        self.assertPreserved()

    def testRootAndNoncommercialArnRefusedWithoutCalls(self):
        for arn in ("arn:aws:iam::" + ACCOUNT + ":root", "arn:aws-us-gov:iam::" + ACCOUNT + ":user/qa"):
            with self.subTest(arn=arn):
                self.args.expected_arn = arn
                with self.assertRaisesRegex(connector.ConnectionError, "EXPLICIT_NONROOT"):
                    self.setupConnector()
        self.assertEqual(self.aws.calls, [])

    def testExistingDirectoryAndSymlinkAreNotOverwritten(self):
        self.directory.mkdir()
        marker = self.directory / "unrelated"
        marker.write_text("preserve")
        with self.assertRaisesRegex(connector.ConnectionError, "EXISTING_STATE"):
            self.setupConnector()
        self.assertEqual(marker.read_text(), "preserve")
        self.args.directory = str(self.root / "linked")
        Path(self.args.directory).symlink_to(self.directory)
        with self.assertRaisesRegex(connector.ConnectionError, "EXISTING_STATE"):
            self.setupConnector()
        self.assertEqual(self.aws.calls, [])

    def testCustomDirectoryCannotCreateDefaultAwsFiles(self):
        self.args.directory = str(self.root / ".aws")
        with patch.object(connector.Path, "home", return_value=self.root):
            with self.assertRaisesRegex(connector.ConnectionError, "DEFAULT_AWS_DIRECTORY"):
                self.setupConnector()
        self.assertFalse((self.root / ".aws").exists())
        self.assertEqual(self.aws.calls, [])

    def testAuthAndEndpointOverridesRefusedBeforeCalls(self):
        for key in ("AWS_ACCESS_KEY_ID", "AWS_SESSION_TOKEN", "AWS_ENDPOINT_URL", "AWS_ENDPOINT_URL_IAM", "AWS_WEB_IDENTITY_TOKEN_FILE"):
            with self.subTest(key=key):
                environment = dict(self.environment, **{key: "synthetic"})
                with self.assertRaisesRegex(connector.ConnectionError, "OVERRIDE_REQUIRES_REVIEW"):
                    connector.setup(self.args, environment)
        self.assertEqual(self.aws.calls, [])

    def testConfigEndpointAndCliHistoryCannotCaptureKey(self):
        for setting in ("endpoint_url = https://example.invalid", "services = local", "cli_history = enabled"):
            with self.subTest(setting=setting):
                self.config.write_text("[profile human]\n" + setting + "\n")
                with self.assertRaisesRegex(connector.ConnectionError, "REQUIRES_REVIEW"):
                    self.setupConnector()
        self.assertEqual(self.aws.calls, [])
        self.assertFalse(self.directory.exists())

    def testNameCollisionNeverAdoptsOrMutatesExistingUser(self):
        self.aws.failures[("iam", "create-user")] = "EntityAlreadyExists"
        with self.assertRaisesRegex(connector.ConnectionError, "ENTITYALREADYEXISTS"):
            self.setupConnector()
        self.assertEqual(self.aws.mutations(), [("iam", "create-user")])
        self.assertTrue((self.directory / "user.started").exists())
        self.assertFalse((self.directory / "user.complete").exists())
        self.assertPreserved()

    def testAttachDenialDoesNotCreateKeyOrRetryMutation(self):
        self.aws.failures[("iam", "attach-user-policy")] = "AccessDenied"
        with self.assertRaisesRegex(connector.ConnectionError, "ACCESSDENIED"):
            self.setupConnector()
        self.assertEqual(self.aws.mutations(), [("iam", "create-user"), ("iam", "attach-user-policy")])
        self.assertTrue((self.directory / "user.complete").exists())
        self.assertFalse((self.directory / "policy.complete").exists())
        self.assertPreserved()

    def testKeyTimeoutNeverRetriesAndKeepsUncertainMarker(self):
        self.aws.failures[("iam", "create-access-key")] = "timeout"
        with self.assertRaisesRegex(connector.ConnectionError, "TIMEOUT_PRESERVE_STATE"):
            self.setupConnector()
        self.assertEqual(self.aws.mutations().count(("iam", "create-access-key")), 1)
        self.assertTrue((self.directory / "key.started").exists())
        self.assertFalse((self.directory / "key.complete").exists())
        with self.assertRaisesRegex(connector.ConnectionError, "EXISTING_STATE"):
            self.setupConnector()
        self.assertPreserved()

    def testKeyLimitNeverDeletesOrRotates(self):
        self.aws.failures[("iam", "create-access-key")] = "LimitExceeded"
        with self.assertRaisesRegex(connector.ConnectionError, "LIMITEXCEEDED"):
            self.setupConnector()
        self.assertEqual(self.aws.mutations().count(("iam", "create-access-key")), 1)
        self.assertFalse((self.directory / "key.json").exists())
        self.assertPreserved()

    def testPropagationRetriesReadsOnlyWithSameKey(self):
        self.aws.runtime_auth_failures = 2
        self.setupConnector()
        self.assertEqual(len(self.aws.mutations()), 3)
        self.assertEqual(self.aws.mutations().count(("iam", "create-access-key")), 1)
        self.assertEqual(connector.time.sleep.call_count, 2)
        self.assertPreserved()

    def testPersistentReadFailureCanFinishWithoutNewKey(self):
        self.aws.runtime_auth_failures = 4
        with self.assertRaisesRegex(connector.ConnectionError, "INVALIDCLIENTTOKENID"):
            self.setupConnector()
        self.assertTrue((self.directory / "key.json").exists())
        self.assertFalse((self.directory / "connection.json").exists())
        before = len(self.aws.mutations())
        connector.finish(self.directory, self.environment, True)
        self.assertEqual(len(self.aws.mutations()), before)
        self.assertTrue((self.directory / "connection.json").exists())
        self.assertPreserved()

    def testFinishOnlyCreatesMissingLocalFilesAndPreservesExisting(self):
        self.setupConnector()
        credentials = self.directory / "credentials"
        original_stat = credentials.stat()
        original_value = credentials.read_bytes()
        (self.directory / "config").unlink()
        (self.directory / "connection.json").unlink()
        self.aws.calls.clear()
        connector.finish(self.directory, self.environment, True)
        self.assertEqual(credentials.read_bytes(), original_value)
        self.assertEqual(credentials.stat().st_mtime_ns, original_stat.st_mtime_ns)
        self.assertEqual(self.aws.mutations(), [])
        self.assertPreserved()

    def testFinishDoesNotRepairUnexpectedRuntimeContents(self):
        self.setupConnector()
        path = self.directory / "credentials"
        path.write_text("preserve unexpected data")
        self.aws.calls.clear()
        with self.assertRaisesRegex(connector.ConnectionError, "RUNTIME_FILES_DIFFER"):
            connector.finish(self.directory, self.environment, True)
        self.assertEqual(path.read_text(), "preserve unexpected data")
        self.assertEqual(self.aws.calls, [])

    def testFinishRequiresPrivateFilesAndBothStageMarkers(self):
        self.setupConnector()
        marker = self.directory / "key.started"
        marker.unlink()
        self.aws.calls.clear()
        with self.assertRaises(OSError):
            connector.finish(self.directory, self.environment, True)
        self.assertEqual(self.aws.calls, [])
        connector.privateWrite(marker, "started")
        (self.directory / "key.json").chmod(0o644)
        with self.assertRaisesRegex(connector.ConnectionError, "PRIVATE_STATE"):
            connector.finish(self.directory, self.environment, True)
        self.assertEqual(self.aws.calls, [])

    def testWrongIdentityOwnershipScopeAndExtraKeyFailReadProof(self):
        self.setupConnector()
        changes = [("identity_override", HUMAN, "EXACT_CONNECTOR"), ("tag_override", "unrelated", "OWNERSHIP"), ("policies", ["arn:aws:iam::aws:policy/AdministratorAccess"], "READ_ONLY"), ("groups", [{"GroupName": "admins"}], "ADDITIONAL"), ("inline", ["custom"], "ADDITIONAL"), ("keys", self.aws.keys * 2, "SINGLE_ACTIVE_KEY")]
        for attribute, value, error in changes:
            with self.subTest(attribute=attribute):
                previous = getattr(self.aws, attribute)
                setattr(self.aws, attribute, value)
                with self.assertRaisesRegex(connector.ConnectionError, error):
                    connector.finish(self.directory, self.environment, False)
                setattr(self.aws, attribute, previous)
        self.assertEqual(len(self.aws.mutations()), 3)
        self.assertPreserved()

    def testOriginalConfigChangeStopsBeforeReadAndIsNotReverted(self):
        self.setupConnector()
        self.config.write_text("[profile changed-by-user]\nregion = eu-west-1\n")
        self.aws.calls.clear()
        with self.assertRaisesRegex(connector.ConnectionError, "ORIGINAL_CONFIGURATION_CHANGED"):
            connector.finish(self.directory, self.environment, True)
        self.assertEqual(self.aws.calls, [])
        self.assertIn("changed-by-user", self.config.read_text())

    def callRuntime(self, command, environment=None):
        if environment is None:
            environment = self.environment
        arguments = ["connect.py", "--directory", str(self.directory), command]
        if command == "run":
            arguments.extend(["--", "ec2", "describe-instances"])
        with patch.object(connector.os, "environ", environment), patch("sys.argv", arguments):
            return connector.main()

    def testRuntimeAllowsUnrelatedProfileAddition(self):
        self.setupConnector()
        original = (self.directory / "original.json").read_bytes()
        self.config.write_text(self.config.read_text() + "[profile unrelated]\nregion = eu-west-1\n")
        current = connector.originalFiles(self.environment)
        self.aws.calls.clear()
        for command in ("check", "run"):
            with self.subTest(command=command):
                self.assertEqual(self.callRuntime(command), 0)
        self.assertEqual(connector.originalFiles(self.environment), current)
        self.assertEqual((self.directory / "original.json").read_bytes(), original)
        self.assertEqual(self.aws.mutations(), [])
        for _, environment, _ in self.aws.calls:
            self.assertEqual(environment["AWS_CONFIG_FILE"], str(self.directory / "config"))

    def testRuntimeAllowsHumanCredentialRotation(self):
        self.setupConnector()
        self.credentials.write_text("[human]\naws_access_key_id = rotated-human\naws_secret_access_key = rotated-private-human\n")
        current = connector.originalFiles(self.environment)
        for command in ("check", "run"):
            with self.subTest(command=command):
                self.assertEqual(self.callRuntime(command), 0)
        self.assertEqual(connector.originalFiles(self.environment), current)
        self.assertNotIn("rotated-private-human", self.output.getvalue())

    def testRuntimeAllowsChangedPersonalProfileSelectors(self):
        self.setupConnector()
        for name in ("AWS_PROFILE", "AWS_DEFAULT_PROFILE"):
            environment = dict(self.environment, **{name: "unrelated-profile"})
            current = connector.originalFiles(environment)
            for command in ("check", "run"):
                with self.subTest(selector=name, command=command):
                    self.assertEqual(self.callRuntime(command, environment), 0)
            self.assertEqual(connector.originalFiles(environment), current)
            self.assertEqual(environment[name], "unrelated-profile")

    def testRuntimeDetectsPersonalConfigChangeDuringOperationWithoutReverting(self):
        self.setupConnector()
        invoke = self.aws.invoke
        def changedDuringRead(command, **options):
            result = invoke(command, **options)
            if command[1:3] == ["ec2", "describe-instances"]:
                self.config.write_text("[profile concurrent-change]\nregion = eu-west-1\n")
            return result
        with patch.object(connector.subprocess, "run", side_effect=changedDuringRead):
            self.assertEqual(self.callRuntime("run"), 1)
        self.assertIn("CURRENT_CONFIGURATION_CHANGED_PRESERVE_STATE", self.output.getvalue())
        self.assertIn("concurrent-change", self.config.read_text())

    def testRuntimeRejectsTamperedConnectorEvenAfterPersonalProfileChange(self):
        self.setupConnector()
        self.config.write_text("[profile unrelated]\nregion = eu-west-1\n")
        runtime_config = self.directory / "config"
        runtime_config.write_text(runtime_config.read_text() + "endpoint_url = https://example.invalid\n")
        self.aws.calls.clear()
        for command in ("check", "run"):
            with self.subTest(command=command):
                self.assertEqual(self.callRuntime(command), 1)
        self.assertIn("SAVED_RUNTIME_FILES_DIFFER_PRESERVE_STATE", self.output.getvalue())
        self.assertEqual(self.aws.calls, [])
        self.assertIn("example.invalid", runtime_config.read_text())

    def testRuntimeClearsInheritedOverridesAndUsesOwnedFiles(self):
        self.setupConnector()
        environment = dict(self.environment, AWS_ACCESS_KEY_ID="other", AWS_SECRET_ACCESS_KEY="other", AWS_ENDPOINT_URL="https://example.invalid", AWS_ROLE_ARN=HUMAN)
        self.aws.calls.clear()
        connector.finish(self.directory, environment, False)
        for _, child, _ in self.aws.calls:
            self.assertEqual(child["AWS_CONFIG_FILE"], str(self.directory / "config"))
            self.assertEqual(child["AWS_SHARED_CREDENTIALS_FILE"], str(self.directory / "credentials"))
            for name in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_ENDPOINT_URL", "AWS_ROLE_ARN", "AWS_PROFILE"):
                self.assertNotIn(name, child)

    def testRunRejectsCredentialCommandsAndGlobalOverridesIncludingAbbreviations(self):
        cases = [["configure", "export-credentials"], ["sts", "get-session-token"], ["sso", "get-role-credentials"]]
        for flag in ("--profile=other", "--prof", "--endpoint-url=https://example.invalid", "--endp", "--no-sign", "--no-verify", "--ca-b", "--debug", "--deb"):
            cases.append(["iam", "get-user", flag])
        for arguments in cases:
            with self.subTest(arguments=arguments):
                with self.assertRaises(connector.ConnectionError):
                    connector.operationArguments(arguments)
        self.assertEqual(connector.operationArguments(["--", "iam", "get-user", "--user-name", "owned"]), ["iam", "get-user", "--user-name", "owned"])
        self.assertEqual(self.aws.calls, [])

    def testSavedKeyFromOtherUserCannotBeReused(self):
        self.setupConnector()
        key_path = self.directory / "key.json"
        data = json.loads(key_path.read_text())
        data["AccessKey"]["UserName"] = "unrelated-user"
        key_path.write_text(json.dumps(data))
        self.aws.calls.clear()
        with self.assertRaisesRegex(connector.ConnectionError, "SAVED_KEY_NOT_VERIFIED"):
            connector.finish(self.directory, self.environment, True)
        self.assertEqual(self.aws.calls, [])

    def testRuntimeSymlinkIsNotReadOrOverwritten(self):
        self.setupConnector()
        target = self.root / "unrelated-private-file"
        target.write_text("preserve unrelated")
        target.chmod(0o600)
        runtime = self.directory / "credentials"
        runtime.unlink()
        runtime.symlink_to(target)
        self.aws.calls.clear()
        with self.assertRaisesRegex(connector.ConnectionError, "PRIVATE_STATE"):
            connector.finish(self.directory, self.environment, True)
        self.assertEqual(target.read_text(), "preserve unrelated")
        self.assertTrue(runtime.is_symlink())
        self.assertEqual(self.aws.calls, [])

    def testCheckCannotWriteMissingRuntimeFiles(self):
        self.setupConnector()
        runtime = self.directory / "config"
        runtime.unlink()
        self.aws.calls.clear()
        with self.assertRaisesRegex(connector.ConnectionError, "PARTIAL_SETUP_USE_FINISH"):
            connector.finish(self.directory, self.environment, False)
        self.assertFalse(runtime.exists())
        self.assertEqual(self.aws.calls, [])

    def testOperationRegionHasOneEffectiveValueAndPreservesSavedConfig(self):
        self.setupConnector()
        saved = (self.directory / "config").read_bytes()
        for flags in (["--region", "us-east-1"], ["--region=us-east-1"]):
            with self.subTest(flags=flags):
                self.aws.calls.clear()
                arguments = ["connect.py", "--directory", str(self.directory), "run", "--", "ec2", "describe-instances", *flags]
                with patch.object(connector.os, "environ", self.environment), patch("sys.argv", arguments):
                    self.assertEqual(connector.main(), 0)
                for command, _, _ in self.aws.calls[:-1]:
                    self.assertEqual(command[command.index("--region") + 1], "ap-southeast-2")
                command = self.aws.calls[-1][0]
                self.assertEqual(command[1:3], ["ec2", "describe-instances"])
                self.assertEqual(command.count("--region"), 1)
                self.assertNotIn("--region=us-east-1", command)
                self.assertEqual(command[command.index("--region") + 1], "us-east-1")
                self.assertEqual((self.directory / "config").read_bytes(), saved)
        self.assertPreserved()

    def testInvalidOrDuplicateOperationRegionStopsBeforeAwsCommand(self):
        cases = [["--region"], ["--region="], ["--region", "--profile"], ["--region=us-east-1", "--region", "eu-west-1"]]
        for flags in cases:
            with self.subTest(flags=flags):
                with self.assertRaises(connector.ConnectionError):
                    connector.cloud(["ec2", "describe-instances", *flags], {}, "default", "ap-southeast-2")
        self.assertEqual(self.aws.calls, [])

    def testRegionAbbreviationsFailExplicitly(self):
        for flag in ("--reg", "--regi=us-east-1"):
            with self.subTest(flag=flag):
                with self.assertRaisesRegex(connector.ConnectionError, "USE_FULL_REGION_OPTION"):
                    connector.operationArguments(["ec2", "describe-instances", flag])
        self.assertEqual(self.aws.calls, [])

    def testMainSanitizesFailureWithoutSecretEcho(self):
        self.aws.failures[("iam", "create-access-key")] = "AccessDenied"
        arguments = ["connect.py", "--directory", str(self.directory), "setup", "--profile", "human", "--expected-arn", HUMAN]
        with patch.object(connector.os, "environ", self.environment), patch("sys.argv", arguments):
            self.assertEqual(connector.main(), 1)
        self.assertIn("AWS_ACCESSDENIED_PRESERVE_STATE", self.output.getvalue())
        self.assertPreserved()


if __name__ == "__main__":
    unittest.main()
