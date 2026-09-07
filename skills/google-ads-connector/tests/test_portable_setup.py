import contextlib
import datetime
import io
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from urllib.request import urlopen


SKILLS = Path(__file__).resolve().parents[2]


def readSkill(vendor):
    return (SKILLS / f'{vendor}-ads-connector' / 'SKILL.md').read_text()


def codeBlocks(vendor, language):
    return re.findall(r'```' + language + r'\n(.*?)\n```', readSkill(vendor), re.S)


class PortableSetupTests(unittest.TestCase):
    def testPrivateCaptureWithoutClipboard(self):
        node_test = r'''
const fs = require('node:fs/promises');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const input = JSON.parse(process.argv[1]);
const credentials = input.credentials;
let blob;
let deleted = false;
let waiting = false;
let download_name;
let saved_path;
let clicked = false;
const labels = [];
for (const [key, value] of Object.entries(credentials)) {
  const names = {client_id: 'Client ID', client_secret: 'Client Secret', app_id: 'App ID', secret: 'Secret', dev_token: 'Developer token'};
  const label = {innerText: names[key], children: []};
  const container = {
    innerText: names[key], children: [label],
    parentElement: {querySelectorAll: () => Object.values(credentials).map(value => ({value})), parentElement: null}
  };
  label.parentElement = {
    innerText: names[key] + '\n' + value,
    querySelectorAll: () => [label, {value}], parentElement: container
  };
  labels.push(container, label);
}
const sandbox = {
  document: {
    querySelectorAll: () => labels,
    body: {appendChild: () => {}},
    createElement: () => ({
      set download(value) { download_name = value; },
      click() { assert.ok(waiting); clicked = true; },
      remove() {}
    })
  },
  navigator: {get clipboard() { throw new Error('Shared clipboard used'); }},
  Blob,
  URL: {createObjectURL(value) { blob = value; return 'blob:offline'; }, revokeObjectURL() {}},
  setTimeout: (callback) => callback()
};
const context = vm.createContext(sandbox);
const page = {
  evaluate: async (fn, value) => {
    context.input_values = value;
    return vm.runInContext('(' + fn.toString() + ')(input_values)', context);
  },
  waitForEvent: (event) => {
    assert.equal(event, 'download');
    waiting = true;
    return Promise.resolve({
      saveAs: async (path) => {
        assert.ok(clicked);
        saved_path = path;
        await fs.writeFile(path, await blob.text());
        await fs.writeFile(input.output_dir + '/' + download_name, await blob.text());
      },
      delete: async () => { deleted = true; }
    });
  }
};
(async () => {
  const capture = vm.runInContext('(' + input.code + ')', context);
  const result = await capture(page);
  if (!Object.keys(credentials).length) {
    assert.equal(result.ok, false);
    assert.equal(waiting, false);
    return;
  }
  assert.equal(result.ok, true);
  assert.ok(deleted);
  assert.ok(saved_path.endsWith(download_name.replace('ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa-', '')));
  assert.deepEqual(JSON.parse(await fs.readFile(saved_path, 'utf8')), credentials);
  for (const value of Object.values(credentials)) {
    assert.ok(!JSON.stringify(result).includes(value));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
'''
        fixtures = {
            'google': [
                {'client_id': '1' * 30 + '.apps.googleusercontent.com', 'client_secret': 's' * 35},
                {'dev_token': 'd' * 22},
            ],
            'tiktok': [{'app_id': '1234567890123456789', 'secret': 's' * 48}],
        }
        for vendor, credentials_list in fixtures.items():
            captures = []
            for block in codeBlocks(vendor, 'js'):
                if 'download.saveAs' in block:
                    captures.append(block)
            self.assertEqual(len(captures), len(credentials_list))
            for block, credentials in zip(captures, credentials_list):
                with self.subTest(vendor=vendor, fields=list(credentials)):
                    with tempfile.TemporaryDirectory() as temp_dir:
                        capture_dir = Path(temp_dir) / 'capture'
                        output_dir = Path(temp_dir) / 'mcp-output'
                        capture_dir.mkdir(mode=0o700)
                        output_dir.mkdir(mode=0o755)
                        unrelated = output_dir / 'existing-user-file.txt'
                        unrelated.write_text('preserve')
                        env = dict(os.environ, ADS_CAPTURE_DIR=str(capture_dir), ADS_OUTPUT_DIR=str(output_dir), ADS_CAPTURE_NAME='ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa')
                        protect = next(part for part in codeBlocks(vendor, 'bash') if 'test -O' in part)
                        subprocess.run(['/bin/bash', '-c', protect], env=env, check=True, capture_output=True)
                        self.assertEqual(output_dir.stat().st_mode & 0o777, 0o700)
                        filename = 'developer.json' if 'dev_token' in credentials else 'client.json'
                        prepare = next(part for part in codeBlocks(vendor, 'bash') if 'set -C' in part and f'/{filename}' in part)
                        prepared = subprocess.run(['/bin/bash', '-c', prepare], env=env, capture_output=True, text=True)
                        self.assertEqual(prepared.returncode, 0, prepared.stderr)
                        existing = subprocess.run(['/bin/bash', '-c', prepare], env=env, capture_output=True, text=True)
                        self.assertNotEqual(existing.returncode, 0)
                        code = block.replace('<absolute ADS_CAPTURE_DIR>', str(capture_dir)).replace('<ADS_CAPTURE_NAME>', 'ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa')
                        for values in [credentials, {}]:
                            result = subprocess.run(
                                ['node', '-e', node_test, json.dumps({'code': code, 'credentials': values, 'output_dir': str(output_dir)})],
                                capture_output=True, text=True,
                            )
                            self.assertEqual(result.returncode, 0, result.stderr)
                            self.assertEqual(result.stdout, '')
                        output_key = 'ADS_DEVELOPER_OUTPUT' if filename == 'developer.json' else 'ADS_CLIENT_OUTPUT'
                        env[output_key] = str(output_dir / f'ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa-{filename}')
                        cleanup = next(part for part in codeBlocks(vendor, 'bash') if part.startswith(f'python3 - "$ADS_CAPTURE_DIR/{filename}"'))
                        subprocess.run(['/bin/bash', '-c', cleanup], env=env, check=True, capture_output=True)
                        self.assertEqual(unrelated.read_text(), 'preserve')
                        self.assertFalse((output_dir / f'ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa-{filename}').exists())
                        self.assertEqual((capture_dir / filename).stat().st_mode & 0o777, 0o600)
                        self.assertEqual(json.loads((capture_dir / filename).read_text()), credentials)

    def testCleanupRejectsUnrelatedPathsAndSymlinks(self):
        cases = ['other-directory', 'other-name', 'normalized-old-name', 'symlink-file', 'symlink-parent', 'hardlink-file', 'invalid-nonce']
        for vendor in ['google', 'tiktok']:
            filenames = ['client.json']
            if vendor == 'google':
                filenames.append('developer.json')
            for filename in filenames:
                for case in cases:
                    with self.subTest(vendor=vendor, filename=filename, case=case), tempfile.TemporaryDirectory() as temp_dir:
                        capture_dir = Path(temp_dir) / 'private'
                        output_dir = Path(temp_dir) / 'output'
                        outside_dir = Path(temp_dir) / 'outside'
                        for directory in [capture_dir, output_dir, outside_dir]:
                            directory.mkdir(mode=0o700)
                        capture_name = 'ads-capture-aaaaaaaaaaaaaaaaaaaaaaaa'
                        private_file = capture_dir / filename
                        expected_file = output_dir / f'{capture_name}-{filename}'
                        unrelated = outside_dir / f'{capture_name}-{filename}'
                        private_file.write_text('private-value')
                        expected_file.write_text('owned-copy')
                        unrelated.write_text('preserve')
                        for file in [private_file, expected_file, unrelated]:
                            file.chmod(0o644)
                        reported_file = expected_file
                        if case == 'other-directory':
                            reported_file = unrelated
                        elif case == 'other-name':
                            reported_file = output_dir / 'unrelated.json'
                            reported_file.write_text('unrelated-value')
                            reported_file.chmod(0o644)
                        elif case == 'normalized-old-name':
                            capture_name = 'ads-capture.T8j5If'
                            reported_file = output_dir / f'ads-capture-T8j5If-{filename}'
                            reported_file.write_text('normalized-copy')
                            reported_file.chmod(0o644)
                        elif case == 'symlink-file':
                            expected_file.unlink()
                            expected_file.symlink_to(unrelated)
                        elif case == 'symlink-parent':
                            alias = output_dir / 'escape'
                            alias.symlink_to(outside_dir, target_is_directory=True)
                            reported_file = alias / expected_file.name
                        elif case == 'hardlink-file':
                            expected_file.unlink()
                            os.link(unrelated, expected_file)
                        elif case == 'invalid-nonce':
                            capture_name = 'ads-capture-unrelated'
                        output_key = 'ADS_DEVELOPER_OUTPUT' if filename == 'developer.json' else 'ADS_CLIENT_OUTPUT'
                        env = dict(os.environ, ADS_CAPTURE_DIR=str(capture_dir), ADS_OUTPUT_DIR=str(output_dir), ADS_CAPTURE_NAME=capture_name)
                        env[output_key] = str(reported_file)
                        cleanup = next(part for part in codeBlocks(vendor, 'bash') if part.startswith(f'python3 - "$ADS_CAPTURE_DIR/{filename}"'))
                        result = subprocess.run(['/bin/bash', '-c', cleanup], env=env, capture_output=True, text=True)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertEqual(result.stdout, '')
                        self.assertTrue(reported_file.exists())
                        self.assertTrue(expected_file.exists())
                        self.assertEqual(private_file.read_text(), 'private-value')
                        self.assertEqual(unrelated.read_text(), 'preserve')
                        self.assertEqual(private_file.stat().st_mode & 0o777, 0o644)
                        self.assertEqual(unrelated.stat().st_mode & 0o777, 0o644)
                        self.assertEqual(reported_file.stat().st_mode & 0o777, 0o644)

    def testListenerSkipsOccupiedPortAndCapturesPrivately(self):
        for vendor in ['google', 'tiktok']:
            with self.subTest(vendor=vendor), tempfile.TemporaryDirectory() as temp_dir:
                with socket.socket() as occupied:
                    occupied.bind(('127.0.0.1', 0))
                    occupied.listen()
                    first_port = occupied.getsockname()[1]
                    block = next(block for block in codeBlocks(vendor, 'bash') if 'nohup python3 -c' in block)
                    script = re.search(r'nohup python3 -c "(.*?)" >', block, re.S).group(1)
                    script = script.replace('range(8765, 8865)', f'range({first_port}, {first_port + 100})')
                    script = script.replace('/tmp/', temp_dir + '/')
                    process = subprocess.Popen(
                        [sys.executable, '-c', script], stdout=subprocess.PIPE, stderr=subprocess.PIPE, umask=0o077,
                    )
                    try:
                        port_file = Path(temp_dir) / f'{vendor}-ads-listener.port'
                        deadline = time.monotonic() + 5
                        while not port_file.exists() and time.monotonic() < deadline:
                            if process.poll() is not None:
                                break
                            time.sleep(0.02)
                        self.assertTrue(port_file.exists())
                        chosen_port = int(port_file.read_text())
                        self.assertGreater(chosen_port, first_port)
                        key = 'auth_code' if vendor == 'tiktok' else 'code'
                        with urlopen(f'http://127.0.0.1:{chosen_port}/callback?{key}=offline-code', timeout=2) as response:
                            self.assertEqual(response.status, 200)
                        stdout, stderr = process.communicate(timeout=3)
                        self.assertEqual(process.returncode, 0, stderr.decode())
                        self.assertEqual(stdout, b'')
                        self.assertEqual(stderr, b'')
                        code_file = Path(temp_dir) / f'{vendor}-ads-auth-code'
                        self.assertEqual(code_file.read_text(), 'offline-code')
                        self.assertEqual(code_file.stat().st_mode & 0o777, 0o600)
                    finally:
                        if process.poll() is None:
                            process.terminate()
                            process.communicate(timeout=3)

    def testPrivateDirectoryAcrossAvailableShells(self):
        block = next(block for block in codeBlocks('google', 'bash') if 'mktemp -d' in block)
        shells = ['/bin/bash', '/bin/sh']
        if Path('/bin/zsh').exists():
            shells.append('/bin/zsh')
        for shell in shells:
            with self.subTest(shell=shell), tempfile.TemporaryDirectory() as temp_dir:
                env = dict(os.environ, TMPDIR=temp_dir)
                result = subprocess.run([shell, '-c', block], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                directory, download_name = result.stdout.splitlines()
                capture_dir = Path(directory)
                self.assertRegex(download_name, r'^ads-capture-[a-f0-9]{24}$')
                self.assertEqual(re.sub(r'[^a-z0-9-]+', '-', download_name), download_name)
                self.assertEqual(capture_dir.parent, Path(temp_dir))
                self.assertEqual(capture_dir.stat().st_mode & 0o777, 0o700)

    def testTikTokDateArithmeticAcrossCalendarBoundaries(self):
        expressions = re.findall(r"python3 -c '(from datetime import date, timedelta; print\([^']+)'", readSkill('tiktok'))
        self.assertEqual(len(set(expressions)), 3)
        for current in [datetime.date(2024, 3, 31), datetime.date(2025, 1, 31), datetime.date(2026, 9, 7)]:
            previous_last = current.replace(day=1) - datetime.timedelta(days=1)
            expected = {
                str(current - datetime.timedelta(days=30)),
                str(previous_last.replace(day=1)),
                str(previous_last),
            }
            actual = set()
            for expression in expressions:
                executable = expression.replace('date.today()', f'date({current.year}, {current.month}, {current.day})')
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    exec(executable, {})
                actual.add(output.getvalue().strip())
            self.assertEqual(actual, expected)


if __name__ == '__main__':
    unittest.main()
