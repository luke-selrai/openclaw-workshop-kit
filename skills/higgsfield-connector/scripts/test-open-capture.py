import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


script_path = Path(__file__).with_name('capture-open.sh')
synthetic_url = 'https://clerk.higgsfield.ai/oauth/authorize?client_id=fixture&state=synthetic%2Bvalue&redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2Fcallback'


class OpenCapture(unittest.TestCase):
    def testProcessLocalCapture(self):
        original_path = os.environ.get('PATH', '/usr/bin:/bin')
        with tempfile.TemporaryDirectory(prefix='higgsfield capture fixture ') as folder:
            fixture_path = Path(folder)
            shim_path = fixture_path / 'open'
            shim_path.write_bytes(script_path.read_bytes())
            shim_path.chmod(0o700)
            capture_path = fixture_path / 'captured-url.txt'
            env = {'PATH': str(fixture_path) + ':' + original_path,
                   'HIGGSFIELD_CAPTURE_URL_FILE': str(capture_path)}
            result = subprocess.run(['open', synthetic_url], env=env, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout + result.stderr, b'')
            self.assertEqual(capture_path.read_text(), synthetic_url + '\n')
            self.assertEqual(stat.S_IMODE(capture_path.stat().st_mode), 0o600)
            self.assertEqual(os.environ.get('PATH', '/usr/bin:/bin'), original_path)

    def testUnexpectedRequestsFailClosed(self):
        for arguments in [[], ['https://example.invalid/unrelated'], ['-a', 'Safari'],
                          [synthetic_url, synthetic_url], ['http://clerk.higgsfield.ai/oauth/authorize?fixture']]:
            with self.subTest(arguments=arguments), tempfile.TemporaryDirectory() as folder:
                capture_path = Path(folder) / 'captured-url.txt'
                capture_path.write_text('preserved')
                result = subprocess.run(['/bin/sh', str(script_path), *arguments],
                                        env={'HIGGSFIELD_CAPTURE_URL_FILE': str(capture_path)},
                                        capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 64)
                self.assertEqual(result.stdout + result.stderr, b'')
                self.assertEqual(capture_path.read_text(), 'preserved')

    def testMissingOrRelativeCapturePathFails(self):
        for capture_value in ['', 'relative-url.txt']:
            with self.subTest(capture_value=capture_value), tempfile.TemporaryDirectory() as folder:
                result = subprocess.run(['/bin/sh', str(script_path), synthetic_url], cwd=folder,
                                        env={'HIGGSFIELD_CAPTURE_URL_FILE': capture_value},
                                        capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 64)
                self.assertEqual(list(Path(folder).iterdir()), [])

    def testUnverifiedBinaryOrPlatformCannotPassPreparation(self):
        reference = (script_path.parent.parent / 'references/background-login.md').read_text()
        check_block = reference.split('```bash\n', 1)[1].split('```', 1)[0]
        verified_hash = 'c0ec3a6dafbf6c23e4803c8c7d382adc7cb7d94de4a3f82f613811d4bd94b9c7'
        for platform, binary_hash, expected_code in [
            ('Darwin', verified_hash, 0),
            ('Darwin', 'unverified', 1),
            ('Linux', verified_hash, 1),
        ]:
            with self.subTest(platform=platform, binary_hash=binary_hash):
                fake_tools = 'uname() { printf "%s\\n" "$FIXTURE_PLATFORM"; }; shasum() { printf "%s  fixture\\n" "$FIXTURE_HASH"; };\n'
                result = subprocess.run(['/bin/sh', '-c', fake_tools + check_block + '\necho PREPARED'],
                                        env={'PATH': '/usr/bin:/bin', 'FIXTURE_PLATFORM': platform,
                                             'FIXTURE_HASH': binary_hash, 'HIGGSFIELD_BINARY': '/fixture/hf'},
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, expected_code)
                if expected_code == 0:
                    self.assertEqual(result.stdout.strip(), 'PREPARED')
                else:
                    self.assertNotIn('PREPARED', result.stdout)


if __name__ == '__main__':
    unittest.main()
