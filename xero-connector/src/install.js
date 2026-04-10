#!/usr/bin/env node
/**
 * Xero Connector — 1-Click Installer
 * Built by Selr AI — selrai.com.au
 *
 * Run this once to set up everything:
 *   node src/install.js
 *
 * It will:
 *   1. Check Node.js version
 *   2. Install npm dependencies
 *   3. Prompt for Xero credentials
 *   4. Run the OAuth sign-in flow
 *   5. Configure Claude Code (~/.claude.json)
 *   6. Verify the connection
 *   7. Print a success summary
 */

import { execSync } from 'child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { createInterface } from 'readline';
import { homedir, platform } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT       = resolve(__dirname, '..');
const ENV_PATH   = resolve(ROOT, '.env');
const TOKEN_PATH = resolve(ROOT, '.xero-token.json');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function ask(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((res) => {
    rl.question(question, (answer) => {
      rl.close();
      res(answer.trim());
    });
  });
}

function step(n, total, label) {
  console.log(`\n[${n}/${total}] ${label}`);
}

function ok(msg) {
  console.log(`  ${msg} -- OK`);
}

function fail(msg) {
  console.error(`\n  ❌  ${msg}\n`);
}

// ─── STEP 1 — Node.js check ──────────────────────────────────────────────────

function checkNode() {
  step(1, 7, 'Checking Node.js...');

  const raw = process.version;                    // e.g. "v22.1.0"
  const major = parseInt(raw.replace('v', ''), 10);

  if (major < 20) {
    fail(`Node.js version is too old (found: ${raw}).`);
    console.error('  This installer needs Node.js v20 or higher.');
    console.error('  Download the LTS version from: https://nodejs.org');
    console.error('  Then run this installer again.');
    process.exit(1);
  }

  ok(`Node.js ${raw}`);
}

// ─── STEP 2 — npm install ────────────────────────────────────────────────────

function npmInstall() {
  step(2, 7, 'Installing dependencies...');
  console.log('  This may take 1-2 minutes -- that is normal.');

  let attempts = 0;
  const maxAttempts = 2;

  while (attempts < maxAttempts) {
    attempts++;
    try {
      execSync('npm install', {
        cwd: ROOT,
        stdio: ['ignore', 'pipe', 'pipe'],
        timeout: 120_000,
      });
      ok('Dependencies installed');
      return;
    } catch (err) {
      const stderr = err.stderr?.toString() || '';
      const stdout = err.stdout?.toString() || '';
      const output = stderr + stdout;

      // EINTEGRITY — corrupted cache, clean and retry once
      if (output.includes('EINTEGRITY') && attempts < maxAttempts) {
        console.log('  npm cache corruption detected -- cleaning and retrying...');
        try { execSync('npm cache clean --force', { stdio: 'ignore' }); } catch {}
        continue;
      }

      // EACCES / permission denied
      if (output.includes('EACCES') || output.includes('permission denied')) {
        fail('Permission error during npm install.');
        console.error('  Recommended fix (avoids sudo entirely):');
        console.error('    1. Install nvm:');
        console.error('       curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash');
        console.error('    2. Restart your terminal, then run:');
        console.error('       nvm install --lts');
        console.error('    3. Run this installer again.');
        process.exit(1);
      }

      // ECONNRESET / ECONNREFUSED / 403 — firewall
      if (output.includes('ECONNRESET') || output.includes('ECONNREFUSED') || output.includes('403')) {
        fail('Network error -- npm cannot reach the internet.');
        console.error('  Common causes:');
        console.error('    - Corporate firewall blocking npmjs.com');
        console.error('    - SSL inspection stripping certificates');
        console.error('  Ask your IT department to allow: registry.npmjs.org:443');
        process.exit(1);
      }

      // Generic failure
      fail('npm install failed.');
      console.error('  Full error output:');
      console.error('  -----------------------------------------------');
      console.error(output.slice(0, 2000));
      console.error('  -----------------------------------------------');
      process.exit(1);
    }
  }
}

// ─── STEP 3 — Credentials prompt ─────────────────────────────────────────────

async function getCredentials() {
  step(3, 7, 'Checking Xero credentials...');

  // Check for existing .env with real values
  if (existsSync(ENV_PATH)) {
    const existing = readFileSync(ENV_PATH, 'utf8');
    const hasId     = /^XERO_CLIENT_ID=(.+)$/m.exec(existing);
    const hasSecret = /^XERO_CLIENT_SECRET=(.+)$/m.exec(existing);

    if (hasId && hasSecret) {
      const id     = hasId[1].trim();
      const secret = hasSecret[1].trim();

      if (id && secret &&
          id !== 'your_client_id_here' &&
          secret !== 'your_client_secret_here') {
        console.log(`  Found existing credentials (Client ID: ${id.slice(0, 8)}...)`);
        const reuse = await ask('  Use these credentials? (y/n): ');
        if (reuse.toLowerCase() === 'y' || reuse.toLowerCase() === 'yes') {
          ok('Credentials loaded');
          return { clientId: id, clientSecret: secret };
        }
      }
    }
  }

  // Prompt for new credentials
  console.log('');
  console.log('  You need a Xero OAuth app (free -- takes 2 minutes):');
  console.log('    1. Go to https://developer.xero.com/app/manage');
  console.log('    2. Click "New app"');
  console.log('    3. Set redirect URI to: http://localhost:3000/callback');
  console.log('    4. Click "Create app", then "Generate a secret"');
  console.log('    5. Copy your Client ID and Client Secret');
  console.log('');

  const clientId = await ask('  Paste your Xero Client ID: ');
  if (!clientId || clientId === 'your_client_id_here') {
    fail('Client ID cannot be empty or a placeholder.');
    console.error('  Get your Client ID from https://developer.xero.com/app/manage');
    process.exit(1);
  }

  const clientSecret = await ask('  Paste your Xero Client Secret: ');
  if (!clientSecret || clientSecret === 'your_client_secret_here') {
    fail('Client Secret cannot be empty or a placeholder.');
    console.error('  Get your Client Secret from your app at developer.xero.com');
    console.error('  (Click "Generate a secret" if you haven\'t already)');
    process.exit(1);
  }

  // Write .env
  const envContent = [
    '# Xero Connector -- Environment Variables',
    '# Generated by the installer -- do not commit this file',
    '',
    `XERO_CLIENT_ID=${clientId}`,
    `XERO_CLIENT_SECRET=${clientSecret}`,
    '',
  ].join('\n');

  writeFileSync(ENV_PATH, envContent);
  ok('Credentials saved');
  return { clientId, clientSecret };
}

// ─── STEP 4 — OAuth flow ─────────────────────────────────────────────────────

async function runOAuth(clientId, clientSecret) {
  step(4, 7, 'Connecting to Xero...');
  console.log('  Opening Xero in your browser -- sign in and click Allow.');
  console.log('');

  // Dynamic import so we only load after npm install has run
  const { XeroClient } = await import('xero-node');
  const express = (await import('express')).default;

  const SCOPES = [
    'openid', 'profile', 'email', 'offline_access',
    'accounting.invoices',
    'accounting.payments',
    'accounting.banktransactions',
    'accounting.contacts',
    'accounting.settings',
    'accounting.reports.profitandloss.read',
    'accounting.reports.balancesheet.read',
  ];

  const PORT = 3000;
  const REDIRECT_URI = `http://localhost:${PORT}/callback`;

  const xero = new XeroClient({
    clientId,
    clientSecret,
    redirectUris: [REDIRECT_URI],
    scopes: SCOPES,
  });

  const consentUrl = await xero.buildConsentUrl();
  const app = express();

  return new Promise((resolve, reject) => {
    // 2-minute timeout
    const timeout = setTimeout(() => {
      server.close();
      fail('No response from browser after 2 minutes.');
      console.error('  Close any other apps on port 3000 and run the installer again.');
      reject(new Error('timeout'));
    }, 120_000);

    const server = app.listen(PORT, async () => {
      console.log('  If your browser does not open automatically,');
      console.log('  paste this URL into any browser:');
      console.log(`  ${consentUrl}`);
      console.log('');
      console.log('  Waiting for sign-in...');

      try {
        const { default: open } = await import('open');
        await open(consentUrl);
      } catch {
        // Browser open failed -- URL already printed above
      }
    });

    server.on('error', (err) => {
      clearTimeout(timeout);
      if (err.code === 'EADDRINUSE') {
        fail(`Port ${PORT} is already in use.`);
        console.error(`  Close whatever is running on port ${PORT} and run the installer again.`);
      } else {
        fail(`Could not start local server: ${err.message}`);
      }
      reject(err);
    });

    app.get('/callback', async (req, res) => {
      clearTimeout(timeout);
      try {
        const tokenSet = await xero.apiCallback(req.url);
        await xero.updateTenants();

        // Persist tokens
        writeFileSync(TOKEN_PATH, JSON.stringify(tokenSet, null, 2));

        const orgName = xero.tenants?.[0]?.tenantName || 'your organisation';

        res.send(`
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Xero Connected</title>
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                     max-width: 540px; margin: 100px auto; text-align: center;
                     color: #1a1a1a; padding: 0 20px; }
              .icon { font-size: 48px; margin-bottom: 16px; }
              h2   { margin: 0 0 12px; font-size: 24px; }
              p    { color: #555; line-height: 1.5; }
              .org { font-weight: 600; color: #1a1a1a; }
            </style>
          </head>
          <body>
            <div class="icon">✅</div>
            <h2>Connected to Xero!</h2>
            <p>Successfully linked to <span class="org">${orgName}</span>.</p>
            <p>You can close this tab and return to your terminal.</p>
          </body>
          </html>
        `);

        server.close();
        ok('Signed in to Xero');
        resolve({ xero, orgName });
      } catch (err) {
        const message = err?.response?.body?.Detail || err?.message || String(err);

        res.status(500).send(`
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <title>Authentication Failed</title>
            <style>
              body { font-family: sans-serif; max-width: 540px; margin: 100px auto;
                     text-align: center; color: #1a1a1a; padding: 0 20px; }
              .icon { font-size: 48px; margin-bottom: 16px; }
              pre   { text-align: left; background: #f5f5f5; padding: 12px;
                      border-radius: 6px; font-size: 13px; overflow-x: auto; }
            </style>
          </head>
          <body>
            <div class="icon">❌</div>
            <h2>Authentication Failed</h2>
            <pre>${message}</pre>
            <p>Close this tab and run the installer again.</p>
          </body>
          </html>
        `);

        server.close();
        reject(new Error(message));
      }
    });
  });
}

// ─── STEP 5 — Configure Claude Code ──────────────────────────────────────────

function configureClaude() {
  step(5, 7, 'Configuring Claude Code...');

  const indexPath = resolve(__dirname, 'index.js');
  const home = homedir();
  const claudeJsonPath = join(home, '.claude.json');

  // Build the path string — Windows needs double backslashes in JSON
  const isWindows = platform() === 'win32';
  const pathForJson = isWindows
    ? indexPath.replace(/\\/g, '\\\\')
    : indexPath;

  // Read existing config or start fresh
  let config = {};
  if (existsSync(claudeJsonPath)) {
    try {
      config = JSON.parse(readFileSync(claudeJsonPath, 'utf8'));
    } catch {
      // Corrupted file — back it up and start fresh
      const backup = claudeJsonPath + '.backup';
      writeFileSync(backup, readFileSync(claudeJsonPath));
      console.log(`  Backed up existing ~/.claude.json to ${backup}`);
      config = {};
    }
  }

  // Merge — don't clobber existing MCP servers
  if (!config.mcpServers) config.mcpServers = {};
  config.mcpServers.xero = {
    command: 'node',
    args: [isWindows ? indexPath.replace(/\//g, '\\') : indexPath],
  };

  writeFileSync(claudeJsonPath, JSON.stringify(config, null, 2));

  console.log(`  Added "xero" MCP server to ${claudeJsonPath}`);
  ok('Claude Code configured');
}

// ─── STEP 6 — Verify connection ──────────────────────────────────────────────

async function verify(clientId, clientSecret) {
  step(6, 7, 'Verifying connection...');

  const { XeroClient } = await import('xero-node');

  const xero = new XeroClient({
    clientId,
    clientSecret,
    redirectUris: ['http://localhost:3000/callback'],
    scopes: ['openid', 'profile', 'email', 'offline_access',
      'accounting.invoices', 'accounting.payments',
      'accounting.banktransactions', 'accounting.contacts',
      'accounting.settings', 'accounting.reports.profitandloss.read',
      'accounting.reports.balancesheet.read'],
  });

  const stored = JSON.parse(readFileSync(TOKEN_PATH, 'utf8'));
  await xero.setTokenSet(stored);

  // Refresh if expired
  const current = xero.readTokenSet();
  if (current?.expired?.()) {
    const refreshed = await xero.refreshWithRefreshToken(
      clientId, clientSecret, stored.refresh_token
    );
    writeFileSync(TOKEN_PATH, JSON.stringify(refreshed, null, 2));
    await xero.setTokenSet(refreshed);
  }

  await xero.updateTenants();

  if (!xero.tenants?.length) {
    fail('No Xero organisations found.');
    console.error('  Run the installer again and select an organisation during sign-in.');
    process.exit(1);
  }

  const tenantId = xero.tenants[0].tenantId;
  const orgName  = xero.tenants[0].tenantName;

  // Fetch invoice count
  let invoiceCount = 0;
  try {
    const res = await xero.accountingApi.getInvoices(tenantId);
    invoiceCount = res.body.invoices?.length ?? 0;
  } catch {
    // Non-fatal — invoice access might be restricted on some plans
    invoiceCount = '(could not count)';
  }

  ok('Connection verified');
  return { orgName, invoiceCount };
}

// ─── STEP 7 — Success summary ────────────────────────────────────────────────

function printSuccess(orgName, invoiceCount) {
  step(7, 7, 'Done!');
  console.log('');
  console.log('================================================');
  console.log('  Xero is connected to Claude Code!');
  console.log('');
  console.log(`  Organisation: ${orgName}`);
  console.log(`  Invoices found: ${invoiceCount}`);
  console.log('');
  console.log('  Restart Claude Code, then try saying:');
  console.log('    "Show me my recent Xero invoices"');
  console.log('    "What\'s my profit and loss this month?"');
  console.log('    "List my Xero contacts"');
  console.log('================================================');
  console.log('');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('================================================');
  console.log('  Xero Connector — Installer');
  console.log('  Built by Selr AI -- selrai.com.au');
  console.log('================================================');

  // Step 1
  try {
    checkNode();
  } catch (err) {
    fail(`Node.js check failed: ${err.message}`);
    process.exit(1);
  }

  // Step 2
  try {
    npmInstall();
  } catch (err) {
    fail(`npm install failed: ${err.message}`);
    process.exit(1);
  }

  // Step 3
  let clientId, clientSecret;
  try {
    ({ clientId, clientSecret } = await getCredentials());
  } catch (err) {
    fail(`Credentials step failed: ${err.message}`);
    process.exit(1);
  }

  // Step 4
  try {
    await runOAuth(clientId, clientSecret);
  } catch (err) {
    fail(`OAuth sign-in failed: ${err.message}`);
    console.error('  Common fixes:');
    console.error('  - Check your Client ID and Secret are correct');
    console.error('  - Confirm redirect URI is http://localhost:3000/callback in your Xero app');
    console.error('  - Close any other apps using port 3000');
    process.exit(1);
  }

  // Step 5
  try {
    configureClaude();
  } catch (err) {
    fail(`Claude Code configuration failed: ${err.message}`);
    console.error('  You can manually add the Xero MCP server to ~/.claude.json');
    console.error('  See XERO-SETUP.md Step 5 for instructions.');
    process.exit(1);
  }

  // Step 6
  let orgName, invoiceCount;
  try {
    ({ orgName, invoiceCount } = await verify(clientId, clientSecret));
  } catch (err) {
    fail(`Verification failed: ${err.message}`);
    console.error('  The connection was set up but verification could not complete.');
    console.error('  Try restarting Claude Code and asking "Show me my Xero invoices"');
    console.error('  If that works, you are all set.');
    process.exit(1);
  }

  // Step 7
  printSuccess(orgName, invoiceCount);
}

main().catch((err) => {
  fail(`Unexpected error: ${err.message}`);
  process.exit(1);
});
