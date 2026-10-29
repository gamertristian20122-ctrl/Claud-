// POST /api/generate: streams a generation in the lib/format.ts wire format.
// GET  /api/generate: which server-side keys exist (never the keys themselves).
//
// Contract
// - 200 text/plain stream. Headers: X-Ninetail-Mode (live | demo),
//   X-Ninetail-Provider (anthropic | openrouter | demo). If generation fails after
//   the stream started, the stream ends with STREAM_ERROR_PREFIX + message + STREAM_ERROR_SUFFIX.
// - Non-2xx: JSON GenerateErrorBody { error, code }.
//   400 BAD_REQUEST / INVALID_KEY / KEY_MODEL_MISMATCH, 401/403 INVALID_KEY (rejected by the provider),
//   429 RATE_LIMITED (+ Retry-After), 402/422/502/503 UPSTREAM.

import { createDemoStream } from "@/lib/demo-stream";
import { STREAM_ERROR_PREFIX, STREAM_ERROR_SUFFIX } from "@/lib/format";
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

function errorJson(status: number, code: GenerateErrorBody["code"], error: string, retryAfterSec?: number): Response {
  const headers: Record<string, string> = { "Cache-Control": "no-store" };
  if (retryAfterSec && retryAfterSec > 0) headers["Retry-After"] = String(retryAfterSec);
  return Response.json({ error, code } satisfies GenerateErrorBody, { status, headers });
}

function streamHeaders(mode: "live" | "demo", provider: KeyProvider | "demo"): HeadersInit {
  return {
    "Content-Type": "text/plain; charset=utf-8",
    "Cache-Control": "no-store, no-transform",
    "X-Accel-Buffering": "no",
    "X-Content-Type-Options": "nosniff",
    "X-Ninetail-Mode": mode,
    "X-Ninetail-Provider": provider,
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

type Route =
  | { kind: "demo" }
  | { kind: "live"; provider: KeyProvider; apiKey: string; paidByServer: boolean };

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

function sentinel(message: string): string {
  return `${STREAM_ERROR_PREFIX}${message.replace(/>>/g, "> >").replace(/\s+/g, " ").trim()}${STREAM_ERROR_SUFFIX}`;
}

function toProviderError(err: unknown, signal: AbortSignal): ProviderError {
  // toAnthropicError passes ProviderErrors through and maps everything else safely.
  return toAnthropicError(err, signal);
}

export async function POST(req: Request) {
  // ---- Parse and validate -------------------------------------------------
  let json: unknown;
  try {
    const text = await req.text();
    if (text.length > MAX_BODY_BYTES) return errorJson(400, "BAD_REQUEST", "That request is too large.");
    json = JSON.parse(text);
  } catch {
    return errorJson(400, "BAD_REQUEST", "Send a JSON body with prompt, target and model.");
  }

  const valid = validate(json);
  if (valid instanceof Response) return valid;

  const route = pickRoute(valid);
  if (route instanceof Response) return route;

  // ---- Demo mode ------------------------------------------------------------
  if (route.kind === "demo") {
    return new Response(createDemoStream(valid.prompt, valid.target, { signal: req.signal }), {
      status: 200,
      headers: streamHeaders("demo", "demo"),
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
  // a real HTTP status instead of a 200 with an error inside the stream.
  let first: IteratorResult<string, ProviderStreamResult>;
  try {
    first = await gen.next();
  } catch (err) {
    detach();
    const pe = toProviderError(err, upstream.signal);
    if (pe.aborted) return new Response(null, { status: 499 });
    console.warn(`[generate] ${route.provider} failed before streaming: ${pe.code} ${pe.status}`);
    return errorJson(pe.status, pe.code, pe.message, pe.retryAfterSec);
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
          const step: IteratorResult<string, ProviderStreamResult> = pending ?? (await gen.next());
          pending = null;
          if (step.done) {
            if (step.value?.truncated) controller.enqueue(encoder.encode(sentinel(TRUNCATED_MESSAGE)));
            finish();
            controller.close();
            return;
          }
          if (step.value) {
            controller.enqueue(encoder.encode(step.value));
            return;
          }
        }
      } catch (err) {
        const pe = toProviderError(err, upstream.signal);
        finish();
        try {
          if (!pe.aborted) {
            console.warn(`[generate] ${route.provider} failed mid-stream: ${pe.code} ${pe.status}`);
            controller.enqueue(encoder.encode(sentinel(pe.message)));
          }
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

  return new Response(stream, { status: 200, headers: streamHeaders("live", route.provider) });
}
