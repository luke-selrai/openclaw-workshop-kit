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

// Tiny safe arithmetic evaluator. This does NOT use eval or the Function
// constructor: it tokenizes the input, runs a shunting-yard parse to RPN, then
// evaluates the RPN numerically. No code path turns the input string into
// executable code, so widening the accepted characters cannot lead to code
// execution. The regex below is kept only as a cheap first-pass reject of
// obviously-unsupported input (defense in depth), not as the safety boundary.
// For richer needs (exponents, functions, variables), reach for a real parser
// such as a Pratt parser or a vetted math-expression library rather than eval.
function calculate(expression: string): string {
  if (!/^[\d\s.+\-*/()]+$/.test(expression)) return "Error: unsupported characters";
  try {
    const tokens = tokenize(expression);
    const rpn = toRpn(tokens);
    const result = evalRpn(rpn);
    return Number.isFinite(result) ? String(result) : "Error: not a finite number";
  } catch {
    return "Error: could not evaluate";
  }
}

type Token =
  | { kind: "num"; value: number }
  | { kind: "op"; value: string }
  | { kind: "unary"; value: "neg" }
  | { kind: "paren"; value: "(" | ")" };

// Split an arithmetic string into number, operator, and parenthesis tokens.
function tokenize(expr: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;
  while (i < expr.length) {
    const ch = expr[i];
    if (ch === " " || ch === "\t") {
      i++;
      continue;
    }
    if (ch === "(" || ch === ")") {
      tokens.push({ kind: "paren", value: ch });
      i++;
      continue;
    }
    if (ch === "+" || ch === "-" || ch === "*" || ch === "/") {
      tokens.push({ kind: "op", value: ch });
      i++;
      continue;
    }
    if (/[\d.]/.test(ch)) {
      let num = "";
      let dots = 0;
      while (i < expr.length && /[\d.]/.test(expr[i])) {
        if (expr[i] === ".") dots++;
        num += expr[i];
        i++;
      }
      // Self-sufficient numeric validity: do NOT lean on the first-pass regex.
      // Reject empty, a bare dot, or multiple dots before trusting Number().
      if (num === "" || num === "." || dots > 1) throw new Error("bad number");
      const value = Number(num);
      if (!Number.isFinite(value)) throw new Error("bad number");
      tokens.push({ kind: "num", value });
      continue;
    }
    throw new Error(`unexpected character: ${ch}`);
  }
  return tokens;
}

// Shunting-yard: convert infix tokens to Reverse Polish Notation.
// A "+" or "-" in a unary position (at the start, after a binary operator, or
// after a "(") has no left-hand operand. Unary "+" is a no-op and is dropped;
// unary "-" becomes a distinct right-associative "neg" operator whose precedence
// is HIGHER than * and /, so it binds tightly to exactly its operand. This
// replaces the old "inject a 0" trick, which let the binary "-" associate with
// the wrong neighbour and silently produced wrong results (e.g. 2 - -3).
function toRpn(tokens: Token[]): Token[] {
  const output: Token[] = [];
  const ops: Token[] = [];
  // Binary precedence: + - = 1, * / = 2. Unary neg sits above both at 3 and is
  // right-associative, so a neg is only popped by another neg, never by * or /.
  const binPrec: Record<string, number> = { "+": 1, "-": 1, "*": 2, "/": 2 };
  const NEG_PREC = 3;
  let prevKind: Token["kind"] | "start" = "start";

  const precOf = (t: Token): number =>
    t.kind === "unary" ? NEG_PREC : t.kind === "op" ? binPrec[t.value] : -1;

  for (const tok of tokens) {
    if (tok.kind === "num") {
      output.push(tok);
    } else if (tok.kind === "op") {
      // A +/- with no left-hand operand is unary.
      const unary =
        (tok.value === "-" || tok.value === "+") &&
        (prevKind === "start" || prevKind === "op" || prevKind === "unary" || prevKind === "paren");
      if (unary) {
        // Unary "+" is a no-op; only unary "-" emits a neg operator. Push neg
        // without popping: it is the highest-precedence, right-associative op,
        // so it never displaces an operator already on the stack.
        if (tok.value === "-") ops.push({ kind: "unary", value: "neg" });
        prevKind = "unary";
        continue;
      }
      // Binary operator: pop strictly-higher, and equal-but-left-associative,
      // operators (neg, being right-associative, is only popped when strictly
      // higher, which it always is, so a pending neg flushes correctly here).
      while (
        ops.length > 0 &&
        (ops[ops.length - 1].kind === "op" || ops[ops.length - 1].kind === "unary") &&
        precOf(ops[ops.length - 1]) >= binPrec[tok.value]
      ) {
        output.push(ops.pop() as Token);
      }
      ops.push(tok);
    } else if (tok.value === "(") {
      ops.push(tok);
    } else {
      // ")": pop until the matching "(".
      while (ops.length > 0 && !(ops[ops.length - 1].kind === "paren" && ops[ops.length - 1].value === "(")) {
        output.push(ops.pop() as Token);
      }
      if (ops.length === 0) throw new Error("mismatched parentheses");
      ops.pop(); // discard the "("
    }
    prevKind = tok.kind === "paren" && tok.value === ")" ? "num" : tok.kind;
  }

  while (ops.length > 0) {
    const op = ops.pop() as Token;
    if (op.kind === "paren") throw new Error("mismatched parentheses");
    output.push(op);
  }
  return output;
}

// Evaluate an RPN token stream numerically.
function evalRpn(rpn: Token[]): number {
  const stack: number[] = [];
  for (const tok of rpn) {
    if (tok.kind === "num") {
      stack.push(tok.value);
      continue;
    }
    if (tok.kind === "unary") {
      // neg: 1-arg pop, negate.
      const x = stack.pop();
      if (x === undefined) throw new Error("malformed expression");
      stack.push(-x);
      continue;
    }
    if (tok.kind !== "op") throw new Error("unexpected token");
    const b = stack.pop();
    const a = stack.pop();
    if (a === undefined || b === undefined) throw new Error("malformed expression");
    switch (tok.value) {
      case "+": stack.push(a + b); break;
      case "-": stack.push(a - b); break;
      case "*": stack.push(a * b); break;
      case "/": stack.push(a / b); break;
      default: throw new Error(`unknown operator: ${tok.value}`);
    }
  }
  if (stack.length !== 1) throw new Error("malformed expression");
  return stack[0];
}

function runTool(name: string, input: Record<string, unknown>): string {
  if (name === "calculator") return calculate(String(input.expression ?? ""));
  return `Error: unknown tool ${name}`;
}

async function runAgent(task: string): Promise<string> {
  // Production: wire timeout + maxRetries on the client and a rate limiter in
  // front of the loop. See the Production Readiness checklist in SKILL.md.
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
