// Voyage AI embeddings via the documented HTTP API (no extra SDK dependency).
// Anthropic recommends Voyage AI for embeddings. voyage-4 is a balanced default.
// Docs: https://docs.voyageai.com/reference/embeddings-api

const VOYAGE_URL = "https://api.voyageai.com/v1/embeddings";
const MODEL = "voyage-4";

type InputType = "query" | "document";

interface VoyageResponse {
  data: { embedding: number[]; index: number }[];
  model: string;
  usage: { total_tokens: number };
}

function requireKey(): string {
  const key = process.env.VOYAGE_API_KEY;
  if (!key) {
    throw new Error("VOYAGE_API_KEY is not set. Copy .env.example to .env and fill it in.");
  }
  return key;
}

// Embed a batch of texts. input_type matters for retrieval quality: pass
// "document" when indexing a corpus, "query" when embedding a user question.
export async function embed(texts: string[], inputType: InputType): Promise<number[][]> {
  const res = await fetch(VOYAGE_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${requireKey()}`,
    },
    body: JSON.stringify({ input: texts, model: MODEL, input_type: inputType }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Voyage API ${res.status}: ${body}`);
  }

  const json = (await res.json()) as VoyageResponse;
  // Sort by index to guarantee alignment with the input order.
  return json.data.sort((a, b) => a.index - b.index).map((d) => d.embedding);
}

// Voyage embeddings are normalized to unit length, so dot product equals
// cosine similarity. We still normalize defensively in case a caller swaps
// in a non-normalized provider.
export function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 0 : dot / denom;
}
