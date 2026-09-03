# Google's Agent Skills — a vendored third-party pack

Not ours. Google's. Vendored into `claude-workshop-kit` on **2026-09-03** so the
assistant can read Google's first-party API guidance from disk, without a network
call and without loading 131 skill descriptions into every session. The entry
point is the router one level up, `../SKILL.md` (`google-stack`); nothing in this
folder is a top-level kit skill and nothing here is loaded until it is read by path.

## Sources

| Upstream | Commit | Upstream date | Skills | Lives at |
|---|---|---|---|---|
| `github.com/google/skills` | `f234cfba096987f3dee291ce6e7c80b048fb20b3` | 2026-09-02 | 128 | `ads/`, `analytics/`, `cloud/`, `developers/` |
| `github.com/google-gemini/gemini-skills` | `e2e931ffd78c503f2a9ad848152e561c8f4e1ea8` | 2026-09-02 | 3 | `gemini/` |

Licence: **Apache-2.0** for both, see `LICENSE` (copied from `google/skills`; the
Gemini repo carries the same licence). The upstream trees are kept verbatim -
nothing renamed, nothing rewritten - so an update stays a clean re-pull. The only
structural change is that the Gemini repo's skills sit under `gemini/`.

Deliberately **not** vendored from `google/skills`: the `plugins/` tree (Claude Code
and Codex plugin manifests) and its 16 git submodules under
`plugins/cloud/data-agent-kit/`, and the root `index.json` catalogue (the router
explains when to fetch it live). If one of the submodules is ever wanted it is a
separate repository and needs its own review.

## Rules

- **Never edit a vendored `SKILL.md`** or anything else under `ads/`, `analytics/`,
  `cloud/`, `developers/` or `gemini/`. A correction goes upstream, or into the
  router at `../SKILL.md`. Local edits are silently destroyed by `update.sh`.
- The pack is exempt from the kit's description rules by construction: the audit
  (`scripts/audit-skills.mjs`) only reads top-level `skills/*/SKILL.md`, and
  Claude Code only discovers `~/.claude/skills/<name>/SKILL.md`, so these files are
  reference material inside the `google-stack` skill folder, not skills of their
  own. Do not move them up a level - that would put 131 descriptions into every
  attendee session.
- Google authored these. They are never stamped, marked or credited as Selr AI's.

## Updating

```bash
skills/google-stack/pack/update.sh
```

Re-clones both repos, replaces the five lane folders and `LICENSE`, reprints the
counts and rewrites the commit table above. Then run
`node scripts/audit-skills.mjs --write`, review the diff, and if a lane's count
or membership changed, make the same edit to the lane tables in `../SKILL.md`.
