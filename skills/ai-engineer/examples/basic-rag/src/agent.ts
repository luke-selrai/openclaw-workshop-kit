// Minimal correct agentic tool-use loop, mirroring the Agent Architecture
// pattern in SKILL.md. The task is seeded ONCE; each turn sends the full
// accumulated transcript; tool_use blocks are answered with tool_result blocks.
// Run: npm run agent -- "what is 19.99 times 3 plus shipping of 9.95?"

import "dotenv/config";
import Anthropic from "@anthropic-ai/sdk";

const MODEL = "claude-sonnet-4-6";
const MAX_ITERATIONS = 5;

// One real local tool the model can call. Keeps the example honest: the tool
// actually runs, there is no mocked transport.
const tools: Anthropic.Tool[] = [
  {
    name: "calculator",
    description: "Evaluate a basic arithmetic expression and return the number.",
    input_schema: {
      type: "object",
      properties: { expression: { type: "string", description: "e.g. (19.99 * 3) + 9.95" } },
      required: ["expression"],
    },
  },
];

// Tiny safe arithmetic evaluator (no eval): supports + - * / and parentheses.
function calculate(expression: string): string {
  if (!/^[\d\s.+\-*/()]+$/.test(expression)) return "Error: unsupported characters";
  try {
    // Function constructor over a validated arithmetic-only string.
    const result = Function(`"use strict"; return (${expression});`)();
    return typeof result === "number" && Number.isFinite(result) ? String(result) : "Error: not a finite number";
  } catch {
    return "Error: could not evaluate";
  }
}

function runTool(name: string, input: Record<string, unknown>): string {
  if (name === "calculator") return calculate(String(input.expression ?? ""));
  return `Error: unknown tool ${name}`;
}

async function runAgent(task: string): Promise<string> {
  const client = new Anthropic();
  // Seed the conversation with the task ONCE, before the loop.
  const messages: Anthropic.MessageParam[] = [{ role: "user", content: task }];

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 1024,
      tools,
      messages, // send the accumulated transcript, not the original task again
    });

    // Record the assistant turn (the content blocks, not the whole response).
    messages.push({ role: "assistant", content: response.content });

    if (response.stop_reason !== "tool_use") {
      return response.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("");
    }

    // Answer every tool_use block with a matching tool_result block.
    const toolResults: Anthropic.ToolResultBlockParam[] = response.content
      .filter((b): b is Anthropic.ToolUseBlock => b.type === "tool_use")
      .map((b) => ({
        type: "tool_result",
        tool_use_id: b.id,
        content: runTool(b.name, b.input as Record<string, unknown>),
      }));

    messages.push({ role: "user", content: toolResults });
  }

  throw new Error("Max iterations exceeded");
}

async function main(): Promise<void> {
  if (!process.env.ANTHROPIC_API_KEY) {
    throw new Error("ANTHROPIC_API_KEY is not set. Copy .env.example to .env and fill it in.");
  }
  const task = process.argv.slice(2).join(" ").trim() || "What is 19.99 times 3 plus shipping of 9.95?";
  console.log(`Task: ${task}`);
  console.log(`\nAnswer:\n${await runAgent(task)}`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
