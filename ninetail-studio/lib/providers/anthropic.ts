// Streams a generation from the Anthropic Messages API with the official SDK.
// Server-only: never import this from client components.

import Anthropic from "@anthropic-ai/sdk";
import type { ModelInfo } from "../models";
import { ProviderError, abortedError, isAbortError, parseRetryAfter, type ProviderStreamResult } from "./errors";

export interface AnthropicStreamArgs {
  apiKey: string;
  model: ModelInfo;
  system: string;
  user: string;
  signal?: AbortSignal;
}

/** Room for a full single-file build. Streaming keeps a large cap safe from HTTP timeouts. */
const MAX_TOKENS = 32000;

/**
 * Yields text deltas as they arrive. Returns `{ truncated }` when the output hit
 * the token cap, and throws a ProviderError for refusals and API failures.
 */
export async function* streamAnthropic({
  apiKey,
  model,
  system,
  user,
  signal,
}: AnthropicStreamArgs): AsyncGenerator<string, ProviderStreamResult, undefined> {
  if (!model.anthropicId) {
    throw new ProviderError("KEY_MODEL_MISMATCH", 400, `${model.name} isn't available with an Anthropic key.`);
  }

  const client = new Anthropic({ apiKey, maxRetries: 1 });

  try {
    // Notes for the current Claude models:
    // - no temperature / top_p / top_k and no `thinking` field: adaptive thinking
    //   is the default and explicit "disabled" or budget_tokens is rejected;
    // - no assistant prefill: the format is enforced by the system prompt;
    // - the system prompt is identical per target, so it carries a cache breakpoint.
    const stream = client.beta.messages.stream(
      {
        model: model.anthropicId,
        max_tokens: MAX_TOKENS,
        system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
        messages: [{ role: "user", content: user }],
        ...(model.effort ? { output_config: { effort: model.effort } } : {}),
        // Server-side refusal fallback: on a policy decline the API continues the
        // same request on a fallback model inside the same stream.
        ...(model.serverFallback
          ? { betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const }
          : {}),
      },
      { signal },
    );

    for await (const event of stream) {
      // Only visible text. Thinking deltas and non-text blocks (including the
      // `fallback` marker block) are skipped.
      if (event.type === "content_block_delta" && event.delta.type === "text_delta" && event.delta.text) {
        yield event.delta.text;
      }
    }

    const final = await stream.finalMessage();
    if (final.stop_reason === "refusal") {
      throw new ProviderError("UPSTREAM", 422, "The model declined this request. Try rephrasing it.");
    }
    return { truncated: final.stop_reason === "max_tokens", stopReason: final.stop_reason };
  } catch (err) {
    throw toAnthropicError(err, signal);
  }
}

function apiMessage(err: InstanceType<typeof Anthropic.APIError>): string | null {
  const body = err.error as { error?: { message?: unknown } } | undefined;
  const msg = body?.error?.message;
  return typeof msg === "string" && msg.trim() ? msg.trim() : null;
}

/** Maps SDK errors (most specific first) to ProviderError. Never includes the key. */
export function toAnthropicError(err: unknown, signal?: AbortSignal): ProviderError {
  if (err instanceof ProviderError) return err;
  if (err instanceof Anthropic.APIUserAbortError || signal?.aborted || isAbortError(err)) return abortedError();

  if (err instanceof Anthropic.AuthenticationError) {
    return new ProviderError("INVALID_KEY", 401, "That Anthropic key was rejected.");
  }
  if (err instanceof Anthropic.PermissionDeniedError) {
    return new ProviderError("INVALID_KEY", 403, "That Anthropic key isn't allowed to use this model.");
  }
  if (err instanceof Anthropic.RateLimitError) {
    return new ProviderError("RATE_LIMITED", 429, "Anthropic is rate-limiting this key. Wait a moment and try again.", {
      retryAfterSec: parseRetryAfter(err.headers?.get("retry-after")),
    });
  }
  if (err instanceof Anthropic.BadRequestError) {
    const detail = apiMessage(err);
    return new ProviderError("BAD_REQUEST", 400, detail ? `Anthropic rejected the request: ${detail}` : "Anthropic rejected the request.");
  }
  if (err instanceof Anthropic.NotFoundError) {
    return new ProviderError("UPSTREAM", 502, "This Claude model isn't available for that key.");
  }
  if (err instanceof Anthropic.APIConnectionError) {
    return new ProviderError("UPSTREAM", 502, "Couldn't reach Anthropic. Try again in a moment.");
  }
  if (err instanceof Anthropic.APIError) {
    if (err.status === 529 || err.type === "overloaded_error") {
      return new ProviderError("UPSTREAM", 503, "Anthropic is overloaded right now. Try again in a moment.");
    }
    const detail = apiMessage(err);
    return new ProviderError("UPSTREAM", 502, detail ? `Anthropic error: ${detail}` : "Anthropic returned an error. Try again.");
  }
  return new ProviderError("UPSTREAM", 500, "Something went wrong while generating. Try again.");
}
