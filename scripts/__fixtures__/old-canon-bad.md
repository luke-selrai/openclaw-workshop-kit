# Old-canon checker fixture - intentional pre-ADR-0001 install references

Feeds scripts/test-verify-conform.mjs. Allowlisted in verify-conform.mjs so the
main old-canon pass skips it. Each line below must be caught by exactly one
rule, on the line number the test asserts. Do not reorder, do not "fix".

These are the INVERTED rules (CORE-116): every line names a fact the new canon
says must be read from the pointer block or the manifest, not written down.

Kit lives at ~/.loup/selr-ai/workshop-kit/skills so I can find it.
Windows kit path C:\Users\Jane\.loup\selr-ai\workshop-kit\skills
Clone target ~/claude-workshop-kit/my-assistant/CLAUDE.md
Windows clone target C:\Users\Jane\claude-workshop-kit\skills
Your workspace is ~/Desktop/my-assistant and that is where I live.
Older installs used $HOME/my-assistant as the workspace folder.
First run is signalled by a .first-run-pending file in the workspace.
