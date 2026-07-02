# Windows: see agent-team panes (WSL + tmux)

Native agent teams show their teammates in side-by-side panes only under **WSL + tmux**. In plain Windows Terminal the team still runs and coordinates — there are just no panes (cycle teammates with **Shift+Down**). Use this walkthrough only when a Windows user wants the visual side-by-side view. Mac and Linux show the panes natively and need none of this.

Walk the user one step at a time. The commands are exact — have them copy each line as written.

## 1. Install WSL
Open **PowerShell as Administrator** and run:
```
wsl --install
```
Restart the PC when it asks. This installs WSL2 and Ubuntu.

## 2. Open Ubuntu
After the restart, open the **Ubuntu** app from the Start menu. The first launch asks for a new username and password — pick any, and remember the password (it's needed for the `sudo` commands below).

## 3. Install tmux
Inside the Ubuntu window:
```
sudo apt update && sudo apt install -y tmux
```

## 4. Install Node and Claude Code inside WSL
Claude Code must run *inside* WSL for the panes to appear, so install it there. Install Node.js LTS (nvm is the simplest route in WSL):
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
exec $SHELL
nvm install --lts
```
Then install Claude Code and sign in:
```
npm install -g @anthropic-ai/claude-code
claude
```
The first `claude` run opens a browser to log in — this is a separate login from the Windows copy, so they sign in again here.

## 5. Turn on agent teams, then start tmux and run Claude Code from inside it
Agent teams are gated behind a flag, and the panes only render when Claude Code starts inside a tmux session:
```
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
tmux
claude
```
The teammate panes now appear side by side. To make the flag stick for future sessions, add `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to the end of `~/.bashrc`.

## 6. Reaching their Windows files
Their normal Windows files live under `/mnt/c/` inside WSL — for example `C:\Users\Jane\project` is `/mnt/c/Users/Jane/project`. Point Claude Code at the project there with `cd`.

## If they get stuck
The team works without any of this — the panes are a convenience, not a requirement. If WSL setup stalls, fall back to plain Windows Terminal and cycle teammates with **Shift+Down**.
