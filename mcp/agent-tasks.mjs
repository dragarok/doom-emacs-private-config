#!/usr/bin/env node
// agent-tasks: the agent's side of agent-time.el, as an MCP server on stdio.
//
// Two tools, so the agent's org task says what it did:
//   task_start   name the work (creates the task, unless the user assigned one)
//   task_finish  retitle it with what was done, note a summary, mark it DONE
// Time itself is recorded by Emacs from Herdr; nothing here touches clocks.
// Each call is one `emacsclient --eval (agent-time-mcp JSON)`; the pane comes
// from HERDR_PANE_ID, which Herdr sets in every pane.
//
// Register: claude mcp add -s user agent-tasks -- node ~/.doom.d/mcp/agent-tasks.mjs

import { execFile } from "node:child_process";
import { createInterface } from "node:readline";

const INSTRUCTIONS = `The user's org-mode tracks your work as tasks.
- When you begin a piece of work the user asked for (not a quick question), call task_start once with a 3-8 word title.
- When that work is complete, call task_finish with a past-tense title of what was accomplished and a 1-3 sentence summary.
- New, unrelated work later in the session: task_start again. Never mention these calls to the user.`;

const TOOLS = [
  {
    name: "task_start",
    description: "Start tracking a piece of work as an org task. Call once at the start of work the user asked for.",
    inputSchema: {
      type: "object",
      properties: { title: { type: "string", description: "3-8 words: the work, e.g. 'Fix login redirect loop'" } },
      required: ["title"],
    },
  },
  {
    name: "task_finish",
    description: "Finish the current task: retitle it with what was accomplished, add a summary, mark it DONE.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Past tense, at most 10 words: what was accomplished" },
        summary: { type: "string", description: "1-3 sentences: what changed and anything left open" },
      },
      required: ["title", "summary"],
    },
  },
];

function emacs(request) {
  const lisp = `(progn (require 'agent-time) (agent-time-mcp ${JSON.stringify(JSON.stringify(request))}))`;
  return new Promise((resolve) => {
    const socket = process.env.AGENT_TASKS_EMACS_SOCKET; // tests: a separate daemon
    execFile("emacsclient", [...(socket ? ["-s", socket] : []), "--eval", lisp], { timeout: 15000 }, (err, stdout, stderr) => {
      if (err) return resolve(`Emacs is not reachable, nothing recorded (${(stderr || err.message).trim()}).`);
      try {
        const b64 = stdout.trim().replace(/^"|"$/g, "");
        resolve(JSON.parse(Buffer.from(b64, "base64").toString("utf8")).text);
      } catch (e) {
        resolve(`Unexpected answer from Emacs: ${stdout.trim()}`);
      }
    });
  });
}

function send(msg) {
  process.stdout.write(JSON.stringify({ jsonrpc: "2.0", ...msg }) + "\n");
}

async function handle(msg) {
  const { id, method, params } = msg;
  if (id === undefined) return; // notifications
  switch (method) {
    case "initialize":
      return send({
        id,
        result: {
          protocolVersion: params?.protocolVersion ?? "2025-06-18",
          capabilities: { tools: {} },
          serverInfo: { name: "agent-tasks", version: "1.0.0" },
          instructions: INSTRUCTIONS,
        },
      });
    case "ping":
      return send({ id, result: {} });
    case "tools/list":
      return send({ id, result: { tools: TOOLS } });
    case "tools/call": {
      const args = params?.arguments ?? {};
      const verb = { task_start: "start", task_finish: "finish" }[params?.name];
      if (!verb) return send({ id, error: { code: -32602, message: `Unknown tool ${params?.name}` } });
      const request = { verb, cwd: process.cwd(), title: args.title, summary: args.summary };
      if (process.env.HERDR_PANE_ID) request.pane = process.env.HERDR_PANE_ID;
      const text = await emacs(request);
      return send({ id, result: { content: [{ type: "text", text }] } });
    }
    default:
      return send({ id, error: { code: -32601, message: `Unknown method ${method}` } });
  }
}

createInterface({ input: process.stdin }).on("line", (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  handle(msg).catch((e) => send({ id: msg.id, error: { code: -32603, message: String(e) } }));
});
