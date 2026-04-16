# Known Issue — GitHub: Connector Limitations

**Status:** Known limitations
**Affects:** github-connector
**Symptoms:** Tool errors on large repos; hitting request limits; write operations failing on a read-only access key; GitHub Enterprise Server not working

---

## How the GitHub Connector Works

The GitHub connector runs through **GitHub's hosted connection** — a service GitHub operates at their end that Claude talks to over the internet. There is nothing to install locally. You create a **GitHub access key** (a one-time setup in your GitHub settings) and Claude uses it to read and update your repos on your behalf.

This is convenient, but because everything goes through GitHub's hosted service there are a few constraints worth knowing about.

---

## Limitation 1 — Read-only vs. Write Access Depends on Your Access Key

When you set up the connector you choose the permission level for your access key. If you chose **read-only**, Claude cannot create issues, open pull requests, push code, or make any other changes — even if you ask it to.

**Fix:** Tell your assistant you want to upgrade:
> "My GitHub access key is read-only. Can you walk me through upgrading it?"

Your assistant will guide you to GitHub Settings → Developer Settings → Personal Access Tokens, where you can edit the existing key and tick the write permissions you need (Issues, Pull requests, Contents). No need to create a new one.

---

## Limitation 2 — GitHub Enterprise Server Is Not Supported

GitHub's hosted connection only works with standard **github.com** accounts. If your organisation runs its own private GitHub instance (sometimes called GitHub Enterprise Server, usually on a domain like `github.yourcompany.com`), the connector will fail to authenticate.

**Workaround:** Self-hosted GitHub instances need a different setup that is not covered by this connector version. Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) to discuss a custom setup.

---

## Limitation 3 — GitHub Temporarily Slows You Down at High Volume

GitHub limits how many requests can be made per hour using your access key (up to 5,000 in an hour). In normal use this is never reached. However, if you ask your assistant to scan many repos, issues, or commits in a row, GitHub will temporarily slow things down — it asks you to wait before continuing.

**Symptoms:** Your assistant will tell you GitHub is asking it to slow down and will automatically wait a few seconds before trying again. If it still can't continue, it will let you know and suggest trying again in a minute.

**Fix:** If you are running a large scan (e.g. "summarise all open issues across all my repos"), ask your assistant to process in smaller batches.

---

## Limitation 4 — Large Directories Are Slow

Requesting the contents of a directory with hundreds of files (`get_file_contents` on a directory) can return a very large response. For big repos, your assistant will warn you and ask if you want a filtered subset instead of the full list.

---

## Related

- Connector docs: `skills/github-connector/SKILL.md`
- General troubleshooting: `docs/TROUBLESHOOTING.md`
- GitHub SETUP guide: `docs/GITHUB-SETUP.md`
