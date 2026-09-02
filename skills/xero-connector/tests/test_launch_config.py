#!/usr/bin/env python3
"""xero-connector — the MCP entry this skill writes must actually boot.

XC-05: the skill wrote `{"command": "npx", "args": ["-y", "...@latest"]}`. Probed
with a real MCP `initialize` handshake, node-direct answered in 0.4s; the same
handshake against `npx -y ...@latest` on a COLD npx cache returned nothing in 45s
and blocked to a 5-minute timeout (a warm retry answered in 0.9s). `@latest`
forces a registry resolve before the server prints a byte, and that window
outruns the MCP boot timeout with no diagnostic anywhere. A first-ever install by
a non-technical owner is always a cold cache — so the default launch shape has to
be the global install plus an absolute node path, with the download moved to
setup time where it can be waited on.

Offline: reads the skill's own markdown, plus the locally installed server for
the version-pin check. No network, no Xero calls, no credentials.
Run standalone:  python3 tests/test_launch_config.py
"""
import json
import re
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
SKILL_MD = SKILL_DIR / "SKILL.md"

PACKAGE = "@xeroapi/xero-mcp-server"
SERVER_CANDIDATES = [
    Path("/opt/homebrew/lib/node_modules") / PACKAGE,
    Path("/usr/local/lib/node_modules") / PACKAGE,
    Path.home() / ".npm-global/lib/node_modules" / PACKAGE,
]


def read() -> str:
    return SKILL_MD.read_text(encoding="utf-8")


def server_root():
    for c in SERVER_CANDIDATES:
        if (c / "dist").is_dir():
            return c
    return None


CONFIG_LITERAL = ".mcpServers[$name] = {"


def config_block(body: str) -> str:
    """The jq invocation that writes the Xero entry into ~/.claude.json.

    The entry name is a jq argument, not a literal: the first organisation is
    `xero` and a second is `xero-<orgslug>`, and every downstream assertion keys
    off the same variable. A hard-coded `.mcpServers.xero` here is the multi-org
    bypass — the slugged entry gets written and then never checked.
    """
    start = body.index("## Phase 1: write the config")
    end = body.index("## Phase 1: restart and verify")
    section = body[start:end]
    match = re.search(r"\.mcpServers\[\$name\] = \{.*?\n\s*\}\n", section, re.S)
    assert match, "the parameterised config literal was not found in the write-config phase"
    return match.group(0)


def pinned_version(body: str) -> str:
    found = set(re.findall(re.escape(PACKAGE) + r"@([0-9]+\.[0-9]+\.[0-9]+)", body))
    assert found, f"no pinned {PACKAGE}@<semver> found in SKILL.md"
    assert len(found) == 1, f"more than one version pin in SKILL.md: {sorted(found)}"
    return found.pop()


class TestDefaultLaunchShape(unittest.TestCase):
    def test_written_config_does_not_launch_through_npx(self):
        """The whole defect in one assertion."""
        block = config_block(read())
        self.assertNotIn('"npx"', block, "the default written config still launches through npx")
        self.assertNotIn("-y", block, "the `npx -y` shim is still in the default config")

    def test_written_config_uses_an_absolute_node_path_and_the_global_entry(self):
        body = read()
        block = config_block(body)
        self.assertRegex(
            block, r'"command":\s*\$node\b',
            "the config must launch the absolute node binary resolved at install time",
        )
        self.assertRegex(
            block, r'"args":\s*\[\$entry\]',
            "the config's only argument must be the global install's entry file",
        )
        section = body[body.index("## Phase 1: write the config"):
                       body.index("## Phase 1: restart and verify")]
        self.assertIn('--arg node "$NODE_BIN"', section, "$node is not bound to the resolved node path")
        self.assertIn('--arg entry "$SERVER_ENTRY"', section, "$entry is not bound to the global entry")
        self.assertIn("dist/index.js", body, "SKILL.md never derives the dist entry point")

    def test_no_at_latest_anywhere(self):
        """`@latest` is the cold-cache resolve. A pin is cacheable and reproducible."""
        self.assertNotIn(f"{PACKAGE}@latest", read(),
                         "an `@latest` reference survives; pin the version instead")

    def test_the_install_step_runs_before_the_config_is_written(self):
        """Moves the download to setup time, where Claude can wait on it."""
        body = read()
        self.assertRegex(body, r"npm (?:i|install) -g", "no global install step")
        self.assertLess(
            body.index("npm i -g") if "npm i -g" in body else body.index("npm install -g"),
            body.index(CONFIG_LITERAL),
            "the global install must happen before the config is written",
        )

    def test_setup_proves_the_entry_file_exists_before_writing_config(self):
        body = read()
        section = body[body.index("## Phase 1: write the config"):
                       body.index("## Phase 1: restart and verify")]
        self.assertRegex(
            section, r"\[ -f \"\$SERVER_ENTRY\" \]",
            "setup must fail loudly when the global entry file is not on disk",
        )

    def test_existing_npx_entry_is_migrated_not_left_alone(self):
        """Phase 0 short-circuits on an existing entry — an old npx entry must be repaired."""
        body = read()
        phase0 = body[body.index("## Phase 0 addition"):body.index("## Phase 1: cost and country gate")]
        self.assertIn("npx", phase0,
                      "Phase 0 must detect a legacy npx entry and rewrite it to the node shape")


class TestFailureTableDiagnosesTheRealCause(unittest.TestCase):
    def test_missing_tools_row_names_the_cold_cache_hang(self):
        """The old table sent the operator into a quit/retry loop that cannot succeed."""
        body = read()
        rows = re.findall(r"^\|\s*`?mcp__xero__\*`? tools not discoverable[^\n]*", body, re.M)
        self.assertTrue(rows, "the missing-tools row disappeared")
        joined = "\n".join(rows).lower()
        self.assertIn("npx", joined, "the row must name the npx launch variant as a cause")
        self.assertIn("cache", joined, "the row must name the cold npm cache as the mechanism")

    def test_full_quit_is_no_longer_the_only_diagnosis(self):
        body = read()
        rows = re.findall(r"^\|\s*`?mcp__xero__\*`? tools not discoverable[^\n]*", body, re.M)
        self.assertGreaterEqual(
            len(rows), 2,
            "one row cannot diagnose both causes; split npx-config from incomplete-quit",
        )

    def test_first_launch_latency_is_stated(self):
        self.assertRegex(
            read(), r"cold (?:npm |npx )?cache",
            "the doc must tell the operator what a cold cache does to a first launch",
        )


class TestPinMatchesTheInstalledServer(unittest.TestCase):
    """Real-shape check: the pinned version is the one this machine actually runs."""

    def setUp(self):
        self.root = server_root()
        if self.root is None:
            self.skipTest(f"{PACKAGE} is not installed globally on this machine")

    def test_pin_matches_installed_package_version(self):
        installed = json.loads((self.root / "package.json").read_text())["version"]
        self.assertEqual(
            pinned_version(read()), installed,
            "SKILL.md pins a version this machine does not have installed",
        )

    def test_documented_entry_path_resolves(self):
        entry = self.root / "dist" / "index.js"
        self.assertTrue(entry.is_file(), f"documented server entry missing: {entry}")
        self.assertIn("dist/index.js", read(), "SKILL.md never names the dist entry point")


if __name__ == "__main__":
    unittest.main(verbosity=2)
