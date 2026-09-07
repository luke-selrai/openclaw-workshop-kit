import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


class ResumeStatusTests(unittest.TestCase):
    def runClassifier(self, status, response_body, curl_exit=0):
        skill_text = (Path(__file__).resolve().parents[1] / "SKILL.md").read_text()
        step = skill_text.split("### Step 7 - Smoke test and report", 1)[1]
        match = re.search(r"```bash\n(.*?)\n```", step, re.S)
        self.assertIsNotNone(match)
        documented_probe = match.group(1)
        classifier = "set +x\n" + documented_probe[documented_probe.index("SERVICEM8_RESPONSE="):]
        bash = shutil.which("bash")
        self.assertIsNotNone(bash)
        with tempfile.TemporaryDirectory() as fixture_dir:
            fixture_path = Path(fixture_dir)
            for command in ["mktemp", "jq", "grep", "rm"]:
                executable = shutil.which(command)
                self.assertIsNotNone(executable, command + " is required")
                (fixture_path / command).symlink_to(executable)
            stub = fixture_path / "curl"
            stub.write_text(
                "#!" + sys.executable + "\n"
                "from pathlib import Path\n"
                "import sys\n"
                "args = sys.argv[1:]\n"
                "assert args[-1] == 'https://api.example.invalid/company.json'\n"
                "assert args[args.index('-H') + 1] == 'X-API-Key: fake_private_api_key'\n"
                "Path(args[args.index('-o') + 1]).write_text(" + repr(response_body) + ")\n"
                "sys.stdout.write(" + repr(status) + ")\n"
                "sys.exit(" + str(curl_exit) + ")\n"
            )
            stub.chmod(0o700)
            response_dir = fixture_path / "responses"
            response_dir.mkdir()
            result = subprocess.run(
                [bash, "--noprofile", "--norc", "-c", classifier],
                env={
                    "PATH": fixture_dir,
                    "TMPDIR": str(response_dir),
                    "SERVICEM8_API_KEY": "fake_private_api_key",
                    "SERVICEM8_API_BASE": "https://api.example.invalid",
                },
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(list(response_dir.iterdir()), [])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")
        self.assertNotIn("fake_private_api_key", result.stdout)
        self.assertNotIn("private_company_marker", result.stdout)
        return result.stdout.strip()

    def testDecisionCases(self):
        cases = [
            ("company read", "200", [{"name": "private_company_marker"}], "connected"),
            ("empty company list", "200", [], "connected"),
            ("200 precedence", "200", {"message": "Account trial has expired"}, "connected"),
            ("expired trial 402", "402", {"errorCode": 402, "message": "Account trial has expired. Please select an account plan and try again."}, "account-plan-required"),
            ("402 without message", "402", {}, "account-plan-required"),
            ("expired account 401", "401", {"message": "Account has expired"}, "account-plan-required"),
            ("lapsed trial 401", "401", {"message": "Trial period has lapsed"}, "account-plan-required"),
            ("expired API key 401", "401", {"message": "Account API key expired"}, "reconnect"),
            ("invalid key 401", "401", {"message": "Invalid API key"}, "reconnect"),
            ("403 permissions", "403", {"message": "Insufficient permissions"}, "permission-denied"),
            ("403 account gate precedence", "403", {"message": "Account trial has expired"}, "account-plan-required"),
            ("server failure", "500", {"message": "Internal error", "company": "private_company_marker"}, "request-failed"),
        ]
        for label, status, body, expected in cases:
            with self.subTest(label=label):
                self.assertEqual(self.runClassifier(status, json.dumps(body)), expected)

    def testMalformedResponseIsPrivate(self):
        self.assertEqual(self.runClassifier("500", "private_company_marker is not JSON"), "request-failed")

    def testTransportFailure(self):
        self.assertEqual(self.runClassifier("000", "", curl_exit=7), "request-failed")


if __name__ == "__main__":
    unittest.main()
