# Read-surface checklist — the 8 checks

Score a tool against every check below. Each is marked **pass/fail** with the exact defect on failure. Every rule traces to Anthropic, *Writing effective tools for AI agents* (https://www.anthropic.com/engineering/writing-tools-for-agents).

> Two different rubrics — don't conflate them. **This 8-point checklist grades a *tool*.** The 5-axis vetting rubric (clarity / evidence / install / differentiation / trigger) grades the *SKILL.md itself*.

| # | Check | Rule | Fails when… |
|---|---|---|---|
| 1 | **Name** | Specific, action-oriented, namespaced. Avoid a bare `list_` / `get_` that collides with siblings. | The name could describe three other tools, or two tools share a stem the model must disambiguate from description alone. |
| 2 | **Boundary** | The description says *use this when… / use this not X*. Applies even to a solo tool: state its scope positively against any plausible future sibling — a truly atomic tool still says when it's the right one. | The description gives no *use-this-when* scope, so the model can't tell this tool from an actual or plausible sibling. |
| 3 | **Explicit context** | Niche terms, formats, and relationships are spelled out — "describe it like you would to a new hire." | The description leans on a term (a status set, an ID format, a domain noun) the model has to guess. |
| 4 | **Params** | Unambiguous names (`user_id`, not `user`); enums for closed sets; required vs optional chosen deliberately; **defaults consistent across sibling tools.** | A param is vaguely named, a closed set is free text, or two sibling tools default the same concept to different values. |
| 5 | **Examples** | Concrete example values for any free-text or format-sensitive param. | A free-text or format-sensitive param ships with no example, so the model invents the format. |
| 6 | **Return contract** | Document what comes back. High-signal fields only (drop raw `uuid` / `mime_type`); token-economical — paginate, filter, or truncate with sensible defaults. | The return shape is undocumented, or dumps low-signal fields that burn context. |
| 7 | **Errors** | Actionable messages ("invalid `date`, expected ISO-8601"), not opaque codes or raw tracebacks. | An error returns a bare code or stack trace the model can't recover from. |
| 8 | **Distinguishability** *(set-mode)* | For each near-duplicate, each description disambiguates against the other. **Flag** overlap and the consolidation *option* — hand the restructure decision back to the person you're working with. | Two tools have overlapping descriptions and neither points at the other, so the model can't choose. |

## Set-mode: flag, don't re-architect

Checks 1–7 grade a tool in isolation. Check 8 fires when two or more tools are in play: it detects when "the model can't tell these two apart" — overlapping descriptions.

The remedy is **capped at the description surface.** Reword each description to disambiguate against its neighbour. You may **flag** a near-duplication or tool-count smell and name the consolidation option, but you must **not** decide the restructure (merge / split) — that is a control-surface call. Flag it; hand it back to the person you're working with.

## Enums: shape is read-surface, values are control-surface

Check 4 asks for an enum on a closed set. Adding the *constraint* (this param is a fixed set, not free text) is a read-surface fix — make it. But the *accepted values themselves* are a contract callers depend on: when you can't know them for certain, list your best-guess set in the hardened schema **and flag the value set in part 3 for confirmation**. Never invent or rename accepted values as if they were settled.
