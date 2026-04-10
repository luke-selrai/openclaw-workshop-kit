#!/usr/bin/env node
/**
 * Xero OAuth 2.0 Authentication
 * Built by Selr AI — selrai.com.au
 *
 * Run once to connect your Xero account:
 *   npm run auth
 */

import { XeroClient } from 'xero-node';
import express from 'express';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT       = resolve(__dirname, '..');
const TOKEN_PATH = resolve(ROOT, '.xero-token.json');
const ENV_PATH   = resolve(ROOT, '.env');

dotenv.config({ path: ENV_PATH });

const PORT         = 3000;
const REDIRECT_URI = `http://localhost:${PORT}/callback`;

const SCOPES = [
  'openid',
  'profile',
  'email',
  'offline_access',
  'accounting.invoices',
  'accounting.payments',
  'accounting.banktransactions',
  'accounting.contacts',
  'accounting.settings',
  'accounting.reports.profitandloss.read',
  'accounting.reports.balancesheet.read',
];

// ─── Credential check ────────────────────────────────────────────────────────

function checkCredentials() {
  const clientId     = process.env.XERO_CLIENT_ID;
  const clientSecret = process.env.XERO_CLIENT_SECRET;

  if (!clientId || !clientSecret ||
      clientId === 'your_client_id_here' ||
      clientSecret === 'your_client_secret_here') {

    console.error('\n❌  Missing or placeholder Xero credentials.\n');

    if (!existsSync(ENV_PATH)) {
      console.error('   No .env file found. Create one by copying .env.example:');
      console.error('   Windows:  copy .env.example .env');
      console.error('   Mac/Linux: cp .env.example .env\n');
    } else {
      console.error('   Open .env and replace the placeholder values:');
      console.error('     XERO_CLIENT_ID=your_client_id_here   ← replace this');
      console.error('     XERO_CLIENT_SECRET=your_client_secret_here  ← and this\n');
    }

    console.error('   To get these values:');
    console.error('   1. Go to https://developer.xero.com/app/manage');
    console.error('   2. Click your app (or create one)');
    console.error('   3. Copy Client ID and Client Secret\n');
    console.error('   See XERO-SETUP.md Step 2 for full instructions.\n');
    process.exit(1);
  }

  return { clientId, clientSecret };
}

// ─── Main auth flow ───────────────────────────────────────────────────────────

async function main() {
  const { clientId, clientSecret } = checkCredentials();

  const xero = new XeroClient({
    clientId,
    clientSecret,
    redirectUris: [REDIRECT_URI],
    scopes: SCOPES,
  });

  const consentUrl = await xero.buildConsentUrl();

  const app = express();

  return new Promise((resolve, reject) => {
    const server = app.listen(PORT, async () => {
      console.log('\n================================================');
      console.log('  Xero Connector — Sign In');
      console.log('================================================\n');
      console.log('Opening your browser to connect Xero...\n');
      console.log('If your browser does not open automatically,');
      console.log('paste this URL into any browser:\n');
      console.log(consentUrl);
      console.log('\nWaiting for sign-in...\n');

      try {
        const { default: open } = await import('open');
        await open(consentUrl);
      } catch {
        // Browser open failed — URL already printed above
      }
    });

    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.error(`\n❌  Port ${PORT} is already in use.`);
        console.error(`   Close whatever is running on port ${PORT} and try again.\n`);
      } else {
        console.error('\n❌  Could not start local server:', err.message);
      }
      reject(err);
    });

    app.get('/callback', async (req, res) => {
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

        console.log(`✅  Connected to: ${orgName}`);
        console.log('\n================================================');
        console.log('  All done! Xero is connected to Claude Code.');
        console.log('\n  Try asking Claude:');
        console.log('    "Show me my recent Xero invoices"');
        console.log('    "List my Xero contacts"');
        console.log('    "Show me the Xero profit and loss"');
        console.log('================================================\n');

        resolve();
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
            <p>Close this tab and run <code>npm run auth</code> again.</p>
          </body>
          </html>
        `);

        server.close();
        reject(new Error(message));
      }
    });
  });
}

main().catch((err) => {
  console.error('\n❌  Authentication error:', err.message, '\n');
  process.exit(1);
});

