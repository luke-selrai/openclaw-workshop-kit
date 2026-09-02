#!/usr/bin/env python3
"""xero-connector — the doc must match the installed MCP server, not a memory of it.

The 2026-08-03 periphery audit found the catalog claiming tools that do not exist
(`get-invoice`, `get-contact`), payroll names with a prefix the server never used,
and a scope list one Xero policy change out of date. These tests read the installed
`@xeroapi/xero-mcp-server` source and compare it to the doc.

Offline: reads local node_modules only. No network, no Xero calls, no credentials.
Run standalone:  python3 tests/test_server_truth.py
"""
import fnmatch
import json
import re
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
SKILL_MD = SKILL_DIR / "SKILL.md"
CATALOG = SKILL_DIR / "references" / "tool-catalog.md"
#: The registration surface of the MCP server, recorded from the installed
#: package and committed. Every doc-vs-server test below reads THIS, so it runs
#: on any machine — including a reader's install and the community release,
#: where the npm package is absent and the whole suite used to vanish into a
#: single setUp skip. A guard that only runs on the one machine that already
#: knows the answer is not guarding the copy that ships.
#:
#: It cannot rot: when the package IS installed, one test asserts the record
#: equals the live registration set and fails if they have drifted.
#: Regenerate with `python3 tests/record_server_truth.py`.
RECORD_PATH = SKILL_DIR / "references" / "server-registrations.json"

SERVER_CANDIDATES = [
    Path("/opt/homebrew/lib/node_modules/@xeroapi/xero-mcp-server"),
    Path("/usr/local/lib/node_modules/@xeroapi/xero-mcp-server"),
    Path.home() / ".npm-global/lib/node_modules/@xeroapi/xero-mcp-server",
]

#: Every verb the deny rules have to cover, and the reader-facing prefix that
#: must never be caught by them. Over-blocking breaks reads silently.
MUTATOR_VERBS = {"create", "update", "delete", "add", "approve", "revert"}


def load_record() -> dict:
    return json.loads(RECORD_PATH.read_text(encoding="utf-8"))


def server_root():
    for c in SERVER_CANDIDATES:
        if (c / "dist").is_dir():
            return c
    return None


def registered_tools(root: Path):
    names = set()
    for js in (root / "dist").rglob("*.js"):
        names.update(
            re.findall(r'CreateXeroTool\(\s*"([a-z0-9-]+)"', js.read_text(errors="ignore"))
        )
    return names


def scope_set(root: Path, version: str):
    src = (root / "dist" / "clients" / "xero-client.js").read_text(errors="ignore")
    m = re.search(
        rf"XERO_DEFAULT_AUTH_SCOPES_{version}\s*=\s*\[(.*?)\]", src, re.S
    )
    return set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()


def catalog_tools():
    """Every backticked tool-shaped token in the catalog's listing sections.

    The preamble deliberately names tools that do NOT exist (`get-invoice`,
    `get-contact`) to stop a session guessing them, so it is excluded.
    """
    text = CATALOG.read_text(encoding="utf-8")
    text = text[text.index("## Read") :]
    return {
        t
        for t in re.findall(r"`([a-z][a-z0-9-]+)`", text)
        if re.match(r"^(list|create|update|get|add|approve|revert|delete)-", t)
    }


def deny_patterns(body: str) -> list[str]:
    """The deny globs the install writes, read out of the jq block in SKILL.md.

    This is the list that actually reaches `~/.claude/settings.json`, so it is
    the list worth testing. Previously the guard only asked whether the string
    `mcp__xero__create-*` appeared somewhere in the page, which a comment
    mentioning it would satisfy just as well as a rule enforcing it.
    """
    block = body[body.index("## Two structural locks, both mandatory"):]
    block = block[: block.index("## Can and cannot")]
    # The array literal appended to the existing deny list. Anchored on `+ [`
    # rather than the first `]`, because `(.permissions.deny // [])` puts an
    # empty-array literal in the way and slicing at that one returned nothing —
    # which the old text-presence assertion could never have noticed.
    jq = block[block.index(".permissions.deny") :]
    jq = jq[jq.index("+ [") : jq.index("| unique")]
    return re.findall(r'"(mcp__[^"]+)"', jq)


class TestServerTruth(unittest.TestCase):
    def setUp(self):
        self.root = server_root()
        self.record = load_record()
        self.tools = set(self.record["tools"])
        self.assertTrue(self.tools, "the recorded registration set is empty")

    def scopes(self, version: str) -> set:
        return set(self.record["scopes"][version])

    def test_the_record_matches_the_installed_package(self):
        """The one test that genuinely needs the package, so it is the only one
        that may skip without it. Everything else runs off the record, and this
        is what stops the record drifting away from the server behind it."""
        if self.root is None:
            self.skipTest("@xeroapi/xero-mcp-server not installed; every other test "
                          "in this file ran against the committed record")
        live = registered_tools(self.root)
        self.assertTrue(live, "no CreateXeroTool registrations found in dist/")
        self.assertEqual(sorted(live), sorted(self.tools),
                         "references/server-registrations.json has drifted from the "
                         "installed server — rerun tests/record_server_truth.py")
        for version in ("V1", "V2"):
            self.assertEqual(sorted(scope_set(self.root, version)),
                             sorted(self.scopes(version)),
                             f"recorded {version} scopes drifted from the installed server")
        client_js = (self.root / "dist" / "clients" / "xero-client.js").read_text(errors="ignore")
        self.assertEqual("process.env.XERO_SCOPES" in client_js,
                         self.record["reads_xero_scopes_env"],
                         "the recorded XERO_SCOPES support drifted from the installed server")

    def test_claimed_tool_count_matches_the_server(self):
        """Guards the 'about 60 tools' style claim that drifts every release."""
        actual = len(self.tools)
        catalog = CATALOG.read_text(encoding="utf-8")
        skill = SKILL_MD.read_text(encoding="utf-8")
        self.assertIn(
            f"{actual} tools",
            catalog,
            f"tool-catalog.md does not state the real count ({actual})",
        )
        self.assertIn(
            f"{actual} Xero tools",
            skill,
            f"SKILL.md hand-off does not state the real count ({actual})",
        )

    def test_no_phantom_tool_names_are_claimed(self):
        """The catalog once listed get-invoice and get-contact, which never existed."""
        phantom = sorted(catalog_tools() - self.tools)
        self.assertEqual([], phantom, f"tools claimed but not registered: {phantom}")

    def test_every_registered_tool_is_catalogued(self):
        """A tool the server exposes but the doc omits is an undiscoverable capability."""
        missing = sorted(self.tools - catalog_tools())
        self.assertEqual([], missing, f"registered tools missing from catalog: {missing}")

    def test_catalog_section_counts_match_the_partition(self):
        """18 read / 19 write / 14 payroll must add up to the real registration set."""
        payroll = {
            t for t in self.tools if "payroll" in t or "timesheet" in t
        }
        reads = {t for t in self.tools - payroll if t.startswith("list-")}
        writes = self.tools - payroll - reads
        catalog = CATALOG.read_text(encoding="utf-8")
        self.assertIn(f"— {len(reads)} tools", catalog, "read count wrong")
        self.assertIn(f"— {len(writes)} tools", catalog, "write count wrong")
        self.assertIn(f"— {len(payroll)} tools", catalog, "payroll count wrong")
        self.assertEqual(len(self.tools), len(reads) + len(writes) + len(payroll))

    def test_the_default_tick_list_is_the_read_only_form_of_the_server_v2_set(self):
        """CR-2: this test used to require the SKILL to tick the server's own V2
        set — four of which are write-capable — so it asserted the defect.

        The tick-list must instead be the read-only granular form: the same
        surface area, with `.read` on every scope that has a write form.
        """
        v2 = {s for s in self.scopes("V2") if s.startswith("accounting.")}
        self.assertTrue(v2, "could not read XERO_DEFAULT_AUTH_SCOPES_V2")
        expected = {s if s.endswith(".read") else f"{s}.read" for s in v2}
        body = SKILL_MD.read_text(encoding="utf-8")
        block = body[body.index("**6. Tick the scopes") : body.index("**Legacy branch")]
        listed = set(re.findall(r"^- `(accounting\.[a-z.]+)`\s*$", block, re.M))
        self.assertEqual(
            expected, listed,
            "step 6 must tick the read-only form of every scope the server covers",
        )
        self.assertIn("29 April 2026", body, "the granular-scope cutover date is missing")

    def test_no_write_capable_scope_reaches_the_grant_by_default(self):
        """The five scopes that carry write authority, named, so no future edit
        can quietly reintroduce one into the tick-list or the pinned config.

        The legacy branch names them too, but only to disclose a hazard on an
        existing connection it is told to leave alone — so it is excluded here."""
        body = SKILL_MD.read_text(encoding="utf-8")
        write_capable = ("accounting.invoices", "accounting.payments",
                         "accounting.banktransactions", "accounting.manualjournals",
                         "accounting.transactions")
        tick_list = body[body.index("**6. Tick the scopes") : body.index("**Legacy branch")]
        ticked = re.findall(r"^- `(accounting\.[a-z.]+)`\s*$", tick_list, re.M)
        for scope in write_capable:
            self.assertNotIn(scope, ticked,
                             f"{scope} is write-capable and must not be ticked by default")
        pinned = re.search(r'READ_ONLY_SCOPES="([^"]+)"', body).group(1).split()
        for scope in pinned:
            self.assertNotIn(scope, write_capable,
                             f"{scope} is write-capable and must not be pinned in the config")
        self.assertIn("## Write access — this connector does not grant it", body,
                      "the page must refuse write access outright, not gate it")
    def test_every_registered_mutator_is_matched_by_a_deny_rule(self):
        """The lock, tested as a lock.

        This used to assert that the string `mcp__xero__create-*` appeared
        somewhere in the Markdown — which prose mentioning the rule satisfies
        exactly as well as a rule enforcing it, and says nothing about whether
        any particular tool is actually refused. A deny entry is a glob matched
        against the tool identifier, so the honest question is whether each
        mutator the server registers is matched by one. That is what runs here,
        with the same matcher the harness uses, against both the plain and the
        slugged multi-org identifier forms.
        """
        patterns = deny_patterns(SKILL_MD.read_text(encoding="utf-8"))
        self.assertTrue(patterns, "no deny globs found in the install block")
        mutators = sorted(t for t in self.tools if t.split("-")[0] in MUTATOR_VERBS)
        self.assertTrue(mutators, "the record holds no mutators — recheck the parse")

        undenied = []
        for tool in mutators:
            for server in (f"mcp__xero__{tool}", f"mcp__xero-acmebooks__{tool}"):
                if not any(fnmatch.fnmatchcase(server, p) for p in patterns):
                    undenied.append(server)
        self.assertEqual([], undenied,
                         f"registered mutators no deny rule matches: {undenied}")

    def test_the_deny_rules_do_not_also_block_the_reads(self):
        """A lock that blocks everything is not a lock, it is a broken install.
        The reads are the entire point of this connector, so prove none of them
        is caught — otherwise over-blocking would pass as safety."""
        patterns = deny_patterns(SKILL_MD.read_text(encoding="utf-8"))
        reads = sorted(t for t in self.tools if t.startswith("list-"))
        self.assertTrue(reads, "the record holds no read tools — recheck the parse")
        blocked = [t for t in reads
                   if any(fnmatch.fnmatchcase(f"mcp__xero__{t}", p) for p in patterns)]
        self.assertEqual([], blocked, f"deny rules also block reads: {blocked}")

    def test_the_deny_matcher_can_fail(self):
        """A guard that cannot fail guards nothing: prove the matcher rejects a
        mutator that no rule covers, so a missing verb is a real failure."""
        patterns = deny_patterns(SKILL_MD.read_text(encoding="utf-8"))
        self.assertFalse(any(fnmatch.fnmatchcase("mcp__xero__archive-invoice", p)
                             for p in patterns),
                         "an unlisted verb matched — the rules are wider than they read")
        self.assertTrue(any(fnmatch.fnmatchcase("mcp__xero__create-invoice", p)
                            for p in patterns))

    def test_the_server_default_scopes_are_documented_as_write_capable(self):
        """The server would request write scopes if left alone; the skill has to
        say so, because that is why XERO_SCOPES is mandatory rather than optional."""
        v1 = self.scopes("V1")
        self.assertIn("accounting.transactions", v1,
                      "the server's V1 default no longer leads with a write scope — recheck")
        body = SKILL_MD.read_text(encoding="utf-8")
        self.assertIn("the server's own defaults are write-capable", body)

    def test_legacy_scope_branch_names_the_server_v1_constant(self):
        """Pre-Apr-2026 apps were granted the broad V1 set. The branch must name it
        exactly — as a hazard to be disclosed, not a set to provision.

        It may also name the `.read` form of those same scopes, and it must: the
        review of 2026-08-10 found the branch claiming the broad set "has no
        read-only form", which is false. Xero publishes
        `accounting.transactions.read`, `accounting.contacts.read` and
        `accounting.settings.read`, and `accounting.reports.read` is already
        read-only. Nothing else may appear — an unrelated scope here is drift.
        """
        v1 = {s for s in self.scopes("V1") if s.startswith("accounting.")}
        read_only = {s if s.endswith(".read") else f"{s}.read" for s in v1}
        body = SKILL_MD.read_text(encoding="utf-8")
        block = body[body.index("**Legacy branch") : body.index("**Scope override.**")]
        listed = set(re.findall(r"`(accounting\.[a-z.]+)`", block))

        self.assertTrue(v1 <= listed,
                        f"legacy branch no longer names the V1 set: {sorted(v1 - listed)}")
        self.assertTrue(read_only <= listed,
                        "the legacy branch must name the read-only form of the broad "
                        f"set, which does exist: {sorted(read_only - listed)}")
        self.assertEqual(set(), listed - v1 - read_only,
                         f"legacy branch names unrelated scopes: {sorted(listed - v1 - read_only)}")
        self.assertNotRegex(
            block, r"(?i)no read-only (form|option|version)",
            "the branch claims the broad set has no read-only form, which is false",
        )

    def test_smoke_test_scope_string_is_the_read_only_set(self):
        """The smoke test must prove the credential works with the scopes the
        install actually provisions, not with a write-capable set."""
        body = SKILL_MD.read_text(encoding="utf-8")
        block = body[
            body.index("## Phase 1: smoke test") : body.index("## Phase 1: write the config")
        ]
        granular = re.search(r'READ_ONLY_SCOPES="([^"]+)"', block)
        self.assertIsNotNone(granular, "smoke test lost its READ_ONLY_SCOPES string")
        expected = {s if s.endswith(".read") else f"{s}.read"
                    for s in self.scopes("V2") if s.startswith("accounting.")}
        self.assertEqual(expected, set(granular.group(1).split()),
                         "smoke-test scope string drifted from the read-only granular set")
        v1 = {s for s in self.scopes("V1") if s.startswith("accounting.")}

        # The legacy fallback is the READ-ONLY form of the V1 surface. There is
        # deliberately no write-capable string here to fall back to: an app that
        # accepts neither read-only set gets no config written at all.
        ro_legacy = re.search(r'LEGACY_READ_ONLY_SCOPES="([^"]+)"', block)
        self.assertIsNotNone(ro_legacy, "smoke test has no read-only legacy fallback")
        self.assertEqual(
            {s if s.endswith(".read") else f"{s}.read" for s in v1},
            set(ro_legacy.group(1).split()),
            "the legacy fallback is not the read-only form of the V1 set",
        )

        # Every scope string the smoke test can assign must be read-only.
        for name, value in re.findall(r'^([A-Z_]*SCOPES)="([^"]*)"', block, re.M):
            for scope in value.split():
                self.assertTrue(scope.endswith(".read"),
                                f"{name} carries the write-capable scope {scope}")

        self.assertIn('ACCEPTED_SCOPES=""', block,
                      "there is no 'accepted nothing' state, so a failed grant has "
                      "nowhere to land but a write-capable pin")
        self.assertRegex(block, r"(?i)write no config",
                         "the smoke test must refuse to install when no read-only "
                         "set is accepted")

    def test_scope_override_lever_is_real_and_used(self):
        """XERO_SCOPES is not an escape hatch here — it is the only thing keeping
        the server from requesting its write-capable defaults."""
        self.assertTrue(self.record["reads_xero_scopes_env"],
                        "the server no longer honours XERO_SCOPES — the read-only "
                        "install has lost the lever it rests on")
        body = SKILL_MD.read_text(encoding="utf-8")
        config = body[body.index("## Phase 1: write the config")
                      : body.index("## Phase 1: restart and verify")]
        self.assertIn("XERO_SCOPES", config,
                      "the written config must pin XERO_SCOPES, not merely mention it")


if __name__ == "__main__":
    unittest.main(verbosity=2)
