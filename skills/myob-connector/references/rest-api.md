# MYOB REST endpoint reference

Every path below is relative to `$COMPANY_URI`, read from `company_file.uri` in `~/.config/myob/tokens.json`.

`<access_token>` comes from `tokens.json`. `<client_id>` comes from `~/.config/myob/credentials.json` — the user's own developer app. Never echo either.

Every call carries all four headers:

```
Authorization: Bearer <access_token>
x-myobapi-key: <client_id>
x-myobapi-version: v2
Accept: application/json
```

POST and PUT add `Content-Type: application/json`.

## Sales

| Operation | Endpoint | Method |
|---|---|---|
| List invoices (item) | `$COMPANY_URI/Sale/Invoice/Item` | GET |
| List invoices (service) | `$COMPANY_URI/Sale/Invoice/Service` | GET |
| Get invoice by UID | `$COMPANY_URI/Sale/Invoice/Item/{UID}` | GET |
| Create item invoice | `$COMPANY_URI/Sale/Invoice/Item` | POST |
| Update item invoice | `$COMPANY_URI/Sale/Invoice/Item/{UID}` | PUT |
| List quotes | `$COMPANY_URI/Sale/Quote/Item` | GET |
| Create quote | `$COMPANY_URI/Sale/Quote/Item` | POST |

## Purchases

| Operation | Endpoint | Method |
|---|---|---|
| List bills | `$COMPANY_URI/Purchase/Bill/Item` | GET |
| Create bill | `$COMPANY_URI/Purchase/Bill/Item` | POST |
| List orders | `$COMPANY_URI/Purchase/Order/Item` | GET |

## Contacts

| Operation | Endpoint | Method |
|---|---|---|
| List customers | `$COMPANY_URI/Contact/Customer` | GET |
| Get customer by UID | `$COMPANY_URI/Contact/Customer/{UID}` | GET |
| Create customer | `$COMPANY_URI/Contact/Customer` | POST |
| List suppliers | `$COMPANY_URI/Contact/Supplier` | GET |
| Create supplier | `$COMPANY_URI/Contact/Supplier` | POST |
| List employees | `$COMPANY_URI/Contact/Employee` | GET |

## Inventory

| Operation | Endpoint | Method |
|---|---|---|
| List items | `$COMPANY_URI/Inventory/Item` | GET |
| Get item by UID | `$COMPANY_URI/Inventory/Item/{UID}` | GET |
| Create item | `$COMPANY_URI/Inventory/Item` | POST |

## Banking

| Operation | Endpoint | Method |
|---|---|---|
| List accounts | `$COMPANY_URI/GeneralLedger/Account` | GET |
| List bank transactions | `$COMPANY_URI/Banking/SpendMoneyTxn` (out) / `$COMPANY_URI/Banking/ReceiveMoneyTxn` (in) | GET |
| Record spend money | `$COMPANY_URI/Banking/SpendMoneyTxn` | POST |
| Record receive money | `$COMPANY_URI/Banking/ReceiveMoneyTxn` | POST |
| List tax codes | `$COMPANY_URI/GeneralLedger/TaxCode` | GET |

## Payroll (AU only, needs the `sme-payroll` scope)

| Operation | Endpoint | Method |
|---|---|---|
| List pay items | `$COMPANY_URI/Payroll/PayrollCategory/Wage` | GET |
| List super funds | `$COMPANY_URI/Payroll/SuperannuationFund` | GET |
| List employees | `$COMPANY_URI/Contact/Employee` | GET |

## Filtering

MYOB endpoints take OData query syntax:

- `?$filter=Status eq 'Open'`
- `?$top=20`
- `?$orderby=Date desc`
- `?$select=UID,Number,Date,TotalAmount`
- `?$filter=substringof('acme',CompanyName)`
- `?$filter=Customer/UID eq guid'<UID>'`

Default to `$top=10` to keep payloads small, then offer more.

## Field shapes

Invoice, contact and item payloads vary by endpoint subtype. An Item invoice and a Service invoice have different `Lines` shapes. When unsure, GET an existing record first to learn the schema, then mirror it on POST.

## AccountRight differences

The endpoint paths above are written for MYOB Business. AccountRight may need the `/accountright/<file-id>/...` prefix instead of the `Uri` returned by company-file discovery. Verify against the live file before assuming.

AccountRight cloud files carrying their own company-file password additionally need `x-myobapi-cftoken: Base64(file-username:file-password)` on data-endpoint calls. Not implemented in v1.
