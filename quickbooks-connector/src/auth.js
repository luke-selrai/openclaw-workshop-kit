#!/usr/bin/env node
/**
 * QuickBooks OAuth 2.0 Authentication
 * Built by Selr AI — selrai.com.au
 *
 * Run standalone:   npm run auth
 * Or import:        import { runAuth } from './auth.js'
 */

import OAuthClient from 'intuit-oauth';
import express from 'express';
import { writeFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT       = resolve(__dirname, '..');
const TOKEN_PATH = resolve(ROOT, '.quickbooks-token.json');
const ENV_PATH   = resolve(ROOT, '.env');

const PORT         = 3000;
const REDIRECT_URI = `http://localhost:${PORT}/callback`;

const SCOPES = ['com.intuit.quickbooks.accounting'];

// ─── Credential check ────────────────────────────────────────────────────────

function loadCredentials() {
  dotenv.config({ path: ENV_PATH });

  const clientId     = process.env.QUICKBOOKS_CLIENT_ID;
  const clientSecret = process.env.QUICKBOOKS_CLIENT_SECRET;
  const environment  = process.env.QUICKBOOKS_ENVIRONMENT || 'sandbox';

  if (!clientId || !clientSecret ||
      clientId === 'your_client_id_here' ||
      clientSecret === 'your_client_secret_here') {

    console.error('\n  ❌  Missing or placeholder QuickBooks credentials.\n');

    if (!existsSync(ENV_PATH)) {
      console.error('   No .env file found. Create one by copying .env.example:');
      console.error('   Windows:  copy .env.example .env');
      console.error('   Mac/Linux: cp .env.example .env\n');
    } else {
      console.error('   Open .env and replace the placeholder values:');
      console.error('     QUICKBOOKS_CLIENT_ID=your_client_id_here   <- replace this');
      console.error('     QUICKBOOKS_CLIENT_SECRET=your_client_secret_here  <- and this\n');
    }

    console.error('   To get these values:');
    console.error('   1. Go to https://developer.intuit.com/app/developer/myapps');
    console.error('   2. Click your app (or create one)');
    console.error('   3. Open the Keys & OAuth tab and copy Client ID and Client Secret\n');
    console.error('   See QUICKBOOKS-SETUP.md Step 2 for full instructions.\n');
    return null;
  }

  return { clientId, clientSecret, environment };
}

// ─── Company info fetch (for success message) ──────────────────────────────

async function fetchCompanyName({ clientId, clientSecret, accessToken, refreshToken, realmId, environment }) {
  try {
    const { default: QuickBooks } = await import('node-quickbooks');
    return await new Promise((res) => {
      const qbo = new QuickBooks(
        clientId,
        clientSecret,
        accessToken,
        false,                       // no token secret (OAuth 2.0)
        realmId,
        environment === 'sandbox',   // useSandbox
        false,                       // debug
        null,                        // minorversion
        '2.0',                       // oAuthVersion
        refreshToken
      );
      qbo.getCompanyInfo(realmId, (err, info) => {
        if (err) return res(null);
        res(info?.CompanyName || null);
      });
    });
  } catch {
    return null;
  }
}

// ─── OAuth flow ──────────────────────────────────────────────────────────────

/**
 * Runs the full OAuth 2.0 flow.
 *
 * @param {object} [options]
 * @param {string} [options.clientId]     — override .env
 * @param {string} [options.clientSecret] — override .env
 * @param {string} [options.environment]  — 'sandbox' or 'production'
 * @param {number} [options.timeout]      — ms before giving up (default: 120000)
 * @returns {Promise<{ companyName: string, realmId: string }>}
 */
export async function runAuth(options = {}) {
  let clientId     = options.clientId;
  let clientSecret = options.clientSecret;
  let environment  = options.environment;

  if (!clientId || !clientSecret) {
    const creds = loadCredentials();
    if (!creds) process.exit(1);
    clientId     = creds.clientId;
    clientSecret = creds.clientSecret;
    environment  = environment || creds.environment;
  }

  environment = environment || 'sandbox';

  const oauthClient = new OAuthClient({
    clientId,
    clientSecret,
    environment,
    redirectUri: REDIRECT_URI,
  });

  const consentUrl = oauthClient.authorizeUri({
    scope: SCOPES,
    state: 'selrai-quickbooks-connector',
  });

  const app = express();

  return new Promise((resolvePromise, reject) => {
    // Timeout — default 2 minutes
    const timeoutMs = options.timeout ?? 120_000;
    const timer = setTimeout(() => {
      server.close();
      reject(new Error(
        'No response from browser after 2 minutes. ' +
        'Close any other apps on port 3000 and run the installer again.'
      ));
    }, timeoutMs);

    const server = app.listen(PORT, async () => {
      console.log('\n================================================');
      console.log('  QuickBooks Connector — Sign In');
      console.log('================================================\n');
      console.log(`Environment: ${environment}\n`);
      console.log('Opening your browser to connect QuickBooks...\n');
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
      clearTimeout(timer);
      if (err.code === 'EADDRINUSE') {
        console.error(`\n  ❌  Port ${PORT} is already in use.`);
        console.error(`   Close whatever is running on port ${PORT} and try again.\n`);
      } else {
        console.error('\n  ❌  Could not start local server:', err.message);
      }
      reject(err);
    });

    app.get('/callback', async (req, res) => {
      clearTimeout(timer);

      // User denied access at the Intuit consent screen
      if (req.query.error) {
        const errMsg = req.query.error_description || req.query.error;
        res.status(400).send(errorHtml(
          'Access Denied',
          `You did not approve the connection: ${errMsg}`
        ));
        server.close();
        return reject(new Error(`User denied access: ${errMsg}`));
      }

      try {
        const authResponse = await oauthClient.createToken(req.url);
        const token = authResponse.getJson();

        // realmId (company ID) comes through on the callback URL
        const realmId = req.query.realmId;
        if (!realmId) {
          throw new Error('No realmId returned from QuickBooks — could not identify company.');
        }

        // Persist token + realmId + environment
        writeFileSync(TOKEN_PATH, JSON.stringify({
          token,
          realmId,
          environment,
        }, null, 2));

        const companyName = await fetchCompanyName({
          clientId,
          clientSecret,
          accessToken:  token.access_token,
          refreshToken: token.refresh_token,
          realmId,
          environment,
        }) || 'your QuickBooks company';

        res.send(`
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>QuickBooks Connected</title>
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
            <h2>Connected to QuickBooks!</h2>
            <p>Successfully linked to <span class="org">${companyName}</span>.</p>
            <p>You can close this tab and return to your terminal.</p>
          </body>
          </html>
        `);

        server.close();

        console.log(`  ✅  Connected to: ${companyName}`);
        console.log(`  ✅  Realm ID: ${realmId}`);
        console.log('\n================================================');
        console.log('  All done! QuickBooks is connected to Claude Code.');
        console.log('\n  Try asking Claude:');
        console.log('    "Show me my recent QuickBooks invoices"');
        console.log('    "List my QuickBooks customers"');
        console.log('    "Show me the QuickBooks profit and loss"');
        console.log('================================================\n');

        resolvePromise({ companyName, realmId });
      } catch (err) {
        const message =
          err?.authResponse?.response?.body ||
          err?.originalMessage ||
          err?.message ||
          String(err);

        // Invalid client ID / secret surfaces here on token exchange
        const hint = /invalid[_ ]client/i.test(String(message))
          ? '\n\nThis usually means your Client ID or Client Secret is wrong. ' +
            'Check .env and confirm the values from developer.intuit.com.'
          : '';

        res.status(500).send(errorHtml('Authentication Failed', message + hint));
        server.close();
        reject(new Error(message));
      }
    });
  });
}

// ─── HTML helpers ────────────────────────────────────────────────────────────

function errorHtml(title, message) {
  return `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>${title}</title>
      <style>
        body { font-family: sans-serif; max-width: 540px; margin: 100px auto;
               text-align: center; color: #1a1a1a; padding: 0 20px; }
        .icon { font-size: 48px; margin-bottom: 16px; }
        pre   { text-align: left; background: #f5f5f5; padding: 12px;
                border-radius: 6px; font-size: 13px; overflow-x: auto;
                white-space: pre-wrap; }
      </style>
    </head>
    <body>
      <div class="icon">❌</div>
      <h2>${title}</h2>
      <pre>${String(message).replace(/</g, '&lt;')}</pre>
      <p>Close this tab and run <code>npm run auth</code> again.</p>
    </body>
    </html>
  `;
}

// ─── Standalone execution ─────────────────────────────────────────────────────
// When run directly (npm run auth), execute the flow and exit.

const isMain = process.argv[1] &&
  resolve(process.argv[1]) === resolve(__filename);

if (isMain) {
  runAuth().catch((err) => {
    console.error('\n  ❌  Authentication error:', err.message, '\n');
    process.exit(1);
  });
}
