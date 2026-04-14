/**
 * Persistent message history.
 *
 * Every inbound WhatsApp message (and optionally outbound replies) is appended
 * as JSONL to ~/.claude/whatsapp-channel/history.jsonl so Claude can read past
 * messages on demand across sessions — not just what arrives while a session
 * is active.
 */
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import type { InboundMessage } from "./monitor.js";

export const HISTORY_FILE = path.join(
  os.homedir(),
  ".claude",
  "whatsapp-channel",
  "history.jsonl",
);

export interface HistoryEntry {
  ts: number;                       // ms epoch
  direction: "in" | "out";
  chat_id: string;
  chat_type: "direct" | "group";
  sender_phone: string | null;
  sender_name?: string;
  group_subject?: string;
  message_id?: string;
  reply_to_body?: string;
  media?: string;
  body: string;
}

function ensureDir(): void {
  try {
    fs.mkdirSync(path.dirname(HISTORY_FILE), { recursive: true });
  } catch {}
}

export function appendInbound(msg: InboundMessage): void {
  const entry: HistoryEntry = {
    ts: msg.timestamp ?? Date.now(),
    direction: msg.isFromMe ? "out" : "in",
    chat_id: msg.chatId,
    chat_type: msg.chatType,
    sender_phone: msg.senderPhone,
    sender_name: msg.senderName,
    group_subject: msg.groupSubject,
    message_id: msg.id,
    reply_to_body: msg.replyToBody,
    media: msg.mediaPlaceholder,
    body: msg.body,
  };
  writeEntry(entry);
}

export function appendOutbound(chatId: string, text: string, messageId?: string): void {
  const entry: HistoryEntry = {
    ts: Date.now(),
    direction: "out",
    chat_id: chatId,
    chat_type: chatId.endsWith("@g.us") ? "group" : "direct",
    sender_phone: null,
    message_id: messageId,
    body: text,
  };
  writeEntry(entry);
}

function writeEntry(entry: HistoryEntry): void {
  ensureDir();
  try {
    fs.appendFileSync(HISTORY_FILE, JSON.stringify(entry) + "\n");
  } catch (err) {
    console.error("[whatsapp-history] Failed to append:", String(err));
  }
}

export interface HistoryQuery {
  chat_id?: string;
  sender_phone?: string;
  since_ts?: number;           // ms epoch — only entries at or after
  until_ts?: number;           // ms epoch — only entries at or before
  contains?: string;           // case-insensitive substring match on body
  direction?: "in" | "out";
  limit?: number;              // default 50, max 500
}

export async function readHistory(query: HistoryQuery = {}): Promise<HistoryEntry[]> {
  let raw: string;
  try {
    raw = await fsp.readFile(HISTORY_FILE, "utf-8");
  } catch (err: any) {
    if (err?.code === "ENOENT") return [];
    throw err;
  }

  const limit = Math.min(Math.max(query.limit ?? 50, 1), 500);
  const needle = query.contains?.toLowerCase();

  // Stream parse — read backwards by splitting and iterating from the end so
  // the most recent matches come out first without loading everything twice.
  const lines = raw.split("\n");
  const out: HistoryEntry[] = [];

  for (let i = lines.length - 1; i >= 0 && out.length < limit; i--) {
    const line = lines[i];
    if (!line) continue;
    let entry: HistoryEntry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    if (query.chat_id && entry.chat_id !== query.chat_id) continue;
    if (query.sender_phone && entry.sender_phone !== query.sender_phone) continue;
    if (query.direction && entry.direction !== query.direction) continue;
    if (query.since_ts && entry.ts < query.since_ts) continue;
    if (query.until_ts && entry.ts > query.until_ts) continue;
    if (needle && !entry.body.toLowerCase().includes(needle)) continue;
    out.push(entry);
  }

  // Return chronological (oldest first) so Claude can read top-to-bottom.
  return out.reverse();
}

export async function listChats(limit = 50): Promise<Array<{
  chat_id: string;
  chat_type: "direct" | "group";
  last_ts: number;
  last_sender?: string;
  group_subject?: string;
  message_count: number;
}>> {
  let raw: string;
  try {
    raw = await fsp.readFile(HISTORY_FILE, "utf-8");
  } catch (err: any) {
    if (err?.code === "ENOENT") return [];
    throw err;
  }

  const chats = new Map<string, {
    chat_id: string;
    chat_type: "direct" | "group";
    last_ts: number;
    last_sender?: string;
    group_subject?: string;
    message_count: number;
  }>();

  for (const line of raw.split("\n")) {
    if (!line) continue;
    let entry: HistoryEntry;
    try { entry = JSON.parse(line); } catch { continue; }

    const existing = chats.get(entry.chat_id);
    if (existing) {
      existing.message_count++;
      if (entry.ts > existing.last_ts) {
        existing.last_ts = entry.ts;
        existing.last_sender = entry.sender_name ?? entry.sender_phone ?? undefined;
        if (entry.group_subject) existing.group_subject = entry.group_subject;
      }
    } else {
      chats.set(entry.chat_id, {
        chat_id: entry.chat_id,
        chat_type: entry.chat_type,
        last_ts: entry.ts,
        last_sender: entry.sender_name ?? entry.sender_phone ?? undefined,
        group_subject: entry.group_subject,
        message_count: 1,
      });
    }
  }

  return Array.from(chats.values())
    .sort((a, b) => b.last_ts - a.last_ts)
    .slice(0, limit);
}
