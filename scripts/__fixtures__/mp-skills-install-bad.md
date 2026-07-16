<!-- Deliberately BROKEN Step 3 fixture for test-mp-skills-install.mjs.
     This is (approximately) the pre-LOUP-19 body: stale `diagnose` selector,
     no self-heal, no summary, "network hiccup" hand-wave. Every rule in
     check-mp-skills-install.mjs must FAIL against it. -->

### Step 3 — Install power-user skills

Say:
> "One last tool step: I'm adding four power-user skills."

Run (same command on Mac and Windows):

```bash
npx -y skills@latest add mattpocock/skills -g -a claude-code -s grill-me -s handoff -s diagnose -s teach -y --copy
```

Check these files exist:

- `~/.claude/skills/grill-me/SKILL.md`
- `~/.claude/skills/handoff/SKILL.md`
- `~/.claude/skills/diagnose/SKILL.md`
- `~/.claude/skills/teach/SKILL.md`

If all four are present, say:
> "Done. **grill-me** stress-tests any plan, **diagnose** works through bugs, **handoff** packages up a conversation, and **teach** walks you through learning."

**Failure branch.** If the command errors or any of the four files is missing, tell the facilitator. This is a hard blocker: stop setup here. Say:

> "The four extra skills didn't come through just now — probably a network hiccup."

## PHASE 3
