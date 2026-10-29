// Demo mode: streams a prebuilt generation as if a model were writing it.
// Works in Node (the API route) and in the browser (the client-side fallback
// when no API route is reachable). Uses only TextEncoder and setTimeout.

import { getDemoOutput } from "./demos";
import type { Target } from "./types";

export interface DemoStreamOptions {
  signal?: AbortSignal;
  /**
   * Scales every delay (1 = normal, ~3.5 s for the main body). 0 streams as
   * fast as timers allow. Handy for tests.
   */
  speed?: number;
}

interface Step {
  text: string;
  delay: number;
}

/** Chars streamed quickly at the start, so the title and preview appear at once. */
const HEAD_CHARS = 300;
const HEAD_CHUNKS = 12;
const HEAD_DELAY_MS = 9;
/** The rest is spread over about this many chunks... */
const BODY_CHUNKS = 190;
/** ...this far apart: ~190 × 18 ms ≈ 3.4 s, whatever the length. */
const BODY_DELAY_MS = 18;
/** A short "thinking" beat before the first token. */
const FIRST_DELAY_MS = 120;

/** Never cut between the two halves of a UTF-16 surrogate pair. */
function safeEnd(text: string, end: number): number {
  if (end <= 0 || end >= text.length) return Math.min(Math.max(end, 0), text.length);
  const code = text.charCodeAt(end - 1);
  return code >= 0xd800 && code <= 0xdbff ? end + 1 : end;
}

/** Splits `text` into timed steps: a quick head, then an evenly paced body. */
export function planDemoChunks(text: string): Step[] {
  const steps: Step[] = [];
  if (!text) return steps;

  let pos = 0;
  const headEnd = safeEnd(text, Math.min(HEAD_CHARS, text.length));
  const headSize = Math.max(1, Math.ceil(headEnd / HEAD_CHUNKS));
  while (pos < headEnd) {
    const end = safeEnd(text, Math.min(headEnd, pos + headSize));
    steps.push({ text: text.slice(pos, end), delay: steps.length === 0 ? FIRST_DELAY_MS : HEAD_DELAY_MS });
    pos = end;
  }

  const rest = text.length - pos;
  if (rest > 0) {
    const base = Math.max(1, Math.ceil(rest / BODY_CHUNKS));
    let i = 0;
    while (pos < text.length) {
      // Vary chunk sizes a little (deterministically) so it reads like real tokens.
      const wobble = [1, 0.7, 1.25, 0.9, 1.15, 0.8, 1.2][i % 7];
      const size = Math.max(1, Math.round(base * wobble));
      const end = safeEnd(text, Math.min(text.length, pos + size));
      steps.push({ text: text.slice(pos, end), delay: steps.length === 0 ? FIRST_DELAY_MS : BODY_DELAY_MS });
      pos = end;
      i++;
    }
  }
  return steps;
}

function abortReason(signal: AbortSignal): unknown {
  if (signal.reason !== undefined) return signal.reason;
  try {
    return new DOMException("The demo stream was aborted.", "AbortError");
  } catch {
    const err = new Error("The demo stream was aborted.");
    err.name = "AbortError";
    return err;
  }
}

/**
 * A byte stream of getDemoOutput(prompt, target), paced to finish in ~3–5 s.
 * Aborting `opts.signal` errors the stream with an AbortError and stops timers.
 */
export function createDemoStream(prompt: string, target: Target, opts: DemoStreamOptions = {}): ReadableStream<Uint8Array> {
  const { signal } = opts;
  const speed = opts.speed ?? 1;
  const encoder = new TextEncoder();
  let timer: ReturnType<typeof setTimeout> | null = null;
  let closed = false;
  let onAbort: (() => void) | null = null;

  const stop = () => {
    closed = true;
    if (timer !== null) clearTimeout(timer);
    timer = null;
    if (signal && onAbort) signal.removeEventListener("abort", onAbort);
  };

  return new ReadableStream<Uint8Array>({
    start(controller) {
      if (signal?.aborted) {
        stop();
        controller.error(abortReason(signal));
        return;
      }

      let steps: Step[];
      try {
        steps = planDemoChunks(getDemoOutput(prompt, target));
      } catch (err) {
        stop();
        controller.error(err);
        return;
      }

      if (signal) {
        onAbort = () => {
          if (closed) return;
          stop();
          try {
            controller.error(abortReason(signal));
          } catch {
            // Already closed.
          }
        };
        signal.addEventListener("abort", onAbort, { once: true });
      }

      let index = 0;
      const tick = () => {
        timer = null;
        if (closed) return;
        if (index >= steps.length) {
          stop();
          controller.close();
          return;
        }
        try {
          controller.enqueue(encoder.encode(steps[index].text));
        } catch {
          stop(); // The consumer went away.
          return;
        }
        index++;
        schedule();
      };
      const schedule = () => {
        if (closed) return;
        const delay = index < steps.length ? steps[index].delay * speed : 0;
        timer = setTimeout(tick, delay);
      };
      schedule();
    },
    cancel() {
      stop();
    },
  });
}
