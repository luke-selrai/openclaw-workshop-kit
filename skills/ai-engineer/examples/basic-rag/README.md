# basic-rag

A minimal, runnable reference for the patterns in the ai-engineer skill: embed a
small corpus with Voyage AI, retrieve the most relevant chunks for a query, and
answer with Claude. A second entrypoint shows a correct agentic tool-use loop.

## What is real and what is illustrative

- Real: Voyage embedding calls, cosine similarity retrieval, the Claude
  Messages call, and the agent tool-use loop (the calculator tool actually runs).
- Illustrative: the corpus is five hard-coded strings, and the rerank stage in
  `rag.ts` is an honest no-op (a sort) with a comment marking where a
  cross-encoder or Voyage Rerank goes in production.

Nothing here is mocked behind a fake transport. With valid keys the scripts make
live API calls.

## Setup

```bash
npm install
cp .env.example .env   # then fill in ANTHROPIC_API_KEY and VOYAGE_API_KEY
```

Get keys: Anthropic at https://console.anthropic.com and Voyage at
https://www.voyageai.com. Never commit `.env`.

## Run

```bash
npm run rag -- "how long do refunds take?"
npm run agent -- "what is 19.99 times 3 plus shipping of 9.95?"
npm run typecheck   # verifies the example compiles, no keys needed
```

## Files

| File | Role |
|------|------|
| `src/embeddings.ts` | Voyage HTTP embedding call + cosine similarity |
| `src/corpus.ts` | The in-memory document set |
| `src/rag.ts` | Embed, retrieve top-k, synthesize an answer with Claude |
| `src/agent.ts` | Correct agentic loop: seed task once, send transcript, answer tool calls |

## Model and embedding choices

- Synthesis and agent: `claude-sonnet-4-6` (balanced tier). Route to
  `claude-haiku-4-5` for cheap/simple turns or `claude-opus-4-8` for the
  hardest reasoning. Model IDs are pinned snapshots; verify the current set
  against the Claude models documentation before shipping.
- Embeddings: `voyage-4` (balanced). Use `voyage-4-large` for best quality,
  `voyage-4-lite` for lowest cost, `voyage-code-3` for code retrieval.
