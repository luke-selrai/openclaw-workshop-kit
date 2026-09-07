import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


script = Path(__file__).resolve().parents[1] / "scripts" / "connect.py"
fake_source = r'''
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
root = Path(os.environ['FIXTURE_ROOT'])
config = Path(os.environ.get('CLOUDSDK_CONFIG', str(root / 'original')))
with (root / 'calls.jsonl').open('a') as output:
    output.write(json.dumps({'args':args, 'config':str(config), 'account_override':os.environ.get('CLOUDSDK_CORE_ACCOUNT'), 'project_override':os.environ.get('CLOUDSDK_CORE_PROJECT')}) + '\n')
project = 'workshop-fixture-123'
account = 'claude-assistant@' + project + '.iam.gserviceaccount.com'
def flag(name):
    for value in args:
        if value.startswith(name + '='):
            return value.split('=',1)[1]
    return None
def emit(value):
    print(json.dumps(value))
if args[:2] == ['config','list']:
    if config == root / 'original':
        emit({'core':{'account':'human@example.test','project':'original-project'}})
    else:
        values = json.loads((config / 'configurations' / 'config_default').read_text())
        emit({'core':{'account':values['account'],'project':values['project']},'auth':values.get('auth',{}),'api_endpoint_overrides':values.get('api_endpoint_overrides',{})})
elif args[:1] == ['info']:
    print(config)
elif args[:3] == ['config','configurations','list']:
    print('default')
elif args[:2] == ['auth','list']:
    emit([{'account':'human@example.test','status':'ACTIVE'},{'account':'personal-assistant@original-project.iam.gserviceaccount.com','status':''}])
elif args[:2] == ['projects','create']:
    if os.environ.get('FIXTURE_PROJECT_FAILURE'):
        print('PERMISSION_DENIED fixture-private-project-error', file=sys.stderr)
        raise SystemExit(1)
    if os.environ.get('FIXTURE_CHANGE_ORIGINAL'):
        (root / 'original' / 'active_config').write_text('unexpected-change')
    print('created')
elif args[:2] == ['services','enable']:
    print('enabled')
elif args[:3] == ['iam','service-accounts','create']:
    print('created')
elif args[:3] == ['iam','service-accounts','describe']:
    emit({'email':account})
elif args[:2] == ['projects','get-iam-policy']:
    bindings = []
    if os.environ.get('FIXTURE_ROLES'):
        bindings = [{'role':'roles/owner','members':['serviceAccount:' + account]}]
    emit({'bindings':bindings})
elif args[:2] == ['projects','add-iam-policy-binding']:
    emit({'bindings':[{'role':'roles/viewer','members':['serviceAccount:' + account]}]})
elif args[:4] == ['iam','service-accounts','keys','create']:
    key = Path(args[4])
    key.write_text('')
    key.chmod(0o600)
    if os.environ.get('FIXTURE_KEY_FAILURE'):
        print(os.environ.get('FIXTURE_ERROR_TEXT','fixture-private-error-and-key'),file=sys.stderr)
        raise SystemExit(1)
    key_account = account
    if os.environ.get('FIXTURE_BAD_KEY'):
        key_account = 'personal-assistant@original-project.iam.gserviceaccount.com'
    key.write_text(json.dumps({'type':'service_account','client_email':key_account,'project_id':project,'private_key':'fixture-private-key','private_key_id':'fixture-key-id'}))
    print('fixture-private-key',file=sys.stderr)
elif args[:2] == ['auth','activate-service-account']:
    (config / 'configurations').mkdir()
    (config / 'configurations' / 'config_default').write_text(json.dumps({'account':args[2],'project':flag('--project')}))
    (config / 'credentials.db').write_text('fixture-private-credential')
    print('activated')
elif args[:2] == ['config','get-value']:
    values = json.loads((config / 'configurations' / 'config_default').read_text())
    print(values[args[2]])
elif args[:2] == ['projects','describe']:
    emit({'projectId':project,'name':'Fixture'})
else:
    raise SystemExit(9)
'''


class ConnectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.original = self.root / "original"
        (self.original / "configurations").mkdir(parents=True)
        (self.original / "active_config").write_text("default")
        (self.original / "configurations" / "config_default").write_text("original bytes")
        (self.original / "application_default_credentials.json").write_text("fixture-ADC-private")
        self.before = {}
        for path in self.original.rglob("*"):
            if path.is_file():
                self.before[path] = path.read_bytes()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        executable = self.bin / "gcloud"
        executable.write_text("#!" + sys.executable + "\n" + fake_source)
        executable.chmod(0o700)
        self.directory = self.root / "connector"
        self.environment = dict(os.environ)
        for name in list(self.environment):
            if name.startswith("CLOUDSDK_"):
                del self.environment[name]
        self.environment.update({"PATH":str(self.bin) + os.pathsep + self.environment["PATH"], "FIXTURE_ROOT":str(self.root), "CLOUDSDK_CONFIG":str(self.original)})

    def tearDown(self):
        self.temp.cleanup()

    def invoke(self, command="new-project"):
        arguments = [sys.executable, str(script), "--directory", str(self.directory), command]
        if command == "new-project":
            arguments.extend(["--account", "human@example.test", "--project", "workshop-fixture-123"])
        result = subprocess.run(arguments, env=self.environment, capture_output=True, text=True, timeout=20)
        self.assertNotIn("fixture-private", result.stdout + result.stderr)
        self.assertNotIn("fixture-ADC", result.stdout + result.stderr)
        return result

    def calls(self):
        path = self.root / "calls.jsonl"
        if not path.exists():
            return []
        result = []
        for line in path.read_text().splitlines():
            result.append(json.loads(line))
        return result

    def assertOriginalUnchanged(self):
        for path, contents in self.before.items():
            self.assertEqual(path.read_bytes(), contents)
        self.assertFalse((self.original / "credentials.db").exists())

    def testFreshConnectionPreservesConfigurationAndScope(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("CONNECTED_VIEWER", result.stdout)
        self.assertOriginalUnchanged()
        self.assertEqual(stat.S_IMODE(self.directory.stat().st_mode), 0o700)
        for name in ("key.json", "credentials.env", "connection.json", "original.json"):
            self.assertEqual(stat.S_IMODE((self.directory / name).stat().st_mode), 0o600)
        env = (self.directory / "credentials.env").read_text()
        self.assertIn("CLOUDSDK_CONFIG=" + str(self.directory / "cli"), env)
        self.assertIn("GCLOUD_CONNECTOR_ACCOUNT=claude-assistant@workshop-fixture-123.iam.gserviceaccount.com", env)
        for call in self.calls():
            args = call["args"]
            self.assertNotIn("--set-as-default", args)
            self.assertNotIn("billing", args)
            self.assertNotIn("delete", args)
            self.assertNotIn("remove-iam-policy-binding", args)
            self.assertNotEqual(args[:2], ["config", "set"])
            if args[0] in ("projects", "services", "iam") and call["config"] == str(self.original):
                self.assertIn("--account=human@example.test", args)
                self.assertIn("--project=workshop-fixture-123", args)
                self.assertIn("--configuration=default", args)
            if args[:2] == ["auth", "activate-service-account"]:
                self.assertEqual(call["config"], str(self.directory / "cli"))
            if args[:2] == ["config", "get-value"]:
                self.assertIsNone(call["account_override"])
                self.assertIsNone(call["project_override"])
        checked = self.invoke("check")
        self.assertEqual(checked.returncode, 0, checked.stdout)
        self.assertOriginalUnchanged()

    def testUnrelatedSavedKeyNeverPasses(self):
        self.assertEqual(self.invoke().returncode, 0)
        key_path = self.directory / "key.json"
        key = json.loads(key_path.read_text())
        key["client_email"] = "personal-assistant@original-project.iam.gserviceaccount.com"
        key_path.write_text(json.dumps(key))
        result = self.invoke("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EXACT_CONNECTOR_KEY", result.stdout)

    def testUnexpectedCreatedKeyIsNeverActivated(self):
        self.environment["FIXTURE_BAD_KEY"] = "1"
        result = self.invoke()
        self.assertIn("EXACT_CONNECTOR_KEY", result.stdout)
        self.assertFalse((self.directory / "credentials.env").exists())
        for call in self.calls():
            self.assertNotIn("activate-service-account", call["args"])
        self.assertOriginalUnchanged()

    def testOriginalConfigurationChangeIsReportedWithoutRestore(self):
        self.environment["FIXTURE_CHANGE_ORIGINAL"] = "1"
        result = self.invoke()
        self.assertIn("ORIGINAL_CONFIGURATION_CHANGED", result.stdout)
        self.assertNotIn("CONNECTED_VIEWER", result.stdout)
        self.assertEqual((self.original / "active_config").read_text(), "unexpected-change")

    def testMissingOwnershipRecordDoesNotAdoptGlobalAccount(self):
        result = self.invoke("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MISSING_OR_PARTIAL", result.stdout)
        self.assertTrue(all(call["args"][0] in ("config", "info") for call in self.calls()))

    def testActualIsolatedAccountMustMatch(self):
        self.assertEqual(self.invoke().returncode, 0)
        config = self.directory / "cli" / "configurations" / "config_default"
        config.write_text(json.dumps({"account":"other@example.test", "project":"workshop-fixture-123"}))
        result = self.invoke("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EXACT_CONNECTOR_CONFIGURATION", result.stdout)

    def testSavedEnvironmentMustPointToExactOwnedConfiguration(self):
        self.assertEqual(self.invoke().returncode, 0)
        env_file = self.directory / "credentials.env"
        env_file.write_text(env_file.read_text().replace(str(self.directory / "cli"), str(self.original)))
        result = self.invoke("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SAVED_ENVIRONMENT_NOT_VERIFIED", result.stdout)
        self.assertOriginalUnchanged()

    def testIsolatedOverridesStopBeforeAuthenticatedRead(self):
        self.assertEqual(self.invoke().returncode, 0)
        config = self.directory / "cli" / "configurations" / "config_default"
        original = json.loads(config.read_text())
        cases = [
            {"auth": {"credential_file_override": "fixture-private-path"}},
            {"auth": {"access_token_file": "fixture-private-path"}},
            {"auth": {"impersonate_service_account": "other@example.test"}},
            {"auth": {"disable_credentials": True}},
            {"api_endpoint_overrides": {"cloudresourcemanager": "https://fixture-private.invalid"}},
        ]
        for overrides in cases:
            with self.subTest(overrides=overrides):
                altered = dict(original)
                altered.update(overrides)
                config.write_text(json.dumps(altered))
                count = len(self.calls())
                result = self.invoke("check")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("ISOLATED_AUTH_OR_ENDPOINT_OVERRIDE_PRESENT", result.stdout)
                for call in self.calls()[count:]:
                    self.assertNotEqual(call["args"][:2], ["projects", "describe"])
                    self.assertNotIn("activate-service-account", call["args"])
                self.assertEqual(json.loads(config.read_text()), altered)
        config.write_text(json.dumps(original))
        self.assertOriginalUnchanged()

    def testExistingDirectoryAndDanglingSymlinkArePreserved(self):
        self.directory.mkdir()
        (self.directory / "key.json").write_text("retained")
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertEqual((self.directory / "key.json").read_text(), "retained")
        self.assertEqual(self.calls(), [])
        (self.directory / "key.json").unlink()
        self.directory.rmdir()
        self.directory.symlink_to(self.root / "missing")
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertEqual(self.calls(), [])

    def testFailedKeyCreationPreservesAttemptAndRefusesRetry(self):
        self.environment["FIXTURE_KEY_FAILURE"] = "1"
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertTrue((self.directory / "key.started").exists())
        self.assertFalse((self.directory / "key.complete").exists())
        self.assertTrue((self.directory / "key.json").exists())
        self.assertFalse((self.directory / "credentials.env").exists())
        count = len(self.calls())
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertEqual(len(self.calls()), count)
        self.assertNotEqual(self.invoke("check").returncode, 0)
        self.assertOriginalUnchanged()

    def testSafeFailureCategoriesRetainStageWithoutErrorContents(self):
        cases = [
            ("PERMISSION_DENIED organization policy constraints/iam.disableServiceAccountKeyCreation", "ORG_POLICY"),
            ("RESOURCE_EXHAUSTED quota exceeded", "QUOTA"),
            ("PERMISSION_DENIED SERVICE_DISABLED", "SERVICE_DISABLED"),
            ("UNAUTHENTICATED invalid_grant", "AUTHENTICATION"),
            ("PERMISSION_DENIED", "PERMISSION"),
            ("unrecognized failure", "UNCLASSIFIED"),
        ]
        for index, (message, category) in enumerate(cases):
            with self.subTest(category=category):
                self.directory = self.root / ("connector-" + str(index))
                self.environment["FIXTURE_KEY_FAILURE"] = "1"
                self.environment["FIXTURE_ERROR_TEXT"] = message + " fixture-private-secret"
                result = self.invoke()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), "GCLOUD_KEY_CREATE_" + category + "_PRESERVE_AND_REVIEW")
                self.assertEqual(result.stderr, "")
                self.assertTrue((self.directory / "key.started").exists())
                self.assertFalse((self.directory / "key.complete").exists())
        self.assertOriginalUnchanged()

    def testFailureIdentifiesDifferentProvisioningStage(self):
        self.environment["FIXTURE_PROJECT_FAILURE"] = "1"
        result = self.invoke()
        self.assertEqual(result.stdout.strip(), "GCLOUD_PROJECT_CREATE_PERMISSION_PRESERVE_AND_REVIEW")
        self.assertTrue((self.directory / "project.started").exists())
        self.assertFalse((self.directory / "iam-api.started").exists())
        self.assertOriginalUnchanged()

    def testUnexpectedExistingRolesStopBeforeBindingOrKey(self):
        self.environment["FIXTURE_ROLES"] = "1"
        result = self.invoke()
        self.assertIn("UNEXPECTED_ROLE_BINDING", result.stdout)
        for call in self.calls():
            self.assertNotIn("add-iam-policy-binding", call["args"])
            self.assertNotIn("remove-iam-policy-binding", call["args"])
            self.assertNotIn("keys", call["args"])
        self.assertOriginalUnchanged()

    def testAuthenticationOverrideStopsBeforeMutation(self):
        self.environment["CLOUDSDK_AUTH_ACCESS_TOKEN"] = "fixture-private-token"
        result = self.invoke()
        self.assertIn("OVERRIDE_PRESENT", result.stdout)
        self.assertFalse(self.directory.exists())
        self.assertTrue(all(call["args"][0] in ("config", "info") for call in self.calls()))
        self.assertOriginalUnchanged()


if __name__ == "__main__":
    unittest.main()
