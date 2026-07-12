# Sample output — one single-tool run

What the three-part output contract looks like on a single tool. Input was one function-calling `tools` entry:

```json
{
  "name": "get_weather",
  "description": "Gets the weather.",
  "input_schema": {
    "type": "object",
    "properties": { "loc": { "type": "string" } },
    "required": ["loc"]
  }
}
```

No sample success or error payload was declared, so both were requested (procedure step 3). Supplied: success `{ "temp": 18, "unit": "C", "conditions": "cloudy" }`; error on a bad location `"ERR_500"`.

---

## Part 1 — Scored checklist

| # | Check | Verdict | Defect |
|---|---|---|---|
| 1 | Name | **fail** | `get_weather` — bare `get_` verb; fine alone but collides the moment a `get_forecast` sibling exists. |
| 2 | Boundary | **fail** | No sibling comparison; nothing says current-conditions vs forecast. |
| 3 | Explicit context | pass | — |
| 4 | Params | **fail** | `loc` is ambiguous — city name? lat/long? postal code? Rename `location`, state the accepted format. |
| 5 | Examples | **fail** | Free-text `location` has no example value. |
| 6 | Return contract | **fail** | Return shape undocumented; `unit` is returned but the caller can't request it. |
| 7 | Errors | **fail** | `"ERR_500"` is opaque — the model can't tell a bad location from an outage, so it retries blindly (the loop). |
| 8 | Distinguishability | n/a | Single tool; set-mode check not applicable. |

## Part 2 — Finished read-surface (read-surface only)

```json
{
  "name": "get_current_weather",
  "description": "Get current conditions for one location. Returns temperature, unit, and a short conditions summary. For a multi-day outlook use get_forecast instead.",
  "input_schema": {
    "type": "object",
    "properties": {
      "location": {
        "type": "string",
        "description": "City and country, or 'lat,long'. Example: \"Melbourne, AU\" or \"-37.81,144.96\"."
      },
      "unit": {
        "type": "string",
        "enum": ["C", "F"],
        "description": "Temperature unit. Defaults to C.",
        "default": "C"
      }
    },
    "required": ["location"]
  }
}
```

Error contract, hardened: return `"invalid location 'xyz' — expected a city name or 'lat,long'"` on a bad location, and a distinct `"weather service unavailable, retry after 30s"` on an outage — so the model recovers instead of looping.

## Part 3 — Control-surface flags — NOT changed, your call

1. **Naming a sibling** — the hardened description now points at `get_forecast`. If no such tool exists yet, that reference is a promise; decide whether to add it. (Tool-count / decomposition = your call.)
2. **Retry policy** — the outage error suggests "retry after 30s", but *whether and how* the agent retries is control-surface. Wire that into your agent's retry/loop logic, not the tool — out of scope here.
