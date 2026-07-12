# Worked example — designing `cancel_order` from scratch

The **design** path: no schema exists yet — the input is a plain-English ask, and the job is to design a tool's read-surface that passes every check on the first draft. Synthetic e-commerce domain; every value here is invented.

The difference from a repair run: there is no vendor schema to critique. You draft the obvious version, score *your own* draft, and — because JSON Schema is inputs-only — you must **design** the success and error shapes rather than ask for a sample (procedure step 3, new-tool branch).

## The ask

> "Let the agent cancel an order."

## Naive first draft

**`cancel`** — *"Cancels an order."*
- `id` — required

## Part 1 — Scored checklist (against the naive draft)

| # | Check | Verdict | Defect |
|---|---|---|---|
| 1 | Name | **fail** | Bare `cancel` — cancel *what*? Collides with any future `cancel_*`. |
| 2 | Boundary | **fail** | No *use-this-when*. A cancel and a refund are different actions; nothing says which this is or when it applies. |
| 3 | Explicit context | **fail** | An order has states (placed, shipped, cancelled). The description never says a *shipped* order can't be cancelled — the model will try and loop on the error. |
| 4 | Params | **fail** | `id` is ambiguous → `order_id`. No `reason` param, though the domain needs one, and its closed set isn't an enum. |
| 5 | Examples | **fail** | `order_id` format not shown — the model invents `"1"` vs `"ORD-1024"`. |
| 6 | Return contract | **fail** | Undocumented. New-tool branch: it must be **designed**, not requested — what does the agent learn back? |
| 7 | Errors | **fail** | None designed. The three real failure modes (not-found, already-shipped, already-cancelled) each need a distinct, actionable message or the agent retries blindly. |
| 8 | Distinguishability | n/a | Single tool; set-mode check not applicable. (But a `refund_order` sibling is implied — see flags.) |

## Part 2 — Finished read-surface (designed)

```json
{
  "name": "cancel_order",
  "description": "Cancel an order that has NOT yet shipped. Returns the order's new status and whether a refund was initiated. For an order that already shipped, use refund_order instead.",
  "input_schema": {
    "type": "object",
    "properties": {
      "order_id": {
        "type": "string",
        "description": "The order's public ID. Example: \"ORD-1024\"."
      },
      "reason": {
        "type": "string",
        "enum": ["customer_request", "fraud", "duplicate", "out_of_stock"],
        "description": "Why the order is being cancelled."
      }
    },
    "required": ["order_id"]
  }
}
```

**Designed success payload** — `{ "order_id": "ORD-1024", "status": "cancelled", "refund_initiated": true }`. High-signal only: the new status and whether money is moving; no raw internal ids.

**Designed error contract** — one distinct, recoverable message per failure mode:
- not found → `"no order 'ORD-9999' — check the order_id"`
- already shipped → `"order 'ORD-1024' already shipped — use refund_order instead"`
- already cancelled → `"order 'ORD-1024' is already cancelled — no action taken"`

Each tells the agent *what to do next* instead of forcing a blind retry — the whole point of designing errors up front.

## Part 3 — Control-surface flags — NOT changed, your call

1. **Implied sibling `refund_order`** — the description sends shipped orders to `refund_order`. Whether that tool exists (or should) is a tool-count / decomposition call. Named here; not decided.
2. **`reason` accepted values** — the enum `{customer_request, fraud, duplicate, out_of_stock}` is a best guess for a tool that doesn't exist yet. The accepted set is a contract callers depend on: confirm it before shipping. Adding the *enum constraint* was the read-surface fix; settling the *values* is yours.
