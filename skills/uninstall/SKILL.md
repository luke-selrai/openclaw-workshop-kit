---
name: uninstall
description: "Removes the Selr AI Business Assistant kit from a machine - the global pointer block, the assistant's instructions file, the kit folder, the installed kit skills and the plugin. Use when the user says 'uninstall it', 'remove the assistant', 'take the Selr kit off my computer', or asks to remove one installed skill."
---

# Uninstall

This skill carries no steps of its own. The whole procedure lives in one file inside the kit,
so the skill and the procedure cannot drift apart. Do this:

1. Read `~/.claude/selr-kit-manifest.json` and take the `kitHome` path from it.
2. Open `<kitHome>/docs/uninstall.md`.
3. Follow it exactly, top to bottom.

If the install record is missing or will not parse, look for `docs/uninstall.md` in the three
places a kit folder may be. The kit installs to `~/claude-workshop-kit`; the other two are
old Loup installs left on machines set up before that channel was retired -
`~/.loup/selrai-company/claude-workshop-kit` and `~/.loup/selr-ai/workshop-kit`. Follow
whichever copy you find. That document has its own section for running without an
install record.

If neither the record nor the document is on disk, say so plainly rather than improvising a
removal, and offer to fetch a fresh copy of the kit so the document is available again.
