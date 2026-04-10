#!/usr/bin/env node
/**
 * Xero MCP Server for Claude Code
 * Built by Selr AI — selrai.com.au
 *
 * Exposes Xero accounting data as MCP tools so Claude Code can
 * read invoices, contacts, accounts, and financial reports.
 */

import { Server }               from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import { XeroClient, Invoice, LineItem, Contact, Phone } from 'xero-node';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath }    from 'url';
import dotenv               from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT       = resolve(__dirname, '..');
const TOKEN_PATH = resolve(ROOT, '.xero-token.json');

dotenv.config({ path: resolve(ROOT, '.env') });

// ─── Token helpers ─────────────────────────────────────────────────────────

function loadTokens() {
  if (!existsSync(TOKEN_PATH)) {
    throw new McpError(
      ErrorCode.InvalidRequest,
      'Not authenticated with Xero. Run: npm run auth   (see XERO-SETUP.md)'
    );
  }
  return JSON.parse(readFileSync(TOKEN_PATH, 'utf8'));
}

function saveTokens(tokenSet) {
  writeFileSync(TOKEN_PATH, JSON.stringify(tokenSet, null, 2));
}

// ─── Xero client factory ───────────────────────────────────────────────────

async function getXeroClient() {
  const clientId     = process.env.XERO_CLIENT_ID;
  const clientSecret = process.env.XERO_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new McpError(
      ErrorCode.InvalidRequest,
      'Missing XERO_CLIENT_ID or XERO_CLIENT_SECRET — check your .env file'
    );
  }

  const xero = new XeroClient({
    clientId,
    clientSecret,
    redirectUris: ['http://localhost:3000/callback'],
    scopes: [
      'openid', 'profile', 'email', 'offline_access',
      'accounting.invoices',          // xero_list_invoices, xero_get_invoice, xero_create_invoice
      'accounting.payments',          // xero_list_payments
      'accounting.banktransactions',  // xero_list_bank_tx
      'accounting.contacts',          // xero_list_contacts, xero_create_contact
      'accounting.settings',          // xero_list_accounts
      'accounting.reports.profitandloss.read',  // xero_get_profit_loss
      'accounting.reports.balancesheet.read',   // xero_get_balance_sheet
    ],
  });

  const stored = loadTokens();
  await xero.setTokenSet(stored);

  // Refresh if expired
  const current = xero.readTokenSet();
  if (current?.expired()) {
    try {
      const refreshed = await xero.refreshWithRefreshToken(
        clientId, clientSecret, stored.refresh_token
      );
      saveTokens(refreshed);
      await xero.setTokenSet(refreshed);
    } catch {
      throw new McpError(
        ErrorCode.InvalidRequest,
        'Xero token expired and refresh failed. Run: npm run auth'
      );
    }
  }

  await xero.updateTenants();
  return xero;
}

function getTenantId(xero) {
  if (!xero.tenants?.length) {
    throw new McpError(ErrorCode.InvalidRequest, 'No Xero organisations found');
  }
  return xero.tenants[0].tenantId;
}

// ─── Report parser helper ──────────────────────────────────────────────────

function parseReportRows(report) {
  const sections = [];
  for (const row of report?.rows ?? []) {
    if (row.rowType === 'Section') {
      const section = { title: row.title || '', rows: [] };
      for (const r of row.rows ?? []) {
        if (r.cells?.length >= 2) {
          section.rows.push({
            account: r.cells[0]?.value ?? '',
            amount:  r.cells[1]?.value ?? '',
          });
        }
      }
      sections.push(section);
    }
  }
  return sections;
}

// ─── Tool definitions ──────────────────────────────────────────────────────

const TOOLS = [
  {
    name: 'xero_get_organisation',
    description: 'Get the name and details of the connected Xero organisation.',
    inputSchema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'xero_list_invoices',
    description:
      'List invoices in Xero. Optionally filter by status (DRAFT, AUTHORISED, PAID, VOIDED) ' +
      'or contact name. Returns invoice number, contact, total, amount due, and due date.',
    inputSchema: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          description: 'Filter by status: DRAFT | SUBMITTED | AUTHORISED | PAID | VOIDED',
          enum: ['DRAFT', 'SUBMITTED', 'AUTHORISED', 'PAID', 'VOIDED'],
        },
        page: { type: 'number', description: 'Page number (100 invoices per page, default 1)' },
        search: { type: 'string', description: 'Search invoices by contact name or invoice number' },
      },
    },
  },
  {
    name: 'xero_get_invoice',
    description: 'Get a specific invoice by its Xero ID or invoice number (e.g. INV-0001).',
    inputSchema: {
      type: 'object',
      properties: {
        invoice_id: {
          type: 'string',
          description: 'Xero invoice ID (UUID) or invoice number such as INV-0001',
        },
      },
      required: ['invoice_id'],
    },
  },
  {
    name: 'xero_create_invoice',
    description:
      'Create a new DRAFT invoice in Xero for a contact. ' +
      'Use xero_list_accounts to find the right account code (e.g. 200 for Sales).',
    inputSchema: {
      type: 'object',
      properties: {
        contact_name:  { type: 'string', description: 'Customer name (must match existing contact, or a new one will be created)' },
        description:   { type: 'string', description: 'Line item description — what was sold or delivered' },
        quantity:      { type: 'number', description: 'Quantity (default: 1)' },
        unit_amount:   { type: 'number', description: 'Price per unit excluding tax' },
        account_code:  { type: 'string', description: 'Account code, e.g. 200 for Sales. Run xero_list_accounts to find codes.' },
        due_date:      { type: 'string', description: 'Due date in YYYY-MM-DD format' },
        currency_code: { type: 'string', description: 'Currency code: AUD, NZD, USD, etc. Defaults to the org default.' },
        reference:     { type: 'string', description: 'Optional reference or PO number' },
      },
      required: ['contact_name', 'description', 'unit_amount'],
    },
  },
  {
    name: 'xero_list_contacts',
    description:
      'List contacts (customers and suppliers) in Xero. ' +
      'Use the search parameter to find a specific contact by name or email.',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Search by name or email address' },
        page:   { type: 'number', description: 'Page number (100 contacts per page)' },
      },
    },
  },
  {
    name: 'xero_create_contact',
    description: 'Create a new contact (customer or supplier) in Xero.',
    inputSchema: {
      type: 'object',
      properties: {
        name:        { type: 'string', description: 'Contact display name (required)' },
        email:       { type: 'string', description: 'Email address' },
        phone:       { type: 'string', description: 'Phone number' },
        is_customer: { type: 'boolean', description: 'Mark as a customer (default: true)' },
        is_supplier: { type: 'boolean', description: 'Mark as a supplier' },
      },
      required: ['name'],
    },
  },
  {
    name: 'xero_list_accounts',
    description:
      'List the chart of accounts in Xero. ' +
      'Returns account codes and names needed when creating invoices.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description:
            'Filter by type: BANK | CURRENT | EQUITY | EXPENSE | FIXED | ' +
            'LIABILITY | PREPAYMENT | REVENUE | SALES | TERMLIABILITY',
        },
      },
    },
  },
  {
    name: 'xero_get_profit_loss',
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
    name: 'xero_get_balance_sheet',
    description:
      'Get the Balance Sheet report showing assets, liabilities, and equity at a point in time.',
    inputSchema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Report date YYYY-MM-DD (default: today)' },
      },
    },
  },
  {
    name: 'xero_list_payments',
    description: 'List payments recorded in Xero against invoices or bills.',
    inputSchema: {
      type: 'object',
      properties: {
        page: { type: 'number', description: 'Page number (100 payments per page)' },
      },
    },
  },
];

// ─── Tool handlers ─────────────────────────────────────────────────────────

async function handleTool(name, args) {
  const xero     = await getXeroClient();
  const tenantId = getTenantId(xero);

  switch (name) {

    // ── Organisation ──────────────────────────────────────────────────
    case 'xero_get_organisation': {
      const org = xero.tenants[0];
      return text({ name: org.tenantName, type: org.tenantType, id: org.tenantId });
    }

    // ── List invoices ──────────────────────────────────────────────────
    case 'xero_list_invoices': {
      const statuses = args.status ? [args.status] : undefined;
      const page     = args.page   || 1;
      const search   = args.search || undefined;

      const res = await xero.accountingApi.getInvoices(
        tenantId,
        /*ifModifiedSince*/ undefined,
        /*where*/           undefined,
        /*order*/           undefined,
        /*ids*/             undefined,
        /*invoiceNumbers*/  undefined,
        /*contactIDs*/      undefined,
        statuses,
        page,
        /*includeArchived*/ undefined,
        /*createdByMyApp*/  undefined,
        /*unitdp*/          undefined,
        /*summaryOnly*/     false,
        /*pageSize*/        100,
        search
      );

      const invoices = (res.body.invoices ?? []).map(inv => ({
        id:        inv.invoiceID,
        number:    inv.invoiceNumber,
        reference: inv.reference,
        status:    inv.status,
        contact:   inv.contact?.name,
        date:      fmtDate(inv.date),
        dueDate:   fmtDate(inv.dueDate),
        total:     inv.total,
        amountDue: inv.amountDue,
        currency:  inv.currencyCode,
      }));

      return text({ count: invoices.length, invoices });
    }

    // ── Get single invoice ─────────────────────────────────────────────
    case 'xero_get_invoice': {
      const res = await xero.accountingApi.getInvoice(tenantId, args.invoice_id);
      const inv = res.body.invoices?.[0];
      if (!inv) throw new McpError(ErrorCode.InvalidRequest, `Invoice not found: ${args.invoice_id}`);

      return text({
        id:          inv.invoiceID,
        number:      inv.invoiceNumber,
        reference:   inv.reference,
        status:      inv.status,
        contact:     inv.contact?.name,
        date:        fmtDate(inv.date),
        dueDate:     fmtDate(inv.dueDate),
        total:       inv.total,
        subTotal:    inv.subTotal,
        totalTax:    inv.totalTax,
        amountDue:   inv.amountDue,
        amountPaid:  inv.amountPaid,
        currency:    inv.currencyCode,
        lineItems:   inv.lineItems?.map(li => ({
          description:  li.description,
          quantity:     li.quantity,
          unitAmount:   li.unitAmount,
          accountCode:  li.accountCode,
          taxType:      li.taxType,
          lineAmount:   li.lineAmount,
        })),
      });
    }

    // ── Create invoice ─────────────────────────────────────────────────
    case 'xero_create_invoice': {
      const contact  = new Contact();
      contact.name   = args.contact_name;

      const lineItem       = new LineItem();
      lineItem.description = args.description;
      lineItem.quantity    = args.quantity    ?? 1;
      lineItem.unitAmount  = args.unit_amount;
      if (args.account_code) lineItem.accountCode = args.account_code;

      const invoice        = new Invoice();
      invoice.type         = Invoice.TypeEnum.ACCREC;
      invoice.contact      = contact;
      invoice.lineItems    = [lineItem];
      invoice.status       = Invoice.StatusEnum.DRAFT;
      if (args.due_date)      invoice.dueDate      = new Date(args.due_date);
      if (args.currency_code) invoice.currencyCode  = args.currency_code;
      if (args.reference)     invoice.reference     = args.reference;

      const res     = await xero.accountingApi.createInvoices(tenantId, { invoices: [invoice] });
      const created = res.body.invoices?.[0];
      const warn    = created?.validationErrors?.length
        ? created.validationErrors.map(e => e.message).join('; ')
        : null;

      return text({
        success:        !warn,
        invoice_id:     created?.invoiceID,
        invoice_number: created?.invoiceNumber,
        status:         created?.status,
        total:          created?.total,
        ...(warn ? { warning: warn } : {}),
      });
    }

    // ── List contacts ──────────────────────────────────────────────────
    case 'xero_list_contacts': {
      const res = await xero.accountingApi.getContacts(
        tenantId,
        /*ifModifiedSince*/ undefined,
        /*where*/           undefined,
        /*order*/           undefined,
        /*ids*/             undefined,
        /*page*/            args.page || 1,
        /*includeArchived*/ undefined,
        /*summaryOnly*/     false,
        /*searchTerm*/      args.search || undefined
      );

      const contacts = (res.body.contacts ?? []).map(c => ({
        id:         c.contactID,
        name:       c.name,
        email:      c.emailAddress,
        phone:      c.phones?.find(p => p.phoneType === 'DEFAULT')?.phoneNumber,
        isCustomer: c.isCustomer,
        isSupplier: c.isSupplier,
      }));

      return text({ count: contacts.length, contacts });
    }

    // ── Create contact ─────────────────────────────────────────────────
    case 'xero_create_contact': {
      const contact      = new Contact();
      contact.name       = args.name;
      if (args.email) contact.emailAddress = args.email;
      if (args.phone) {
        const phone         = new Phone();
        phone.phoneNumber   = args.phone;
        phone.phoneType     = Phone.PhoneTypeEnum.DEFAULT;
        contact.phones      = [phone];
      }
      if (args.is_customer !== undefined) contact.isCustomer = args.is_customer;
      if (args.is_supplier !== undefined) contact.isSupplier = args.is_supplier;

      const res     = await xero.accountingApi.createContacts(tenantId, { contacts: [contact] });
      const created = res.body.contacts?.[0];

      return text({
        success:    true,
        contact_id: created?.contactID,
        name:       created?.name,
        email:      created?.emailAddress,
      });
    }

    // ── List accounts ──────────────────────────────────────────────────
    case 'xero_list_accounts': {
      const where = args.type ? `Type=="${args.type}"` : undefined;
      const res   = await xero.accountingApi.getAccounts(tenantId, undefined, where);

      const accounts = (res.body.accounts ?? []).map(a => ({
        code:    a.code,
        name:    a.name,
        type:    a.type,
        status:  a.status,
        taxType: a.taxType,
      }));

      return text({ count: accounts.length, accounts });
    }

    // ── Profit & Loss ──────────────────────────────────────────────────
    case 'xero_get_profit_loss': {
      const today    = todayStr();
      const fromDate = args.from_date || `${new Date().getFullYear()}-01-01`;
      const toDate   = args.to_date   || today;

      const res    = await xero.accountingApi.getReportProfitAndLoss(tenantId, fromDate, toDate);
      const report = res.body.reports?.[0];

      return text({
        title:    report?.reportTitle,
        from:     fromDate,
        to:       toDate,
        sections: parseReportRows(report),
      });
    }

    // ── Balance Sheet ──────────────────────────────────────────────────
    case 'xero_get_balance_sheet': {
      const date   = args.date || todayStr();
      const res    = await xero.accountingApi.getReportBalanceSheet(tenantId, date);
      const report = res.body.reports?.[0];

      return text({
        title:    report?.reportTitle,
        date,
        sections: parseReportRows(report),
      });
    }

    // ── Payments ───────────────────────────────────────────────────────
    case 'xero_list_payments': {
      const res = await xero.accountingApi.getPayments(
        tenantId,
        undefined, undefined, undefined,
        args.page || 1
      );

      const payments = (res.body.payments ?? []).map(p => ({
        id:        p.paymentID,
        date:      fmtDate(p.date),
        amount:    p.amount,
        type:      p.paymentType,
        status:    p.status,
        reference: p.reference,
        invoice:   p.invoice?.invoiceNumber,
      }));

      return text({ count: payments.length, payments });
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

function fmtDate(d) {
  if (!d) return null;
  // Xero dates come back as "/Date(timestamp)/" or ISO strings
  if (typeof d === 'string' && d.startsWith('/Date(')) {
    const ms = parseInt(d.replace('/Date(', '').replace(')/', ''));
    return new Date(ms).toISOString().split('T')[0];
  }
  if (d instanceof Date) return d.toISOString().split('T')[0];
  return String(d);
}

export { getXeroClient };

// ─── MCP server bootstrap ──────────────────────────────────────────────────

const server = new Server(
  { name: 'xero-connector', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  try {
    return await handleTool(name, args ?? {});
  } catch (err) {
    if (err instanceof McpError) throw err;
    const msg = err?.response?.body?.Detail ?? err?.message ?? String(err);
    throw new McpError(ErrorCode.InternalError, `Xero API error: ${msg}`);
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);

