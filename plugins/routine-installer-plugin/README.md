# routine-installer-plugin

Package one or more local Claude Code skills into a working Remote Routine on claude.ai/code/routines.

## What it does

Takes a skill (or several) you have running locally and produces:

- A GitHub repo with the canonical routine shape - skill folders, `.mcp.json`, `setup.sh`, `.claude/settings.json` (pre-approves the skill's tools so scheduled runs never pause on a permission prompt), `CLAUDE.md`, `README.md`.
- An env var manifest (one paste per secret) for the routine environment.
- An autonomous drive of the claude.ai/code/routines UI in a Playwright MCP browser for the bits the API doesn't cover (env creation, trusted-domains, secret env vars, routine prompt, cron). You sign in to claude.ai once; the skill does the rest. Falls back to a guided manual hand-off only if no Playwright server is connected.
- A RemoteTrigger Run-now at the end to prove the routine fires.

## How

Triggered by `/package-as-routine` (slash command) or natural-language phrases like "schedule my morning-brief skill as a routine". Drives the flow through `skills/package-as-routine/SKILL.md`, calling deterministic helpers in `skills/package-as-routine/scripts/` for the load-bearing steps (dependency introspection, connector extraction, setup.sh generation, repo scaffold).

## Mental model

The Anthropic routine sandbox boots fresh every run. It contains language runtimes and package managers; nothing else. The `setup.sh` field in the routine environment is the only window to install CLIs, restore credentials, and stage MCP config before Claude takes over.

Every introspected dependency in your skill emits a **triple**:

| Field | Goes into |
|---|---|
| install_line | `setup.sh` (top half: get the binary on disk) |
| restoration_line | `setup.sh` (bottom half: read the env var, write creds to disk in the path the CLI expects) |
| env_var_manifest | Routine env config (the user pastes these one at a time) |

`setup.sh` = concatenation of install_lines (in dependency order) then restoration_lines. `.mcp.json` = HTTP-MCP url/headers with `${ENV_VAR}` substitution. The env-var manifest is the user-paste surface.

## Connector reuse

When a connector library is available, this plugin **does not invent per-CLI extraction logic** - it reuses the library. A connector library is an optional folder with one subfolder per tool, each describing "how do I install + restore tool X on a fresh Linux machine" via `detect.sh` / `export.sh` / `server-install.sh` / `server-import.sh`. Point the plugin at one with the `ROUTINE_CONNECTORS_DIR` env var. When no library is configured, every dependency is resolved at runtime by the resolution ladder in `SKILL.md` instead - the plugin never assumes a fixed path on disk.

For routine targets specifically, two additional optional scripts are read if present:

- `routine-export.sh` - runs locally; emits `KEY=value` lines to stdout (one env var per line).
- `routine-restore.sh` - appended into the generated `setup.sh`; reads env vars, writes files to disk.

If a connector lacks these, the plugin asks the user to scaffold them (or falls back to a conservative auto-translation from `server-import.sh`).

## Status

0.1.x - development. End-to-end fixture: package a local skill into a working routine repo with the canonical shape.

## Updating this plugin (read before editing)

The desktop app does NOT run this plugin live from source. On install it copies the plugin into a versioned cache at `~/.claude/plugins/cache/selrai-routine-installer/routine-installer-plugin/<version>/` and runs from there. Editing the source files alone changes nothing the app sees - the cache stays frozen at the installed version. This silently masked several fixes during development.

To make a source edit actually take effect:

1. Edit the source under this repo.
2. **Bump the version** in BOTH `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (same number). Without a bump, the plugin manager treats the cache as current and will not re-copy.
3. Refresh: `claude plugin marketplace update selrai-routine-installer` then `claude plugin update routine-installer-plugin@selrai-routine-installer`.
4. **Restart the desktop app** so it loads the new cache.

Same-version reinstalls are a no-op - the version bump in step 2 is the load-bearing part.

## Layout

```
routine-installer-plugin/
├── .claude-plugin/plugin.json
├── README.md
├── INSTALL.md
├── commands/
│   └── package-as-routine.md
├── skills/
│   └── package-as-routine/
│       ├── SKILL.md
│       └── scripts/
│           ├── discover_skills.py
│           ├── introspect_skill.py
│           ├── map_deps_to_connectors.py
│           ├── run_connector_export.sh
│           ├── compact_json_secret.py
│           ├── generate_setup_sh.py
│           ├── generate_mcp_json.py
│           ├── generate_readme.py
│           ├── scaffold_repo.sh
│           └── fire_routine.py
└── tests/
    └── fixtures/
        └── (sample skills for smoke tests)
```

## Out of scope (V1)

- Auth-refresh command (`/refresh-routine-auth`). V1.1.
- Skill stripping mode (the public-distribution case done manually on morning-brief - strip assets, footer, hoist hardcoded recipients to CLAUDE.md). V1 assumes private routines for workshop attendees.
- brew-only CLIs (sandbox is Linux). Plugin warns + asks for alternative.
- Routine session-content inspection (the API doesn't expose it). Verification = "did the side effect land?"
