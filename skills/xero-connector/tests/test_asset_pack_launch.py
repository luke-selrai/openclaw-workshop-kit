#!/usr/bin/env python3
"""Keep the installable connector aligned with the audited MCP launch contract."""

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
PACK = REPO / "asset-library/connectors/xero"
SETUP = PACK / "skills/xero-mcp-setup/SKILL.md"
#: The skill this file lives in — present in every tree, release included.
SKILL_MD = Path(__file__).resolve().parents[1] / "SKILL.md"
PIN = "0.0.17"
PACKAGE = "@xeroapi/xero-mcp-server"

# The asset-library connector pack is a maintainer-side artefact and is not part
# of any release: it was never scrubbed, and one of its skills would have a
# reader emailing their own debtors under somebody else's brand. This suite
# checks that the pack and this skill agree on the MCP launch contract, so
# without the pack there is nothing here to compare. It says so rather than
# erroring out of setUpClass with a bare FileNotFoundError.
PACK_PRESENT = SETUP.is_file() and (PACK / "MANIFEST.yaml").is_file()
SKIP_REASON = ("the asset-library connector pack is not on this tree — it is a "
               "maintainer artefact and ships in no release, so there is no "
               "second copy of the launch contract to compare against")


#: Sibling suite that checks the SAME launch contract against the shipped
#: SKILL.md rather than against the pack. It runs in every tree, release
#: included, which is why the skips below cost coverage rather than all of it.
LAUNCH_CONFIG_SUITE = Path(__file__).resolve().parent / "test_launch_config.py"


class TestTheContractIsStillCoveredWhereThisFileSkips(unittest.TestCase):
    """Never skips, and exists because the two classes below always could.

    Both of those compare the maintainer's asset pack against this skill, and
    the pack ships in no release. In the tree a reader receives, all eleven of
    them skip. The audit reports that honestly and does not count a skip as a
    pass, but nothing anywhere said whether the launch contract was still
    checked once they stopped running — the file simply went quiet.

    It is still checked. `test_launch_config.py` asserts the pin, the absolute
    Node launch, the refusal to float and the npx migration against the SHIPPED
    SKILL.md, and it runs everywhere. Duplicating those assertions here would
    add no coverage. What was missing is anything that fails if that sibling
    coverage disappears, which is what this asserts: the drift check may skip,
    but only while something else is proving the same contract on the file that
    ships.
    """

    def test_the_shipped_contract_suite_exists_and_covers_each_clause(self):
        self.assertTrue(LAUNCH_CONFIG_SUITE.is_file(),
                        "the suite that proves the launch contract on the "
                        "shipped SKILL.md is gone, so in a release nothing "
                        "checks the contract at all")
        body = LAUNCH_CONFIG_SUITE.read_text(encoding="utf-8")
        for clause, marker in (
                ("version pin", r"@\(\?P?<?\w*>?\\?d|@\(\\d|semver|version pin"),
                ("no floating @latest", r"@latest"),
                ("absolute node launch", r"command -v node|absolute"),
                ("npx migration", r"npx"),
        ):
            with self.subTest(clause=clause):
                self.assertRegex(body, marker,
                                 f"{clause} is no longer asserted against the "
                                 "shipped SKILL.md by the suite that runs in a "
                                 "release")

    def test_the_pin_this_file_audits_is_the_pin_the_shipped_skill_carries(self):
        """The one contract value this file can check without the pack. If the
        shipped skill moves off the audited pin, the drift check below would
        skip in a release and nothing would notice."""
        pins = set(re.findall(re.escape(PACKAGE) + r"@(\d+\.\d+\.\d+)",
                              SKILL_MD.read_text(encoding="utf-8")))
        self.assertEqual({PIN}, pins,
                         "the shipped connector pins a version other than the "
                         "one this suite audits, or pins more than one")

    def test_this_class_is_not_itself_pack_gated(self):
        """The guard on the guard. If this class ever acquired the skip decorator
        the file would go back to proving nothing in a release."""
        self.assertFalse(getattr(type(self), "__unittest_skip__", False))


@unittest.skipUnless(PACK_PRESENT, SKIP_REASON)
class TestAssetPackLaunchContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.setup = SETUP.read_text(encoding="utf-8")
        cls.manifest = (PACK / "MANIFEST.yaml").read_text(encoding="utf-8")
        cls.references = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted(PACK.rglob("*.md"))
            if "xero-reconcile" not in path.parts
        )

    def test_manifest_uses_the_audited_exact_pin(self):
        match = re.search(r"^\s*version_pin:\s*([^\s#]+)", self.manifest, re.MULTILINE)
        self.assertIsNotNone(match)
        self.assertEqual(PIN, match.group(1))
        connection = (PACK / "references/connection.md").read_text(encoding="utf-8")
        pins = re.findall(r"^> \*\*Version pin:\*\* ([^ ]+)", connection, re.MULTILINE)
        self.assertEqual([PIN], pins)

    def test_setup_installs_the_exact_pin(self):
        self.assertIn(f'PINNED_VERSION="{PIN}"', self.setup)
        self.assertIn(f'npm install -g "{PACKAGE}@${{PINNED_VERSION}}"', self.setup)

    def test_setup_writes_resolved_absolute_paths(self):
        self.assertIn('NODE_BIN="$(command -v node)"', self.setup)
        self.assertIn('SERVER_ENTRY="$(npm root -g)/@xeroapi/xero-mcp-server/dist/index.js"', self.setup)
        self.assertRegex(self.setup, r'"command":\s*\$node')
        self.assertRegex(self.setup, r'"args":\s*\[\$entry\]')

    def test_existing_floating_launcher_is_migrated(self):
        self.assertIn('EXISTING_COMMAND=$(jq', self.setup)
        self.assertIn('[[ "$EXISTING_COMMAND" = /*node ]]', self.setup)
        self.assertIn('MIGRATE_CONFIG', self.setup)

    def test_no_floating_latest_package_reference_remains(self):
        self.assertNotIn(f"{PACKAGE}@latest", self.references)

    def test_setup_references_name_the_pin_and_absolute_strategy(self):
        connection = (PACK / "references/connection.md").read_text(encoding="utf-8")
        checks = (PACK / "references/checks.md").read_text(encoding="utf-8")
        self.assertIn(f"{PACKAGE}@{PIN}", connection)
        self.assertIn(f"{PACKAGE}@{PIN}", checks)
        self.assertIn("absolute Node executable", connection)
        self.assertIn("absolute Node executable", checks)


@unittest.skipUnless(PACK_PRESENT, SKIP_REASON)
class TestAssetPackOfflineVerifier(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.verifier = PACK / "tests/verify.sh"
        cls.body = cls.verifier.read_text(encoding="utf-8")

    def run_fixture(self, mutate=None):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp) / "xero"
            shutil.copytree(PACK, fixture)
            if mutate is not None:
                mutate(fixture)
            env = os.environ.copy()
            env["XERO_PACK_DIR"] = str(fixture)
            return subprocess.run(
                ["bash", str(self.verifier)],
                text=True,
                capture_output=True,
                check=False,
                env=env,
            )

    def test_verifier_is_offline_and_has_no_legacy_write_probe(self):
        forbidden = (
            "smoke-test.sh", "curl ", "ssh ", "EC2", "Desktop connector",
            "Zapier-Xero MCP", "xero.sh", "Layer 1", "Layer 2", "Layer 3",
        )
        self.assertEqual([], [token for token in forbidden if token in self.body])

    def test_real_pack_passes_offline(self):
        result = self.run_fixture()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("VERIFY PASS — offline package", result.stdout)

    def test_missing_shipped_skill_fails(self):
        def remove_skill(fixture):
            (fixture / "skills/xero-bas-prep/SKILL.md").unlink()

        result = self.run_fixture(remove_skill)
        self.assertEqual(2, result.returncode, result.stdout + result.stderr)
        self.assertIn("FAIL: skills/xero-bas-prep/SKILL.md missing or empty", result.stdout)

    def test_floating_or_changed_pin_fails(self):
        def change_pin(fixture):
            manifest = fixture / "MANIFEST.yaml"
            manifest.write_text(
                manifest.read_text(encoding="utf-8").replace(
                    "version_pin: 0.0.17", "version_pin: latest"
                ),
                encoding="utf-8",
            )

        result = self.run_fixture(change_pin)
        self.assertEqual(2, result.returncode, result.stdout + result.stderr)
        self.assertIn("FAIL: audited MCP version is pinned", result.stdout)

    def test_write_capable_smoke_scope_fails(self):
        def widen_scope(fixture):
            setup = fixture / "skills/xero-mcp-setup/SKILL.md"
            setup.write_text(
                setup.read_text(encoding="utf-8").replace(
                    "scope=accounting.transactions.read accounting.contacts.read "
                    "accounting.settings.read accounting.reports.read",
                    "scope=accounting.transactions accounting.contacts "
                    "accounting.settings accounting.reports.read",
                ),
                encoding="utf-8",
            )

        result = self.run_fixture(widen_scope)
        self.assertEqual(2, result.returncode, result.stdout + result.stderr)
        self.assertIn("FAIL: credential smoke requests read-only scopes", result.stdout)


if __name__ == "__main__":
    unittest.main()
