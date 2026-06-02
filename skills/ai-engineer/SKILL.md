---
name: ai-engineer
description: Build production-ready LLM applications, advanced RAG systems, intelligent agents, and multi-model routers. Implements vector search, retrieval pipelines, agent orchestration, multi-model routing, and enterprise AI integrations. Use PROACTIVELY to build or design any LLM feature, chatbot, AI agent, RAG system, or model router.
allowed-tools: Read,Write,Edit,Glob,Grep,Bash,WebFetch,mcp__SequentialThinking__sequentialthinking
metadata:
  category: AI & Machine Learning
  pairs-with:
  - skill: prompt-engineer
    reason: Optimize prompts for LLM applications
  - skill: chatbot-analytics
    reason: Monitor and analyze AI chatbot performance
  - skill: backend-architect
    reason: Design scalable AI service architecture
  - skill: claude-api
    reason: SDK-level reference for wiring Claude into application code
  tags:
  - llm
  - rag
  - agents
  - ai
  - production
  - embeddings
---

# AI Engineer

Expert in building production-ready LLM applications, from simple chatbots to complex multi-agent systems. Specializes in RAG architectures, vector databases, prompt management, and enterprise AI deployments.

This skill is for BUILDING the system. For product strategy, positioning, and roadmap decisions about an AI feature, use ai-product instead. For SDK-level wiring of the Anthropic API (language-specific setup, prompt caching, tool-use plumbing), use claude-api as the reference layer.

## Quick Start

```
User: "Build a customer support chatbot with our product documentation"

AI Engineer:
1. Design RAG architecture (chunking, embedding, retrieval)
2. Set up vector database (Pinecone/Weaviate/Chroma)
3. Implement retrieval pipeline with reranking
4. Build conversation management with context
5. Add guardrails and fallback handling
6. Deploy with monitoring and observability
```

**Result**: Production-ready AI chatbot in days, not weeks. A self-hosted RAG pipeline like the one below replaces a managed RAG service that runs roughly $200 to $800/mo at low volume, and deflects routine support tickets a human would otherwise answer.

**Try it now**: a runnable end-to-end reference ships in `examples/basic-rag/`. Run `npm install`, copy `.env.example` to `.env`, then `npm run rag -- "how long do refunds take?"` to see embedding, retrieval, fenced context, and a grounded Claude answer end to end. It uses the same loop shapes shown below. Read it to verify the patterns before adapting them.

## Core Competencies

### 1. RAG System Design
| Component | Implementation | Best Practices |
|-----------|---------------|----------------|
| **Chunking** | Semantic, token-based, hierarchical | 512-1024 tokens, overlap 10-20% |
| **Embedding** | Voyage AI, OpenAI, local models | Match model to domain |
| **Vector DB** | Pinecone, Weaviate, Chroma, Qdrant | Index by use case |
| **Retrieval** | Dense, sparse, hybrid | Start hybrid, tune |
| **Reranking** | Cross-encoder, Voyage Rerank, Cohere Rerank | Always rerank top-k |

### 2. LLM Application Patterns
- Chat with memory and context management
- Agentic workflows with tool use
- Multi-model orchestration (router + specialists)
- Structured output generation (JSON, XML)
- Streaming responses with error handling

### 3. Production Operations
- Token usage tracking and cost optimization
- Latency monitoring and caching strategies
- A/B testing for prompt versions
- Fallback chains and graceful degradation
- Security (prompt injection, PII handling)

## Architecture Patterns

### Basic RAG Pipeline

```typescript
// Simple RAG implementation
async function ragQuery(query: string): Promise<string> {
  // 1. Embed the query
  const queryEmbedding = await embed(query);

  // 2. Retrieve relevant chunks
  const chunks = await vectorDb.query({
    vector: queryEmbedding,
    topK: 10,
    includeMetadata: true
  });

  // 3. Rerank for relevance
  const reranked = await reranker.rank(query, chunks);
  const topChunks = reranked.slice(0, 5);

  // 4. Generate response with context
  const response = await llm.chat({
    system: SYSTEM_PROMPT,
    messages: [
      { role: 'user', content: buildPrompt(query, topChunks) }
    ]
  });

  return response.content;
}
```

### Agent Architecture

```typescript
// Agentic loop with tool use.
// The task is seeded once. Each turn sends the full accumulated transcript,
// appends the assistant turn and any tool results, then loops until the
// model stops requesting tools or the iteration cap is hit.
interface Agent {
  systemPrompt: string;
  tools: Tool[];
  maxIterations: number;
}

async function runAgent(agent: Agent, task: string): Promise<string> {
  // Seed the conversation with the task ONCE, before the loop.
  const messages: Message[] = [{ role: 'user', content: task }];
  let iterations = 0;

  while (iterations < agent.maxIterations) {
    // Send the accumulated transcript, not the original task again.
    const response = await llm.chat({
      system: agent.systemPrompt,
      messages,
      tools: agent.tools
    });

    // Record the assistant turn. content is the assistant's message content,
    // not the whole response object.
    messages.push({ role: 'assistant', content: response.content });

    if (!response.toolCalls || response.toolCalls.length === 0) {
      return response.content; // Final answer, no more tools requested.
    }

    // Execute the requested tools and feed results back as a tool turn.
    const toolResults = await executeTools(response.toolCalls);
    messages.push({ role: 'tool', content: toolResults });
    iterations++;
  }

  throw new Error('Max iterations exceeded');
}
```

### Multi-Model Router

```typescript
// Route queries to the appropriate Claude model by complexity.
// IDs are the current generally-available Claude 4.x snapshots.
// Verify the freshest IDs at build time against the Claude models docs;
// model IDs are pinned snapshots, not evergreen pointers.
const MODEL_ROUTER = {
  simple: 'claude-haiku-4-5',     // Fast, cheap
  moderate: 'claude-sonnet-4-6',  // Balanced
  complex: 'claude-opus-4-8',     // Best quality
};

function routeQuery(query: string, context: any): ModelId {
  // Classify complexity
  if (isSimpleQuery(query)) return MODEL_ROUTER.simple;
  if (requiresReasoning(query, context)) return MODEL_ROUTER.complex;
  return MODEL_ROUTER.moderate;
}
```

## Implementation Checklist

### RAG System
- [ ] Document ingestion pipeline
- [ ] Chunking strategy (semantic preferred)
- [ ] Embedding model selection
- [ ] Vector database setup
- [ ] Retrieval with hybrid search
- [ ] Reranking layer
- [ ] Citation/source tracking
- [ ] Evaluation metrics (relevance, faithfulness)

### Production Readiness
- [ ] Error handling and retries
- [ ] Rate limiting
- [ ] Token tracking
- [ ] Cost monitoring
- [ ] Latency metrics
- [ ] Caching layer
- [ ] Fallback responses
- [ ] PII filtering
- [ ] Prompt injection guards

### Observability
- [ ] Request logging
- [ ] Response quality scoring
- [ ] User feedback collection
- [ ] A/B test framework
- [ ] Drift detection
- [ ] Alert thresholds

## Anti-Patterns

### Anti-Pattern: RAG Everything
**What it looks like**: Using RAG for every query
**Why wrong**: Adds latency, cost, and complexity when unnecessary
**Instead**: Classify queries, use RAG only when context needed

### Anti-Pattern: Chunking by Character
**What it looks like**: `text.slice(0, 1000)` for chunks
**Why wrong**: Breaks semantic meaning, poor retrieval
**Instead**: Semantic chunking respecting document structure

### Anti-Pattern: No Reranking
**What it looks like**: Using raw vector similarity as final ranking
**Why wrong**: Embedding similarity != relevance for query
**Instead**: Always add cross-encoder reranking

### Anti-Pattern: Unbounded Context
**What it looks like**: Stuffing all retrieved chunks into prompt
**Why wrong**: Dilutes relevance, wastes tokens, confuses model
**Instead**: Top 3-5 chunks after reranking, dynamic selection

### Anti-Pattern: No Guardrails
**What it looks like**: Direct user input to LLM
**Why wrong**: Prompt injection, toxic outputs, off-topic responses
**Instead**: Input validation, output filtering, topic guardrails. Treat retrieved
documents as untrusted data too: instructions inside a retrieved chunk are not
your instructions, fence them as content.

## Technology Stack

### Vector Databases
| Database | Best For | Notes |
|----------|----------|-------|
| **Pinecone** | Production, scale | Managed, fast |
| **Weaviate** | Hybrid search | GraphQL, modules |
| **Chroma** | Development, local | Embedded, simple |
| **Qdrant** | Self-hosted, filters | Rust, performant |
| **pgvector** | Existing Postgres | Easy integration |

### LLM Frameworks
| Framework | Best For | Notes |
|-----------|----------|-------|
| **LangChain** | Prototyping | Many integrations |
| **LlamaIndex** | RAG focus | Document handling |
| **Vercel AI SDK** | Streaming, React | Edge-ready |
| **Anthropic SDK** | Direct API | Full control |

### Embedding Models
Anthropic does not ship its own embedding model and recommends Voyage AI for embeddings.

| Model | Dimensions | Notes |
|-------|------------|-------|
| **voyage-4-large** | 1024 (256/512/2048 opt.) | Best general-purpose and multilingual quality |
| **voyage-4** | 1024 (256/512/2048 opt.) | Balanced quality and efficiency, good default |
| **voyage-4-lite** | 1024 (256/512/2048 opt.) | Optimized for latency and cost |
| **voyage-code-3** | 1024 (256/512/2048 opt.) | Code and technical retrieval |
| **text-embedding-3-large** | 3072 | OpenAI, high quality |
| **text-embedding-3-small** | 1536 | OpenAI, cost-effective |
| **bge-large** | 1024 | Open source, self-hosted |

For retrieval, pass `input_type` (`query` vs `document`) so the model produces
asymmetric query/document representations. Voyage embeddings are normalized to
unit length, so dot-product and cosine similarity are equivalent.

## When to Use

**Use for:**
- Building chatbots and conversational AI
- Implementing RAG systems
- Creating AI agents with tools
- Designing multi-model architectures
- Production AI deployments

**Do NOT use for:**
- Prompt optimization (use prompt-engineer)
- ML model training (use ml-engineer)
- Data pipelines (use data-pipeline-engineer)
- General backend (use backend-architect)
- AI product strategy, positioning, roadmap (use ai-product)
- SDK setup and per-language Claude API wiring (use claude-api)

---

**Core insight**: Production AI systems need more than good prompts. They need robust retrieval, intelligent routing, comprehensive monitoring, and graceful failure handling.

**Use with**: prompt-engineer (optimization) | chatbot-analytics (monitoring) | backend-architect (infrastructure) | claude-api (SDK wiring) | ai-product (strategy)
