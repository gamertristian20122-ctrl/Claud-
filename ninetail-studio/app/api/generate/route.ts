// POST /api/generate: streams a generation in the lib/format.ts wire format.
// GET  /api/generate: which server-side keys exist (never the keys themselves).
//
// Contract
// - 200 text/plain stream. Headers: X-Ninetail-Mode (live | demo),
//   X-Ninetail-Provider (anthropic | openrouter | demo), X-Ninetail-Sentinel (a
//   per-request nonce). If generation fails after the stream started, the stream
//   ends with formatStreamError(message, nonce) (lib/format.ts).
// - Non-2xx: JSON GenerateErrorBody { error, code }.
//   400 BAD_REQUEST / INVALID_KEY / KEY_MODEL_MISMATCH, 401/403 INVALID_KEY (rejected by the provider),
//   403 BAD_REQUEST (cross-site), 413 BAD_REQUEST (body too large), 415 BAD_REQUEST (not JSON),
//   429 RATE_LIMITED (+ Retry-After), 402/422/502/503 UPSTREAM (503 also when the server's own key fails).

import { createDemoStream } from "@/lib/demo-stream";
import { STREAM_SENTINEL_HEADER, formatStreamError } from "@/lib/format";
import { detectKeyProvider, getModel, isModelId, isTarget, providerSupportsModel, type ModelInfo } from "@/lib/models";
import { buildSystemPrompt, buildUserPrompt } from "@/lib/prompts";
import { streamAnthropic, toAnthropicError } from "@/lib/providers/anthropic";
import { ProviderError, type ProviderStreamResult } from "@/lib/providers/errors";
import { streamOpenRouter } from "@/lib/providers/openrouter";
import { checkRateLimit, getClientIp } from "@/lib/ratelimit";
import type { GenerateErrorBody, KeyProvider, ServerStatus, Target } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 300;

const MAX_PROMPT = 4000;
const MAX_KEY = 300;
const MAX_BODY_BYTES = 32 * 1024;

const TRUNCATED_MESSAGE = "The build was cut off because it hit the length limit. Try a smaller or simpler request.";
const SERVER_KEY_UNAVAILABLE = "Free builds are unavailable right now. Try again later or connect your own key.";

function errorJson(status: number, code: GenerateErrorBody["code"], error: string, retryAfterSec?: number): Response {
  const headers: Record<string, string> = { "Cache-Control": "no-store" };
  if (retryAfterSec && retryAfterSec > 0) headers["Retry-After"] = String(retryAfterSec);
  return Response.json({ error, code } satisfies GenerateErrorBody, { status, headers });
}

function streamHeaders(mode: "live" | "demo", provider: KeyProvider | "demo", nonce: string): HeadersInit {
  return {
    "Content-Type": "text/plain; charset=utf-8",
    "Cache-Control": "no-store, no-transform",
    "X-Accel-Buffering": "no",
    "X-Content-Type-Options": "nosniff",
    "X-Ninetail-Mode": mode,
    "X-Ninetail-Provider": provider,
    [STREAM_SENTINEL_HEADER]: nonce,
  };
}

function serverKeys() {
  return {
    anthropic: process.env.ANTHROPIC_API_KEY?.trim() || null,
    openrouter: process.env.OPENROUTER_API_KEY?.trim() || null,
  };
}

export async function GET() {
  const keys = serverKeys();
  const status: ServerStatus = { anthropic: Boolean(keys.anthropic), openrouter: Boolean(keys.openrouter) };
  return Response.json(status, { headers: { "Cache-Control": "no-store" } });
}

/**
 * A browser request started by another site (e.g. a no-cors "simple" POST that
 * would spend the server's keys from every visitor's IP). Non-browser clients
 * send neither header. Origin is compared with the Host the browser used as well
 * as req.url, because under `next start` req.url is http://localhost:<port>.
 */
function isCrossSite(req: Request): boolean {
  if (req.headers.get("sec-fetch-site") === "cross-site") return true;
  const origin = req.headers.get("origin");
  if (!origin) return false;
  let host: string;
  try {
    host = new URL(origin).host.toLowerCase();
  } catch {
    return true; // "null" (sandboxed frames, file://).
  }
  const own = [new URL(req.url).host, req.headers.get("x-forwarded-host")?.split(",")[0], req.headers.get("host")];
  const site = process.env.NEXT_PUBLIC_SITE_URL;
  if (site) {
    try {
      own.push(new URL(site).host);
    } catch {
      // Not a URL: ignore.
    }
  }
  return !own.some((h) => h?.trim().toLowerCase() === host);
}

/**
 * Reads the body as UTF-8 text, or returns null as soon as it passes `limit`
 * bytes. Counting bytes as they arrive also covers chunked uploads, which have
 * no Content-Length.
 */
async function readBody(req: Request, limit: number): Promise<string | null> {
  if (!req.body) return "";
  const reader = req.body.getReader();
  const decoder = new TextDecoder();
  let size = 0;
  let text = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      reader.cancel().catch(() => {});
      return null;
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

interface ValidBody {
  prompt: string;
  target: Target;
  model: ModelInfo;
  byokKey: string | null;
}

function validate(json: unknown): ValidBody | Response {
  if (typeof json !== "object" || json === null || Array.isArray(json)) {
    return errorJson(400, "BAD_REQUEST", "Send a JSON body with prompt, target and model.");
  }
  const body = json as Record<string, unknown>;

  if (typeof body.prompt !== "string" || !body.prompt.trim()) {
    return errorJson(400, "BAD_REQUEST", "Describe what to build first.");
  }
  const prompt = body.prompt.trim();
  if (prompt.length > MAX_PROMPT) {
    return errorJson(400, "BAD_REQUEST", `Keep the prompt under ${MAX_PROMPT} characters.`);
  }
  if (!isTarget(body.target)) {
    return errorJson(400, "BAD_REQUEST", "Unknown target. Use web, imgui or ctk.");
  }
  if (!isModelId(body.model)) {
    return errorJson(400, "BAD_REQUEST", "Unknown model.");
  }

  let byokKey: string | null = null;
  if (body.byokKey !== undefined && body.byokKey !== null) {
    if (typeof body.byokKey !== "string" || body.byokKey.length > MAX_KEY) {
      return errorJson(400, "BAD_REQUEST", "That key doesn't look right.");
    }
    byokKey = body.byokKey.trim() || null;
  }

  return { prompt, target: body.target, model: getModel(body.model), byokKey };
}

type LiveRoute = { kind: "live"; provider: KeyProvider; apiKey: string; paidByServer: boolean };
type Route = { kind: "demo" } | LiveRoute;

function pickRoute({ model, byokKey }: ValidBody): Route | Response {
  if (byokKey) {
    const provider = detectKeyProvider(byokKey);
    if (!provider) {
      return errorJson(400, "INVALID_KEY", "Keys start with sk-ant- (Anthropic) or sk-or- (OpenRouter).");
    }
    // Printable ASCII only: keeps the key safe to put in a header.
    if (/[^\x21-\x7e]/.test(byokKey)) {
      return errorJson(400, "INVALID_KEY", "That key has spaces or unexpected characters. Paste it again.");
    }
    if (!providerSupportsModel(provider, model.id)) {
      return errorJson(400, "KEY_MODEL_MISMATCH", "DeepSeek and GPT-4o need an OpenRouter key.");
    }
    return { kind: "live", provider, apiKey: byokKey, paidByServer: false };
  }

  const keys = serverKeys();
  if (model.anthropicId && keys.anthropic) return { kind: "live", provider: "anthropic", apiKey: keys.anthropic, paidByServer: true };
  if (keys.openrouter) return { kind: "live", provider: "openrouter", apiKey: keys.openrouter, paidByServer: true };
  // No usable key for this model: demo mode (prebuilt outputs, no AI call).
  return { kind: "demo" };
}

function toProviderError(err: unknown, signal: AbortSignal): ProviderError {
  // toAnthropicError passes ProviderErrors through and maps everything else safely.
  return toAnthropicError(err, signal);
}

/**
 * Logs a provider failure and returns what the visitor should see. When the
 * server's own key is rejected, out of credit or blocked, the visitor gets a
 * generic 503 instead of "your key was rejected" or the operator's billing
 * text; the real reason goes to the server log. BYOK keeps the provider's message.
 */
function visibleError(pe: ProviderError, route: LiveRoute, when: string): ProviderError {
  const serverKeyFailed =
    route.paidByServer && (pe.code === "INVALID_KEY" || pe.code === "BAD_REQUEST" || pe.status === 402 || pe.status === 403);
  if (!serverKeyFailed) {
    console.warn(`[generate] ${route.provider} failed ${when}: ${pe.code} ${pe.status}`);
    return pe;
  }
  // pe.message is already scrubbed of anything key-like (ProviderError).
  console.error(`[generate] server ${route.provider} key failed ${when}: ${pe.code} ${pe.status} ${pe.message}`);
  return new ProviderError("UPSTREAM", 503, SERVER_KEY_UNAVAILABLE);
}

export async function POST(req: Request) {
  // ---- Parse and validate -------------------------------------------------
  if (isCrossSite(req)) return errorJson(403, "BAD_REQUEST", "Builds can only be started from the studio itself.");
  // JSON only: any other type could be a cross-origin "simple" request that skips the CORS preflight.
  if (!req.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
    return errorJson(415, "BAD_REQUEST", "Send a JSON body with prompt, target and model.");
  }
  if (Number(req.headers.get("content-length")) > MAX_BODY_BYTES) {
    return errorJson(413, "BAD_REQUEST", "That request is too large.");
  }
  let json: unknown;
  try {
    const text = await readBody(req, MAX_BODY_BYTES);
    if (text === null) return errorJson(413, "BAD_REQUEST", "That request is too large.");
    json = JSON.parse(text);
  } catch {
    return errorJson(400, "BAD_REQUEST", "Send a JSON body with prompt, target and model.");
  }

  const valid = validate(json);
  if (valid instanceof Response) return valid;

  const route = pickRoute(valid);
  if (route instanceof Response) return route;

  // Marks the server's own error trailer; the model never sees it.
  const nonce = crypto.randomUUID();
  const sentinel = (message: string) => formatStreamError(message, nonce);

  // ---- Demo mode ------------------------------------------------------------
  if (route.kind === "demo") {
    return new Response(createDemoStream(valid.prompt, valid.target, { signal: req.signal }), {
      status: 200,
      headers: streamHeaders("demo", "demo", nonce),
    });
  }

  // ---- Live: rate limit builds paid by the server's keys --------------------
  if (route.paidByServer) {
    const limit = checkRateLimit(getClientIp(req.headers));
    if (!limit.ok) {
      const minutes = Math.max(1, Math.ceil(limit.retryAfterSec / 60));
      return errorJson(
        429,
        "RATE_LIMITED",
        `Free builds are cooling down. Try again in about ${minutes} minute${minutes === 1 ? "" : "s"}, or connect your own key.`,
        limit.retryAfterSec,
      );
    }
  }

  const system = buildSystemPrompt(valid.target);
  const user = buildUserPrompt(valid.prompt, valid.target);

  // Abort the upstream request when the client disconnects.
  const upstream = new AbortController();
  const onClientAbort = () => upstream.abort();
  if (req.signal.aborted) upstream.abort();
  else req.signal.addEventListener("abort", onClientAbort, { once: true });
  const detach = () => req.signal.removeEventListener("abort", onClientAbort);

  const gen: AsyncGenerator<string, ProviderStreamResult, undefined> =
    route.provider === "anthropic"
      ? streamAnthropic({ apiKey: route.apiKey, model: valid.model, system, user, signal: upstream.signal })
      : streamOpenRouter({
          apiKey: route.apiKey,
          model: valid.model,
          system,
          user,
          signal: upstream.signal,
          referer: new URL(req.url).origin,
        });

  // Pull the first chunk before answering, so auth and validation failures get
  // a real HTTP status instead of a 200 with an error inside the stream. The
  // providers yield an empty chunk as soon as the request is accepted, so this
  // doesn't wait through the model's thinking.
  let first: IteratorResult<string, ProviderStreamResult>;
  try {
    first = await gen.next();
  } catch (err) {
    detach();
    const pe = toProviderError(err, upstream.signal);
    if (pe.aborted) return new Response(null, { status: 499 });
    const shown = visibleError(pe, route, "before streaming");
    return errorJson(shown.status, shown.code, shown.message, shown.retryAfterSec);
  }

  const encoder = new TextEncoder();
  let pending: IteratorResult<string, ProviderStreamResult> | null = first;
  let done = false;

  const finish = () => {
    done = true;
    detach();
  };

  const stream = new ReadableStream<Uint8Array>({
    async pull(controller) {
      if (done) return;
      try {
        // Loop until something is enqueued, so empty deltas don't stall the stream.
        for (;;) {
          if (upstream.signal.aborted) {
            // The client went away: stop quietly and release the provider stream.
            finish();
            controller.close();
            await gen.return({ truncated: false }).catch(() => {});
            return;
          }
          const isFirst = pending !== null;
          const step: IteratorResult<string, ProviderStreamResult> = pending ?? (await gen.next());
          pending = null;
          if (step.done) {
            if (step.value?.truncated) controller.enqueue(encoder.encode(sentinel(TRUNCATED_MESSAGE)));
            finish();
            controller.close();
            return;
          }
          // An empty first chunk still goes out: Next only flushes the headers on the first write.
          if (step.value || isFirst) {
            controller.enqueue(encoder.encode(step.value));
            return;
          }
        }
      } catch (err) {
        const pe = toProviderError(err, upstream.signal);
        finish();
        try {
          if (!pe.aborted) controller.enqueue(encoder.encode(sentinel(visibleError(pe, route, "mid-stream").message)));
          controller.close();
        } catch {
          // The client is gone.
        }
      }
    },
    async cancel() {
      // Client disconnected: stop the upstream request and the generator.
      finish();
      upstream.abort();
      await gen.return({ truncated: false }).catch(() => {});
    },
  });

  return new Response(stream, { status: 200, headers: streamHeaders("live", route.provider, nonce) });
}
