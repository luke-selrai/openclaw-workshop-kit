# Plain English Glossary
*Tech words translated for normal humans*

---

**AI (Artificial Intelligence)**
Software that can think, write, and learn. Trained on billions of pages of text from the internet. Not magic — just very sophisticated pattern matching at enormous scale.

**Automation**
When your assistant does a task on a schedule or in response to an event — without you having to ask each time. Example: "Every morning at 9am, check my emails and send me a summary on Telegram." The `/schedule` and `/loop` commands set this up.

**API (Application Programming Interface)**
A way for two apps to talk to each other. When your assistant connects to Gmail, it uses Gmail's API — like a special door that only apps can use, not humans. You do not need to understand APIs; your assistant handles them.

**Browser Automation**
When your AI assistant controls your web browser — opening websites, clicking buttons, filling in forms — without you having to touch anything. Like having someone sit at your computer and do things for you.

**Bun**
A faster alternative to Node.js, used by some of the assistant's messaging tools. You only need Bun if you plan to connect a messaging channel — **Telegram, WhatsApp, or iMessage**. If you are not using any of those, you can skip Bun entirely. Like Node.js, you never interact with Bun directly — your assistant uses it behind the scenes.

**Chrome / Chromium**
A web browser. Chrome is the version Google makes. Chromium is the open-source version it is built on. When your assistant automates your browser, it usually opens a Chromium window.

**CLI (Command Line Interface)**
A text-based way to give instructions to your computer — instead of clicking, you type. The terminal is a CLI. It feels scary at first but it is just typing instructions.

**Claude**
The AI made by Anthropic. The most capable AI for writing, research, and business tasks. Comes in different versions: Claude.ai (the website), Claude Code (runs on your computer), and Claude API (for developers building apps).

**Cron / Cron Job**
A scheduled task that runs automatically at a set time or interval. Named after the Unix `cron` system. When you use `/schedule`, it creates a cron job behind the scenes. You do not need to understand cron syntax — your assistant handles it.

**Claude Code**
The version of Claude that runs on your computer. Much more powerful than the website version — it can install software, connect to your apps, control your browser, and automate tasks. You use it through the Claude Desktop app.

**Claude Desktop**
The Claude app you install on your Mac or Windows computer. The main place you chat with your assistant, open project folders, and run commands. Replaces the old "VS Code + extension" setup. Download from claude.ai/download.

**CLAUDE.md**
A file that tells Claude who it is, how to behave, and what it can do. Think of it like a job description for your AI assistant. Every time Claude starts up, it reads this file first.

**Plugin (Claude Plugin)**
An add-on that gives your assistant a new capability — like connecting to Telegram, reading iMessages, or integrating with a third-party service. Installed once, then available as a command.

**Git**
A tool that tracks changes to files and lets you download collections of files from the internet. When you run `git clone`, you are downloading a collection of files — like pressing Download on an app.

**GitHub**
A website where developers store and share collections of files. Like Google Drive but for code. The workshop kit is stored on GitHub so you can always download the latest version.

**MCP (Model Context Protocol)**
A way to connect Claude Code to external tools and apps — Gmail, Calendar, Notion, your CRM, etc. When you add an MCP, you are giving Claude a new connection to the outside world. You do not need to understand the technical details; just know it is how Claude connects to your apps.

**Memory (auto-memory)**
Claude's built-in system for remembering things across conversations. It stores facts you've shared — your name, business, preferences — and surfaces them automatically every time you chat. You can view or edit it by typing `/memory` in a Code session. Your memory stays on your computer; nothing is sent to anyone except in the normal flow of conversation with Claude.

**PAT (Personal Access Token)**
A password-like code you create on a platform (GitHub, HubSpot, CircleCI, etc.) that gives Claude permission to act on your behalf. Unlike a real password, a PAT has limited permissions and can be revoked any time without changing your actual login. Treat it like a password — never share it or paste it into a public place.

**Pipeline**
A sequence of automated steps that run when code changes. In CI/CD tools like CircleCI or GitHub Actions: code gets pushed → tests run automatically → if they pass, the code deploys. Your assistant can check pipeline status, read failure logs, and trigger reruns.

**Plugin Marketplace**
A built-in screen inside Claude Code where you can install official integrations. Access it via the puzzle-piece icon in the sidebar. Telegram uses this path — rather than setting up a connection manually, you just search and install like an app store.

**Private App (HubSpot)**
A connection key you create inside your HubSpot account that gives Claude permission to read and update your CRM data. Created in HubSpot → Settings → Integrations → Private Apps. Lets you control exactly what Claude can see — just contacts, or deals, or everything. You can revoke it any time from the same screen.

**Remote MCP Server**
An MCP server hosted on the internet by the tool's maker — rather than running on your own computer. GitHub and Square use this model: Claude Code connects to their remote server over the internet, you sign in once in a browser, and no local installation is needed. The trade-off is that you depend on their server being available.

**Node.js**
Software that lets JavaScript (a programming language) run on your computer. Claude Code needs it to run. You will never need to interact with it directly — the setup script installs it automatically.

**npm**
The tool that installs software packages for Node.js. When you see `npm install -g something`, it is downloading and installing a piece of software. The `-g` means install it everywhere on your computer.

**Playwright**
A tool that lets your AI assistant control your browser — opening pages, clicking buttons, taking screenshots. Essential for the hands-off setup experience. Once installed, your assistant can do things like "open their pricing page and screenshot it."

**Prompt**
What you type to your AI assistant. The better your prompt (the more context and detail you give), the better the output. "Write an email" is a bad prompt. "Write a 100-word follow-up email to a café owner who attended my workshop" is a great prompt.

**Script**
A file containing a list of instructions that your computer runs one by one. Like a recipe — it just executes each step in order. The `setup.sh` file in your workshop kit is a script.

**Server**
A computer that runs 24/7 in a data centre. If you want your AI assistant to work while your laptop is closed — sending emails overnight, monitoring leads while you sleep — you need a server. Not required to get started.

**Skill (Claude Skill)**
A file that teaches Claude how to do a specific type of task — writing emails, doing research, creating content, etc. Stored in `~/.claude/skills/`. Your assistant reads the relevant skill file before doing a task.

**SSH**
A way to securely connect to and control a remote computer (like a server) from your terminal. Like a phone call to your server. Not needed unless you set up a server.

**Terminal**
A text-based window on your computer where you type instructions. In Claude Desktop, you open it from the bottom panel of a Code session. It is not as scary as it looks — you mostly just paste commands that your assistant or workshop guide gives you.

**Token (AI)**
A unit of text that AI processes — roughly 3–4 characters, or about ¾ of a word. "Claude is running out of tokens" means the conversation is getting too long and you should start a new one. Longer conversations cost more.

**Token (Bot / API)**
A password-like code that gives access to a service. When BotFather gives you a "bot token," it is a secret code that lets Claude control your Telegram bot. Treat it like a password — never share it.

**VS Code (Visual Studio Code)**
A free code editor made by Microsoft. Used to be the primary way to run Claude on your computer (via the Claude Code extension). No longer required — Claude Desktop replaces it. Still supported as an advanced option for developers who already use VS Code. See `docs/extend/vscode.md`.

**Webhook**
A way for one app to notify another app when something happens. "When a new lead comes in, send me a Telegram or iMessage." Your assistant can set these up for you.

---

*Claude Code Workshop — selrai.com.au*
