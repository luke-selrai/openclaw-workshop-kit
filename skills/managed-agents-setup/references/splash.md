# /managed-agents-setup — what this is

> The driver agent prints this on first invocation, then asks the user "ready?" before Phase 0. After it prints, agent writes `.state/splash-shown` to skip on subsequent invocations.

```
            YOU (have an Anthropic API key)
                       |
                       | "build me a managed agent"
                       v
            +-------------------------+
            | /managed-agents-setup   |
            | (this skill, 8 phases)  |
            +-------------------------+
                       |
       +---------------+---------------+
       |               |               |
       v               v               v
   +--------+    +-----------+    +----------+
   |  Vault |    |  Agent    |    | Routine  |
   | (secs) |    | (Claude)  |    | (cron)   |
   +--------+    +-----------+    +----------+
                       |
                       v
            +-------------------------+
            |   Cloud agent running   |
            |   on Anthropic infra    |
            |   + kill switch         |
            |   + cost monitor        |
            |   + handoff one-pager   |
            +-------------------------+
```

## In one sentence

**You hand us your Anthropic API key. We give you back a cloud agent that runs on a schedule, can use your tools (Gmail, GHL, Xero, etc.), has a one-click kill switch, and sends you an email if it ever costs more than $5/day.**

## Phases (0 → 7)

| Phase | What happens |
|---|---|
| 0 | Quick check that the few tools we need are installed |
| 1 | Either we drive Playwright through the Anthropic console for you, or you paste a key |
| 2 | Install the `ant` CLI + Python SDK locally |
| 3 | Seed the vault with your service credentials (Gmail, GHL, Xero, etc.) |
| 4 | Create your first environment |
| 5 | Create the agent (pick from 35 business-outcome presets) |
| 6 | Schedule it via Routine (e.g. "every morning at 7am") |
| 7 | Run smoke test, write handoff doc, wire kill switch + cost monitor |

## What you'll never have to do

- Touch the command line
- Write code
- Manage MCP servers manually (we use Rube as the OAuth gateway)
- Worry about the agent burning unexpected cost (cap defaults to $5/day, email alert)

## Built-in safeguards

- **Cost cap** — agent stops itself at $5/day unless you raise it
- **Kill switch** — `bash scripts/killswitch.sh --agent <id>` pauses one agent without affecting the others
- **Daily monitor** — emails / Telegrams you if any agent goes weird
- **Anthropic vault** — your API keys never live in plaintext on disk

## Ready?

Type **yes** to start Phase 0. Type **show me presets** to see the 35 ready-made agent templates first. Type **what does it cost** for a cost calculator.
