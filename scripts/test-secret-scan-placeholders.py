import json
from pathlib import Path
import secrets
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SecretScanPlaceholderTests(unittest.TestCase):
    def testMedusaExceptionRequiresPathAndExactVariable(self):
        literal = secrets.token_hex(24) + ':'
        cases = [
            ('skills/medusa-connector/SKILL.md', '$MEDUSA_ADMIN_SECRET_KEY:', 0),
            ('skills/medusa-connector/SKILL.md', literal, 1),
            ('examples/other.md', '$MEDUSA_ADMIN_SECRET_KEY:', 1),
            ('examples/other.md', literal, 1),
        ]
        for file_path, credential, expected in cases:
            with self.subTest(file_path=file_path, literal=credential == literal):
                with tempfile.TemporaryDirectory() as directory:
                    fixture = Path(directory) / file_path
                    fixture.parent.mkdir(parents=True)
                    fixture.write_text('curl -sS --user "' + credential + '" https://example.invalid\n')
                    report = Path(directory) / 'report.json'
                    result = subprocess.run(
                        ['gitleaks', 'dir', '.', '--config', str(ROOT / '.gitleaks.toml'),
                         '--redact', '--no-banner', '--report-format', 'json',
                         '--report-path', str(report)],
                        cwd=directory, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, expected, result.stderr)
                    findings = json.loads(report.read_text())
                    self.assertEqual(len(findings), expected)
                    if findings:
                        self.assertEqual(findings[0]['RuleID'], 'curl-auth-user')


if __name__ == '__main__':
    unittest.main()
