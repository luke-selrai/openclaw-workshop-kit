# Known Issue — GitHub: Remote MCP Server Limitations

**Status:** Known limitations
**Affects:** github-connector
**Symptoms:** Tool errors on large repos; rate limit hits; write operations failing on a read-only token; GitHub Enterprise Server not working

---

## How the GitHub Connector Works

The GitHub connector uses GitHub's **official remote MCP server**, hosted by GitHub at `https://api.githubcopilot.com/mcp`. There is nothing to install — authentication is a Personal Access Token (PAT) that you create once in your GitHub settings. Claude Code sends requests through that hosted server rather than talking to the GitHub API directly.

This is convenient but introduces a few constraints that a local CLI would not have.

---

## Limitation 1 — Read-only vs. Write Access Depends on Your Token

When you set up the connector you choose the permission level for your token. If you chose **read-only**, Claude cannot create issues, open pull requests, push code, or make any other changes — even if you ask it to.

**Fix:** Tell your assistant you want to upgrade:
> "My GitHub token is read-only. Can you walk me through upgrading it?"

Your assistant will guide you to GitHub Settings → Developer Settings → Personal Access Tokens, where you can edit the existing token and tick the write permissions you need (Issues, Pull requests, Contents). No need to create a new token.

---

## Limitation 2 — GitHub Enterprise Server Is Not Supported

The remote MCP server (`https://api.githubcopilot.com/mcp`) only works with **github.com** accounts. If your organisation uses **GitHub Enterprise Server** (a self-hosted GHES instance with its own domain, e.g. `github.yourcompany.com`), the connector will fail to authenticate.

**Workaround:** GHES support requires the local Docker version of the GitHub MCP server with a `--gh-host` flag. This is not set up by the current connector. Contact your Selr AI contact to discuss a custom setup.

---

## Limitation 3 — Rate Limits at High Volume

Authenticated PATs have a limit of **5,000 GitHub API requests per hour**. In normal use this is never reached. However, automated workflows that loop over many repos, issues, or commits can hit it faster than expected.

**Symptoms:** You will see a 429 or "secondary rate limit" error. Your assistant will automatically wait 10 seconds and retry once. If the second attempt also fails, you will need to wait before continuing.

**Fix:** If you are running a large scan (e.g. "summarise all open issues across all my repos"), ask your assistant to process in smaller batches.

---

## Limitation 4 — Large Directories Are Slow

Requesting the contents of a directory with hundreds of files (`get_file_contents` on a directory) can return a very large response. For big repos, your assistant will warn you and ask if you want a filtered subset instead of the full list.

---

## Related

- Connector docs: `skills/github-connector/SKILL.md`
- General troubleshooting: `docs/TROUBLESHOOTING.md`
- GitHub SETUP guide: `docs/GITHUB-SETUP.md`
