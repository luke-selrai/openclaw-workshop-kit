#!/usr/bin/env python3
"""xero-connector — every path, launcher and sibling skill it names must resolve.

Offline. No network, no Xero calls, no credential reads.
Run standalone:  python3 tests/test_paths.py
"""
import re
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
SKILL_MD = SKILL_DIR / "SKILL.md"
REFS = SKILL_DIR / "references"


def checkout_root(start: Path) -> Path:
    """The checkout this test file belongs to, found by walking up from itself.

    Never `Path.home() / "selrai-internal-kit"` (AC-N14): a git worktree carries a
    full copy of the stack, so a path pinned to the kit checks the kit while
    claiming to check the branch it is running on. Machine-local resources —
    launchers in ~/bin, npm installs, Keeper — stay on $HOME below, because those
    genuinely belong to the machine rather than to a checkout.
    """
    for parent in start.parents:
        if (parent / ".claude" / "skills-cold").is_dir():
            return parent
    return Path.home() / "selrai-internal-kit"


KIT = checkout_root(Path(__file__).resolve()) / ".claude"
SKILL_ROOTS = [KIT / "skills", KIT / "skills-cold", KIT / "skills-retired"]

DOC_FILES = [SKILL_MD] + sorted(REFS.glob("*.md"))

# Launchers this skill's "Unlocking the launchers" section names.
LAUNCHERS = [
    "xero-selrai-mcp-launch",
    "xero-heka-mcp-launch",
    "codex-mcp-xero-selrai",
    "codex-mcp-xero-heka",
]


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def skill_exists(name: str) -> bool:
    return any((root / name).exists() for root in SKILL_ROOTS)


# The operator's deployment tree: the control pack under ~/active/ and the four
# fail-closed launchers in ~/bin. It exists on the maintainer's machine and on no
# reader's. Asserting these unconditionally is how a reader who installed
# correctly gets two hard failures for something that was never theirs to have —
# and, worse, how those two failures cancelled a false-green audit into looking
# like a real one. Present means checked; absent means skipped and said so.
# Same pattern as test_launchagent_integrity.py.
OPERATOR_ROOTS = (Path.home() / "active" / "xero-revolut-cleanup", Path.home() / "bin")
OPERATOR_PREFIXES = ("~/active", "~/bin", "~/selrai-internal-kit")

# Host state, not documentation. `~/.claude.json` is the file this skill writes
# its MCP entry into and Claude Code owns; `~/.cache` is where the token cache
# lands on first use. Both are correct to name in the doc and wrong to assert:
# their absence means "not used yet", never "the doc points at nothing".
RUNTIME_STATE_PREFIXES = ("~/.claude.json", "~/.claude/", "~/.cache")


def operator_tree_present() -> bool:
    return all(p.exists() for p in OPERATOR_ROOTS)


class TestPaths(unittest.TestCase):
    def require_operator_tree(self):
        if not operator_tree_present():
            self.skipTest(
                "operator deployment tree absent — this checks the maintainer's control "
                "pack and launchers, which a fresh install neither has nor needs"
            )

    def test_markdown_links_to_local_files_resolve(self):
        """Guards against a references/ file being renamed out from under the doc."""
        missing = []
        for f in DOC_FILES:
            for target in re.findall(r"\]\((?!https?:)([^)#]+)\)", read(f)):
                if not (f.parent / target).exists():
                    missing.append(f"{f.name} -> {target}")
        self.assertEqual([], missing, f"dead relative links: {missing}")

    def test_every_tilde_path_resolves(self):
        """Every ~/ path that is not part of the operator's own deployment."""
        missing = []
        for f in DOC_FILES:
            for raw in re.findall(r"`(~/[^`\s]+)`", read(f)):
                cleaned = raw.rstrip("/.,")
                if cleaned.startswith(OPERATOR_PREFIXES):
                    continue  # operator deployment — covered by the gated test below
                if cleaned.startswith(RUNTIME_STATE_PREFIXES):
                    continue  # host state, created on use
                if not Path(cleaned).expanduser().exists():
                    missing.append(f"{f.name}: {raw}")
        self.assertEqual([], missing, f"unresolvable ~/ paths: {missing}")

    def test_every_operator_tilde_path_resolves(self):
        """The control pack and launcher paths, checked only where they belong."""
        self.require_operator_tree()
        missing = []
        for f in DOC_FILES:
            for raw in re.findall(r"`(~/(?:active|bin|selrai-internal-kit)/[^`\s]+)`", read(f)):
                if not Path(raw.rstrip("/.,")).expanduser().exists():
                    missing.append(f"{f.name}: {raw}")
        self.assertEqual([], missing, f"unresolvable operator ~/ paths: {missing}")

    def test_grant_ritual_is_documented_and_present(self):
        """The four launchers are fail-closed; without this file they are unusable.

        Conditional on the doc still naming them. The launcher section is fenced
        `<!-- operator-only -->` and the community build cuts it out, so in a
        release there is no claim here to check. The assertion is "if this doc
        names the launchers, they and their grant ritual are real", which is the
        claim that can actually go wrong.
        """
        self.require_operator_tree()
        body = read(SKILL_MD)
        if "## Unlocking the launchers" not in body:
            self.skipTest("the operator launcher section is not in this copy of SKILL.md "
                          "(community build: the fenced block is stripped)")
        m = re.search(r"`(~/active/[^`]*GRANT-RITUAL\.md)`", body)
        self.assertIsNotNone(m, "launcher section must name the grant ritual doc")
        self.assertTrue(Path(m.group(1)).expanduser().exists())
        for launcher in LAUNCHERS:
            self.assertIn(launcher, body, f"launcher not named: {launcher}")
            self.assertTrue(
                (Path.home() / "bin" / launcher).exists(),
                f"launcher missing from ~/bin: {launcher}",
            )

    def test_pairs_with_skills_exist(self):
        """Guards against routing a user to a connector that was never built.

        "Never built" is a claim about the library this skill was authored in, so
        it is checked on a maintainer checkout. A reader's install holds three
        skills by design and none of the sibling connectors, and failing there
        would be reporting a healthy install as broken. The block must still
        parse everywhere, so doc rot cannot hide behind the install case.
        """
        body = read(SKILL_MD)
        block = body[body.index("## Pairs with") : body.index("## Reference")]
        named = re.findall(r"^- `([a-z0-9:_-]+)`", block, re.M)
        self.assertGreaterEqual(len(named), 4, "Pairs with block failed to parse")
        if not any((root / "xero-api-core").exists() and (root / "xero-connector").exists()
                   and len(list(root.glob("*-connector"))) > 3 for root in SKILL_ROOTS):
            self.skipTest("installed subset, not the skill library this doc was authored "
                          "against — the sibling connectors it names are not part of any "
                          "release and their absence here is correct")
        missing = []
        for name in named:
            if ":" in name:  # plugin skill, e.g. superpowers:systematic-debugging
                plugin, leaf = name.split(":", 1)
                candidates = [
                    root / sub
                    for root in SKILL_ROOTS
                    for sub in (f"{plugin}/{leaf}", f"{plugin}/skills/{leaf}", leaf)
                ]
                candidates += list(
                    (Path.home() / ".claude" / "plugins" / "cache").glob(
                        f"*/{plugin}/*/skills/{leaf}"
                    )
                )
                if not any(p.exists() for p in candidates):
                    missing.append(name)
            elif not skill_exists(name):
                missing.append(name)
        self.assertEqual([], missing, f"Pairs-with skills not on disk: {missing}")

    def test_doctrine_reference_is_optional_and_resolves_when_present(self):
        """connector-scaffold is a house style, not a dependency.

        It is named in no install list, so marking it REQUIRED sent a reader
        looking for a file nobody had shipped them. The banner must stay
        conditional; where the skill IS on disk its doctrine file must be too.
        """
        body = read(SKILL_MD)
        self.assertIn("connector-scaffold", body)
        self.assertIn("references/connector-doctrine.md", body)
        self.assertNotIn("**REQUIRED:** follow the connector doctrine", body)
        if skill_exists("connector-scaffold"):
            self.assertTrue(
                any(
                    (root / "connector-scaffold" / "references" / "connector-doctrine.md").exists()
                    for root in SKILL_ROOTS
                ),
                "connector-doctrine.md missing from connector-scaffold",
            )

    def test_no_dead_hot_path_self_reference(self):
        """This skill is tiered cold; ~/.claude/skills/xero-connector/ does not exist."""
        for f in DOC_FILES:
            self.assertNotIn(
                ".claude/skills/xero-connector",
                read(f),
                f"{f.name} points at the dead hot path for this skill",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
