import json
import os
import re
import shlex
import stat
import subprocess
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


repo_path = Path(__file__).resolve().parents[1]
medusa_text = (repo_path / 'skills/medusa-connector/SKILL.md').read_text()
twenty_text = (repo_path / 'skills/twenty-connector/SKILL.md').read_text()
gcloud_text = (repo_path / 'skills/gcloud-connector/SKILL.md').read_text()


def firstBlock(text, heading):
    return text.split(heading, 1)[1].split('```bash\n', 1)[1].split('```', 1)[0]


class BootstrapRepairs(unittest.TestCase):
    def runShell(self, script, fixture_path):
        script = script.replace('$HOME', '$FIXTURE_ROOT')
        env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin')}
        env['FIXTURE_ROOT'] = str(fixture_path)
        env['MEDUSA_PROJECT_NAME'] = 'fixture-store'
        fake_tools = 'openssl() { printf \"FixtureOnly0123456789FixtureOnly0123456789ABCD\\n\"; }; kill() { echo UNEXPECTED_KILL >&2; return 97; };\n'
        return subprocess.run(['/bin/bash', '-c', fake_tools + script], cwd=fixture_path,
                              env=env, capture_output=True, text=True, timeout=15)

    def testCleanMedusaBootstrapAndRestart(self):
        with tempfile.TemporaryDirectory(prefix='connector fixture ') as folder:
            fixture_path = Path(folder)
            backend_path = fixture_path / 'projects/fixture-store/apps/backend'
            backend_path.mkdir(parents=True)
            launch_block = firstBlock(medusa_text, '### Step A.2')
            restart_block = firstBlock(medusa_text, '### Stopping the local dev server later')
            fake_tools = 'npx() { printf "Server is ready\\n"; }; nohup() { "$@"; };\n'
            launch_block = launch_block.replace('/tmp/medusa-dev.log', shlex.quote(str(fixture_path / 'server.log')))
            restart_block = restart_block.replace('/tmp/medusa-dev.log', shlex.quote(str(fixture_path / 'server.log')))
            result = self.runShell(fake_tools + launch_block, fixture_path)
            self.assertEqual(result.returncode, 0, result.stderr)
            state_path = fixture_path / '.claude/state'
            bootstrap_path = state_path / 'medusa-connector-bootstrap.json'
            pid_path = state_path / 'medusa-connector-dev.json'
            bootstrap = json.loads(bootstrap_path.read_text())
            first_pid = json.loads(pid_path.read_text())['dev_pid']
            self.assertGreater(first_pid, 1)
            self.assertEqual(bootstrap['backend_path'], str(backend_path))
            self.assertNotIn(bootstrap['admin_password'], result.stdout + result.stderr)
            self.assertEqual(stat.S_IMODE(state_path.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE(bootstrap_path.stat().st_mode), 0o600)
            result = self.runShell(fake_tools + restart_block, fixture_path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotEqual(json.loads(pid_path.read_text())['dev_pid'], first_pid)
            self.assertEqual(stat.S_IMODE(pid_path.stat().st_mode), 0o600)
            self.assertEqual(json.loads(bootstrap_path.read_text()), bootstrap)

    def testPidValidationRejectsUnsafeRecords(self):
        stop_block = firstBlock(medusa_text, 'To stop it explicitly,')
        for record in ['medusa-pid=42', '{}', '{"dev_pid":0}', '{"dev_pid":-1}',
                       '{"dev_pid":1}', '{"dev_pid":"42"}', '{"dev_pid":2.5}']:
            with self.subTest(record=record), tempfile.TemporaryDirectory() as folder:
                fixture_path = Path(folder)
                state_path = fixture_path / '.claude/state'
                state_path.mkdir(parents=True)
                (state_path / 'medusa-connector-dev.json').write_text(record)
                result = self.runShell('ps() { echo INSPECTED; };\n' + stop_block, fixture_path)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('INSPECTED', result.stdout)

    def testTwentyReplacement(self):
        block = firstBlock(twenty_text, '### Step A.2')
        block = block[block.index('set +x'):]
        for prefix in ['', '#', '# ']:
            with self.subTest(prefix=prefix), tempfile.TemporaryDirectory() as folder:
                fixture_path = Path(folder)
                env_path = fixture_path / '.env'
                env_path.write_text(prefix + 'APP_SECRET=placeholder\n' + prefix +
                                    'PG_DATABASE_PASSWORD=placeholder\nOTHER=preserved\n')
                result = self.runShell(block, fixture_path)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), 'LOCAL_SECRETS_SAVED')
                values = dict(re.findall(r'^(\w+)=(.*)$', env_path.read_text(), re.M))
                self.assertRegex(values['APP_SECRET'], r'^[A-Za-z0-9]{20,40}$')
                self.assertRegex(values['PG_DATABASE_PASSWORD'], r'^[A-Za-z0-9]{20}$')
                self.assertEqual(values['OTHER'], 'preserved')
                self.assertNotIn(values['APP_SECRET'], result.stdout + result.stderr)
                self.assertNotIn(values['PG_DATABASE_PASSWORD'], result.stdout + result.stderr)
                self.assertEqual(stat.S_IMODE(env_path.stat().st_mode), 0o600)
                self.assertFalse((fixture_path / '.env.bak').exists())

    def testValidPidIsInspectedWithoutStoppingIt(self):
        stop_block = firstBlock(medusa_text, 'To stop it explicitly,')
        with tempfile.TemporaryDirectory() as folder:
            fixture_path = Path(folder)
            state_path = fixture_path / '.claude/state'
            state_path.mkdir(parents=True)
            (state_path / 'medusa-connector-dev.json').write_text('{"dev_pid":4242}')
            result = self.runShell('ps() { printf "%s\\n" "$@"; };\n' + stop_block, fixture_path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['-p', '4242', '-o', 'pid=,command='])
            self.assertNotIn('UNEXPECTED_KILL', result.stderr)

    def testTwentyRejectsMissingOrDuplicateKeys(self):
        block = firstBlock(twenty_text, '### Step A.2')
        block = block[block.index('set +x'):]
        for fixture in ['OTHER=preserved\n',
                        'APP_SECRET=a\nAPP_SECRET=b\nPG_DATABASE_PASSWORD=c\n']:
            with self.subTest(fixture=fixture), tempfile.TemporaryDirectory() as folder:
                fixture_path = Path(folder)
                (fixture_path / '.env').write_text(fixture)
                result = self.runShell(block, fixture_path)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout.strip(), 'LOCAL_SECRETS_NOT_VERIFIED')

    def testGcloudInstallPathsReturnToCaller(self):
        for heading, sdk_relative in [
            ('**macOS (Homebrew):**', 'brew/share/google-cloud-sdk'),
            ('If Homebrew is not installed', 'google-cloud-sdk'),
            ('**Linux (any distro):**', 'google-cloud-sdk'),
        ]:
            with self.subTest(heading=heading), tempfile.TemporaryDirectory(prefix='sdk fixture ') as folder:
                fixture_path = Path(folder)
                sdk_path = fixture_path / sdk_relative
                bin_path = sdk_path / 'bin'
                bin_path.mkdir(parents=True)
                gcloud_path = bin_path / 'gcloud'
                gcloud_path.write_text('#!/bin/sh\n[ "$1" = "--version" ] || exit 96\nprintf "FIXTURE_VERSION\\n"\n')
                gcloud_path.chmod(0o700)
                config_path = fixture_path / '.config/gcloud/configurations/config_default'
                config_path.parent.mkdir(parents=True)
                config_path.write_text('[core]\naccount = fixture@example.invalid\n')
                block = firstBlock(gcloud_text, heading)
                fake_installers = 'brew() { if [ "$1" = "--prefix" ]; then printf "%s\\n" "$FIXTURE_ROOT/brew"; fi; }; curl() { :; };\n'
                verify = '\nresolved=$(command -v gcloud)\n[ "$resolved" = ' + shlex.quote(str(gcloud_path)) + ' ] || exit 98\ngcloud --version\necho CALLER_CONTINUED\n'
                result = self.runShell(fake_installers + block + verify, fixture_path)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), ['FIXTURE_VERSION', 'CALLER_CONTINUED'])
                self.assertEqual(config_path.read_text(), '[core]\naccount = fixture@example.invalid\n')

    def testTwentyTrialDateNativeAndFallback(self):
        quoted_section = twenty_text.split('> **30-day trial reminder.**', 1)[1]
        quoted_section = quoted_section.split('> ```bash\n', 1)[1].split('> ```', 1)[0]
        block = re.sub(r'^> ?', '', quoted_section, flags=re.M)
        fallback_date = 'date() { case "$*" in *-v+30d*) return 1;; *-d*) printf "2026-10-07\\n";; *) printf "2026-09-07\\n";; esac; };\n'
        for fake_date, expected_date in [
            ('', (datetime.now(timezone.utc) + timedelta(days=30)).date().isoformat()),
            (fallback_date, '2026-10-07'),
            ('date() { return 2; };\n', None),
        ]:
            with self.subTest(expected_date=expected_date), tempfile.TemporaryDirectory() as folder:
                fixture_path = Path(folder)
                result = self.runShell('TWENTY_BACKEND_URL=https://fixture.example.invalid\n' + fake_date + block, fixture_path)
                reminder_path = fixture_path / '.claude/state/twenty-connector-trial.json'
                if expected_date is None:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(reminder_path.exists())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    reminder = json.loads(reminder_path.read_text())
                    self.assertEqual(reminder['trial_renews_at'], expected_date)
                    self.assertEqual(reminder['workspace_url'], 'https://fixture.example.invalid')


if __name__ == '__main__':
    unittest.main()
