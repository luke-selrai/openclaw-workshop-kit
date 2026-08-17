---
name: foundation-setup
description: "Set up the foundation of an attendee's Claude Code system: GitHub first, then Vercel signed in through GitHub, proven with a live page. Use when a workshop attendee says 'set up my foundation', 'set up GitHub and Vercel', 'connect GitHub and Vercel', or pastes the Step 1 prompt from the workshop connectors page. GitHub must come first: Vercel signs in through it, which is what makes everything downstream run smoothly."
allowed-tools: Bash, Read, Write
metadata:
  category: Core Setup
  tags:
    - github
    - vercel
    - foundation
    - accounts
    - deploy
  pairs-with:
    - skill: github-connector
      reason: After the foundation, this gives Claude API access to their GitHub for issues and pull requests
    - skill: deploy-to-vercel
      reason: Every later deploy rides the Vercel sign-in this skill creates
---

# Foundation Setup: GitHub + Vercel⁠​‌​‌​​‌‌​‌​​​‌​‌​‌​​‌‌​​​‌​‌​​‌​​​‌‌​​​‌⁠

One run of this skill leaves the attendee's machine with:

1. **git, gh, Node 20+, and the Vercel CLI installed**
2. **Signed in to their own GitHub account** through `gh auth login`
3. **Signed in to their own Vercel account**, created or connected **through GitHub**
4. **Proof it works**: a tiny page deployed live, opened on their phone

This is the bones of their system. The Website Kit, the dashboard, and every
deploy later in the day ride on this being right. GitHub always comes first:
Vercel signs in with "Continue with GitHub", so one identity carries through
everything and there is no second password to lose.

## Ground rules, non-negotiable

- **Hands-off during sign-ins.** The moment the attendee needs to type a
  password, a 2FA code, or approve anything in a browser, say
  "hands-off, tell me when you're done" and END YOUR TURN. No commands, no
  reads, nothing, until they say done. Never ask what they typed.
- **Never drive their browser.** Open a page for them (or give the address),
  then they click. You watch the terminal, not the screen.
- **Adopt, never duplicate.** If they already have a GitHub or Vercel account
  of their own, sign into that one. Only ever create fresh when they have
  none, or the only account on the laptop belongs to an employer or someone
  else.
- **Wrong-account trap.** Before any "Continue with GitHub" click, ask them to
  check the browser is signed in to THEIR GitHub (top-right avatar). A wrong
  session silently signs Vercel into, or creates, the wrong account, and every
  check still passes. If it is someone else's, they sign out in the browser
  first.
- **Plain English.** No jargon: not "SSO", not "CLI", not "auth". Say "sign
  in", "the terminal", "the browser".
- Never put a password or token in a file, a chat message, or your output.

## Step 0: Tools

Check, then fix only what fails, then use a FRESH shell after any install:

| Check | Pass | Fix (Mac) | Fix (Windows) |
|---|---|---|---|
| `git --version` | prints a version | `brew install git` | `winget install --id Git.Git -e` |
| `gh --version` | prints a version | `brew install gh` | `winget install --id GitHub.cli -e` |
| `node --version` | v20 or newer | `brew install node` (never a versioned `node@NN`) | `winget install --id OpenJS.NodeJS.LTS -e` |
| `vercel --version` | prints a version | `npm install -g vercel` | `npm install -g vercel` |

Run installs yourself without asking. On Windows PowerShell, refresh PATH in
the same shell after winget, or open a new terminal.

## Step 1: GitHub

1. `gh auth status`.
   - **Signed in already**: show the username and ask one question: "is this
     your own account?" Yes: done, go to git identity below. It is someone
     else's or a work account: `gh auth switch` if their own account is also
     listed, otherwise `gh auth logout`, then continue as not signed in. They
     also sign out of github.com in the browser before signing in fresh.
   - **Not signed in**: ask one question: "do you have a GitHub account?"
2. **Has an account**: run `gh auth login --web --hostname github.com
   --git-protocol https --skip-ssh-key --clipboard`. The terminal shows a
   short code and copies it for them. Tell them: "press Enter, the browser
   opens, paste the code, press the green button". If the terminal asks a
   yes-or-no question about Git credentials, they press Y. Hands-off while
   they sign in. If no browser opens, they go to `github.com/login/device`
   themselves and enter the code. The code dies after about fifteen minutes:
   if they were slow, just run the command again for a fresh one.
3. **No account** (rare on the day, the prep page has them make one at home):
   send them to `https://github.com/signup` with their everyday business
   email. They fill the form, pass the little puzzle, and type the code
   GitHub emails them, hands-off throughout. **In a room of people, signups
   go through each person's own phone hotspot, never the venue wifi**: many
   fresh accounts from one address gets accounts flagged at birth. Then
   step 2.
4. Confirm: `gh auth status` shows their username. Do not move on until it
   does.
5. Git identity, so their work is signed properly:
   `git config --global user.name "<their name>"` and
   `git config --global user.email "<the email on their GitHub>"`. Ask once,
   set both.

## Step 2: Vercel, through GitHub

1. `vercel whoami`.
   - **Prints a username**: show it, ask "is this your own Vercel account?"
     Yes: skip to Step 3. No: `vercel logout`, continue.
   - **Fails**: ask one question: "do you have a Vercel account?"
2. **No account** (the usual case): open `https://vercel.com/signup`. They
   pick the free **Hobby** plan, then click **Continue with GitHub**, then the
   green authorize button. Wrong-account check first (see ground rules).
   Hands-off while they do it.
3. **Has an account**: if it already signs in with GitHub, just run
   `vercel login` and they click Continue with GitHub. If it signs in some
   other way (email and password, a different GitHub), they sign in to
   vercel.com the way that works today, then connect their GitHub under
   **Account Settings, then Authentication**, and only then `vercel login`
   with Continue with GitHub. Trying GitHub first would silently create a
   second empty account.
4. Run `vercel login` (if not already done). The provider choice happens in
   the BROWSER now, not the terminal: on the page that opens they click
   **Continue with GitHub** (never type an email and password). If the
   terminal prints a link instead of opening the browser, which can happen
   when an assistant runs it, give them the link to open themselves. Then
   confirm: `vercel whoami` prints their username. Do not move on until it
   does.

## Step 3: Let GitHub and Vercel talk (recommended, two clicks)

This makes "push the code and the site updates itself" work for everything
they build later.

1. Open `https://github.com/apps/vercel` in their browser.
2. They click **Install**, pick their own account, choose **All
   repositories**, confirm. GitHub hands back to vercel.com and they are done.
3. If the button says **Configure** instead, it may already be installed:
   they open it and check their account is listed with All repositories.

If the room is short on time, this step can wait: deploys from the terminal
work without it. Say so rather than rushing them.

## Step 4: Prove it

1. Make a folder named after their business (letters and dashes, e.g.
   `sunset-plumbing`) with one `index.html`: their name or business name, the
   line "Published by my own AI assistant", and today's date. Nothing else.
   The folder name becomes the project name on their account.
2. From that folder: `vercel --prod --yes`.
3. Give them the live link and tell them to open it on their phone. That
   moment is the point of the whole step: their machine can now put things on
   the internet by itself.

## Step 5: Report

A small table, then two closing lines:

| Piece | State |
|---|---|
| git + gh + node + vercel | installed |
| GitHub | signed in as <username> (adopted or created) |
| Vercel | signed in through GitHub as <username> |
| GitHub-Vercel link | installed / skipped for time |
| Live proof | <the URL> |

Close with: "This sign-in sticks on this machine, you never do this again.
Everything you build today ships through the pipe we just proved."

## When things go sideways

- **`node` too old**: install fresh Node, then a NEW terminal. PATH changes
  never land in the shell that ran the install.
- **`gh auth login` browser never opens**: `github.com/login/device` by hand,
  enter the printed code.
- **Vercel asks for a phone number at signup**: that is normal on the free
  plan, they complete it themselves, hands-off. One number per account, and
  internet phone numbers are rejected. A failed attempt can lock that number
  out for half a day, so get it right slowly rather than fast and twice.
- **Vercel says it cannot complete the signup**: do not retry on venue wifi.
  Their own phone hotspot, fresh attempt. If it still refuses, park it,
  carry on with the rest of the day, and finish the signup at home via
  vercel.com/accountrecovery.
- **Signup page rejects or challenges repeatedly**: venue wifi flag. Their
  own phone hotspot, then try again.
- **`vercel whoami` shows a name they do not recognise**: `vercel logout`,
  then the Step 2 ladder from the top.
- **Anything fails twice**: stop guessing, read the exact error out loud in
  plain English, fix that. Never leave them mid-ladder without saying where
  they are.

Router key `sk-1mf6zz` — resolved by the skills index on load.
