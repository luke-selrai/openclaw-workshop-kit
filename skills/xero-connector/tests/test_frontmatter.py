#!/usr/bin/env python3
"""xero-connector — frontmatter integrity.

Offline. No network, no Xero calls, no credential reads.
Run standalone:  python3 tests/test_frontmatter.py
"""
import re
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
SKILL_MD = SKILL_DIR / "SKILL.md"


def frontmatter_text() -> str:
    body = SKILL_MD.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", body, re.S)
    return m.group(1) if m else ""


class TestFrontmatter(unittest.TestCase):
    def test_frontmatter_block_parses_with_name_and_description(self):
        """Guards against a malformed header that makes the connector undiscoverable."""
        fm = frontmatter_text()
        self.assertTrue(fm, "SKILL.md has no --- frontmatter block")
        keys = dict(re.findall(r"^(name|description):\s*(.+)$", fm, re.M))
        self.assertIn("name", keys, "frontmatter missing name:")
        self.assertIn("description", keys, "frontmatter missing description:")
        self.assertEqual(
            keys["name"].strip(),
            SKILL_DIR.name,
            "frontmatter name must match the skill directory name",
        )

    def test_description_carries_use_when_trigger_phrasing(self):
        """House style: the router matches on 'Use when the user says ...'."""
        fm = frontmatter_text()
        desc = re.search(r"^description:\s*(.+)$", fm, re.M).group(1)
        self.assertRegex(desc, r"[Uu]se when")
        self.assertGreaterEqual(
            len(re.findall(r'"[^"]{4,}"', desc)),
            3,
            "description must quote at least 3 concrete trigger phrases",
        )

    def test_description_covers_the_data_surface_not_just_setup(self):
        """A setup-only description never fires on 'show me my unpaid invoices'."""
        desc = re.search(r"^description:\s*(.+)$", frontmatter_text(), re.M).group(1).lower()
        for topic in ("invoices", "contacts", "bank transactions", "balance sheet"):
            self.assertIn(topic, desc, f"description omits the {topic} surface")


if __name__ == "__main__":
    unittest.main(verbosity=2)
