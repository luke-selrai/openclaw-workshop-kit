#!/usr/bin/env python3
"""xero-connector — safety and honesty content that must not be edited away.

Offline. No network, no Xero calls, no credential reads.
Run standalone:  python3 tests/test_content.py
"""
import re
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
SKILL_MD = SKILL_DIR / "SKILL.md"
DOC_FILES = [SKILL_MD] + sorted((SKILL_DIR / "references").glob("*.md"))

# Case-insensitive stub markers. NB "a read-only placeholder was captured" is real
# diagnosis prose about Xero's own UI, so only the authoring-stub forms are matched.
PLACEHOLDER_MARKERS = [
    r"\bTODO\b",
    r"\bTBD\b",
    r"\bFIXME\b",
    r"lorem ipsum",
    r"\[returns the result",
    r"placeholder (?:text|content|value here)",
    r"<placeholder",
    r"XXXX",
    r"0\.0\.0",
]
# Case-sensitive: an all-caps token is always an authoring stub, never prose.
SHOUTED_MARKERS = [r"\bPLACEHOLDER\b", r"\bREPLACE_ME\b", r"\bYOUR_[A-Z_]+_HERE\b"]


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


class TestContent(unittest.TestCase):
    def test_edit_deactivates_connection_warning_is_present(self):
        """Apr-2026 rule: saving a scope edit deactivates the Custom Connection."""
        body = read(SKILL_MD)
        self.assertRegex(
            body,
            r"editing scopes DEACTIVATES the connection",
            "the standalone scope-edit warning block is missing",
        )
        self.assertIn("Connection deactivated", body)

    def test_both_error_tables_route_scope_edits_through_reactivation(self):
        """Without this, 'tick the scope and retry' loops forever on a dead connection."""
        body = read(SKILL_MD)
        smoke_row = re.search(r"\|\s*`invalid_scope`[^|\n]*\|([^\n]*re-activate[^\n]*)", body, re.I)
        self.assertIsNotNone(
            smoke_row,
            "no smoke-test invalid_scope row routes a scope edit through re-activation",
        )

        verify_row = re.search(r"\|\s*`403 insufficient_scope`\s*\|([^\n]+)", body)
        self.assertIsNotNone(verify_row, "verify 403 insufficient_scope row missing")
        self.assertRegex(verify_row.group(1), r"re-activate", re.I)

    def test_paid_and_country_gate_runs_before_the_browser(self):
        """Money gate: the user consents to the ~$5/mo charge before any portal work."""
        body = read(SKILL_MD)
        self.assertLess(
            body.index("## Phase 1: cost and country gate"),
            body.index("## Phase 1: portal walkthrough"),
            "the cost gate must precede the portal walkthrough",
        )
        self.assertIn("Australia, New Zealand, UK, or US", body)

    def test_card_entry_stays_the_users_own_action(self):
        """Hard rule: Claude never fills payment details."""
        body = read(SKILL_MD)
        self.assertIn("This is the one field you never fill", body)
        self.assertIn("Card entry is the user's own action", body)

    def test_the_default_install_is_read_only(self):
        """CR-2: the default install used to provision `accounting.invoices`,
        `accounting.payments`, `accounting.banktransactions` and
        `accounting.manualjournals` — all write-capable — handing a
        non-technical owner 51 tools with write authority over their books."""
        body = read(SKILL_MD)
        tick_list = body[body.index("**6. Tick the scopes"): body.index("**Legacy branch")]
        # The bullets are what actually gets ticked in the portal; surrounding
        # prose names write scopes deliberately, to warn against them.
        scopes = re.findall(r"^- `(accounting\.[a-z.]+)`\s*$", tick_list, re.M)
        self.assertTrue(scopes, "step 6 lost its scope tick-list")
        for scope in scopes:
            self.assertTrue(
                scope.endswith(".read"),
                f"the default install ticks the write-capable scope {scope}",
            )

    def test_there_is_no_write_upgrade_procedure_at_all(self):
        """Regression, Codex review 2026-08-09 finding 2 (CRITICAL).

        This page used to carry a write-upgrade procedure: swap the read scopes
        for write scopes on an explicit spoken request, refusing only `selr` and
        `heka`. `local` — the reader's OWN real books, the single organisation
        this connector ever reaches — was not on that exclusion list, so the one
        org the procedure could actually be run against was the one org it had
        no business touching. Enabling it exposes 19 accounting and 6 payroll
        mutators, `delete-timesheet` among them.

        There is now no upgrade path, so the assertions are negative: the
        procedure must stay gone. A gate that can be walked through on request
        is not a gate.
        """
        body = read(SKILL_MD)
        self.assertIn("## Write access — this connector does not grant it", body)
        block = body[body.index("## Write access — this connector does not grant it"):]
        block = block[: block.index("\n## ")]

        # The refusal, stated positively. Each of the three escape hatches the
        # old procedure offered is named here only to be closed.
        self.assertIn("no upgrade procedure", block.lower())
        self.assertIn('no "they asked for it in words" exception', block,
                      "the spoken-request escape hatch is no longer closed in words")
        self.assertIn("no explicit-yes path", block.lower())

        # Section headings and instructions the old procedure shipped. These are
        # what a re-admission would actually look like.
        for readmitted in (
            "## Write access — a separate, explicit decision",
            "Writes are drafts",
            "Never auto-authorise, never auto-send",
            "Verify after every write",
        ):
            self.assertNotIn(readmitted, body,
                             f"the write-upgrade procedure is back: {readmitted!r}")

        # The old procedure's own words. Any of them returning means the swap
        # step returned with them.
        self.assertNotRegex(
            body,
            r"(?i)(swap|replace|change) the .{0,30}read.{0,20}scopes? (for|with) .{0,20}write",
            "a scope-swap upgrade step is back in the page",
        )

    def test_the_readers_own_books_are_protected_like_the_operators(self):
        """`local` is a reader's real books, so it gets `selr`/`heka` treatment.

        The old exclusion list named only the operator's two tenants, which read
        as caution but protected the wrong books. The page must now name `local`
        alongside them and point writes at the disposable demo company instead.
        """
        body = read(SKILL_MD)
        block = body[body.index("## Write access — this connector does not grant it"):]
        block = block[: block.index("\n## ")]

        self.assertIn("`local`", block, "the reader's own tenant key is not named")
        self.assertRegex(
            block,
            r"`selr`,\s*`heka`\s*\*\*and\s*`local`\*\*|`selr`,\s*`heka`\s*and\s*`local`",
            "`local` must sit in the same no-write set as `selr` and `heka`",
        )
        self.assertIn("empty `write_scopes_allowed`", block,
                      "the page must cite the code-level freeze, not a promise")
        self.assertRegex(block, r"(?i)demo company",
                         "the page must name where writes actually belong")

    def test_safety_is_never_described_as_merely_behavioural(self):
        """"Behavioural" safety is not safety — it is a promise about conduct.

        The page used to call the write branch's protection behavioural. Two
        structural locks replaced it: the scope pin and the harness deny rules,
        the second of which is the only one a legacy app has.
        """
        body = read(SKILL_MD)
        for word in ("behavioural safety", "behavioral safety",
                     "safety is behavioural", "safety is behavioral"):
            self.assertNotIn(word.lower(), body.lower(),
                             f"safety is claimed as {word!r}, which is a posture not a lock")

        self.assertIn("## Two structural locks, both mandatory", body)
        locks = body[body.index("## Two structural locks, both mandatory"):]
        locks = locks[: locks.index("\n## ")]
        self.assertIn("Lock 1 — the scope pin", locks)
        self.assertIn("Lock 2 — the deny rules", locks)
        # The deny rules are the lock that survives a legacy app, where the
        # scope pin cannot help. Every mutator verb the server registers.
        for verb in ("create", "update", "delete", "add", "approve", "revert"):
            self.assertIn(f"mcp__xero__{verb}-*", locks,
                          f"{verb} mutators are not denied at the harness")
            self.assertIn(f"mcp__xero-*__{verb}-*", locks,
                          f"{verb} mutators are undenied on the multi-org slug form")

    def test_the_config_pins_the_read_only_scope_string(self):
        """The server's own defaults are write-capable (V1 leads with
        `accounting.transactions`), so XERO_SCOPES is the setting that actually
        routes. Verify the router, not the asset."""
        body = read(SKILL_MD)
        config = body[body.index("## Phase 1: write the config"):
                      body.index("## Phase 1: restart and verify")]
        self.assertIn("XERO_SCOPES", config,
                      "the config must pin scopes; the server default is write-capable")
        pinned = re.search(r'READ_ONLY_SCOPES="([^"]+)"', body)
        self.assertIsNotNone(pinned, "the read-only scope string is not defined in the skill")
        for scope in pinned.group(1).split():
            self.assertTrue(scope.endswith(".read"), f"{scope} is not read-only")

    def test_the_cost_gate_quotes_the_price_xero_publishes(self):
        """Review 2026-08-10 finding 1. A money claim, so it gets a real source.

        The page said "about $5 USD (~$8 AUD, £5 GBP)". The AUD figure was wrong
        and no figure carried a tax basis. Xero publishes $10 AUD inc GST at
        developer.xero.com/custom-development, verified 2026-08-10 (not on their
        /pricing page, which lists app tiers only).

        AUD is the only figure quoted, by decision: this reads to an Australian
        audience, and the other three currencies were noise. Everyone else is
        sent to Xero's own activation screen for the number, which is where the
        AUD reader is sent to confirm it too.
        """
        body = read(SKILL_MD)
        gate = body[body.index("## Phase 1: cost and country gate"):
                    body.index("## Phase 1: portal walkthrough")]
        self.assertIn("$10 AUD", gate, "the cost gate no longer quotes the AUD price")
        self.assertIn("including GST", gate, "the AUD price lost its tax basis")
        self.assertNotIn("$8 AUD", body, "the unverified ~$8 AUD figure is back")
        self.assertRegex(
            gate, r"(?i)outside australia",
            "quoting one currency only is fine, but non-AU users must be routed "
            "to Xero's own screen rather than given the AUD figure",
        )
        self.assertIn("developer.xero.com/custom-development", gate,
                      "a money claim must cite the page it came from")

    def test_no_payroll_scope_is_ever_ticked(self):
        """Review 2026-08-10 finding 2.

        Step 6 used to tell NZ/UK users to tick `payroll.employees`,
        `payroll.settings` and `payroll.timesheets` on request. Those are the
        view-AND-MANAGE forms: they grant write authority over live pay runs
        while the page advertises a read-only install, and they end in something
        other than `.read`, so they would also trip the config assertion. The
        server registers six payroll mutators behind them, `delete-timesheet`
        among them — the only delete it has.
        """
        body = read(SKILL_MD)
        step6 = body[body.index("**6. Tick the scopes"): body.index("**Legacy branch")]
        self.assertNotRegex(
            step6,
            r"(?i)tick(?!\s+nothing)[^.]{0,80}`payroll\.",
            "step 6 instructs a payroll scope to be ticked",
        )
        self.assertFalse(
            re.findall(r"^- `payroll\.[a-z.]+`\s*$", step6, re.M),
            "a payroll scope is in step 6's tick-list",
        )
        self.assertRegex(step6, r"(?i)no payroll",
                         "step 6 must refuse payroll outright, not stay silent on it")
        # Nothing anywhere may provision one, on either branch.
        for scope in ("payroll.employees", "payroll.settings", "payroll.timesheets"):
            self.assertNotRegex(
                body, r"(?i)(tick|add|include|pin)[^.\n]{0,60}`" + re.escape(scope) + "`",
                f"{scope} is provisioned somewhere on the page",
            )

    def test_the_scope_readback_checks_the_entry_that_was_written(self):
        """Review 2026-08-10 finding 5, the multi-org bypass.

        Both the scope assertion and the Phase 0 audit hard-coded
        `.mcpServers.xero`. A second organisation installs to
        `mcpServers."xero-<orgslug>"`, so on that machine the assertion read an
        entry that does not exist and the entry that does was never checked.
        """
        body = read(SKILL_MD)
        self.assertNotIn(
            ".mcpServers.xero.env.XERO_SCOPES", body,
            "the scope assertion hard-codes the plain entry and skips a slugged one",
        )
        config = body[body.index("## Phase 1: write the config"):
                      body.index("## Phase 1: restart and verify")]
        self.assertIn('.mcpServers[$name].env.XERO_SCOPES', config,
                      "the readback must key off the entry name that was written")
        self.assertIn('--arg name "$ENTRY"', config,
                      "the entry name must be bound as a jq argument, not a literal")

    def test_the_deny_verification_covers_the_multi_org_slug_form(self):
        """The deny rules always listed `mcp__xero-*__`; the verification did not.

        A machine whose only Xero entry is slugged would pass a check that looks
        exclusively at `mcp__xero__*` while every mutator remained reachable as
        `mcp__xero-<slug>__*`.
        """
        body = read(SKILL_MD)
        locks = body[body.index("## Two structural locks, both mandatory"):]
        locks = locks[: locks.index("\n## ")]
        verify = locks[locks.index("# Verify the rule that BLOCKS"):]
        self.assertIn("mcp__xero__", verify)
        self.assertIn('"mcp__xero-*__"', verify,
                      "the deny verification never checks the multi-org slug form")

    def test_the_quarantine_discloses_the_dropped_mcp_servers(self):
        """Review 2026-08-10 finding 10.

        A corrupt `~/.claude.json` is replaced with `{"mcpServers": {}}`, which
        silently removes every other MCP server the machine had configured. The
        old file is kept, so this is recoverable — but only if the user is told.
        """
        body = read(SKILL_MD)
        config = body[body.index("## Phase 1: write the config"):
                      body.index("## Phase 1: restart and verify")]
        self.assertIn('.corrupt.', config, "the quarantine path is gone")
        self.assertRegex(
            config, r"(?i)every other MCP server",
            "the quarantine never says the other MCP servers are dropped",
        )
        self.assertRegex(
            config, r"(?i)your claude settings file was corrupted",
            "there is no plain-English line telling the user what happened",
        )

    def test_the_client_secret_is_not_claimed_to_stay_on_the_machine(self):
        """Review 2026-08-10 finding 8.

        Security notes claimed the credentials were "never transmitted anywhere
        but Xero". Step 10 has Claude read the secret off the page, so it passes
        through the conversation before being stored in plain text.
        """
        body = read(SKILL_MD)
        self.assertNotIn("never transmitted anywhere but Xero", body,
                         "the false containment claim is back")
        notes = body[body.index("## Security notes"):]
        notes = notes[: notes.index("\n## ")] if "\n## " in notes else notes
        self.assertRegex(notes, r"(?i)plain text",
                         "the notes must say the credential is stored unencrypted")
        self.assertRegex(
            notes, r"(?i)passes through the model|part of the conversation",
            "the notes must disclose that the secret goes through the conversation",
        )

    def test_no_invented_cli_command_and_no_hidden_failures(self):
        """Review 2026-08-10 finding 6.

        `claude mcp add-from-marketplace playwright` is not a real subcommand,
        and `2>/dev/null || true` meant the run carried on calling Playwright
        tools that were never going to be registered. Prose *about* the invented
        command is allowed — running it is not.
        """
        for f in DOC_FILES:
            text = read(f)
            for block in re.findall(r"```(?:bash|sh)\n(.*?)```", text, re.S):
                self.assertNotIn(
                    "add-from-marketplace", block,
                    f"{f.name} runs a CLI subcommand that does not exist",
                )
                self.assertNotIn(
                    "2>/dev/null || true", block,
                    f"{f.name} hides a command failure instead of handling it",
                )

    def test_no_placeholder_or_stub_content(self):
        """A connector doc with TODOs in it is not installable."""
        hits = []
        for f in DOC_FILES:
            text = read(f)
            hits += [f"{f.name}: {p}" for p in PLACEHOLDER_MARKERS if re.search(p, text, re.I)]
            hits += [f"{f.name}: {p}" for p in SHOUTED_MARKERS if re.search(p, text)]
        self.assertEqual([], hits, f"placeholder markers found: {hits}")

    def test_cannot_list_does_not_overpromise(self):
        """The 'Cannot' block is the honesty gate — reconciliation is UI-only."""
        body = read(SKILL_MD)
        block = body[body.index("## Can and cannot") : body.index("## Service-specific failures")]
        for claim in (
            "Delete records",
            "Reconcile bank transactions",
            "File BAS or VAT",
            "1:1 by design",
        ):
            self.assertIn(claim, block, f"'Cannot' block lost: {claim}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
