/**
 * WhatsApp Web session management via Baileys.
 * Handles socket creation, QR authentication, credential persistence, and reconnection.
 */
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import {
  DisconnectReason,
  fetchLatestBaileysVersion,
  makeCacheableSignalKeyStore,
  makeWASocket,
  useMultiFileAuthState,
  type WASocket,
  type ConnectionState,
} from "@whiskeysockets/baileys";
import qrcode from "qrcode-terminal";

// ── Auth directory ──────────────────────────────────────────────────
const DEFAULT_AUTH_DIR = path.join(os.homedir(), ".claude", "whatsapp-channel", "auth");

export function resolveAuthDir(custom?: string): string {
  return custom ?? DEFAULT_AUTH_DIR;
}

function credsPath(authDir: string): string {
  return path.join(authDir, "creds.json");
}

function credsBackupPath(authDir: string): string {
  return path.join(authDir, "creds.json.bak");
}

// ── Credential helpers ──────────────────────────────────────────────
export function hasCredentials(authDir: string = DEFAULT_AUTH_DIR): boolean {
  try {
    const stats = fs.statSync(credsPath(authDir));
    return stats.isFile() && stats.size > 1;
  } catch {
    return false;
  }
}

async function maybeRestoreBackup(authDir: string): Promise<void> {
  try {
    const cp = credsPath(authDir);
    const bp = credsBackupPath(authDir);
    let raw: string | null = null;
    try { raw = await fsp.readFile(cp, "utf-8"); } catch {}
    if (raw && raw.length > 1) {
      JSON.parse(raw); // validate
      return;
    }
    // Try backup
    let backup: string | null = null;
    try { backup = await fsp.readFile(bp, "utf-8"); } catch { return; }
    if (!backup) return;
    JSON.parse(backup); // validate
    await fsp.copyFile(bp, cp);
    try { await fsp.chmod(cp, 0o600); } catch {}
    console.error("[whatsapp] Restored creds from backup");
  } catch {}
}

// ── Credential save queue (prevents corruption) ─────────────────────
const saveQueues = new Map<string, Promise<void>>();

function enqueueSave(authDir: string, saveCreds: () => Promise<void>): void {
  const prev = saveQueues.get(authDir) ?? Promise.resolve();
  const next = prev
    .then(async () => {
      // Backup current creds before overwriting
      try {
        const cp = credsPath(authDir);
        const bp = credsBackupPath(authDir);
        if (fs.existsSync(cp)) {
          const raw = fs.readFileSync(cp, "utf-8");
          JSON.parse(raw); // only backup valid JSON
          fs.copyFileSync(cp, bp);
          try { fs.chmodSync(bp, 0o600); } catch {}
        }
      } catch {}
      await saveCreds();
      try { fs.chmodSync(credsPath(authDir), 0o600); } catch {}
    })
    .catch((err) => console.error("[whatsapp] Creds save error:", String(err)))
    .finally(() => {
      if (saveQueues.get(authDir) === next) saveQueues.delete(authDir);
    });
  saveQueues.set(authDir, next);
}

// ── Baileys version cache ──────────────────────────────────────────
// fetchLatestBaileysVersion() hits the network on every call.
// Cache it for the lifetime of the process to avoid repeated slow lookups.
let cachedVersion: [number, number, number] | null = null;
const FALLBACK_VERSION: [number, number, number] = [2, 3000, 1015901307];

async function getBaileysVersion(verbose?: boolean): Promise<[number, number, number]> {
  if (cachedVersion) return cachedVersion;
  try {
    const result = await Promise.race([
      fetchLatestBaileysVersion(),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("Version fetch timeout")), 5_000),
      ),
    ]);
    cachedVersion = result.version;
    return cachedVersion;
  } catch (err) {
    if (verbose) console.error("[whatsapp] Version fetch failed, using fallback:", String(err));
    cachedVersion = FALLBACK_VERSION;
    return cachedVersion;
  }
}

// ── Socket creation ─────────────────────────────────────────────────
export type QrCallback = (qr: string) => void;
export type ConnectionCallback = (update: Partial<ConnectionState>) => void;

export interface CreateSocketOptions {
  authDir?: string;
  onQr?: QrCallback;
  onConnection?: ConnectionCallback;
  printQrToTerminal?: boolean;
  verbose?: boolean;
}

export async function createWhatsAppSocket(
  opts: CreateSocketOptions = {},
): Promise<WASocket> {
  const authDir = resolveAuthDir(opts.authDir);

  // Run auth dir creation, backup restore, auth state load, and version fetch in parallel
  await fsp.mkdir(authDir, { recursive: true });
  await maybeRestoreBackup(authDir);

  const [{ state, saveCreds }, version] = await Promise.all([
    useMultiFileAuthState(authDir),
    getBaileysVersion(opts.verbose),
  ]);

  // Baileys wants a pino-like logger; silence it unless verbose
  const logger = {
    level: opts.verbose ? "info" : "silent",
    info: opts.verbose ? console.log.bind(console) : () => {},
    warn: console.warn.bind(console),
    error: console.error.bind(console),
    debug: () => {},
    trace: () => {},
    fatal: console.error.bind(console),
    child: () => logger,
  } as any;

  const sock = makeWASocket({
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, logger),
    },
    version,
    logger,
    printQRInTerminal: false,
    browser: ["Claude Code WhatsApp", "CLI", "1.0.0"],
    syncFullHistory: false,
    markOnlineOnConnect: false,
  });

  // Save credentials on update
  sock.ev.on("creds.update", () => enqueueSave(authDir, saveCreds));

  // Connection state changes
  sock.ev.on("connection.update", (update: Partial<ConnectionState>) => {
    try {
      const { connection, lastDisconnect, qr } = update;
      if (qr) {
        opts.onQr?.(qr);
        if (opts.printQrToTerminal) {
          console.error("\nScan this QR code in WhatsApp > Linked Devices:\n");
          qrcode.generate(qr, { small: true }, (output: string) => {
            console.error(output);
          });
        }
      }
      if (connection === "close") {
        const statusCode = (lastDisconnect?.error as any)?.output?.statusCode;
        if (statusCode === DisconnectReason.loggedOut) {
          console.error("[whatsapp] Session logged out. Re-run to scan a new QR code.");
        }
      }
      if (connection === "open") {
        console.error("[whatsapp] Connected to WhatsApp Web.");
      }
      opts.onConnection?.(update);
    } catch (err) {
      console.error("[whatsapp] connection.update error:", String(err));
    }
  });

  // Prevent unhandled WS errors from crashing
  if (sock.ws && typeof (sock.ws as any).on === "function") {
    (sock.ws as any).on("error", (err: Error) => {
      console.error("[whatsapp] WebSocket error:", String(err));
    });
  }

  return sock;
}

// ── Wait for connection ─────────────────────────────────────────────
const DEFAULT_CONNECT_TIMEOUT_MS = 60_000; // 60s — covers QR scan time

export function waitForConnection(
  sock: WASocket,
  timeoutMs = DEFAULT_CONNECT_TIMEOUT_MS,
): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      (sock.ev as any).off?.("connection.update", handler);
      reject(new Error(`Connection timeout after ${timeoutMs / 1000}s`));
    }, timeoutMs);

    const handler = (update: Partial<ConnectionState>) => {
      if (settled) return;
      if (update.connection === "open") {
        settled = true;
        clearTimeout(timer);
        (sock.ev as any).off?.("connection.update", handler);
        resolve();
      }
      if (update.connection === "close") {
        settled = true;
        clearTimeout(timer);
        (sock.ev as any).off?.("connection.update", handler);
        reject(update.lastDisconnect?.error ?? new Error("Connection closed"));
      }
    };
    sock.ev.on("connection.update", handler);
  });
}

// ── Read self identity ──────────────────────────────────────────────
export function readSelfId(authDir: string = DEFAULT_AUTH_DIR): {
  phone: string | null;
  jid: string | null;
} {
  try {
    const raw = fs.readFileSync(credsPath(authDir), "utf-8");
    const parsed = JSON.parse(raw) as { me?: { id?: string } };
    const jid = parsed?.me?.id ?? null;
    const phone = jid ? jid.split("@")[0].split(":")[0] : null;
    return { phone, jid };
  } catch {
    return { phone: null, jid: null };
  }
}

// ── Logout ──────────────────────────────────────────────────────────
export async function logout(authDir: string = DEFAULT_AUTH_DIR): Promise<boolean> {
  const dir = resolveAuthDir(authDir);
  if (!hasCredentials(dir)) return false;
  await fsp.rm(dir, { recursive: true, force: true });
  console.error("[whatsapp] Cleared WhatsApp session.");
  return true;
}
