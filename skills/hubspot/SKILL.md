---
name: hubspot
description: HubSpot CRM management. Contacts, companies, deals, tickets, invoices, products, and association queries via official MCP.
---

# HubSpot CRM Skill

You are managing HubSpot CRM via the official `@hubspot/mcp-server`.

## Access Method

### MCP Server
The official HubSpot MCP server provides read access to 13 CRM objects plus association queries.

**MCP server name:** `hubspot`

Use `ToolSearch: +hubspot` to find and load available tools.

### Credentials
- **Private App Access Token**: In `~/.claude/projects/-Users-<username>/secrets/hubspot.env`
- Token format: `pat-na1-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

## Available Objects (13)

| Object | What It Contains |
|---|---|
| `contacts` | People — name, email, phone, lifecycle stage |
| `companies` | Businesses — name, domain, industry, revenue |
| `deals` | Sales opportunities — amount, stage, close date |
| `tickets` | Support requests — subject, status, priority |
| `invoices` | Bills sent to customers |
| `products` | Items/services you sell |
| `line_items` | Individual items on a deal or invoice |
| `quotes` | Price proposals |
| `subscriptions` | Recurring service agreements |
| `orders` | Purchase orders |
| `carts` | Shopping carts (e-commerce) |
| `users` | HubSpot users in your account |
| `owners` | Record owners (for assignment) |

## Key Operations

### Search/List Records
- Search contacts by name, email, or any property
- Search companies by name or domain
- Search deals by stage, amount, or owner
- Filter tickets by status or priority
- All searches support property filtering and sorting

### Get Record Details
- Get any record by ID with all properties
- Specify which properties to return (for efficiency)

### Association Queries
- Find all deals associated with a contact
- Find all contacts at a company
- Find all tickets for a contact
- Find line items on a deal
- Associations work between any two object types

## API Quirks

### Property Names
- HubSpot uses internal property names, not display names
- Contact: `firstname`, `lastname`, `email`, `phone`, `lifecyclestage`
- Company: `name`, `domain`, `industry`, `annualrevenue`
- Deal: `dealname`, `amount`, `dealstage`, `closedate`, `pipeline`
- Ticket: `subject`, `content`, `hs_pipeline_stage`, `hs_ticket_priority`

### Deal Stages
- Stages are referenced by internal ID, not name
- Use the pipeline API to get stage IDs and names
- Common stages: appointmentscheduled, qualifiedtobuy, presentationscheduled, decisionmakerboughtin, contractsent, closedwon, closedlost

### Pagination
- Default page size: 10
- Max page size: 100
- Uses `after` cursor for pagination

### Read-Only Limitation
- The official MCP server is currently **read-only** (public beta)
- You can search, list, and get records but NOT create or update
- For write operations, use the HubSpot API directly via curl or a bash helper

### Rate Limits
- 100 requests per 10 seconds for Private Apps
- Daily limit: 250,000 calls
- If you get 429, wait 10 seconds

## Common Operations

### Find a contact
```
Search contacts with email or name filter
Returns: name, email, phone, lifecycle stage, recent activity
```

### List open deals
```
Search deals with dealstage filter (exclude closedwon, closedlost)
Returns: deal name, amount, stage, expected close date, owner
```

### Check open tickets
```
Search tickets with status filter (exclude closed)
Returns: subject, status, priority, assigned owner, created date
```

### Find all deals for a company
```
1. Search companies by name
2. Get associations: company → deals
3. Get each deal's details
```

### Get contact activity
```
1. Search contact by email
2. Get associations: contact → deals, tickets, companies
3. Compile full picture of the contact's engagement
```

## Safety Rules

1. **Read-only by default** — the MCP server cannot modify records (beta limitation)
2. **Respect data privacy** — contact data may include personal information
3. **Check associations before reporting** — a contact may be associated with multiple companies
4. **Always verify the correct record** — search by email is more reliable than name (duplicates)
5. **Report what you find accurately** — do not infer data that is not in the record
