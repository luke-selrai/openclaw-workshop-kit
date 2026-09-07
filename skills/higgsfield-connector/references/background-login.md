# Background login on macOS

Use this branch when the user needs their everyday browser left untouched and the installed CLI has no documented suppression option. The harness performs these steps; the attendee still completes any sign-in or consent that requires them. Other platforms retain Step 3's normal flow.

## Verify the installed binary before login

This capture was verified statically and through a live Claude Desktop login attempt on macOS arm64, Higgsfield 1.1.24, commit `74e091aaff646537b8f77d42e695ecccafbaa761`. It captured the original authorization URL and reached Higgsfield sign-in in an isolated browser while the original CLI kept its loopback callback open. That verifies opener isolation, not completed account authentication.

The verified binary calls `os/exec.Command("open", url).Start()`. The slash-free command resolves through the child process's PATH ([Go's contract](https://pkg.go.dev/os/exec#Command)). The npm launcher preserves that environment. The capture script replaces only that process's opener and never forwards a request to the system browser.

Read the installed version and resolve its actual native executable: for npm, inspect the installed launcher to locate `vendor/hf`; do not hash the JavaScript wrapper. Set `HIGGSFIELD_BINARY` to that absolute executable path and `HIGGSFIELD_SKILL_DIR` to this skill's absolute directory. Verify the binary before creating an attempt:

```bash
[ "$(uname -s)" = "Darwin" ] || exit 1
HIGGSFIELD_BINARY_SHA=$(shasum -a 256 "$HIGGSFIELD_BINARY" | cut -d ' ' -f 1)
[ "$HIGGSFIELD_BINARY_SHA" = "c0ec3a6dafbf6c23e4803c8c7d382adc7cb7d94de4a3f82f613811d4bd94b9c7" ] || exit 1
```

A mismatch means this implementation is unverified. Use documented suppression or inspect and verify that version's opener before retrying; do not fall back to an auto-opening login while the user's isolation constraint applies. Leave the vendor executable, global PATH, shell profiles, browser defaults, and existing auth configuration unchanged.

## Prepare one private attempt

```bash
umask 077
HIGGSFIELD_OPEN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/higgsfield-opener.XXXXXX") || exit 1
chmod 700 "$HIGGSFIELD_OPEN_DIR" || exit 1
cp "$HIGGSFIELD_SKILL_DIR/scripts/capture-open.sh" "$HIGGSFIELD_OPEN_DIR/open" || exit 1
chmod 700 "$HIGGSFIELD_OPEN_DIR/open" || exit 1
```

In the harness's retained task facility, run the following command with those resolved values. Keep stdout/stderr in a unique owner-only file inside the same attempt directory, since the CLI prints the authorization URL. Scope the environment to this command; do not export its PATH into other tasks.

```bash
env PATH="$HIGGSFIELD_OPEN_DIR:$PATH" \
  HIGGSFIELD_CAPTURE_URL_FILE="$HIGGSFIELD_OPEN_DIR/captured-url.txt" \
  "$HIGGSFIELD_BINARY" auth login
```

Keep the attempt directory until the retained process has ended. The opener is asynchronous: wait for a non-empty capture file, then read the URL privately and navigate the isolated browser on the same computer to it. Preserve its query and callback exactly. Unexpected opener arguments fail with exit 64; no request reaches the real `open`. If capture never appears, inspect the retained task's result rather than launching the default browser.

Continue Step 3's sign-in, consent, callback, workspace selection, and account-status verification. On success, failure, cancellation, or timeout, wait for or end only that retained attempt, then remove its private directory. Its URL is stale after exit. A retry gets a new directory and a new login URL. The capture helper does not own callback handling, task lifetime, or approvals.
