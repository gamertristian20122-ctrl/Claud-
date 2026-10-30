// Streams a generation from OpenRouter's OpenAI-compatible chat completions API.
// OpenRouter is not Anthropic, so this uses plain fetch + a small SSE parser.
// Server-only: never import this from client components.

import type { ModelInfo } from "../models";
import { ProviderError, abortedError, isAbortError, parseRetryAfter, type ProviderStreamResult } from "./errors";

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";
const MAX_TOKENS = 16000;

export interface OpenRouterStreamArgs {
  apiKey: string;
  model: ModelInfo;
  system: string;
  user: string;
  signal?: AbortSignal;
  /** Sent as HTTP-Referer for OpenRouter's app attribution. */
  referer?: string;
}

interface ChunkPayload {
  error?: { message?: unknown; code?: unknown };
  choices?: { delta?: { content?: unknown }; finish_reason?: unknown }[];
}

export async function* streamOpenRouter({
  apiKey,
  model,
  system,
  user,
  signal,
  referer,
}: OpenRouterStreamArgs): AsyncGenerator<string, ProviderStreamResult, undefined> {
  let res: Response;
  try {
    res = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": process.env.NEXT_PUBLIC_SITE_URL || referer || "https://ninetail.studio",
        "X-Title": "NineTail Studio",
      },
      body: JSON.stringify({
        model: model.openrouterId,
        stream: true,
        max_tokens: MAX_TOKENS,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
      signal,
      cache: "no-store",
    });
  } catch (err) {
    if (signal?.aborted || isAbortError(err)) throw abortedError();
    throw new ProviderError("UPSTREAM", 502, "Couldn't reach OpenRouter. Try again in a moment.");
  }

  if (!res.ok) {
    const detail = await readErrorDetail(res);
    throw httpError(res.status, detail, parseRetryAfter(res.headers.get("retry-after")));
  }
  if (!res.body) throw new ProviderError("UPSTREAM", 502, "OpenRouter returned an empty response.");

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let finishReason: string | null = null;
  let finished = false;
  /** "[DONE]" arrived. A body that ends without it or a finish_reason was cut off. */
  let sawDone = false;
  /** Something was yielded, so the route has sent its headers. */
  let started = false;

  try {
    while (!finished) {
      let chunk: ReadableStreamReadResult<Uint8Array>;
      try {
        chunk = await reader.read();
      } catch (err) {
        if (signal?.aborted || isAbortError(err)) throw abortedError();
        throw new ProviderError("UPSTREAM", 502, "The connection to OpenRouter dropped mid-build.");
      }
      if (chunk.done) {
        buffer += decoder.decode();
        // Process a final line that had no trailing newline.
        if (buffer) buffer += "\n";
        finished = true;
      } else {
        buffer += decoder.decode(chunk.value, { stream: true });
      }

      let newline: number;
      while ((newline = buffer.indexOf("\n")) !== -1) {
        let line = buffer.slice(0, newline);
        buffer = buffer.slice(newline + 1);
        if (line.endsWith("\r")) line = line.slice(0, -1);

        // Blank lines end an event; ":" lines are comments such as ": OPENROUTER PROCESSING".
        if (!line) continue;
        if (line.startsWith(":")) {
          // OpenRouter accepted the request and is waiting on the model: an empty
          // chunk lets the route send its headers now instead of after the first token.
          if (!started) {
            started = true;
            yield "";
          }
          continue;
        }
        if (!line.startsWith("data:")) continue;

        const data = line.slice(5).trimStart();
        if (data === "[DONE]") {
          sawDone = true;
          finished = true;
          break;
        }

        let payload: ChunkPayload;
        try {
          payload = JSON.parse(data) as ChunkPayload;
        } catch {
          continue; // Ignore malformed keep-alive fragments.
        }

        if (payload.error) throw streamError(payload.error);

        const choice = payload.choices?.[0];
        const content = choice?.delta?.content;
        if (typeof content === "string" && content) {
          started = true;
          yield content;
        }

        if (typeof choice?.finish_reason === "string") {
          finishReason = choice.finish_reason;
          if (finishReason === "error") {
            throw new ProviderError("UPSTREAM", 502, "The model stopped with an error. Try again.");
          }
        }
      }
    }
  } finally {
    // Closes the upstream connection when we stop early (done, error or the
    // consumer called return() after a client disconnect).
    reader.cancel().catch(() => {});
  }

  if (!sawDone && finishReason === null) {
    throw new ProviderError("UPSTREAM", 502, "The connection to OpenRouter dropped mid-build.");
  }
  if (finishReason === "content_filter") {
    throw new ProviderError("UPSTREAM", 422, "The model declined this request. Try rephrasing it.");
  }
  return { truncated: finishReason === "length", stopReason: finishReason };
}

async function readErrorDetail(res: Response): Promise<string | null> {
  try {
    const text = await res.text();
    try {
      const json = JSON.parse(text) as { error?: { message?: unknown } };
      const msg = json.error?.message;
      if (typeof msg === "string" && msg.trim()) return msg.trim();
    } catch {
      // Not JSON.
    }
    return null;
  } catch {
    return null;
  }
}

function httpError(status: number, detail: string | null, retryAfterSec?: number): ProviderError {
  switch (status) {
    case 401:
      return new ProviderError("INVALID_KEY", 401, "That OpenRouter key was rejected.");
    case 402:
      return new ProviderError("UPSTREAM", 402, "Your OpenRouter account is out of credits.");
    case 403:
      return new ProviderError("UPSTREAM", 403, detail ? `OpenRouter blocked this request: ${detail}` : "OpenRouter blocked this request.");
    case 429:
      return new ProviderError("RATE_LIMITED", 429, "OpenRouter is rate-limiting this key. Wait a moment and try again.", {
        retryAfterSec,
      });
    case 400:
      return new ProviderError("BAD_REQUEST", 400, detail ? `OpenRouter rejected the request: ${detail}` : "OpenRouter rejected the request.");
    case 404:
      return new ProviderError("UPSTREAM", 502, "That model isn't available on OpenRouter right now.");
    default:
      return new ProviderError("UPSTREAM", 502, `OpenRouter returned an error (${status}). Try again in a moment.`);
  }
}

function streamError(error: { message?: unknown; code?: unknown }): ProviderError {
  const code = typeof error.code === "number" ? error.code : Number(error.code);
  const msg = typeof error.message === "string" && error.message.trim() ? error.message.trim() : null;
  if (code === 401 || code === 402 || code === 403 || code === 429 || code === 400) return httpError(code, msg);
  return new ProviderError("UPSTREAM", 502, msg ? `OpenRouter error: ${msg}` : "OpenRouter reported an error mid-build.");
}
