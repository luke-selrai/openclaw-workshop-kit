---
name: deep-research
description: "Deep research on any topic using Claude's built-in web search, synthesised into a structured, cited report. Use when the user asks to research competitors, size up a market, run due diligence on a company, or wants a sourced report they can act on."
risk: safe
source: "https://github.com/sanjay3290/ai-skills/tree/main/skills/deep-research"
date_added: "2026-02-27"
---

# Deep Research

Bundled artifacts (read these to verify the SKILL works end-to-end):

- [`examples/deep-research-session.md`](examples/deep-research-session.md), full worked transcript.
- [`CHANGELOG.md`](CHANGELOG.md), version history.

Run autonomous research that plans, searches the web, reads multiple sources, and synthesises them into a structured, cited report. The default method runs entirely on Claude's built-in web search. There is nothing to install, no API key, and no Python. It works the moment the kit is set up.

## When to Use This Skill

Use this skill when the owner wants to:

- Research competitors or size up a market
- Landscape an industry or track trends
- Do due diligence on a company, product, or partner
- Pull a literature or technical review together
- Get a detailed, cited research report they can act on

## How it works (default, no setup)

1. Clarify the question in one line. If it is broad, ask one or two quick scoping questions (industry, region, what decision it feeds).
2. Break it into 3 to 6 sub-questions that together answer the whole thing.
3. For each sub-question, use `WebSearch` to find the strongest sources, then fetch and read the most relevant ones.
4. Cross-check the important claims across more than one source and note where sources disagree.
5. Synthesise into a structured report with inline source citations, and end with a short "what this means for you" section aimed at the owner's decision.

Typical run: a few minutes, depending on how deep the owner wants to go. There is no per-task API charge; it is covered by the owner's existing Claude subscription. If a search returns thin results, say so plainly and give the best answer available rather than inventing detail.

## Output Formats

- **Default**: a human-readable markdown report with sources.
- **Structured**: on request, a table (for example a competitor comparison matrix) plus a short recommendation.

## Best Use Cases

- Market analysis and competitive landscaping
- Technical literature reviews
- Due diligence research
- Historical research and timelines
- Comparative analysis (frameworks, products, technologies)

## Advanced (optional, not required, not bundled)

For very large or long-running batch research, an optional Gemini-powered script mode exists upstream. It is NOT needed for normal research and is NOT shipped with this kit. Using it requires the owner to set up, on their own machine, Python 3.8+, a free `GEMINI_API_KEY` from [Google AI Studio](https://aistudio.google.com/), and the `research.py` script from the upstream project (see `source` above). If none of that is set up, ignore this section entirely; the default native method above is the supported path and covers normal research needs.

When that advanced setup exists, the upstream script is driven like this (reference only):

```bash
python3 scripts/research.py --query "Analyze EV battery market" --stream
python3 scripts/research.py --status <interaction_id>
python3 scripts/research.py --wait <interaction_id>
```

If the owner asks for research and this advanced mode is not configured, do NOT try to run the script or ask them to install Python or a key. Just run the default native method above.
