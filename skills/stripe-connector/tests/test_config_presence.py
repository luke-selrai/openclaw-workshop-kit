import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import textwrap
import unittest


class ConfigPresenceTests(unittest.TestCase):
    def runProbe(self, config_text=None, return_code=0):
        skill_text = (Path(__file__).resolve().parents[1] / "SKILL.md").read_text()
        match = re.search(r"   python3 - <<'PY'\n(.*?)\n   PY", skill_text, re.S)
        self.assertIsNotNone(match)
        probe = textwrap.dedent(match.group(1))
        with tempfile.TemporaryDirectory() as fixture_dir:
            if config_text is not None:
                stub = Path(fixture_dir) / "stripe"
                stub.write_text(
                    "#!" + sys.executable + "\n"
                    "import sys\n"
                    "assert sys.argv[1:] == ['config', '--list']\n"
                    "sys.stdout.write(" + repr(config_text) + ")\n"
                    "sys.stderr.write('sk_test_fake_stderr_must_not_escape')\n"
                    "sys.exit(" + str(return_code) + ")\n"
                )
                stub.chmod(0o700)
            result = subprocess.run(
                [sys.executable, "-c", probe],
                env={"PATH": fixture_dir},
                capture_output=True,
                text=True,
                timeout=20,
            )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")
        self.assertNotIn("sk_test_fake", result.stdout)
        self.assertNotIn("sk_live_fake", result.stdout)
        self.assertNotIn("private_account_marker", result.stdout)
        return json.loads(result.stdout)

    def testMissingBinary(self):
        self.assertEqual(self.runProbe(), {
            "config_readable": False,
            "test_key_present": False,
            "live_key_present": False,
        })

    def testMissingConfigSuppressesErrorOutput(self):
        self.assertEqual(self.runProbe("sk_test_fake_error_details", 1), {
            "config_readable": False,
            "test_key_present": False,
            "live_key_present": False,
        })

    def testConfigFixtures(self):
        fixtures = [
            ("empty file", "", False, False),
            ("empty fields", 'test_mode_api_key = ""\nlive_mode_api_key = \'\'\n', False, False),
            ("blank fields", '  test_mode_api_key = "   "\nlive_mode_api_key = # absent\n', False, False),
            ("test key", '[default]\n  test_mode_api_key = "sk_test_fake_value"\n', True, False),
            ("live key", "live_mode_api_key='sk_live_fake_value'\n", False, True),
            ("unquoted profile output", '[named]\n test_mode_api_key=sk_test_fake_value\n', True, False),
            ("both fields", 'test_mode_api_key="sk_test_fake_value"\nlive_mode_api_key="sk_live_fake_value"\n', True, True),
            ("unrelated private values", 'device_name="private_account_marker"\nnot_test_mode_api_key="sk_test_fake_value"\n', False, False),
            ("commented key", '# test_mode_api_key="sk_test_fake_value"\n', False, False),
            ("separate profile", '[profiles.other]\n test_mode_api_key="sk_test_fake_value"\n', True, False),
        ]
        for label, config_text, test_present, live_present in fixtures:
            with self.subTest(label=label):
                self.assertEqual(self.runProbe(config_text), {
                    "config_readable": True,
                    "test_key_present": test_present,
                    "live_key_present": live_present,
                })


if __name__ == "__main__":
    unittest.main()
