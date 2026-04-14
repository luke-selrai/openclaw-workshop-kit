#!/usr/bin/env bun
/**
 * WhatsApp Channel for Claude Code
 *
 * An MCP channel server that bridges WhatsApp messages into a Claude Code session.
 * Uses Baileys (WhatsApp Web) for authentication via QR code — no Business API needed.
 *
 * Features:
 * - Two-way messaging: receive WhatsApp messages, Claude replies back
 * - QR code authentication (scan with your phone)
 * - Sender allowlist for security
 * - Permission relay (approve/deny Claude's tool use from WhatsApp)
 * - Group chat support
 * - Media placeholders
 * - Message deduplication
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { exec } from "node:child_process";
import { monitorWhatsApp, type InboundMessage } from "./monitor.js";
import { hasCredentials, resolveAuthDir, readSelfId } from "./session.js";
import { startQrServer, updateQr, markConnected, stopQrServer } from "./qr-server.js";
import {
  appendInbound,
  appendOutbound,
  readHistory,
  listChats,
  HISTORY_FILE,
} from "./history.js";

// ── Configuration from environment ──────────────────────────────────
const AUTH_DIR = process.env.WA_AUTH_DIR ?? undefined;
const ALLOW_FROM = process.env.WA_ALLOW_FROM
  ? process.env.WA_ALLOW_FROM.split(",").map((s) => s.trim()).filter(Boolean)
  : [];
const VERBOSE = process.env.WA_VERBOSE === "1" || process.env.WA_VERBOSE === "true";
const AUTO_OPEN_QR = process.env.WA_AUTO_OPEN_QR === "1" || process.env.WA_AUTO_OPEN_QR === "true";

// ── MCP Channel Server ─────────────────────────────────────────────
const mcp = new Server(
  { name: "whatsapp", version: "0.1.0" },
  {
    capabilities: {
      experimental: {
        "claude/channel": {},             // registers as a channel
        "claude/channel/permission": {},  // opt in to permission relay
      },
      tools: {},                          // two-way: Claude can reply
    },
    instructions: [
      'WhatsApp messages arrive as <channel source="whatsapp" chat_id="..." sender_phone="..." sender_name="..." chat_type="direct|group">.',
      "Each message includes the sender's phone number and name when available.",
      'Reply using the "whatsapp_reply" tool, passing the chat_id from the tag.',
      'To read past messages (including ones from before this session started), use "whatsapp_history" — it reads from a persistent log at ~/.claude/whatsapp-channel/history.jsonl.',
      'Use "whatsapp_list_chats" to discover chat_ids when the user references a conversation you did not see live.',
      "For group messages, the group subject is included when available.",
      "If a message is a reply to a previous message, reply_to_body contains the quoted text.",
      "Media messages show placeholders like <media:image>, <media:video>, etc.",
      "Be conversational and helpful. Format replies for WhatsApp (no markdown links, use *bold* and _italic_).",
    ].join(" "),
  },
);

// ── Reply Tool ──────────────────────────────────────────────────────
mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "whatsapp_reply",
      description:
        "Send a reply message back to a WhatsApp chat. Use chat_id from the inbound <channel> tag.",
      inputSchema: {
        type: "object" as const,
        properties: {
          chat_id: {
            type: "string",
            description: "The WhatsApp chat JID to reply to (from the channel tag's chat_id attribute)",
          },
          text: {
            type: "string",
            description: "The message text to send. Use WhatsApp formatting: *bold*, _italic_, ~strikethrough~, ```code```",
          },
        },
        required: ["chat_id", "text"],
      },
    },
    {
      name: "whatsapp_history",
      description:
        "Read past WhatsApp messages from the persistent history log. Works across sessions — returns messages even if they arrived before this session started. Results are chronological (oldest first).",
      inputSchema: {
        type: "object" as const,
        properties: {
          chat_id: {
            type: "string",
            description: "Filter to a single chat JID (e.g. a direct chat or group). Omit to search across all chats.",
          },
          sender_phone: {
            type: "string",
            description: "Filter to messages from a specific phone number in E.164 (e.g. '+1234567890').",
          },
          contains: {
            type: "string",
            description: "Case-insensitive substring to search for in message bodies.",
          },
          since_ts: {
            type: "number",
            description: "Only return messages at or after this Unix timestamp in milliseconds.",
          },
          until_ts: {
            type: "number",
            description: "Only return messages at or before this Unix timestamp in milliseconds.",
          },
          direction: {
            type: "string",
            enum: ["in", "out"],
            description: "Filter by inbound (received) or outbound (sent by you/Claude) messages.",
          },
          limit: {
            type: "number",
            description: "Maximum number of messages to return (1-500, default 50). Returns the most recent matches.",
          },
        },
      },
    },
    {
      name: "whatsapp_list_chats",
      description:
        "List all WhatsApp chats that have appeared in the history log, sorted by most recent activity. Useful for finding a chat_id to pass to whatsapp_history or whatsapp_reply.",
      inputSchema: {
        type: "object" as const,
        properties: {
          limit: {
            type: "number",
            description: "Maximum number of chats to return (default 50).",
          },
        },
      },
    },
    {
      name: "whatsapp_react",
      description: "React to a WhatsApp message with an emoji.",
      inputSchema: {
        type: "object" as const,
        properties: {
          chat_id: {
            type: "string",
            description: "The WhatsApp chat JID",
          },
          message_id: {
            type: "string",
            description: "The message ID to react to",
          },
          emoji: {
            type: "string",
            description: "The emoji to react with (e.g., '👍', '❤️', '😂')",
          },
        },
        required: ["chat_id", "message_id", "emoji"],
      },
    },
  ],
}));

// Store the monitor instance so tools can send messages
let waMonitor: Awaited<ReturnType<typeof monitorWhatsApp>> | null = null;

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name === "whatsapp_reply") {
    const { chat_id, text } = req.params.arguments as { chat_id: string; text: string };
    if (!waMonitor) {
      return { content: [{ type: "text", text: "WhatsApp not connected" }] };
    }
    try {
      const result = await waMonitor.sendMessage(chat_id, text);
      appendOutbound(chat_id, text, result.messageId);
      return {
        content: [{ type: "text", text: `Sent (id: ${result.messageId})` }],
      };
    } catch (err) {
      return {
        content: [{ type: "text", text: `Failed to send: ${String(err)}` }],
      };
    }
  }

  if (req.params.name === "whatsapp_history") {
    const args = (req.params.arguments ?? {}) as {
      chat_id?: string;
      sender_phone?: string;
      contains?: string;
      since_ts?: number;
      until_ts?: number;
      direction?: "in" | "out";
      limit?: number;
    };
    try {
      const entries = await readHistory(args);
      if (entries.length === 0) {
        return {
          content: [{
            type: "text",
            text: `No messages found matching the query. History file: ${HISTORY_FILE}`,
          }],
        };
      }
      const lines = entries.map((e) => {
        const when = new Date(e.ts).toISOString();
        const who = e.direction === "out"
          ? "you"
          : (e.sender_name ?? e.sender_phone ?? "unknown");
        const chat = e.group_subject ? `group:${e.group_subject}` : e.chat_type;
        return `[${when}] (${chat}) ${who}: ${e.body}`;
      });
      return {
        content: [{
          type: "text",
          text: `Found ${entries.length} message(s):\n${lines.join("\n")}`,
        }],
      };
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to read history: ${String(err)}` }] };
    }
  }

  if (req.params.name === "whatsapp_list_chats") {
    const { limit } = (req.params.arguments ?? {}) as { limit?: number };
    try {
      const chats = await listChats(limit ?? 50);
      if (chats.length === 0) {
        return {
          content: [{
            type: "text",
            text: `No chats in history yet. History file: ${HISTORY_FILE}`,
          }],
        };
      }
      const lines = chats.map((c) => {
        const when = new Date(c.last_ts).toISOString();
        const label = c.group_subject ?? c.last_sender ?? c.chat_id;
        return `[${when}] ${c.chat_type} "${label}" — ${c.message_count} msg — chat_id=${c.chat_id}`;
      });
      return {
        content: [{ type: "text", text: `Chats (${chats.length}):\n${lines.join("\n")}` }],
      };
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to list chats: ${String(err)}` }] };
    }
  }

  if (req.params.name === "whatsapp_react") {
    const { chat_id, message_id, emoji } = req.params.arguments as {
      chat_id: string;
      message_id: string;
      emoji: string;
    };
    if (!waMonitor) {
      return { content: [{ type: "text", text: "WhatsApp not connected" }] };
    }
    try {
      await waMonitor.sendReaction(chat_id, message_id, emoji);
      return { content: [{ type: "text", text: `Reacted with ${emoji}` }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `Failed to react: ${String(err)}` }],
      };
    }
  }

  throw new Error(`Unknown tool: ${req.params.name}`);
});

// ── Permission Relay ────────────────────────────────────────────────
// When Claude wants to run a tool that needs approval, forward the prompt to WhatsApp
const PermissionRequestSchema = z.object({
  method: z.literal("notifications/claude/channel/permission_request"),
  params: z.object({
    request_id: z.string(),
    tool_name: z.string(),
    description: z.string(),
    input_preview: z.string(),
  }),
});

mcp.setNotificationHandler(PermissionRequestSchema, async ({ params }) => {
  if (!waMonitor || !permissionReplyTarget) return;

  pendingPermissionId = params.request_id;
  const prompt = `Allow *${params.tool_name}*? Reply *yes ${params.request_id}* or *no ${params.request_id}*`;

  try {
    await waMonitor.sendMessage(permissionReplyTarget, prompt);
  } catch (err) {
    console.error("[whatsapp] Failed to send permission prompt:", String(err));
  }
});

// Track which chat to send permission prompts to (most recent DM sender)
let permissionReplyTarget: string | null = null;

// Track the most recent pending permission request ID
let pendingPermissionId: string | null = null;

// ── Permission verdict regex ────────────────────────────────────────
// Matches: "y", "yes", "n", "no" (with optional request ID)
const PERMISSION_REPLY_RE = /^\s*(y|yes|n|no)\s*([a-km-z]{5})?\s*$/i;

// ── Inbound message handler ─────────────────────────────────────────
async function handleInboundMessage(msg: InboundMessage): Promise<void> {
  // Persist to history log so whatsapp_history can read it across sessions.
  appendInbound(msg);

  // Track the most recent DM sender for permission relay
  if (msg.chatType === "direct") {
    permissionReplyTarget = msg.chatId;
  }

  // Check if this is a permission verdict
  const verdictMatch = PERMISSION_REPLY_RE.exec(msg.body);
  if (verdictMatch) {
    const requestId = verdictMatch[2]?.toLowerCase() ?? pendingPermissionId;
    if (requestId) {
      pendingPermissionId = null;
      await mcp.notification({
        method: "notifications/claude/channel/permission" as any,
        params: {
          request_id: requestId,
          behavior: verdictMatch[1].toLowerCase().startsWith("y") ? "allow" : "deny",
        },
      });
      return; // Don't forward verdict as chat
    }
  }

  // Build meta attributes for the <channel> tag
  const meta: Record<string, string> = {
    chat_id: msg.chatId,
    chat_type: msg.chatType,
  };
  if (msg.senderPhone) meta.sender_phone = msg.senderPhone;
  if (msg.senderName) meta.sender_name = msg.senderName;
  if (msg.id) meta.message_id = msg.id;
  if (msg.groupSubject) meta.group_subject = msg.groupSubject;
  if (msg.replyToBody) meta.reply_to_body = msg.replyToBody;
  if (msg.timestamp) meta.timestamp = String(msg.timestamp);

  // Build content
  let content = msg.body;
  if (msg.mediaPlaceholder && msg.body !== msg.mediaPlaceholder) {
    content = `${msg.mediaPlaceholder}\n${msg.body}`;
  }

  // Push to Claude Code session
  await mcp.notification({
    method: "notifications/claude/channel",
    params: { content, meta },
  });
}

// ── Start everything ────────────────────────────────────────────────
async function main() {
  // Connect MCP to Claude Code over stdio
  await mcp.connect(new StdioServerTransport());

  console.error("[whatsapp-channel] MCP server connected to Claude Code.");
  console.error(`[whatsapp-channel] Auth dir: ${resolveAuthDir(AUTH_DIR)}`);
  if (ALLOW_FROM.length > 0) {
    console.error(`[whatsapp-channel] Extra allowlist: ${ALLOW_FROM.join(", ")}`);
  } else {
    console.error("[whatsapp-channel] Only your linked phone can message Claude (self-only mode).");
    console.error("[whatsapp-channel] Set WA_ALLOW_FROM=+1234567890 to allow additional numbers.");
  }

  // Check for existing credentials
  const authDir = resolveAuthDir(AUTH_DIR);
  const needsQr = !hasCredentials(authDir);

  if (!needsQr) {
    const self = readSelfId(authDir);
    console.error(`[whatsapp-channel] Existing session found: ${self.phone ?? "unknown"}`);
  } else {
    console.error("[whatsapp-channel] No existing session. Will show QR code.");
  }

  // Start QR server first — we need it ready before opening the browser
  let qrPort: number | null = null;
  try {
    qrPort = await startQrServer();
    console.error(`[whatsapp-channel] QR login page: http://127.0.0.1:${qrPort}`);
  } catch (err) {
    console.error("[whatsapp-channel] QR server failed to start:", String(err));
  }

  // Open browser IMMEDIATELY if login needed — only when WA_AUTO_OPEN_QR=1
  if (needsQr && qrPort) {
    const url = `http://127.0.0.1:${qrPort}`;

    if (AUTO_OPEN_QR) {
      const openCmd = process.platform === "win32" ? `start "" "${url}"`
        : process.platform === "darwin" ? `open "${url}"`
        : `xdg-open "${url}"`;
      exec(openCmd, (err) => {
        if (err) console.error("[whatsapp-channel] Failed to open browser:", String(err));
      });
    } else {
      console.error("[whatsapp-channel] QR login needed. Set WA_AUTO_OPEN_QR=1 to auto-open browser.");
    }

    await mcp.notification({
      method: "notifications/claude/channel",
      params: {
        content: `WhatsApp needs to be linked.${AUTO_OPEN_QR ? " A browser window has been opened at" : " Open"} ${url}. Scan the QR code with your phone (WhatsApp > Settings > Linked Devices > Link a Device).`,
        meta: { type: "system", action: "qr_login_required" },
      },
    });
  }

  // Start WhatsApp monitor (generates QR codes via onQr callback)
  try {
    waMonitor = await monitorWhatsApp({
      authDir: AUTH_DIR,
      verbose: VERBOSE,
      allowFrom: ALLOW_FROM,
      onMessage: handleInboundMessage,
      onQr: (qr) => {
        updateQr(qr).catch(() => {});
        console.error("[whatsapp-channel] New QR code generated. Scan at http://127.0.0.1:" + (qrPort ?? 8787));
      },
      onConnected: () => {
        markConnected();
        console.error("[whatsapp-channel] WhatsApp connected!");
        mcp.notification({
          method: "notifications/claude/channel",
          params: {
            content: "WhatsApp connected successfully! Now listening for messages.",
            meta: { type: "system", action: "connected" },
          },
        }).catch(() => {});
      },
      onClose: (reason) => {
        console.error("[whatsapp-channel] Connection closed:", JSON.stringify(reason));
        stopQrServer();
        if (reason.isLoggedOut) {
          console.error("[whatsapp-channel] Logged out. Restart to re-authenticate.");
        }
      },
    });

    console.error("[whatsapp-channel] WhatsApp monitor active. Listening for messages...");
    if (waMonitor.selfPhone) {
      console.error(`[whatsapp-channel] Linked to: ${waMonitor.selfPhone}`);
    }

    // Auto-reconnect loop: when the connection drops, reconnect instead of exiting.
    // Only exit permanently if the user logged out (removed the linked device).
    const MAX_RECONNECTS = 10;
    const RECONNECT_DELAY_MS = 5000;
    let reconnectCount = 0;

    while (true) {
      const closeReason = await waMonitor.onClose;
      console.error("[whatsapp-channel] Connection closed:", JSON.stringify(closeReason));

      if (closeReason.isLoggedOut) {
        console.error("[whatsapp-channel] Logged out. Restart to re-authenticate.");
        process.exit(1);
      }

      reconnectCount++;
      if (reconnectCount > MAX_RECONNECTS) {
        console.error(`[whatsapp-channel] Exceeded ${MAX_RECONNECTS} reconnect attempts. Exiting.`);
        process.exit(1);
      }

      console.error(`[whatsapp-channel] Reconnecting in ${RECONNECT_DELAY_MS / 1000}s (attempt ${reconnectCount}/${MAX_RECONNECTS})...`);
      await new Promise((r) => setTimeout(r, RECONNECT_DELAY_MS));

      try {
        await waMonitor.close();
      } catch {}

      try {
        waMonitor = await monitorWhatsApp({
          authDir: AUTH_DIR,
          verbose: VERBOSE,
          allowFrom: ALLOW_FROM,
          onMessage: handleInboundMessage,
          onQr: (qr) => {
            updateQr(qr).catch(() => {});
          },
          onConnected: () => {
            reconnectCount = 0;
            console.error("[whatsapp-channel] Reconnected to WhatsApp!");
            mcp.notification({
              method: "notifications/claude/channel",
              params: {
                content: "WhatsApp reconnected after a brief disconnection. Listening for messages again.",
                meta: { type: "system", action: "reconnected" },
              },
            }).catch(() => {});
          },
          onClose: (reason) => {
            console.error("[whatsapp-channel] Connection closed:", JSON.stringify(reason));
          },
        });
        console.error("[whatsapp-channel] Reconnected. Listening for messages...");
      } catch (err) {
        console.error("[whatsapp-channel] Reconnect failed:", String(err));
      }
    }
  } catch (err) {
    console.error("[whatsapp-channel] Failed to start:", String(err));
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("[whatsapp-channel] Fatal error:", String(err));
  process.exit(1);
});
