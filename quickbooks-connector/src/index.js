#!/usr/bin/env node
/**
 * QuickBooks MCP Server for Claude Code
 * Built by Selr AI — selrai.com.au
 *
 * Exposes QuickBooks Online data as MCP tools so Claude Code can
 * read invoices, customers, accounts, and financial reports.
 */

import { Server }               from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import OAuthClient              from 'intuit-oauth';
import QuickBooks               from 'node-quickbooks';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath }    from 'url';
import dotenv               from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT       = resolve(__dirname, '..');
const TOKEN_PATH = resolve(ROOT, '.quickbooks-token.json');

dotenv.config({ path: resolve(ROOT, '.env') });

const REDIRECT_URI = 'http://localhost:3000/callback';

// ─── Token helpers ─────────────────────────────────────────────────────────

function loadTokenFile() {
  if (!existsSync(TOKEN_PATH)) {
    throw new McpError(
      ErrorCode.InvalidRequest,
      'Not authenticated with QuickBooks. Run: npm run auth   (see QUICKBOOKS-SETUP.md)'
    );
  }
  return JSON.parse(readFileSync(TOKEN_PATH, 'utf8'));
}

function saveTokenFile(data) {
  writeFileSync(TOKEN_PATH, JSON.stringify(data, null, 2));
}

// ─── QuickBooks client factory ─────────────────────────────────────────────

export async function getQuickBooksClient() {
  const clientId     = process.env.QUICKBOOKS_CLIENT_ID;
  const clientSecret = process.env.QUICKBOOKS_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new McpError(
      ErrorCode.InvalidRequest,
      'Missing QUICKBOOKS_CLIENT_ID or QUICKBOOKS_CLIENT_SECRET -- check your .env file'
    );
  }

  const stored      = loadTokenFile();
  const realmId     = stored.realmId;
  const environment = stored.environment || process.env.QUICKBOOKS_ENVIRONMENT || 'sandbox';
  let   token       = stored.token;

  if (!realmId) {
    throw new McpError(
      ErrorCode.InvalidRequest,
      'Missing realmId in .quickbooks-token.json — run: npm run auth'
    );
  }

  const oauthClient = new OAuthClient({
    clientId,
    clientSecret,
    environment,
    redirectUri: REDIRECT_URI,
  });

  oauthClient.setToken(token);

  // Refresh if expired
  if (!oauthClient.isAccessTokenValid()) {
    try {
      const authResponse = await oauthClient.refresh();
      token = authResponse.getJson();
      saveTokenFile({ token, realmId, environment });
    } catch {
      throw new McpError(
        ErrorCode.InvalidRequest,
        'QuickBooks token expired and refresh failed. Run: npm run auth'
      );
    }
  }

  const qbo = new QuickBooks(
    clientId,
    clientSecret,
    token.access_token,
    false,                       // no token secret (OAuth 2.0)
    realmId,
    environment === 'sandbox',   // useSandbox
    false,                       // debug
    null,                        // minorversion
    '2.0',                       // oAuthVersion
    token.refresh_token
  );

  return { qbo, realmId };
}

// ─── Promise wrapper for node-quickbooks callbacks ─────────────────────────

function qb(qbo, method, ...args) {
  return new Promise((res, rej) => {
    qbo[method](...args, (err, result) => {
      if (err) return rej(err);
      res(result);
    });
  });
}

// ─── Report parser helper ──────────────────────────────────────────────────

function parseReportRows(report) {
  const sections = [];

  const harvest = (rows) => {
    const out = [];
    for (const r of rows ?? []) {
      if (r.ColData) {
        out.push({
          account: r.ColData[0]?.value ?? '',
          amount:  r.ColData[r.ColData.length - 1]?.value ?? '',
        });
      }
      if (r.Rows?.Row) out.push(...harvest(r.Rows.Row));
      if (r.Summary?.ColData) {
        out.push({
          account: r.Summary.ColData[0]?.value ?? '',
          amount:  r.Summary.ColData[r.Summary.ColData.length - 1]?.value ?? '',
        });
      }
    }
    return out;
  };

  for (const row of report?.Rows?.Row ?? []) {
    if (row.type === 'Section') {
      sections.push({
        title: row.Header?.ColData?.[0]?.value || row.group || '',
        rows:  harvest([row]),
      });
    } else if (row.ColData) {
      sections.push({
        title: row.ColData[0]?.value ?? '',
        rows:  [{
          account: row.ColData[0]?.value ?? '',
          amount:  row.ColData[row.ColData.length - 1]?.value ?? '',
        }],
      });
    }
  }
  return sections;
}

// ─── Tool definitions ──────────────────────────────────────────────────────

const TOOLS = [
  {
    name: 'quickbooks_get_company',
    description: 'Get the name, address, and industry of the connected QuickBooks company.',
    inputSchema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'quickbooks_list_invoices',
    description:
      'List invoices in QuickBooks. Optionally filter by status. ' +
      'Returns invoice number, customer, total, balance due, and due date.',
    inputSchema: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          description: 'Filter by status: Draft | Pending | Voided | Deleted | Synced | Overdue',
          enum: ['Draft', 'Pending', 'Voided', 'Deleted', 'Synced', 'Overdue'],
        },
        limit: { type: 'number', description: 'Maximum number of invoices (default 20)' },
      },
    },
  },
  {
    name: 'quickbooks_get_invoice',
    description: 'Get a specific invoice by its QuickBooks ID.',
    inputSchema: {
      type: 'object',
      properties: {
        invoice_id: { type: 'string', description: 'QuickBooks invoice ID' },
      },
      required: ['invoice_id'],
    },
  },
  {
    name: 'quickbooks_create_invoice',
    description:
      'Create a new invoice in QuickBooks for a customer. ' +
      'If the customer does not exist, it will be created automatically. ' +
      'The invoice is saved as pending (not emailed).',
    inputSchema: {
      type: 'object',
      properties: {
        customer_name: { type: 'string', description: 'Customer display name (required)' },
        description:   { type: 'string', description: 'Line item description (required)' },
        amount:        { type: 'number', description: 'Total amount excluding tax (required)' },
        due_date:      { type: 'string', description: 'Due date in YYYY-MM-DD format (optional)' },
      },
      required: ['customer_name', 'description', 'amount'],
    },
  },
  {
    name: 'quickbooks_list_customers',
    description:
      'List customers in QuickBooks. ' +
      'Use the search parameter to find a specific customer by display name.',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Search by customer display name' },
        limit:  { type: 'number', description: 'Maximum number of customers (default 20)' },
      },
    },
  },
  {
    name: 'quickbooks_create_customer',
    description: 'Create a new customer in QuickBooks.',
    inputSchema: {
      type: 'object',
      properties: {
        name:  { type: 'string', description: 'Customer display name (required)' },
        email: { type: 'string', description: 'Email address' },
        phone: { type: 'string', description: 'Phone number' },
      },
      required: ['name'],
    },
  },
  {
    name: 'quickbooks_list_accounts',
    description:
      'List the chart of accounts in QuickBooks. ' +
      'Optionally filter by account type (e.g. Bank, Income, Expense).',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description:
            'Filter by account type: Bank | Accounts Receivable | Income | Expense | ' +
            'Cost of Goods Sold | Fixed Asset | Other Asset | Credit Card | ' +
            'Accounts Payable | Long Term Liability | Equity',
        },
      },
    },
  },
  {
    name: 'quickbooks_list_bank_transactions',
    description:
      'List recent bank transactions in QuickBooks (purchases and deposits). ' +
      'Returns date, type, payee/customer, and amounts.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Maximum number of transactions per type (default 20)' },
      },
    },
  },
  {
    name: 'quickbooks_list_payments',
    description:
      'List payments received from customers in QuickBooks. ' +
      'Returns payment ID, date, customer, amount, and linked invoice references.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Maximum number of payments (default 20)' },
      },
    },
  },
  {
    name: 'quickbooks_get_profit_loss',
    description:
      'Get the Profit and Loss (Income Statement) report. ' +
      'Shows income, expenses, and net profit for a date range.',
    inputSchema: {
      type: 'object',
      properties: {
        from_date: { type: 'string', description: 'Start date YYYY-MM-DD (default: 1 Jan of current year)' },
        to_date:   { type: 'string', description: 'End date YYYY-MM-DD (default: today)' },
      },
    },
  },
  {
    name: 'quickbooks_get_balance_sheet',
    description:
      'Get the Balance Sheet report showing assets, liabilities, and equity at a point in time.',
    inputSchema: {
      type: 'object',
      properties: {
        as_of_date: { type: 'string', description: 'Report date YYYY-MM-DD (default: today)' },
      },
    },
  },
];

// ─── Tool handlers ─────────────────────────────────────────────────────────

async function handleTool(name, args) {
  const { qbo, realmId } = await getQuickBooksClient();

  switch (name) {

    // ── Company ────────────────────────────────────────────────────────
    case 'quickbooks_get_company': {
      const info = await qb(qbo, 'getCompanyInfo', realmId);
      const addr = info?.CompanyAddr;
      return text({
        name:         info?.CompanyName,
        legal_name:   info?.LegalName,
        country:      info?.Country,
        email:        info?.Email?.Address,
        phone:        info?.PrimaryPhone?.FreeFormNumber,
        industry:     info?.NameValue?.find?.(n => n.Name === 'IndustryType')?.Value,
        fiscal_start: info?.FiscalYearStartMonth,
        address: addr ? {
          line1:       addr.Line1,
          city:        addr.City,
          region:      addr.CountrySubDivisionCode,
          postal_code: addr.PostalCode,
          country:     addr.Country,
        } : null,
      });
    }

    // ── List invoices ──────────────────────────────────────────────────
    case 'quickbooks_list_invoices': {
      const criteria = {
        limit: args.limit || 20,
        desc:  'MetaData.CreateTime',
      };

      const result = await qb(qbo, 'findInvoices', criteria);
      let invoices = result?.QueryResponse?.Invoice ?? [];

      // QuickBooks has no top-level Status field — derive from balance/dates
      const today = new Date().toISOString().split('T')[0];
      invoices = invoices.map(inv => {
        let status;
        if (inv.Balance === 0)                          status = 'Synced';
        else if (inv.DueDate && inv.DueDate < today)    status = 'Overdue';
        else                                            status = 'Pending';
        return { ...inv, _status: status };
      });

      if (args.status) {
        invoices = invoices.filter(inv => inv._status === args.status);
      }

      const out = invoices.map(inv => ({
        id:          inv.Id,
        doc_number:  inv.DocNumber,
        status:      inv._status,
        customer:    inv.CustomerRef?.name,
        date:        inv.TxnDate,
        due_date:    inv.DueDate,
        total:       inv.TotalAmt,
        balance_due: inv.Balance,
        currency:    inv.CurrencyRef?.value,
      }));

      return text({ count: out.length, invoices: out });
    }

    // ── Get single invoice ─────────────────────────────────────────────
    case 'quickbooks_get_invoice': {
      const inv = await qb(qbo, 'getInvoice', args.invoice_id);
      if (!inv) throw new McpError(ErrorCode.InvalidRequest, `Invoice not found: ${args.invoice_id}`);

      return text({
        id:          inv.Id,
        doc_number:  inv.DocNumber,
        customer:    inv.CustomerRef?.name,
        date:        inv.TxnDate,
        due_date:    inv.DueDate,
        total:       inv.TotalAmt,
        balance_due: inv.Balance,
        currency:    inv.CurrencyRef?.value,
        line_items:  (inv.Line ?? [])
          .filter(l => l.DetailType === 'SalesItemLineDetail')
          .map(l => ({
            description: l.Description,
            amount:      l.Amount,
            item:        l.SalesItemLineDetail?.ItemRef?.name,
            quantity:    l.SalesItemLineDetail?.Qty,
          })),
      });
    }

    // ── Create invoice ─────────────────────────────────────────────────
    case 'quickbooks_create_invoice': {
      // 1. Find or create the customer
      const customerSearch = await qb(qbo, 'findCustomers', {
        DisplayName: args.customer_name,
        limit: 1,
      });
      let customer = customerSearch?.QueryResponse?.Customer?.[0];
      if (!customer) {
        customer = await qb(qbo, 'createCustomer', { DisplayName: args.customer_name });
      }

      // 2. Find a default Item to attach the line to (QB requires ItemRef)
      const itemSearch = await qb(qbo, 'findItems', { limit: 1 });
      const item = itemSearch?.QueryResponse?.Item?.[0];
      if (!item) {
        throw new McpError(
          ErrorCode.InvalidRequest,
          'No Products/Services found in QuickBooks — create at least one Item in QuickBooks before creating invoices.'
        );
      }

      // 3. Build invoice payload
      const payload = {
        CustomerRef: { value: customer.Id, name: customer.DisplayName },
        Line: [{
          Amount:      args.amount,
          DetailType:  'SalesItemLineDetail',
          Description: args.description,
          SalesItemLineDetail: {
            ItemRef: { value: item.Id, name: item.Name },
            Qty:     1,
            UnitPrice: args.amount,
          },
        }],
      };
      if (args.due_date) payload.DueDate = args.due_date;

      const created = await qb(qbo, 'createInvoice', payload);

      return text({
        success:    true,
        invoice_id: created?.Id,
        doc_number: created?.DocNumber,
        customer:   created?.CustomerRef?.name,
        total:      created?.TotalAmt,
        due_date:   created?.DueDate,
      });
    }

    // ── List customers ─────────────────────────────────────────────────
    case 'quickbooks_list_customers': {
      const criteria = { limit: args.limit || 20 };
      const result   = args.search
        ? await qb(qbo, 'findCustomers', [
            { field: 'DisplayName', value: `%${args.search}%`, operator: 'LIKE' },
            { field: 'limit',       value: args.limit || 20 },
          ])
        : await qb(qbo, 'findCustomers', criteria);

      const customers = (result?.QueryResponse?.Customer ?? []).map(c => ({
        id:     c.Id,
        name:   c.DisplayName,
        email:  c.PrimaryEmailAddr?.Address,
        phone:  c.PrimaryPhone?.FreeFormNumber,
        active: c.Active,
        balance: c.Balance,
      }));

      return text({ count: customers.length, customers });
    }

    // ── Create customer ────────────────────────────────────────────────
    case 'quickbooks_create_customer': {
      const payload = { DisplayName: args.name };
      if (args.email) payload.PrimaryEmailAddr = { Address: args.email };
      if (args.phone) payload.PrimaryPhone     = { FreeFormNumber: args.phone };

      const created = await qb(qbo, 'createCustomer', payload);

      return text({
        success:     true,
        customer_id: created?.Id,
        name:        created?.DisplayName,
        email:       created?.PrimaryEmailAddr?.Address,
        phone:       created?.PrimaryPhone?.FreeFormNumber,
      });
    }

    // ── List accounts ──────────────────────────────────────────────────
    case 'quickbooks_list_accounts': {
      const criteria = args.type
        ? { AccountType: args.type, limit: 200 }
        : { limit: 200 };
      const result = await qb(qbo, 'findAccounts', criteria);

      const accounts = (result?.QueryResponse?.Account ?? []).map(a => ({
        id:           a.Id,
        name:         a.Name,
        type:         a.AccountType,
        sub_type:     a.AccountSubType,
        classification: a.Classification,
        current_balance: a.CurrentBalance,
        active:       a.Active,
      }));

      return text({ count: accounts.length, accounts });
    }

    // ── Bank transactions (purchases + deposits) ───────────────────────
    case 'quickbooks_list_bank_transactions': {
      const limit = args.limit || 20;
      const [purchasesRes, depositsRes] = await Promise.all([
        qb(qbo, 'findPurchases', { limit, desc: 'TxnDate' }),
        qb(qbo, 'findDeposits',  { limit, desc: 'TxnDate' }),
      ]);

      const purchases = (purchasesRes?.QueryResponse?.Purchase ?? []).map(p => ({
        id:       p.Id,
        type:     'Purchase',
        date:     p.TxnDate,
        payee:    p.EntityRef?.name,
        account:  p.AccountRef?.name,
        amount:   -Math.abs(p.TotalAmt || 0),
        currency: p.CurrencyRef?.value,
      }));

      const deposits = (depositsRes?.QueryResponse?.Deposit ?? []).map(d => ({
        id:       d.Id,
        type:     'Deposit',
        date:     d.TxnDate,
        payee:    null,
        account:  d.DepositToAccountRef?.name,
        amount:   d.TotalAmt,
        currency: d.CurrencyRef?.value,
      }));

      const combined = [...purchases, ...deposits].sort(
        (a, b) => String(b.date).localeCompare(String(a.date))
      );

      return text({ count: combined.length, bank_transactions: combined });
    }

    // ── Payments ───────────────────────────────────────────────────────
    case 'quickbooks_list_payments': {
      const result = await qb(qbo, 'findPayments', [
        { field: 'limit', value: args.limit || 20 },
        { field: 'desc',  value: 'TxnDate' },
      ]);

      const payments = (result?.QueryResponse?.Payment ?? []).map(p => ({
        id:             p.Id,
        date:           p.TxnDate,
        customer:       p.CustomerRef?.name,
        amount:         p.TotalAmt,
        unapplied:      p.UnappliedAmt,
        payment_method: p.PaymentMethodRef?.name,
        reference:      p.PaymentRefNum,
        currency:       p.CurrencyRef?.value,
        linked_invoices: (p.Line ?? [])
          .flatMap(l => l.LinkedTxn ?? [])
          .filter(lt => lt.TxnType === 'Invoice')
          .map(lt => lt.TxnId),
      }));

      return text({ count: payments.length, payments });
    }

    // ── Profit & Loss ──────────────────────────────────────────────────
    case 'quickbooks_get_profit_loss': {
      const today    = todayStr();
      const fromDate = args.from_date || `${new Date().getFullYear()}-01-01`;
      const toDate   = args.to_date   || today;

      const report = await qb(qbo, 'reportProfitAndLoss', {
        start_date: fromDate,
        end_date:   toDate,
      });

      return text({
        title:    report?.Header?.ReportName || 'Profit and Loss',
        from:     fromDate,
        to:       toDate,
        currency: report?.Header?.Currency,
        sections: parseReportRows(report),
      });
    }

    // ── Balance Sheet ──────────────────────────────────────────────────
    case 'quickbooks_get_balance_sheet': {
      const date   = args.as_of_date || todayStr();
      const report = await qb(qbo, 'reportBalanceSheet', { end_date: date });

      return text({
        title:    report?.Header?.ReportName || 'Balance Sheet',
        as_of:    date,
        currency: report?.Header?.Currency,
        sections: parseReportRows(report),
      });
    }

    default:
      throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
  }
}

// ─── Utilities ─────────────────────────────────────────────────────────────

function text(obj) {
  return { content: [{ type: 'text', text: JSON.stringify(obj, null, 2) }] };
}

function todayStr() {
  return new Date().toISOString().split('T')[0];
}

// ─── MCP server bootstrap ──────────────────────────────────────────────────
// Only run when executed directly (node src/index.js), not when imported
// by install.js for its verification step.

const isMain = process.argv[1] &&
  resolve(process.argv[1]) === resolve(__filename);

if (isMain) {
  const server = new Server(
    { name: 'quickbooks-connector', version: '1.0.0' },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    try {
      return await handleTool(name, args ?? {});
    } catch (err) {
      if (err instanceof McpError) throw err;
      const msg =
        err?.Fault?.Error?.[0]?.Detail ||
        err?.fault?.error?.[0]?.detail ||
        err?.message ||
        String(err);
      throw new McpError(ErrorCode.InternalError, `QuickBooks API error: ${msg}`);
    }
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);
}
