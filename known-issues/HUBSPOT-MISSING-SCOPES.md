# Known Issue — HubSpot: Missing Scopes After Initial Setup

**Status:** Known limitation
**Affects:** hubspot-connector
**Symptom:** `403 Forbidden` or `Missing scope` errors when trying to read contacts, create deals, or use any HubSpot tool

---

## What Is Happening

The HubSpot connector authenticates using a **Private App** that you create in your HubSpot account. During setup, you choose which **scopes** to give it — a scope is a permission that controls what your assistant is allowed to see or do (for example, "read contacts" or "create deals").

If you chose a narrow set of scopes during setup, any action that needs a permission you did not tick will return a `403 Forbidden` error — even though the connection itself is working fine.

The most common cause is setting up the connector for read-only access and then trying to create or update records.

---

## How to Tell If This Is Your Problem

Your assistant will say something like:
> "I need an extra permission to do that. Let me walk you through adding it."

Or you may see an error mentioning `Missing scope` or `403 Forbidden`.

---

## How to Fix It

You do **not** need to create a new Private App — you can edit the existing one.

1. Tell your assistant: *"My HubSpot connection is missing a permission. Can you help me add it?"*
2. Your assistant will tell you exactly which permission is needed
3. Go to **HubSpot → Settings → Integrations → Private Apps** → click your app name
4. Click the **Scopes** tab (this is where permissions are listed)
5. Tick the permission your assistant identified
6. Click **Save changes** — the connection updates automatically, no need to copy anything new

---

## Common Scopes and What They Unlock

| Scope | Unlocks |
|---|---|
| `crm.objects.contacts.read` | Read contacts |
| `crm.objects.contacts.write` | Create and update contacts |
| `crm.objects.deals.read` | Read deals |
| `crm.objects.deals.write` | Create and update deals |
| `crm.objects.companies.read` | Read companies |
| `crm.objects.companies.write` | Create and update companies |
| `crm.objects.notes.write` | Create notes on CRM records |
| `crm.objects.tasks.write` | Create tasks on CRM records |

For most business use cases, setting all of the above to read + write during initial setup avoids having to add scopes later.

---

## Rate Limits

HubSpot enforces **200 API requests per 10 seconds** for Private Apps. In normal conversational use this is never reached. If you are running a large data export or batch operation and hit a 429 error, your assistant will automatically wait and retry.

---

## Related

- Connector docs: `skills/hubspot-connector/SKILL.md`
- Setup guide: `docs/HUBSPOT-SETUP.md`
- General troubleshooting: `docs/TROUBLESHOOTING.md`
