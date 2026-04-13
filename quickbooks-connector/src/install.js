#!/usr/bin/env node
/**
 * QuickBooks Connector — 1-Click Installer
 * Built by Selr AI — selrai.com.au
 *
 * Run this once to set up everything:
 *   node src/install.js
 *
 * It will:
 *   1. Check Node.js version
 *   2. Install npm dependencies
 *   3. Prompt for QuickBooks credentials + environment
 *   4. Run the OAuth sign-in flow
 *   5. Configure Claude Code (~/.claude.json)
 *   6. Verify the connection
 *   7. Print a success summary
 */

import { execSync } from 'child_process';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { createInterface } from 'readline';
import { homedir, platform } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT       = resolve(__dirname, '..');
const ENV_PATH   = resolve(ROOT, '.env');
const TOKEN_PATH = resolve(ROOT, '.quickbooks-token.json');

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
  step(3, 7, 'Checking QuickBooks credentials...');

  // Check for existing .env with real values
  if (existsSync(ENV_PATH)) {
    const existing  = readFileSync(ENV_PATH, 'utf8');
    const hasId     = /^QUICKBOOKS_CLIENT_ID=(.+)$/m.exec(existing);
    const hasSecret = /^QUICKBOOKS_CLIENT_SECRET=(.+)$/m.exec(existing);
    const hasEnv    = /^QUICKBOOKS_ENVIRONMENT=(.+)$/m.exec(existing);

    if (hasId && hasSecret) {
      const id     = hasId[1].trim();
      const secret = hasSecret[1].trim();
      const env    = hasEnv?.[1].trim() || 'sandbox';

      if (id && secret &&
          id !== 'your_client_id_here' &&
          secret !== 'your_client_secret_here') {
        console.log(`  Found existing credentials (Client ID: ${id.slice(0, 8)}...)`);
        console.log(`  Environment: ${env}`);
        const reuse = await ask('  Use these credentials? (y/n): ');
        if (reuse.toLowerCase() === 'y' || reuse.toLowerCase() === 'yes') {
          ok('Credentials loaded');
          return { clientId: id, clientSecret: secret, environment: env };
        }
      }
    }
  }

  // Prompt for new credentials
  console.log('');
  console.log('  You need an Intuit developer app (free -- takes 3 minutes):');
  console.log('    1. Go to https://developer.intuit.com/app/developer/myapps');
  console.log('    2. Click "Create an app" -> "QuickBooks Online and Payments"');
  console.log('    3. Open the "Keys & OAuth" tab');
  console.log('    4. Add redirect URI: http://localhost:3000/callback');
  console.log('    5. Copy your Client ID and Client Secret');
  console.log('');

  const clientId = await ask('  Paste your QuickBooks Client ID: ');
  if (!clientId || clientId === 'your_client_id_here') {
    fail('Client ID cannot be empty or a placeholder.');
    console.error('  Get your Client ID from https://developer.intuit.com/app/developer/myapps');
    process.exit(1);
  }

  const clientSecret = await ask('  Paste your QuickBooks Client Secret: ');
  if (!clientSecret || clientSecret === 'your_client_secret_here') {
    fail('Client Secret cannot be empty or a placeholder.');
    console.error('  Get your Client Secret from the Keys & OAuth tab of your app.');
    process.exit(1);
  }

  // Environment prompt — sandbox vs production
  console.log('');
  console.log('  QuickBooks has two environments:');
  console.log('    sandbox     - test company with fake data (recommended for workshops)');
  console.log('    production  - your real QuickBooks Online account');
  console.log('');
  const envAnswer = (await ask('  Are you using sandbox or production? (sandbox/production) [sandbox]: '))
    .toLowerCase();

  let environment;
  if (envAnswer === '' || envAnswer === 'sandbox' || envAnswer === 's') {
    environment = 'sandbox';
  } else if (envAnswer === 'production' || envAnswer === 'prod' || envAnswer === 'p') {
    environment = 'production';
  } else {
    fail(`Unrecognised environment: "${envAnswer}".`);
    console.error('  Please answer with "sandbox" or "production" and run the installer again.');
    process.exit(1);
  }

  // Write .env
  const envContent = [
    '# QuickBooks Connector -- Environment Variables',
    '# Generated by the installer -- do not commit this file',
    '',
    `QUICKBOOKS_CLIENT_ID=${clientId}`,
    `QUICKBOOKS_CLIENT_SECRET=${clientSecret}`,
    `QUICKBOOKS_ENVIRONMENT=${environment}`,
    '',
  ].join('\n');

  writeFileSync(ENV_PATH, envContent);
  ok(`Credentials saved (environment: ${environment})`);
  return { clientId, clientSecret, environment };
}

// ─── STEP 4 — OAuth flow ─────────────────────────────────────────────────────

async function runOAuth(clientId, clientSecret, environment) {
  step(4, 7, 'Connecting to QuickBooks...');
  console.log('  Opening QuickBooks in your browser -- sign in and click Connect.');
  console.log('');

  // Dynamic import so we only load after npm install has run
  const { runAuth } = await import('./auth.js');

  return runAuth({ clientId, clientSecret, environment });
}

// ─── STEP 5 — Configure Claude Code ──────────────────────────────────────────

function configureClaude() {
  step(5, 7, 'Configuring Claude Code...');

  const indexPath = resolve(__dirname, 'index.js');
  const home = homedir();
  const claudeJsonPath = join(home, '.claude.json');

  const isWindows = platform() === 'win32';

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
  config.mcpServers.quickbooks = {
    command: 'node',
    args: [isWindows ? indexPath.replace(/\//g, '\\') : indexPath],
  };

  writeFileSync(claudeJsonPath, JSON.stringify(config, null, 2));

  console.log(`  Added "quickbooks" MCP server to ${claudeJsonPath}`);
  ok('Claude Code configured');
}

// ─── STEP 6 — Verify connection ──────────────────────────────────────────────

async function verify() {
  step(6, 7, 'Verifying connection...');

  if (!existsSync(TOKEN_PATH)) {
    fail('Token file not found after OAuth step.');
    console.error('  Run the installer again.');
    process.exit(1);
  }

  const { getQuickBooksClient } = await import('./index.js');
  const { qbo, realmId } = await getQuickBooksClient();

  const companyInfo = await new Promise((res, rej) => {
    qbo.getCompanyInfo(realmId, (err, info) => {
      if (err) return rej(err);
      res(info);
    });
  });

  const companyName = companyInfo?.CompanyName || 'your QuickBooks company';
  ok('Connection verified');
  return { companyName };
}

// ─── STEP 7 — Success summary ────────────────────────────────────────────────

function printSuccess(companyName, environment) {
  step(7, 7, 'Done!');
  console.log('');
  console.log('================================================');
  console.log('  QuickBooks is connected to Claude Code!');
  console.log('');
  console.log(`  Company: ${companyName}`);
  console.log(`  Environment: ${environment}`);
  console.log('');
  console.log('  Restart Claude Code, then try saying:');
  console.log('    "Show me my recent QuickBooks invoices"');
  console.log('    "What\'s my profit and loss this month?"');
  console.log('    "List my QuickBooks customers"');
  console.log('================================================');
  console.log('');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('================================================');
  console.log('  QuickBooks Connector — Installer');
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
  let clientId, clientSecret, environment;
  try {
    ({ clientId, clientSecret, environment } = await getCredentials());
  } catch (err) {
    fail(`Credentials step failed: ${err.message}`);
    process.exit(1);
  }

  // Step 4
  try {
    await runOAuth(clientId, clientSecret, environment);
  } catch (err) {
    fail(`OAuth sign-in failed: ${err.message}`);
    console.error('  Common fixes:');
    console.error('  - Check your Client ID and Secret are correct');
    console.error('  - Confirm redirect URI is http://localhost:3000/callback in your Intuit app');
    console.error('  - Confirm your Intuit app is set to the same environment (sandbox/production)');
    console.error('  - Close any other apps using port 3000');
    process.exit(1);
  }

  // Step 5
  try {
    configureClaude();
  } catch (err) {
    fail(`Claude Code configuration failed: ${err.message}`);
    console.error('  You can manually add the QuickBooks MCP server to ~/.claude.json');
    console.error('  See QUICKBOOKS-SETUP.md Step 5 for instructions.');
    process.exit(1);
  }

  // Step 6
  let companyName;
  try {
    ({ companyName } = await verify());
  } catch (err) {
    fail(`Verification failed: ${err.message}`);
    console.error('  The connection was set up but verification could not complete.');
    console.error('  Try restarting Claude Code and asking "Show me my QuickBooks invoices"');
    console.error('  If that works, you are all set.');
    process.exit(1);
  }

  // Step 7
  printSuccess(companyName, environment);
}

main().catch((err) => {
  fail(`Unexpected error: ${err.message}`);
  process.exit(1);
});
