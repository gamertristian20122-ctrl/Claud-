// /api/mcp: NineTail Studio's MCP server over Streamable HTTP.
// Connect an MCP client (Claude, ChatGPT, Cursor, ...) to https://<your-site>/api/mcp.
// The tools and prompts live in lib/mcp/server.ts. None of them call an AI model
// or spend the studio's API keys, so the route needs no sign-in.

import { createMcpHandler } from "mcp-handler";
import { SERVER_INFO, SERVER_INSTRUCTIONS, registerNinetailMcp } from "@/lib/mcp/server";
import { readBody } from "@/lib/read-body";

export const runtime = "nodejs";
export const maxDuration = 30;

/** Fits the largest check_build input (200,000 characters) with JSON escaping. */
const MAX_BODY_BYTES = 2 * 1024 * 1024;

const mcpHandler = createMcpHandler(registerNinetailMcp, {
  serverInfo: SERVER_INFO,
  instructions: SERVER_INSTRUCTIONS,
});

function tooLarge(): Response {
  return Response.json(
    { jsonrpc: "2.0", id: null, error: { code: -32600, message: "Request body too large." } },
    { status: 413, headers: { "Cache-Control": "no-store" } },
  );
}

/** Caps the request body before the MCP handler reads it into memory. */
async function handler(req: Request): Promise<Response> {
  if (!req.body) return mcpHandler(req);
  if (Number(req.headers.get("content-length")) > MAX_BODY_BYTES) return tooLarge();
  const body = await readBody(req, MAX_BODY_BYTES);
  if (body === null) return tooLarge();
  const headers = new Headers(req.headers);
  headers.delete("content-length");
  return mcpHandler(new Request(req.url, { method: req.method, headers, body, signal: req.signal }));
}

export { handler as GET, handler as POST, handler as DELETE };
