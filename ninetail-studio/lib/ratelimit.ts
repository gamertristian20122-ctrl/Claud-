// Sliding-window rate limit for builds paid by the server's own API keys.
// BYOK and demo builds are never limited here.
//
// Best-effort only: the window lives in this process's memory, so on serverless
// hosts each warm instance keeps its own counts and a cold start resets them.
// Put a shared store (Redis, Upstash, a KV) behind checkRateLimit for a hard cap.

const WINDOW_MS = 10 * 60 * 1000;
const MAX_BUILDS = 8;
/** Upper bound on tracked clients before stale entries are swept. */
const MAX_TRACKED = 5000;

type Store = Map<string, number[]>;

// Kept on globalThis so dev-mode hot reloads don't reset the window.
const globalStore = globalThis as typeof globalThis & { __ninetailRateLimit?: Store };
const hits: Store = globalStore.__ninetailRateLimit ?? (globalStore.__ninetailRateLimit = new Map());

export const RATE_LIMIT = { windowMs: WINDOW_MS, max: MAX_BUILDS } as const;

/** Client IP from proxy headers: first x-forwarded-for entry, else x-real-ip, else "local". */
export function getClientIp(headers: Headers): string {
  const forwarded = headers.get("x-forwarded-for");
  const first = forwarded?.split(",")[0]?.trim();
  if (first) return first.slice(0, 64);
  const real = headers.get("x-real-ip")?.trim();
  if (real) return real.slice(0, 64);
  return "local";
}

function sweep(now: number) {
  for (const [ip, times] of hits) {
    if (!times.length || now - times[times.length - 1] >= WINDOW_MS) hits.delete(ip);
  }
}

/**
 * Records one build for `ip` if it is under the limit.
 * `retryAfterSec` is how long until the next build is allowed (0 when ok).
 */
export function checkRateLimit(ip: string, now: number = Date.now()): { ok: boolean; retryAfterSec: number } {
  if (hits.size > MAX_TRACKED) sweep(now);

  const recent = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (recent.length >= MAX_BUILDS) {
    hits.set(ip, recent);
    const retryAfterMs = WINDOW_MS - (now - recent[0]);
    return { ok: false, retryAfterSec: Math.max(1, Math.ceil(retryAfterMs / 1000)) };
  }
  recent.push(now);
  hits.set(ip, recent);
  return { ok: true, retryAfterSec: 0 };
}
