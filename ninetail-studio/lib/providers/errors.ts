// Shared error type for the AI providers and the /api/generate route.

import type { GenerateErrorBody } from "../types";

export type ProviderErrorCode = GenerateErrorBody["code"];

/** What a provider stream returns when it ends normally. */
export interface ProviderStreamResult {
  /** The output stopped because it hit the token limit. */
  truncated: boolean;
  /** Raw stop / finish reason from the provider, for diagnostics. */
  stopReason?: string | null;
}

export class ProviderError extends Error {
  readonly code: ProviderErrorCode;
  /** HTTP status the route should answer with (when the response has not started yet). */
  readonly status: number;
  /** Seconds the caller should wait before retrying (rate limits). */
  readonly retryAfterSec?: number;
  /** The request was cancelled by the client; nothing should be reported. */
  readonly aborted: boolean;

  constructor(
    code: ProviderErrorCode,
    status: number,
    message: string,
    opts: { retryAfterSec?: number; aborted?: boolean } = {},
  ) {
    super(scrubSecrets(message));
    this.name = "ProviderError";
    this.code = code;
    this.status = status;
    this.retryAfterSec = opts.retryAfterSec;
    this.aborted = Boolean(opts.aborted);
  }
}

export function abortedError(): ProviderError {
  return new ProviderError("UPSTREAM", 499, "Build stopped.", { aborted: true });
}

/** True for fetch/DOM abort errors (AbortError, or a TimeoutError raised by AbortSignal.timeout). */
export function isAbortError(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  const name = (err as { name?: unknown }).name;
  return name === "AbortError";
}

/**
 * Removes anything that looks like an API key from a message, so upstream error
 * text can be shown to the visitor without ever echoing a key back.
 */
export function scrubSecrets(message: string): string {
  return message.replace(/\b(sk-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]{4,}/g, "$1…").slice(0, 400);
}

/** Parses a Retry-After header value (seconds or HTTP date) into whole seconds. */
export function parseRetryAfter(value: string | null | undefined): number | undefined {
  if (!value) return undefined;
  const secs = Number(value);
  if (Number.isFinite(secs) && secs >= 0) return Math.ceil(secs);
  const date = Date.parse(value);
  if (Number.isFinite(date)) return Math.max(0, Math.ceil((date - Date.now()) / 1000));
  return undefined;
}
