<!-- Deliberately BROKEN power-user-skills step for test-mp-skills-install.mjs.
     This is (approximately) the pre-LOUP-19 body: stale `diagnose` selector,
     no self-heal, no per-skill report, "network hiccup" hand-wave. Every rule
     in check-mp-skills-install.mjs must FAIL against it. It carries the setup
     prompt's anchors so the extraction path is exercised too. -->

4. **Power-user skills** — same command on Mac and Windows:

   ```
   npx -y skills@latest add mattpocock/skills -g -a claude-code -s grill-me -s handoff -s diagnose -s teach -y --copy
   ```

   Then confirm these exist:

   - `~/.claude/skills/grill-me/SKILL.md`
   - `~/.claude/skills/handoff/SKILL.md`
   - `~/.claude/skills/diagnose/SKILL.md`
   - `~/.claude/skills/teach/SKILL.md`

   If the command errors or any of the four files is missing, tell the
   facilitator. Say: "The four extra skills didn't come through just now -
   probably a network hiccup."

### Step 7 — The one restart
