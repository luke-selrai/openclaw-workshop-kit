# Private capture and supported registration

Run the bundled commands from this skill's directory. They support macOS/Linux owner-only files. On Windows, an equivalent owner-only ACL and capture helper must be verified before a password is generated; do not treat POSIX mode bits as an ACL check or fall back to pasting credentials.

## Prepare before creating a password

Identify the intended self-hosted site and signed-in WordPress account. HTTPS is required except an explicitly local site at `localhost`, `127.0.0.1` or `[::1]`. HTTP on LAN addresses, public domains or arbitrary names resolving to loopback is rejected. Do not change WordPress security settings to bypass this check.

Find the browser MCP's actual output directory from a public artifact link or configured output root. Do not guess it from the shell working directory. Check it is an owned, nonsymlink directory and protect it with mode 700 before opening any secret-bearing UI. Preserve unrelated files in it. Run:

`python3 scripts/connect.py prepare --site <site-base-url> --output-dir <absolute-private-MCP-output-directory>`

The optional top-level `--directory <absolute-owned-directory>` supports another site. Default: `~/.config/wordpress-connector`. Any existing directory is preserved for resume; it is never erased to get a fresh attempt. The command creates a private state directory, random capture names and two pre-created mode-600 output files. It prints only the public probe/password/function paths and unique server name.

On a disposable blank tab, call the available `browser_evaluate` with `function: () => ({probe: true})` and its optional `filename` set to the exact absolute probe-file path. The tool must return only an artifact link, not the object contents. Verify its observed artifact link resolves to that exact file, then run:

`python3 scripts/connect.py accept-probe --artifact <actual-absolute-probe-artifact>`

The helper checks exact tracked path/name, private directory, regular file, owner, single hardlink, mode 600 and JSON schema. It deletes only that verified public probe. If `filename` is unavailable, the output path is changed, or result withholding cannot be verified, stop before creating a password. This is a capture capability gate, not a WordPress plan restriction.

## Create and capture once

Return to exactly `<site-base-url>/wp-admin/profile.php` in the intended account. Before generating anything, confirm Application Passwords are available and no earlier unsaved password notice is visible. Read only the generated `capture-function.js`; it contains selectors and public setup context, no credentials.

Call `browser_evaluate` once with that entire async function and `filename` equal to the exact pre-created password-file path. **Do not use a separate `browser_click` for Add New:** its post-click snapshot could reveal the generated password before capture. The function fills the unique application name, clicks once, waits for WordPress's real `#new-application-password-value` input, captures its value and `#user_login`, and removes the generated notice before a post-evaluation snapshot. The `.application-password-display` text contains labels, not the password, in current WordPress core.

The function retains its result only in this tab's temporary capture state until acceptance. If the tool's artifact write fails, reusing the same generated function can return the same in-memory result without another creation click. A timed-out creation is uncertain state; it must not be retried by clicking Add New again. Preserve the tab, files and existing application-password row for inspection.

The real tool return must contain only its artifact link. Resolve that **observed** path and run:

`python3 scripts/connect.py accept-capture --artifact <actual-absolute-password-artifact>`

This verifies exact output path, owner, mode, file type and hardlink count; exact intended profile URL; username schema; and the 24-character alphanumeric WordPress password after whitespace removal. It creates `credentials.json` privately and never prints its fields. An existing matching credential file is preserved; a different one stops without replacement. Only the exact accepted capture file is deleted. Other snapshots/downloads are never glob-deleted. Clean up only additional private artifacts positively attributed to this one capture.

After acceptance, clear the temporary tab state with a safe boolean-returning evaluation: `() => { delete window.__claudeWordPressPrivateCapture; return true; }`. Do not read or log that state. The generated notice has already been removed. Never request network-response bodies, screenshots, DOM dumps or console logs from the secret-bearing interval.

If any capture step fails, preserve partial state. Do not generate another password, revoke unrelated passwords, weaken file permissions or copy a key through chat/clipboard. `python3 scripts/connect.py check` returns only schema status and the registered-name candidate; it does not claim a live connection.

## Install and register the official bridge

Install the pinned official bridge into the owned connector directory with the harness's available npm:

`npm install --prefix <owned-directory>/runtime --save-exact --ignore-scripts --no-audit --no-fund @automattic/mcp-wordpress-remote@0.4.0`

Resolve the installed Node executable to an absolute path (Node 22+ recommended; the published 0.4.0 package declares >=18). Then run:

`python3 scripts/connect.py register --node <absolute-node-executable>`

The helper verifies the package name/version and built entry point. It uses supported `claude mcp add --transport stdio --scope user <unique-wordpress-name> -- <absolute-python> <absolute-helper> --directory <owned-directory> run`. The command contains paths only, no credential values or `--env` secrets. The supported CLI owns its config write. The helper privately checks registration structure before and after, preserves pre-existing server entries, refuses a conflicting target, and never rewrites/restores the global config itself. It does not ask the user to close other Claude windows. Custom `CLAUDE_CONFIG_DIR` needs an exact supported-path review before this default-config registration helper runs.

The wrapper reads the private credentials at launch and sets `WP_API_URL`, `WP_API_USERNAME`, `WP_API_PASSWORD` and `OAUTH_ENABLED=false` only in the bridge's child environment. It clears conflicting OAuth/JWT/custom-header/debug overrides and keeps bridge stderr in a private owned file. It launches the pinned installed `dist/proxy.js` via absolute Node; it does not download npm code on each MCP startup. Never print the private credential or stderr files during troubleshooting.

Registration success is not connection success. In the actual Claude Desktop Code, terminal or VS Code caller, rediscover deferred tools and use its normal MCP reconnect/refresh control. If that surface cannot reload the new server, start a fresh task session when supported, preserving unrelated windows and work. Do not mint another password to fix tool pickup. The plain Desktop chat surface may use a different MCP configuration interface; CLI user-scope registration does not prove that surface sees the server.

Discover the exact registered server's meta-tools, read its abilities, inspect one read ability's schema and execute a real site-info or recent-post read. Confirm the intended site/account. Keep registration, private credential persistence, actual read and each caller's pickup as separate evidence. Only the actual read completes the connection.

## Sources and offline checks

- [Official bridge](https://github.com/Automattic/mcp-wordpress-remote): endpoint and Application Password environment, including disabled OAuth.
- [Published 0.4.0 metadata](https://registry.npmjs.org/@automattic%2fmcp-wordpress-remote/0.4.0): package version, entry point and engine floor.
- [WordPress core profile template](https://github.com/WordPress/WordPress/blob/master/wp-admin/user-edit.php): generated password input and profile fields.
- [Claude MCP registration](https://code.claude.com/docs/en/mcp): stdio add syntax, user scope and actual-caller verification.

Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s skills/wordpress-connector/tests -v` from the repository root. All credentials/configs are synthetic and registration is mocked; tests make no vendor, authentication or MCP calls.
