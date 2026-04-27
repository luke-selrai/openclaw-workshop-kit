---
name: meta-business-suite-connector
description: "Read and publish Instagram Business and Threads content on behalf of the user via the @mikusnuz/meta-mcp server. Handles Instagram publishing (photos, videos, carousels, Reels, stories), media management, comments and replies, profile and account insights, hashtag search, mentions, and DMs. Also handles Threads publishing (text, image, video, carousels, polls, link attachments), replies, search, profile, and post insights. Plus Meta platform token management (exchange short-lived tokens for long-lived ones, refresh, debug). Use this skill when the user asks about their Instagram Business, Threads, scheduling or publishing posts, Reels, stories, comments, DMs on Instagram, post analytics, hashtag research, or when they say 'connect my Instagram', 'install the Meta Business Suite connector', 'help me set up Instagram', 'connect Threads', or 'help me post to Instagram'. On the first use of any Instagram or Threads feature, run Phase 1 to wire the MCP server into Claude Code before attempting any tool calls. Does NOT cover Meta Ads (use lukeselr/meta-ads-mcp-setup for that) or Facebook Page organic posting (separate connector, not yet built)."
allowed-tools: mcp__meta__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - instagram
    - threads
    - meta
    - social-media
    - publishing
    - mcp
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Meta access tokens or Graph API errors
    - skill: canva-connector
      reason: Generate the image/video/Reel cover, then publish through this skill
    - skill: ad-creative
      reason: Draft the post copy and creative concept, then publish through this skill
---

# Meta Business Suite Connector

## Overview

This skill lets you read and publish a user's **Instagram Business** and **Threads** content on their behalf using the **community [`@mikusnuz/meta-mcp`](https://github.com/mikusnuz/meta-mcp)** server (npm-published, MIT-licensed, MCP SDK v1.26+, Graph API v25.0). It has two phases:

- **Phase 1 — Install & Connect.** A conversational bootstrap (≤6 steps). The user has never used this before. You walk them through preparing their Meta accounts, creating a Meta Developer App, generating a long-lived access token, and wiring the MCP server into Claude Code. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "env var", "Graph API", or any file paths. They should feel like they are having a conversation, and at the end their Instagram is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__meta__*` native tools to read and publish. The server exposes **57 tools** across Instagram (33), Threads (18), and Meta platform token management (6). All 57 are documented in the Phase 2 tables below.

**Which phase to run** — Before any tool call, check whether the Meta MCP server is already configured. Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.meta` entry with `INSTAGRAM_ACCESS_TOKEN` and `INSTAGRAM_USER_ID` (or, if the user only wants Threads, `THREADS_ACCESS_TOKEN` and `THREADS_USER_ID`) in its `env` block. If the relevant pair exists and is non-empty, treat the connector as configured and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT cover

- **Meta Ads (paid campaigns, ad sets, audiences, creatives, insights for paid spend).** Use Luke's [`lukeselr/meta-ads-mcp-setup`](https://github.com/lukeselr/meta-ads-mcp-setup) for that. The two skills can coexist — they wrap different MCP servers and use different tokens.
- **Facebook Page organic posting.** This skill is intentionally Instagram + Threads only. A separate `facebook-page-connector` is the right home for that surface and has not been built yet.
- **Personal Instagram accounts.** The Graph API only supports Business and Creator accounts. The user must convert (free, takes 30 seconds in IG settings) before this skill works. Phase 0 catches this.
- **Messenger / Facebook Page DMs.** This skill exposes Instagram DMs only.
- **Cross-posting from Instagram to Facebook.** That is a per-post toggle in the Instagram app and is not exposed via Graph API publishing endpoints.

---

## Phase 0 — Pre-flight check (BEFORE the safety gate)

Before anything else, confirm the user has the right kind of account on the right platform. These three checks save 20 minutes of dead-end troubleshooting later. Ask one at a time, wait for each answer.

**Say this verbatim (or close to it):**

> "Quick check before we start, I need to make sure your account setup will work. Three short questions:"
>
> "**1.** Is your Instagram a **Business** or **Creator** account, or a personal one? (If you're not sure, open Instagram on your phone, go to your profile, tap Settings, and look for 'Account type'. Personal accounts won't work, but switching is free and takes about 30 seconds.)"

Wait for the answer.

- **User says Business or Creator** → proceed to question 2.
- **User says Personal** → tell them: *"All good. Open Instagram on your phone, go to Settings, then 'Account type and tools', and tap 'Switch to professional account'. Pick Business or Creator. Tell me when you're done."* Wait for confirmation, then go to question 2.
- **User says they don't have Instagram at all** → tell them: *"No worries, this skill needs an Instagram Business account to work. If you'd like to set one up first, that's a separate task. Otherwise we can skip Instagram and just connect Threads, if you have a Threads account. Want to do that?"* Branch to Threads-only setup if yes; stop if no.

> "**2.** Is your Instagram Business account **linked to a Facebook Page**? (Meta requires this. It's a one-time link in Instagram settings. Most Business accounts already have it.)"

Wait for the answer.

- **User says yes** → proceed to question 2b.
- **User says no or doesn't know** → tell them: *"That's the next step then. On your phone, open Instagram, tap your profile, go to Settings, find 'Linked accounts' or 'Account Center', and link your Facebook Page. If you don't have a Facebook Page, you'll need to create one. It can be a simple one and you don't need to use it. Tell me when it's linked."* Wait for confirmation, then go to question 2b.

> "**2b.** When you switched your Instagram to Business and linked it to a Page, did you finish the link from the Facebook side too? On a desktop browser, open your Facebook Page, go to **Settings**, then find **Linked Accounts** or **Instagram**, and confirm your Instagram account is showing as connected there. (Some accounts get the Instagram-side toggle but never the Facebook-side confirmation, and Meta's API treats them as unlinked.)"

Wait for the answer.

- **User confirms** → proceed to question 3.
- **User says they don't see it linked on the Facebook side** → walk them through the Page Settings → Linked Accounts → Instagram → Connect flow. If they cannot complete the link (e.g., Instagram-side ownership mismatch), stop here and tell them this needs to be sorted in Meta Business Suite before the connector can work.

> "**3.** Will you also want to post to **Threads**? (Threads is separate from Instagram for tokens, but I can set both up in one go if you want.)"

Wait for the answer. Remember it for Step 4 of Phase 1.

Only proceed past Phase 0 when the user has a Business or Creator IG account linked to a Facebook Page (or has confirmed Threads-only setup).

---

## ⚠️ Safety gate — run this BEFORE Phase 1 Step 1

Two real constraints the user must acknowledge before you touch anything. These are non-negotiable and need to be raised in plain English, upfront, with explicit confirmation.

**Say this verbatim (or very close to it) and wait for the user's answer:**

> "Two more quick things you need to know about connecting Instagram to me:"
>
> "**1. Token expiry.** The connection key Meta gives me lasts about **60 days**. After that you'll need to refresh it. I can do the refresh for you in one command when the time comes, but I can't do it silently behind your back, so it's worth knowing."
>
> "**2. What I can do.** Once connected, I'll be able to **post, edit, and delete content** on your Instagram, **reply to and hide comments**, and **read your DMs**. That's a lot of authority. Are you comfortable with that?"
>
> "If yes, we'll start. If you want to limit any of those, tell me which and I'll set it up with narrower permissions."

**Handle the response:**

- **User confirms both** → proceed to Step 1.
- **User wants narrower scope** → say: *"Good instinct. Tell me which of the three you want to drop (posting, comment moderation, or DM access) and I'll leave that permission out of the connection. We can always add it back later."* Then proceed to Step 1, remembering to omit the corresponding permissions in Step 3.
- **User is hesitant** → say: *"Totally fair. Want me to walk you through what each permission actually lets me do before you decide?"* Answer questions if asked, then wait for clear consent before proceeding.
- **User refuses** → say: *"No problem, we can skip Instagram for now. If you change your mind later, just say 'connect my Instagram' and we'll pick this back up."* Do not proceed.

Only proceed past this gate when the user has explicitly confirmed they're okay with the authority level.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, environment variable, Graph API, or app secret as a technical concept. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer", "the connection details".
- **Tell them what is about to happen.** Before any action you take: "I'm going to save your connection details now, this takes just a moment."
- **React warmly.** Good: "That worked, your Instagram is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem, let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **No em dashes in italicised user-facing strings.** Em dashes are fine in section headings and Claude-facing prose, but the user-visible italic quotes above use commas or full stops instead.

---

## PHASE 1 — Install & Connect (≤6 steps)

This phase gets the Meta Developer App created, the long-lived access token generated, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only clicks things in their browser and pastes a few values.

### Step 1 — Orient the user

Tell the user in one short message:

> "Great, let's connect your Instagram. I'll walk you through creating a small connection in Meta's developer area, then I'll save it on your computer and check everything is talking. The Meta part takes about five minutes."

### Step 2 — Walk the user through creating a Meta Developer App

The user needs to create a Meta Developer App and add the Instagram Graph API product. You cannot do this for them — Meta requires their authenticated session.

Tell the user, one instruction at a time, waiting for confirmation between each:

1. "Please open this page in your browser: **https://developers.facebook.com/apps** — and sign in with the Facebook account that owns your Facebook Page. Let me know when you are signed in."

2. When they confirm → "Click the green **Create app** button (top right). Meta will ask you a few questions to set up the app."

3. When they're on the create-app form → deliver the field values:
   - "For **App name**, type: **Claude Assistant**."
   - "For **App contact email**, use your own email."
   - "For **Use case**, choose: **Other**. Then click Next."
   - "For **App type**, choose: **Business**. Then click Next."
   - "For **Business portfolio**, pick the one linked to your Facebook Page (or skip if Meta lets you). Then click **Create app**."

4. When they confirm the app was created → "You should now be on your app's dashboard. On the left side, find **App settings**, click **Basic**, and you'll see two values near the top: **App ID** and **App secret** (you'll need to click 'Show' next to App secret and confirm your password). Please copy the **App ID** and paste it to me."

5. When they paste the App ID → "Thanks. Now click 'Show' next to **App secret**, copy the long string, and paste it to me. Don't worry about remembering it, I'll save it for you and never show it back."

6. When they paste the App secret → "Last app step: on the left sidebar, click **Add product** (or 'Products') and add **Instagram Graph API**. Click 'Set up' next to it. Tell me when Instagram Graph API shows up in your sidebar."

### Step 3 — Generate the long-lived access token

This is the trickiest part for non-technical users. We use Meta's Graph API Explorer because it lets the user generate a real token without writing any code.

Tell the user, one instruction at a time:

1. "Now open this page in a new tab: **https://developers.facebook.com/tools/explorer/**. Tell me when it loads."

2. When they confirm → "At the top right, you'll see an **Application** dropdown. Click it and select **Claude Assistant** (the app you just made)."

3. When they confirm → "Just below that, click **Generate Access Token** and sign in with the Facebook account that owns your Page. A permissions dialog will appear."

4. When they see the permissions dialog → "Tick all of these permissions (you'll find them in the list, scroll if needed):
   - **instagram_basic**
   - **instagram_content_publish**
   - **instagram_manage_comments**
   - **instagram_manage_insights**
   - **instagram_manage_messages** (only if you want me to read DMs, skip if you're keeping that off)
   - **pages_show_list**
   - **pages_read_engagement**
   
   Then click **Continue as [your name]** and approve."

   > *(If the user chose to drop a scope at the safety gate, omit the matching permission(s) from this list. Posting needs `instagram_content_publish`; comment moderation needs `instagram_manage_comments`; DMs need `instagram_manage_messages`.)*

   > **Auth-flow note (Claude-facing).** This skill uses the **Facebook-Login flow** (the user signs into Graph API Explorer with the FB account that owns the Page). Under that flow, the scope names listed above are the correct ones. If a user is later moved to the **Instagram-Login flow** (a separate Meta product where IG users sign in directly without a linked FB Page), the scope names change: `instagram_manage_messages` becomes `instagram_business_manage_messages`, and `instagram_manage_insights` becomes `instagram_business_manage_insights`. This skill does not currently cover the IG-Login path; if a user reports they have no FB Page, return to Phase 0 question 2 rather than substituting scope names.

5. When they confirm → "Back in Graph API Explorer, you should now see a long string in the **Access Token** field. Copy that whole string and paste it to me. (This is a short-lived token. I'll upgrade it to a long-lived one in the next step. Don't worry, I'll handle that part.)"

6. When they paste the short-lived token → silently call the Meta token-exchange endpoint to upgrade it to a long-lived (60-day) token. Use this `curl`-equivalent (run via `Bash`):
   ```
   curl -s "https://graph.facebook.com/v25.0/oauth/access_token?grant_type=fb_exchange_token&client_id=<APP_ID>&client_secret=<APP_SECRET>&fb_exchange_token=<SHORT_LIVED_TOKEN>"
   ```
   Parse the JSON, capture `access_token`. This is the long-lived token.

   **Common mistakes to handle:**
   - **`{"error":{"code":190,...}}` — token invalid or expired** → ask the user to redo Step 3 from part 3 (the short-lived token expires in ~1 hour).
   - **Response contains `OAuthException` with `Error validating application` or `Invalid OAuth access token signature`** → ask the user to recopy the App secret from Step 2 part 5; the secret in the curl call did not match the one Meta has on file.

7. When the long-lived token is in hand → call:
   ```
   curl -s "https://graph.facebook.com/v25.0/me/accounts?access_token=<LONG_LIVED_TOKEN>"
   ```
   This returns the list of Pages the user manages. Find the one with the Instagram Business account. Then call:
   ```
   curl -s "https://graph.facebook.com/v25.0/<PAGE_ID>?fields=instagram_business_account&access_token=<LONG_LIVED_TOKEN>"
   ```
   Capture the Instagram Business Account ID from the response.

   **Common mistakes to handle:**
   - **No Pages returned** → the user signed into Graph API Explorer with the wrong Facebook account. Ask them to redo Step 3 part 3 with the account that admins their Page.
   - **`instagram_business_account` is null** → the Instagram account is not linked to that Page. Loop back to Phase 0 question 2.
   - **Multiple Pages with IG accounts** → ask the user *"You manage [N] Pages with Instagram. Which one should I connect: [list names]?"* Use their answer.

### Step 4 — (Optional) Generate a Threads token

Only run this step if the user said yes to Threads in Phase 0 question 3. Otherwise skip to Step 5.

Threads has a separate token flow because it uses a different API surface.

Tell the user, one instruction at a time:

1. "For Threads, we need a separate connection because Threads is technically its own app. Open this in a new tab: **https://developers.facebook.com/apps**, same as before."

2. "Find your **Claude Assistant** app, open it, then click **Add product** in the sidebar and add **Threads API**."

3. When they confirm Threads API is added → "Open Graph API Explorer again at **https://developers.facebook.com/tools/explorer/**. In the **Application** dropdown, your app should still be selected. Click **Generate Access Token** again and tick these permissions: **threads_basic**, **threads_content_publish**, **threads_manage_replies**, **threads_read_replies**, **threads_manage_insights**, **threads_keyword_search**, **threads_delete**. Then approve and copy the new token."

   > *(Drop `threads_keyword_search` if the user does not want public-post search; drop `threads_delete` if they don't want delete authority. The `threads_*` tools that need each scope are noted in the Phase 2 tables.)*

4. When they paste the short-lived Threads token → silently exchange it for a long-lived one using the same `fb_exchange_token` endpoint as Step 3 part 6.

5. Capture the Threads user ID by calling:
   ```
   curl -s "https://graph.threads.net/v1.0/me?fields=id,username&access_token=<LONG_LIVED_THREADS_TOKEN>"
   ```
   The `id` field is the Threads user ID.

### Step 5 — Save the credentials

Once you have the long-lived Instagram access token + Instagram Business Account ID (and optionally the Threads token + Threads user ID), silently add or update the Meta MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The structure to add:

```json
{
  "mcpServers": {
    "meta": {
      "command": "npx",
      "args": ["-y", "@mikusnuz/meta-mcp@latest"],
      "env": {
        "INSTAGRAM_ACCESS_TOKEN": "<long-lived IG token from Step 3>",
        "INSTAGRAM_USER_ID": "<IG Business Account ID from Step 3>",
        "META_APP_ID": "<App ID from Step 2>",
        "META_APP_SECRET": "<App secret from Step 2>"
      }
    }
  }
}
```

If the user opted into Threads, also include:

```json
        "THREADS_ACCESS_TOKEN": "<long-lived Threads token from Step 4>",
        "THREADS_USER_ID": "<Threads user ID from Step 4>"
```

**Rules:**
- Merge into the existing `mcpServers` object rather than overwriting it. Preserve every other `mcpServers` entry the user already has.
- If `~/.claude.json` does not exist, create it with just the Meta entry.
- **If the file exists but cannot be parsed as JSON, STOP. Do not write.** Back it up to `~/.claude.json.backup` first, then tell the user in plain English: *"Your settings file looks corrupted. I can rebuild it from scratch, but you'll lose any other connections you had set up (like Xero, HubSpot, etc.) and need to reinstall those. I've saved a backup at `~/.claude.json.backup` either way. Want me to rebuild, or stop here so you can recover the file manually first?"* Wait for explicit confirmation before writing the fresh config. **Never silently destroy the user's existing config.**
- Never echo any access token, App ID, or App secret back to the user after writing them. Never include them in any output visible to the user.
- File permissions: on Mac/Linux, ensure `~/.claude.json` is mode `600` (user-read-write only). On Windows, the default user-profile ACL is sufficient.

Tell the user in one short message:

> "I've saved your connection details. One more step: you'll need to close Claude Code and open it again so it picks up the new connection. Do that now, and tell me when you're back."

### Step 6 — Verify the connection

Wait for the user to restart. When they return, tell them: *"Welcome back. Let me just check that everything is talking to Instagram."*

Call the `mcp__meta__ig_get_profile` tool (no arguments). Handle the response:

- **Tool returns profile info with username** → Capture the username. Tell the user:
  > "All done! I'm now connected to your Instagram **@[username]**. You can ask me things like 'show me my recent posts', 'post this photo to Instagram', 'what's the engagement on my last Reel', or 'reply to that comment'. Give it a try!"

  If Threads was also configured, also call `mcp__meta__threads_get_profile` and confirm Threads is alive in the same message.

- **Tool returns `Invalid OAuth access token` or `190` error code** → "Hmm, the connection key didn't work — let me take it again." Silently go back to Step 3 and regenerate the short-lived token + re-exchange. Rewrite `~/.claude.json` with the fresh values, ask them to restart Claude Code, and try Step 6 again.

- **Tool returns `Permissions error` or `200` error code (insufficient permissions)** → "Your connection is working, but I need one or two extra permissions. Let me show you which boxes to tick." Guide the user back to Graph API Explorer (Step 3 part 3), regenerate with the missing permission ticked, re-exchange for a long-lived token, rewrite `~/.claude.json`, and re-verify. **Restart of Claude Code IS needed** for new tokens — unlike Xero's scope additions which apply server-side without env changes, Meta's tokens are env-var-injected at MCP server boot, so any token rewrite requires a Claude Code restart to pick up the new env.

- **Tool is not yet available (`mcp__meta__*` tools not discoverable)** → "Looks like Claude Code didn't pick up the new connection yet. Please make sure you fully closed it (not just the window) and opened it again, then let me know." Repeat Step 5's restart instruction.

- **Any other error** → "Something's not quite right, let me try once more." Retry the tool call once. If it still fails, tell the user in plain English what you saw (translated, never raw errors), and ask if they want to retry or stop.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__meta__*` MCP tools below. The server exposes **57 tools total** across Instagram (33), Threads (18), and Meta platform token management (6). All 57 are catalogued in the tables that follow; resources (`instagram://profile`, `threads://profile`) and prompts (`content_publish`, `analytics_report`) are also exposed by the server but are not surfaced as tools — see [the maintainer's `llms.txt`](https://github.com/mikusnuz/meta-mcp/blob/main/llms.txt) for those.

### Instagram — Publishing

| Tool | Description | Use when |
|---|---|---|
| `ig_publish_photo` | Publish a photo post (supports `alt_text`) | User asks to post a photo to Instagram |
| `ig_publish_video` | Publish a video post | User asks to post a video to Instagram |
| `ig_publish_carousel` | Publish a carousel/album (2–10 items, `alt_text` per item) | User asks to post multiple photos/videos as one post |
| `ig_publish_reel` | Publish a Reel (supports `alt_text`) | User asks to post a Reel |
| `ig_publish_story` | Publish a Story (24-hour) | User asks to post a Story |
| `ig_get_container_status` | Check media container processing status | After publishing video/Reel, before assuming it's live |

### Instagram — Media

| Tool | Description | Use when |
|---|---|---|
| `ig_get_media_list` | List published media | User asks "show me my recent posts" |
| `ig_get_media` | Get media details | User asks about a specific post |
| `ig_delete_media` | Delete a media post | User asks to delete a post — **confirm first** |
| `ig_get_media_insights` | Get media analytics (views, reach, saved, shares) | User asks about post performance |
| `ig_toggle_comments` | Enable/disable comments on a post | User asks to lock comments on a post |

### Instagram — Comments

| Tool | Description | Use when |
|---|---|---|
| `ig_get_comments` | Get comments on a post | User asks to see comments on a post |
| `ig_get_comment` | Get comment details | User asks about a specific comment |
| `ig_post_comment` | Post a comment on a post | User asks to comment on a post — **confirm first** |
| `ig_get_replies` | Get replies to a comment | User asks to see replies under a comment |
| `ig_reply_to_comment` | Reply to a comment | User asks to reply to a comment — **confirm first** |
| `ig_hide_comment` | Hide/unhide a comment | User asks to hide a negative comment |
| `ig_delete_comment` | Delete a comment (own comments only) | User asks to delete their own comment — **confirm first** |

### Instagram — Profile & Insights

| Tool | Description | Use when |
|---|---|---|
| `ig_get_profile` | Get account profile info | Verifying connection or showing account stats |
| `ig_get_account_insights` | Account-level analytics (views, reach, follower_count) | User asks "how is my account doing?" |
| `ig_business_discovery` | Look up another business account by username | User asks "what's @competitor's stats?" |
| `ig_get_collaboration_invites` | Get pending collaboration invites | User asks about collab requests |
| `ig_respond_collaboration_invite` | Accept or decline collaboration invite | User asks to accept/decline a collab — **confirm first** |

### Instagram — Hashtags

| Tool | Description | Use when |
|---|---|---|
| `ig_search_hashtag` | Search hashtag by name | Hashtag research |
| `ig_get_hashtag` | Get hashtag info | Detail on a specific hashtag |
| `ig_get_hashtag_recent` | Get recent media for a hashtag | "Show me recent posts for #[tag]" |
| `ig_get_hashtag_top` | Get top media for a hashtag | "Show me top posts for #[tag]" |

### Instagram — Mentions, Tags & Messaging

| Tool | Description | Use when |
|---|---|---|
| `ig_get_mentioned_comments` | Get comments mentioning you | "Who mentioned me recently?" |
| `ig_get_tagged_media` | Get media you're tagged in | "Show me posts I'm tagged in" |
| `ig_get_conversations` | List DM conversations | "Show me my DMs" |
| `ig_get_messages` | Get messages in a conversation | Reading a specific DM thread |
| `ig_send_message` | Send a DM | User asks to send a DM — **confirm first** |
| `ig_get_message` | Get message details | Reading a specific message |

### Threads — Publishing

| Tool | Description | Use when |
|---|---|---|
| `threads_publish_text` | Publish text post (polls, GIFs, link attachments, topic tags, quote, spoiler) | User asks to post text to Threads |
| `threads_publish_image` | Publish image post (alt_text, topic tags, spoiler) | User asks to post image to Threads |
| `threads_publish_video` | Publish video post (alt_text, topic tags, spoiler) | User asks to post video to Threads |
| `threads_publish_carousel` | Publish carousel (2–20 items, alt_text per item) | User asks to post multiple items to Threads |
| `threads_delete_post` | Delete a Threads post (maintainer notes a 100/day cap; verify against current Meta policy before bulk deletes) | User asks to delete a thread — **confirm first** |
| `threads_get_container_status` | Check container processing status | After publishing, before assuming it's live |
| `threads_get_publishing_limit` | Check remaining quota (250 posts/day) | Before bulk publishing |

### Threads — Read, Replies & Insights

| Tool | Description | Use when |
|---|---|---|
| `threads_get_posts` | List published posts | "Show me my recent threads" |
| `threads_get_post` | Get post details | Detail on a specific thread |
| `threads_search_posts` | Search public posts by keyword or topic tag | Research |
| `threads_get_replies` | Get replies to a post | "Who replied to my thread?" |
| `threads_reply` | Reply to a post (supports image/video attachments) | User asks to reply to a thread — **confirm first** |
| `threads_hide_reply` | Hide a reply | User asks to hide a reply |
| `threads_unhide_reply` | Unhide a reply | User asks to unhide |
| `threads_get_profile` | Get Threads profile info | Verifying Threads connection |
| `threads_get_user_threads` | List threads for an arbitrary user_id (defaults to connected user when omitted) | Use when the user asks for someone else's public threads by user_id; for the connected user use `threads_get_posts` instead |
| `threads_get_post_insights` | Post analytics (views, likes, replies, reposts, quotes, clicks) | User asks about post performance |
| `threads_get_user_insights` | Account-level analytics | User asks "how is my Threads doing?" |

### Meta Platform — Token & App management

| Tool | Description | Use when |
|---|---|---|
| `meta_exchange_token` | Exchange short-lived token for long-lived (~60 days) | After regenerating a token in Graph API Explorer |
| `meta_refresh_token` | Refresh a long-lived token before expiration | At the 50-day mark, to extend another 60 days |
| `meta_debug_token` | Inspect token validity, expiration, and scopes | Troubleshooting auth errors |
| `meta_get_app_info` | Get Meta App information | Verifying app config |
| `meta_subscribe_webhook` | Subscribe to webhook notifications | Setting up event-driven workflows |
| `meta_get_webhook_subscriptions` | List current webhook subscriptions | Auditing what events are wired up |

> **Note:** This skill documents all 57 tools above. The server also exposes resources (`instagram://profile`, `threads://profile`) and prompts (`content_publish`, `analytics_report`) which are not surfaced as tools. Consult [the maintainer's `llms.txt`](https://github.com/mikusnuz/meta-mcp/blob/main/llms.txt) for those.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Instagram" / "Install the Meta Business Suite connector" | **Run Phase 1** (starting with Phase 0 pre-flight, then the safety gate) |
| "Connect Threads" | **Run Phase 1**, but skip directly to Step 4 if Instagram is already configured |
| "Post this photo to Instagram" | `ig_publish_photo` — **confirm first** |
| "Post a Reel" | `ig_publish_reel` — **confirm first** |
| "Post a carousel" | `ig_publish_carousel` — **confirm first** |
| "Post a story" | `ig_publish_story` — **confirm first** |
| "Show me my recent posts" | `ig_get_media_list` |
| "How did my last Reel do?" | `ig_get_media_insights` on the latest video |
| "What's my account growth?" | `ig_get_account_insights` |
| "Show me comments on [post]" | `ig_get_comments` |
| "Reply to that comment" | `ig_reply_to_comment` — **confirm first** |
| "Hide that troll comment" | `ig_hide_comment` |
| "Show me my DMs" | `ig_get_conversations` |
| "Reply to [name]'s DM" | `ig_send_message` — **confirm first** |
| "Top posts for #[tag]" | `ig_get_hashtag_top` |
| "What's @[competitor] doing?" | `ig_business_discovery` |
| "Who mentioned me?" | `ig_get_mentioned_comments` |
| "Post this to Threads" | `threads_publish_text` (or `_image` / `_video`) — **confirm first** |
| "Reply to that thread" | `threads_reply` — **confirm first** |
| "How is my Threads doing?" | `threads_get_user_insights` |
| "Refresh my connection key" | `meta_refresh_token` |
| "Is my connection still valid?" | `meta_debug_token` |

---

## Error Handling (Phase 2)

When a Meta tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say to the user | How to fix |
|---|---|---|
| `Invalid OAuth access token` / error code `190` | "Your Instagram connection key has expired or been revoked, let me sort that now." | Run Phase 1 from Step 3 (regenerate short-lived token, re-exchange, rewrite `~/.claude.json`, restart). If repeats, check `meta_debug_token` for clues. |
| Error code `200` (insufficient permissions) | "I need one extra permission for that, let me show you which box to tick." | Run Phase 1 from Step 3 with the missing scope ticked, re-exchange, rewrite, restart. The Graph API Explorer dialog determines scopes — they cannot be added on the fly. |
| Error code `4` (App-level rate cap, rare) | "Meta is asking me to slow down at the app level. I'll wait a moment and try again." | Wait 60 seconds and retry once. Code 4 is the app-wide cap, almost never hit by a workshop user. |
| Error code `17` (user-level throttling) / Error code `32` (Page-level throttling) | "Meta is asking me to slow down on this account. I'll wait a moment and try again." | Wait 60 seconds and retry once. If still throttled, fall back to the BUC budget guidance below in Phase 2 Behaviour Guidelines. |
| Error code `10` (permission denied) | "I'm not allowed to do that, let me check why." | Cause is one of: (a) the scope was never granted on the token, (b) it was revoked in Meta settings, or (c) in production mode the feature requires Meta App Review. Workshop users on dev mode are exempt from App Review **as long as they are listed as a Tester** on the app's Roles → Testers list. Diagnose with `meta_debug_token`. |
| Error code `100` (invalid parameter) | Summarise which field is invalid in plain English (e.g., *"Instagram says the image URL isn't reachable, let me fix it and try again"*) | Correct the request and retry once. Common: image URL not publicly accessible, Reels exceed 15-minute max or are below 3-second min, carousel mixing photos and videos in unsupported order. |
| Container `status_code: ERROR` after publish | "Instagram couldn't process the media, let me check what went wrong." | Call `ig_get_container_status` and read the `error_message`. Common: bitrate too high (Reels max 25Mbps video bitrate), aspect ratio outside the 0.01:1–10:1 Reels range or 4:5–1.91:1 feed-post range, file size over 300MB, or unsupported codec (Reels need H.264 or HEVC + AAC). |
| `OAuthException` with `Error validating application` in the message | "Your App secret didn't validate, let me recheck it." | Re-run Step 2 part 5 to recopy the App secret. Compare to what's in `~/.claude.json`. |
| Daily publishing limit hit (Instagram: 100/day, Threads: 250/day) | "You've hit Meta's daily posting limit. Try again tomorrow or pace your posts." | No fix — the limit is real. Carousels count as 1 toward the 100/day Instagram cap. Defer to next 24-hour window. |
| MCP server not discovered (`mcp__meta__*` tools missing) | "The Meta connection isn't active in this session. Please close Claude Code fully and reopen it, then try again." | User restarts Claude Code. |
| Any other Graph API error | "Something went wrong with Meta, let me try again." | Retry once; if still failing, run `meta_debug_token` to inspect token state. |

---

## Security Assessment

This skill grants broad publishing and read authority over the user's Instagram Business and Threads accounts. The risks below are catalogued so the safety gate, scope-narrowing offer, and Phase 2 confirmation prompts can defend against them.

| # | Risk | Likelihood | Impact | Mitigation in this skill |
|---|---|---|---|---|
| 1 | **Token theft via leaked `~/.claude.json`.** Long-lived token grants 60-day full-account access if exfiltrated. | Medium | High (attacker can post, delete, DM as the user) | File permissions guidance in Step 5 (mode `600` on Mac/Linux). Token never echoed back. Encourage user to enable filesystem encryption. Recommend `meta_refresh_token` rotation if the file is ever shared. |
| 2 | **App secret leak.** `META_APP_SECRET` is in `~/.claude.json` — required for token-management tools but enables impersonation if stolen. | Low | High (attacker can mint new tokens) | Step 5 stores it alongside the token (same file, same protection). Note: app secret is not strictly required for IG/Threads runtime tool calls, only for `meta_*` token tools (`meta_exchange_token`, `meta_refresh_token`, `meta_debug_token`, `meta_subscribe_webhook`). **Optional hardening:** if the user does not plan to use those tools after install, omit `META_APP_SECRET` from `~/.claude.json` and paste it back temporarily when refreshing or debugging. **Caveat:** removing `META_APP_SECRET` disables Phase 2 troubleshooting via `meta_debug_token`. If the user relies on that error-handling path, leave the secret in place. |
| 3 | **Unauthorised content publishing.** Anyone with shell access can call `ig_publish_*` to post anything to the user's account. | Medium | High (brand damage, legal exposure for offensive content) | Phase 2 publishing tools all require **explicit confirmation**. The skill never auto-publishes. Recommend pairing with `~/.claude.json` filesystem encryption. |
| 4 | **Comment moderation abuse.** Token holder can hide/delete legitimate user comments — the user may not notice. | Medium | Medium (silenced critics, hidden customer complaints) | `ig_hide_comment` and `ig_delete_comment` are noted as confirm-first. Skill instructs Claude to summarise the comment text before hiding/deleting. |
| 5 | **DM exfiltration.** With `instagram_manage_messages`, all Messenger/IG inbox content is readable. Includes private customer data. | Medium | High (privacy breach, potential GDPR/Privacy Act exposure for AU clients) | Safety gate offers to drop `instagram_manage_messages`. If dropped, `ig_send_message` and `ig_get_*` message tools fail at runtime — the skill should detect a `permissions` error and explain. |
| 6 | **Account takeover.** Long-lived tokens cannot be revoked silently — they appear in the user's Meta security settings. | Low | High | The safety gate explicitly tells the user about token authority. `meta_debug_token` lets the user audit the live token. Users should review Meta → Settings → Security → Apps and Websites monthly. |
| 7 | **Scope creep at install.** User ticks every permission "to be safe" without understanding. | High | Medium | Phase 0 + safety gate force the user to opt in to each permission category (publish, comment moderation, DMs). Step 3 part 4 calls out which scopes belong to which authority. |
| 8 | **Webhook hijack.** `meta_subscribe_webhook` can register external URLs that receive event notifications including post and comment data. | Low | High (silent data exfil to attacker-controlled URL) | This skill **does not call `meta_subscribe_webhook` automatically.** It is reserved for advanced workflows. If a user requests webhooks, treat as a sensitive action and show the URL plainly before calling. |
| 9 | **Rate limit triggering account flag.** Mass operations (bulk hide-comment, bulk DM) can trigger Meta's anti-spam systems and shadow-ban the account. | Medium | Medium (reduced reach, account restriction) | Phase 2 instructs Claude to throttle bulk operations, add 1–2 second delays, and warn the user before any operation touching >10 items. |
| 10 | **App Review bypass risk.** Workshop users in dev mode skip Meta App Review by adding themselves as Testers. The Tester role is silent and persistent. | Low | Low | Note in error handling — if a user offboards a developer, they should remove that developer from the app's Roles → Testers list. The skill itself does not modify the Tester list. |

**Recommended user-side hardening (not in this skill, but worth telling the user):**
- Enable two-factor auth on the Facebook account that owns the App.
- Review **Meta Settings → Security → Apps and Websites** quarterly and revoke unused.
- Rotate the long-lived token via `meta_refresh_token` every 50 days (don't wait for expiry).
- If Claude Code is shared on a machine, **do not** add `META_APP_SECRET` to `~/.claude.json` permanently — paste it only when running `meta_exchange_token`/`meta_refresh_token`.

---

## Scope Limitations

The Meta Business Suite connector **can** do (via `@mikusnuz/meta-mcp`):

- Publish to Instagram Business: photos, videos, carousels, Reels, stories
- Read Instagram media list, media details, media insights
- Manage Instagram comments: post, reply, hide, delete (own comments only)
- Read/send Instagram DMs (with `instagram_manage_messages` scope)
- Search Instagram hashtags, look up other Business accounts via `ig_business_discovery`
- Publish to Threads: text, image, video, carousels, polls, link attachments, quotes, replies
- Read Threads posts, replies, search public posts
- Read account-level + post-level insights for both Instagram and Threads
- Manage Meta tokens: exchange, refresh, debug

The Meta Business Suite connector **cannot** do:

- **Post to a Facebook Page** organically. Use a separate `facebook-page-connector` (not yet built).
- **Run Meta Ads** (paid campaigns, ad sets, targeting, creatives). Use Luke's `lukeselr/meta-ads-mcp-setup`.
- **Schedule posts for later.** Meta Graph API does not expose scheduled publishing for organic content. The user can use Meta Business Suite's UI scheduler, or pair this skill with a cron-based skill.
- **Post to personal Instagram accounts.** Graph API only supports Business and Creator accounts.
- **Cross-post Instagram → Facebook automatically.** This is a per-post toggle in the Instagram app and is not exposed via Graph API.
- **Create Instagram Shopping product tags.** Requires the separate Catalog API and is out of scope.
- **Access Stories highlights, archive, or close-friends list** beyond what `ig_get_media_list` returns.
- **Manage Facebook Messenger DMs** (Page-side). Only Instagram DMs are exposed.
- **Read or post to Threads private/restricted accounts** other than the connected one.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before publishing, deleting, or sending DMs.** Summarise what you're about to post (caption + hashtags + media URL or filename) and wait for the user's OK before calling the publish tool. Same for `ig_send_message`, `ig_delete_media`, `ig_delete_comment`, `threads_delete_post`.
- **Container processing is asynchronous.** After `ig_publish_video` or `ig_publish_reel`, call `ig_get_container_status` once before assuming the post is live. Same for Threads media containers via `threads_get_container_status`.
- **Never echo or log credentials.** `INSTAGRAM_ACCESS_TOKEN`, `THREADS_ACCESS_TOKEN`, `META_APP_SECRET`, and `META_APP_ID` must never appear in any output visible to the user.
- **One platform, one tool call at a time.** Do not parallel-publish to Instagram and Threads in a single batched action without confirming both with the user.
- **Format insights clearly.** When showing media insights or account insights, format as a readable summary (top metrics first), not raw JSON. Highlight surprising values.
- **Pagination.** `ig_get_media_list` and `threads_get_posts` default to a small page. Show the first page and offer to fetch more.
- **Rate limits are real.** Instagram uses a **Business Use Case (BUC) rate limit**: roughly **4,800 calls per 24-hour rolling window per impression count**. High-impression accounts get more headroom; new or quiet accounts get less. Instagram publishing has a separate cap: **100 published posts per 24 hours** (carousels count as 1). Threads: **250 publishes per day**. If the user is doing bulk work, pace it. Catch error codes 17 (user throttle) and 32 (page throttle) and back off.
- **Check token expiry before risky operations.** If the user is about to publish a multi-step Reel or carousel, optionally call `meta_debug_token` first to confirm the token has >7 days left. Avoid the publish-fails-mid-batch surprise.
- **Hashtag and `@` mentions.** Instagram captions can include hashtags and mentions, but Graph API does not validate them — typos won't error, they'll just sit dead in the caption. Spell-check before publishing.
- **Reels constraints.** Aspect ratio range **0.01:1 to 10:1** (9:16 recommended). Duration **3 seconds minimum, 15 minutes maximum**. Container **MP4 or MOV**. Video codec **H.264 or HEVC** with frame rate **23–60 FPS** and bitrate **≤25 Mbps**. Audio codec **AAC**, **≤48 kHz**, **1–2 channels**. Max file size **300 MB**. If the user provides something outside these bounds, warn before the publish call rather than letting Meta reject it.
- **Comment moderation tone.** When asked to hide or delete comments, summarise the comment text first so the user is making the decision, not Claude.
- **DM privacy.** Treat DM content as confidential. Don't include DM bodies in summaries unless the user asks. Don't suggest reading DMs proactively.
- **Single account per platform.** The connector is locked to one Instagram Business account and one Threads account per token pair. Switching accounts requires re-running Phase 1 with new tokens.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules.
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Meta access tokens or Graph API errors.
- **canva-connector**: Generate the image, video, or Reel cover, then publish through this skill.
- **ad-creative**: Draft the post copy and creative concept, then publish through this skill.
- **xero-connector**: Sibling first-party-style connector — same `~/.claude.json` + restart pattern, different platform.
- **wordpress-connector**: Same `npx + ~/.claude.json` install pattern using `@rnaga/wp-mcp`.
- **(future) facebook-page-connector**: Will cover Facebook Page organic posting; not yet built.
- **(external) lukeselr/meta-ads-mcp-setup**: Covers Meta Ads. Coexists with this skill — they wrap different MCP servers and use different tokens.
