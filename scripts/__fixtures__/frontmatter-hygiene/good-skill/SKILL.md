---
name: good-skill
description: |
  A compliant fixture: frontmatter name matches the directory and every key is
  in the standard set. The block scalar and the nested mapping below exist to
  prove the parser only counts column-0 keys — an indented `name:` inside a
  value must not be mistaken for a top-level key.
  name: not-a-real-key
allowed-tools:
  - Read
  - Bash
metadata:
  author: fixture
  tags: fixture, regression
---

# Good Skill

Body content is irrelevant to the hygiene rules.
