import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SKILL = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('wordpress_connector', SKILL / 'scripts' / 'connect.py')
connector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(connector)
PASSWORD = 'A1b2' * 6


class PrivateSetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output_dir = self.root / 'output'
        self.output_dir.mkdir(mode=0o700)
        self.directory = self.root / 'connector'
        self.output = io.StringIO()
        self.capture = contextlib.redirect_stdout(self.output)
        self.capture.__enter__()
        self.addCleanup(self.capture.__exit__, None, None, None)
        connector.prepare(self.directory, 'http://localhost:8099', self.output_dir)
        self.state = connector.stateFile(self.directory)
        self.probe = connector.artifactPath(self.state, 'probe')
        self.artifact = connector.artifactPath(self.state, 'password')
        self.payload = {'profile_url':'http://localhost:8099/wp-admin/profile.php', 'username':'synthetic-admin', 'password':PASSWORD}
        self.config = self.root / '.claude.json'
        self.other = {'type':'stdio','command':'/usr/bin/false','args':[], 'env':{'SYNTHETIC_SECRET':'unrelated-secret'}}
        self.config.write_text(json.dumps({'mcpServers':{'other':self.other}, 'preference':'preserve'}))

    def acceptCredentials(self):
        self.probe.write_text(json.dumps({'probe':True}))
        connector.acceptProbe(self.directory, self.probe)
        self.artifact.write_text(json.dumps(self.payload))
        connector.acceptCapture(self.directory, self.artifact)

    def installFixture(self):
        self.acceptCredentials()
        bridge = self.directory / 'runtime' / 'node_modules' / '@automattic' / 'mcp-wordpress-remote'
        (bridge / 'dist').mkdir(parents=True)
        (bridge / 'package.json').write_text(json.dumps({'name':connector.PACKAGE, 'version':connector.VERSION}))
        (bridge / 'dist' / 'proxy.js').write_text('synthetic fixture only')

    def fakeRegistration(self, command, **options):
        self.registration_command = command
        data = json.loads(self.config.read_text())
        name = command[command.index('--scope') + 2]
        separator = command.index('--')
        data['mcpServers'][name] = {'type':'stdio','command':command[separator + 1], 'args':command[separator + 2:], 'env':{}}
        self.config.write_text(json.dumps(data))
        return subprocess.CompletedProcess(command, 0, PASSWORD, '')

    def testPrepareCreatesPrivateEmptyUniqueArtifacts(self):
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        for path in (self.probe, self.artifact, self.directory / 'capture.json'):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.probe.stat().st_size, 0)
        self.assertEqual(self.artifact.stat().st_size, 0)
        self.assertRegex(self.state['server_name'], '^wordpress-[a-f0-9]{12}$')
        self.assertNotIn(PASSWORD, self.output.getvalue())

    def testPublicProbeAndCredentialAcceptanceUseActualTrackedFiles(self):
        self.payload['password'] = ' '.join(['A1b2'] * 6)
        self.acceptCredentials()
        self.assertFalse(self.probe.exists())
        self.assertFalse(self.artifact.exists())
        _, saved = connector.credentials(self.directory)
        self.assertEqual(saved['WP_API_PASSWORD'], PASSWORD)
        self.assertEqual(saved['WP_API_URL'], 'http://localhost:8099/wp-json/mcp/mcp-adapter-default-server')
        self.assertEqual((self.directory / 'credentials.json').stat().st_mode & 0o777, 0o600)
        self.assertNotIn(PASSWORD, self.output.getvalue())
        self.assertNotIn('synthetic-admin', self.output.getvalue())

    def testCaptureRequiresProbeBeforeSavingCredential(self):
        self.artifact.write_text(json.dumps(self.payload))
        with self.assertRaises(OSError):
            connector.acceptCapture(self.directory, self.artifact)
        self.assertFalse((self.directory / 'credentials.json').exists())
        self.assertTrue(self.artifact.exists())

    def testUnexpectedOutputPathCannotBeReadDeletedOrAdopted(self):
        unrelated = self.root / self.artifact.name
        unrelated.write_text(json.dumps(self.payload))
        unrelated.chmod(0o600)
        with self.assertRaisesRegex(connector.SetupError, 'REPORTED_ARTIFACT_DIFFERS'):
            connector.artifactPayload(self.state, 'password', unrelated)
        self.assertTrue(unrelated.exists())
        self.assertTrue(self.artifact.exists())

    def testSymlinkHardlinkAndOpenPermissionsFailClosed(self):
        target = self.root / 'unrelated'
        target.write_text('preserve')
        target.chmod(0o600)
        self.artifact.unlink()
        self.artifact.symlink_to(target)
        with self.assertRaisesRegex(connector.SetupError, 'PRIVATE_REGULAR'):
            connector.artifactPayload(self.state, 'password', self.artifact)
        self.artifact.unlink()
        os.link(target, self.artifact)
        with self.assertRaisesRegex(connector.SetupError, 'PRIVATE_REGULAR'):
            connector.artifactPayload(self.state, 'password', self.artifact)
        self.artifact.unlink()
        self.artifact.write_text('{}')
        self.artifact.chmod(0o644)
        with self.assertRaisesRegex(connector.SetupError, 'PRIVATE_REGULAR'):
            connector.artifactPayload(self.state, 'password', self.artifact)
        self.assertEqual(target.read_text(), 'preserve')

    def testSchemaRejectsWrongSiteUsernamePasswordAndExtraFields(self):
        changes = [('profile_url', 'https://other.invalid/wp-admin/profile.php'), ('profile_url','http://localhost:8099/wp-admin/profile.php?other=1'), ('username','bad:username'), ('password','x' * 23), ('password',123), ('unexpected','value')]
        for key, value in changes:
            with self.subTest(key=key, value=value):
                payload = dict(self.payload, **{key:value})
                with self.assertRaises(connector.SetupError):
                    connector.credentialPayload(self.state, payload)

    def testHttpsAndExactLoopbackBoundary(self):
        for value in ('https://example.invalid/blog', 'http://localhost:8099', 'http://127.0.0.1:8099', 'http://[::1]:8099'):
            self.assertEqual(connector.siteUrl(value), value)
        for value in ('http://example.invalid', 'http://192.168.1.1', 'http://localtest.me', 'http://localhost.example.invalid', 'https://user:pass@example.invalid', 'https://example.invalid?token=secret'):
            with self.subTest(value=value):
                with self.assertRaises(connector.SetupError):
                    connector.siteUrl(value)

    def testExistingStateAndCredentialsAreNeverOverwritten(self):
        self.acceptCredentials()
        path = self.directory / 'credentials.json'
        before = path.read_bytes()
        with self.assertRaisesRegex(connector.SetupError, 'EXISTING_STATE'):
            connector.prepare(self.directory, 'https://other.invalid', self.output_dir)
        connector.createFile(self.artifact, json.dumps(dict(self.payload, password='B' * 24)))
        with self.assertRaisesRegex(connector.SetupError, 'EXISTING_CREDENTIALS_DIFFER'):
            connector.acceptCapture(self.directory, self.artifact)
        self.assertEqual(path.read_bytes(), before)
        self.assertTrue(self.artifact.exists())

    def testRegistrationPreservesEntriesAndAvoidsSecretArgv(self):
        self.installFixture()
        with patch.object(connector.Path, 'home', return_value=self.root), patch.object(connector.subprocess, 'run', side_effect=self.fakeRegistration) as invoke:
            connector.register(self.directory, Path(sys.executable), {})
            connector.register(self.directory, Path(sys.executable), {})
        self.assertEqual(invoke.call_count, 1)
        data = json.loads(self.config.read_text())
        self.assertEqual(data['mcpServers']['other'], self.other)
        self.assertEqual(data['preference'], 'preserve')
        self.assertEqual(data['mcpServers'][self.state['server_name']], connector.registrationEntry(self.directory))
        self.assertNotIn(PASSWORD, json.dumps(self.registration_command))
        self.assertNotIn(PASSWORD, self.config.read_text())
        self.assertNotIn('--env', self.registration_command)
        self.assertNotIn(PASSWORD, self.output.getvalue())

    def testExistingServerConflictIsNotReplaced(self):
        self.installFixture()
        data = json.loads(self.config.read_text())
        data['mcpServers'][self.state['server_name']] = self.other
        self.config.write_text(json.dumps(data))
        before = self.config.read_bytes()
        with patch.object(connector.Path, 'home', return_value=self.root), patch.object(connector.subprocess, 'run') as invoke:
            with self.assertRaisesRegex(connector.SetupError, 'EXISTING_SERVER_DIFFERS'):
                connector.register(self.directory, Path(sys.executable), {})
        invoke.assert_not_called()
        self.assertEqual(self.config.read_bytes(), before)

    def testUnexpectedOtherEntryChangeStopsWithoutGlobalRestore(self):
        self.installFixture()
        def changedConfig(command, **options):
            result = self.fakeRegistration(command, **options)
            data = json.loads(self.config.read_text())
            data['mcpServers']['other']['args'] = ['concurrent-change']
            self.config.write_text(json.dumps(data))
            return result
        with patch.object(connector.Path, 'home', return_value=self.root), patch.object(connector.subprocess, 'run', side_effect=changedConfig):
            with self.assertRaisesRegex(connector.SetupError, 'OTHER_REGISTRATION_CHANGED'):
                connector.register(self.directory, Path(sys.executable), {})
        self.assertEqual(json.loads(self.config.read_text())['mcpServers']['other']['args'], ['concurrent-change'])

    def testRegistrationErrorPreservesPrivateCredentialAndConfig(self):
        self.installFixture()
        before = self.config.read_bytes()
        failure = subprocess.CompletedProcess([], 1, PASSWORD, PASSWORD)
        with patch.object(connector.Path, 'home', return_value=self.root), patch.object(connector.subprocess, 'run', return_value=failure):
            with self.assertRaisesRegex(connector.SetupError, 'REGISTRATION_FAILED'):
                connector.register(self.directory, Path(sys.executable), {})
        self.assertTrue((self.directory / 'credentials.json').exists())
        self.assertEqual(self.config.read_bytes(), before)
        self.assertNotIn(PASSWORD, self.output.getvalue())

    def testPinnedPackageMismatchCannotRegister(self):
        self.installFixture()
        metadata = self.directory / 'runtime/node_modules/@automattic/mcp-wordpress-remote/package.json'
        metadata.write_text(json.dumps({'name':connector.PACKAGE, 'version':'99.0.0'}))
        with patch.object(connector.subprocess, 'run') as invoke:
            with self.assertRaisesRegex(connector.SetupError, 'PINNED_BRIDGE'):
                connector.register(self.directory, Path(sys.executable), {})
        invoke.assert_not_called()

    def testChildEnvLoadsPrivateCredentialsWithoutMutatingParentOrArgv(self):
        self.installFixture()
        with patch.object(connector.Path, 'home', return_value=self.root), patch.object(connector.subprocess, 'run', side_effect=self.fakeRegistration):
            connector.register(self.directory, Path(sys.executable), {})
        parent = {'PATH':'/synthetic/bin', 'JWT_TOKEN':'other', 'CUSTOM_HEADERS':'other', 'OAUTH_ENABLED':'true', 'WP_API_URL':'https://other.invalid', 'NODE_TLS_REJECT_UNAUTHORIZED':'0', 'NODE_OPTIONS':'--inspect'}
        original = dict(parent)
        command, child = connector.launchCommand(self.directory, parent)
        self.assertEqual(parent, original)
        self.assertEqual(child['WP_API_PASSWORD'], PASSWORD)
        self.assertEqual(child['OAUTH_ENABLED'], 'false')
        self.assertNotIn(PASSWORD, json.dumps(command))
        for name in ('JWT_TOKEN','CUSTOM_HEADERS','NODE_OPTIONS','NODE_TLS_REJECT_UNAUTHORIZED'):
            self.assertNotIn(name, child)

    @unittest.skipUnless(shutil.which('node'), 'Node unavailable for offline DOM fixture')
    def testRealCaptureFunctionReadsInputRemovesNoticeAndNeverClicksTwice(self):
        fixture = Path(__file__).parent / 'capture-fixture.cjs'
        result = subprocess.run([shutil.which('node'), str(fixture), str(self.directory / 'capture-function.js')], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, 'Offline DOM fixture failed; output withheld')
        self.assertEqual(json.loads(result.stdout), {'clicks':1, 'removed':True, 'input_value_captured':True, 'same_capture_reused':True})
        self.assertNotIn(PASSWORD, result.stdout)


class InstalledCliFixture(unittest.TestCase):
    @unittest.skipUnless(shutil.which('claude'), 'Installed Claude CLI unavailable for isolated registration fixture')
    def testActualCliShapeAndOtherEntriesInTemporaryConfig(self):
        with tempfile.TemporaryDirectory(prefix='wordpress-registration-fixture-') as temporary:
            directory = Path(temporary)
            config = directory / '.claude.json'
            other = {'type':'stdio','command':'/usr/bin/false','args':[], 'env':{'SYNTHETIC_SETTING':'preserve'}}
            config.write_text(json.dumps({'mcpServers':{'unrelated-fixture':other}, 'syntheticPreference':'preserve'}))
            config.chmod(0o600)
            environment = dict(os.environ, CLAUDE_CONFIG_DIR=str(directory))
            command = [shutil.which('claude'),'mcp','add','--transport','stdio','--scope','user','wordpress-fixture','--','/usr/bin/false','synthetic-argument']
            result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, 'Isolated CLI registration failed; output withheld')
            data = json.loads(config.read_text())
            self.assertEqual(data['mcpServers']['wordpress-fixture'], {'type':'stdio','command':'/usr/bin/false','args':['synthetic-argument'],'env':{}})
            self.assertEqual(data['mcpServers']['unrelated-fixture'], other)
            self.assertEqual(data['syntheticPreference'], 'preserve')


if __name__ == '__main__':
    unittest.main()
