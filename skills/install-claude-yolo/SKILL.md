---
name: install-claude-yolo
description: Install a cross-platform 'claude-yolo' shell alias that launches Claude Code with --dangerously-skip-permissions (bypass permissions mode). Detects the user's OS and shell, writes to the correct config file (.zshrc, .bashrc, .bash_profile, fish config, or PowerShell $PROFILE), and is idempotent (safe to re-run). Use when the user wants to install the claude-yolo alias, set up bypass permissions shortcut, or when they ask to install this skill from a workshop.
---

# Install claude-yolo alias

## Goal

Add a `claude-yolo` alias (or function) to the user's shell so they can launch Claude Code in bypass permissions mode by typing one short command instead of `claude --dangerously-skip-permissions`.

This is a one-shot install task. Do it, confirm it worked, and stop. Do not over-explain or add unrelated configuration.

## Step 1 — Detect OS and shell

Run a single Bash command to gather the facts you need:

    uname -s; echo "SHELL=$SHELL"; echo "MSYSTEM=$MSYSTEM"; echo "WSL=$WSL_DISTRO_NAME"

Interpret the output:

- `Darwin` → macOS
- `Linux` (with `WSL_DISTRO_NAME` set) → Linux inside WSL
- `Linux` → native Linux
- `MINGW*` / `MSYS*` / `CYGWIN*` → Git Bash or similar on Windows
- If `uname` is not available at all → assume Windows PowerShell

For the active shell, read `$SHELL` (zsh, bash, fish). If you cannot determine it, ask the user.

## Step 2 — Pick the right config file

| Shell | Config file |
|---|---|
| zsh (any OS) | `~/.zshrc` |
| bash on macOS | `~/.bash_profile` if it exists, otherwise `~/.bashrc` |
| bash on Linux / WSL / Git Bash | `~/.bashrc` |
| fish | `~/.config/fish/config.fish` |
| PowerShell | the path returned by running `pwsh -NoProfile -Command "$PROFILE"` (or `powershell.exe` on older systems). Create the parent directory if it does not exist. |

If the chosen file does not exist, create it.

## Step 3 — Check for existing alias (idempotency)

Before writing anything, grep the chosen file for `claude-yolo`. If it already exists, tell the user it is already installed and stop. Do not write a duplicate.

## Step 4 — Append the right line for the shell

Use a comment header so the user can find it later. Append (do not overwrite) the file.

**bash / zsh:**

    # Claude Code: launch with bypass permissions
    alias claude-yolo='claude --dangerously-skip-permissions'

**fish:**

    # Claude Code: launch with bypass permissions
    alias claude-yolo 'claude --dangerously-skip-permissions'

**PowerShell** (aliases cannot take arguments, so define a function):

    # Claude Code: launch with bypass permissions
    function claude-yolo { claude --dangerously-skip-permissions @args }

## Step 5 — Verify and report

1. Read the file back and confirm the line is present.
2. Print one short confirmation telling the user:
   - Which file you wrote to (full path)
   - That they need to **open a new terminal** (or run `source <file>` for bash/zsh, or `. $PROFILE` for PowerShell) to activate it
   - That from then on they can type `claude-yolo` to launch Claude Code in bypass mode
   - That bypass mode means **Claude will not ask for permission before running commands or editing files** — they should only use it when they are comfortable with that

## Things NOT to do

- Do not modify `~/.claude/settings.json` — that is a separate concern.
- Do not install any packages.
- Do not change the user's default shell.
- Do not add any other aliases or environment variables.
- Do not remove existing content from the config file.
- If `claude` itself is not on the user's PATH, mention it but do not try to fix it — that is outside this skill's scope.
