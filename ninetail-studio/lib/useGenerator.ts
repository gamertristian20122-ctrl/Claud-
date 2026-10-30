"use client";

// Client side of a build: POSTs to /api/generate, reads the text stream, and
// exposes a throttled, parsed view of it. Falls back to an in-browser demo
// stream when the API route is unreachable (static hosting, offline), except
// for builds with the visitor's own key, which never get canned output.

import { useCallback, useEffect, useRef, useState } from "react";
import { STREAM_SENTINEL_HEADER } from "./format";
import { extractStreamError, parseGeneration } from "./parse";
import type { GenerateErrorBody, GenerateRequestBody, GenMode, GenStatus, ModelId, ParsedGeneration, Target } from "./types";

/** Static hosting with no API route (NEXT_PUBLIC_STATIC_DEMO=true): every build streams a demo. */
export const STATIC_DEMO = process.env.NEXT_PUBLIC_STATIC_DEMO === "true";

/** The error text a user-stopped build ends with. UI compares against it to say "stopped" rather than "failed". */
export const STOPPED_MESSAGE = "Build stopped.";

export interface GenerateOptions {
  prompt: string;
  target: Target;
  model: ModelId;
  byokKey?: string | null;
  /** Override the API endpoint (default "/api/generate"). Mainly for tests and lab pages. */
  endpoint?: string;
}

export interface Generator {
  status: GenStatus;
  /** Raw streamed text so far. */
  raw: string;
  /** Parsed view of `raw`; updates while streaming. */
  parsed: ParsedGeneration | null;
  /** The target of the current/last generation. */
  target: Target | null;
  error: string | null;
  mode: GenMode | null;
  /** Resolves true when the build finished successfully. */
  generate: (opts: GenerateOptions) => Promise<boolean>;
  cancel: () => void;
  reset: () => void;
}

interface GenState {
  status: GenStatus;
  raw: string;
  parsed: ParsedGeneration | null;
  target: Target | null;
  error: string | null;
  mode: GenMode | null;
}

const INITIAL: GenState = { status: "idle", raw: "", parsed: null, target: null, error: null, mode: null };

/** Minimum time between React state updates while streaming. */
const FLUSH_MS = 60;

const STATUS_MESSAGES: Record<number, string> = {
  400: "That request didn't go through. Check the prompt and try again.",
  401: "That API key was rejected.",
  403: "That API key isn't allowed to use this model.",
  413: "That request is too large.",
  429: "Too many builds right now. Wait a moment and try again.",
  500: "The studio hit an error. Try again.",
  502: "The model provider had a problem. Try again in a moment.",
  503: "The model is overloaded right now. Try again in a moment.",
  504: "The build timed out. Try again.",
};

async function readErrorMessage(res: Response): Promise<string> {
  try {
    const body = (await res.json()) as Partial<GenerateErrorBody>;
    if (typeof body.error === "string" && body.error.trim()) return body.error.trim();
  } catch {
    // Not JSON.
  }
  return STATUS_MESSAGES[res.status] ?? `The build failed (error ${res.status}). Try again.`;
}

function now(): number {
  return typeof performance !== "undefined" ? performance.now() : Date.now();
}

export function useGenerator(): Generator {
  const [state, setState] = useState<GenState>(INITIAL);

  const mountedRef = useRef(false);
  /** Bumped on every generate/cancel/reset; stale requests compare against it. */
  const requestIdRef = useRef(0);
  const abortRef = useRef<AbortController | null>(null);
  const runningRef = useRef(false);
  /** Latest raw text and target of the running build (state lags behind by up to FLUSH_MS). */
  const rawRef = useRef("");
  const targetRef = useRef<Target | null>(null);

  useEffect(() => {
    mountedRef.current = true;
    const requestId = requestIdRef;
    return () => {
      // Also runs on StrictMode's simulated unmount; the next mount resets the flag.
      // Bumping the id makes any in-flight request stale (it reads the latest value on purpose).
      mountedRef.current = false;
      requestId.current++;
      abortRef.current?.abort();
      abortRef.current = null;
      runningRef.current = false;
    };
  }, []);

  const generate = useCallback(async (opts: GenerateOptions): Promise<boolean> => {
    // Stop any running build first; its results will be ignored.
    abortRef.current?.abort();
    const id = ++requestIdRef.current;
    const controller = new AbortController();
    abortRef.current = controller;
    runningRef.current = true;
    rawRef.current = "";
    targetRef.current = opts.target;

    const target = opts.target;
    const isCurrent = () => mountedRef.current && requestIdRef.current === id;
    const update = (patch: Partial<GenState>) => {
      if (isCurrent()) setState((s) => ({ ...s, ...patch }));
    };
    const end = () => {
      if (requestIdRef.current === id) {
        runningRef.current = false;
        if (abortRef.current === controller) abortRef.current = null;
      }
    };

    if (mountedRef.current) setState({ status: "streaming", raw: "", parsed: null, error: null, target, mode: null });

    const body: GenerateRequestBody = { prompt: opts.prompt, target, model: opts.model };
    const key = opts.byokKey?.trim();
    if (key) body.byokKey = key;

    // ---- Open the stream (or fall back to the in-browser demo) ---------------
    let stream: ReadableStream<Uint8Array> | null = null;
    let mode: GenMode = "live";
    /** Marks the server's own error trailer (see lib/format.ts). */
    let nonce: string | null = null;
    // Loaded on demand so the demo outputs (~120 KB of source) stay out of the main bundle.
    const demo = async () => {
      mode = "demo";
      const { createDemoStream } = await import("./demo-stream");
      return createDemoStream(opts.prompt, target, { signal: controller.signal });
    };

    if (STATIC_DEMO) {
      stream = await demo();
    } else {
      try {
        const res = await fetch(opts.endpoint ?? "/api/generate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
          signal: controller.signal,
          cache: "no-store",
        });
        if (!isCurrent()) {
          res.body?.cancel().catch(() => {});
          return false;
        }
        const contentType = res.headers.get("content-type") ?? "";
        if (res.status === 404 || res.status === 405 || (res.ok && contentType.includes("text/html"))) {
          // No API route here (static hosting): run the demo in the browser.
          res.body?.cancel().catch(() => {});
          stream = await demo();
        } else if (!res.ok) {
          const message = await readErrorMessage(res);
          update({ status: "error", error: message });
          end();
          return false;
        } else if (!res.body) {
          update({ status: "error", error: "The server sent an empty response. Try again." });
          end();
          return false;
        } else {
          stream = res.body;
          mode = res.headers.get("x-ninetail-mode") === "demo" ? "demo" : "live";
          nonce = res.headers.get(STREAM_SENTINEL_HEADER);
        }
      } catch {
        if (controller.signal.aborted || !isCurrent()) return false;
        // Network error: the API is unreachable, so show the demo instead. Not for
        // a build with the visitor's own key: canned output would pass as their result.
        try {
          stream = key ? null : await demo();
        } catch {
          stream = null;
        }
        if (!stream) {
          update({ status: "error", error: "Couldn't reach the studio server. Check your connection and try again." });
          end();
          return false;
        }
      }

    }

    update({ mode });

    // ---- Read the stream ----------------------------------------------------
    const reader = stream.getReader();
    const decoder = new TextDecoder();
    let raw = "";
    let lastFlush = 0;
    let timer: ReturnType<typeof setTimeout> | null = null;

    const flush = () => {
      if (timer !== null) clearTimeout(timer);
      timer = null;
      lastFlush = now();
      if (!isCurrent()) return;
      const snapshot = raw;
      setState((s) => ({ ...s, raw: snapshot, parsed: parseGeneration(snapshot, target) }));
    };

    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (!isCurrent()) {
          reader.cancel().catch(() => {});
          if (timer !== null) clearTimeout(timer);
          return false;
        }
        if (done) break;
        raw += decoder.decode(value, { stream: true });
        rawRef.current = raw;
        const since = now() - lastFlush;
        if (since >= FLUSH_MS) flush();
        else if (timer === null) timer = setTimeout(flush, FLUSH_MS - since);
      }
      raw += decoder.decode();
      rawRef.current = raw;
    } catch {
      if (timer !== null) clearTimeout(timer);
      if (controller.signal.aborted || !isCurrent()) return false;
      update({
        status: "error",
        raw,
        parsed: parseGeneration(raw, target),
        error: "The connection dropped mid-build. Try again.",
      });
      end();
      return false;
    }
    if (timer !== null) clearTimeout(timer);

    // ---- Finish ---------------------------------------------------------------
    if (!isCurrent()) return false;
    end();

    const streamError = extractStreamError(raw, nonce);
    if (streamError) {
      update({ status: "error", raw, parsed: parseGeneration(raw, target), error: streamError });
      return false;
    }

    const parsed = parseGeneration(raw, target, { final: true });
    if (!parsed || !parsed.code.trim()) {
      update({ status: "error", raw, parsed, error: "The model returned an empty build. Try again." });
      return false;
    }

    update({ status: "done", raw, parsed, error: null });
    return true;
  }, []);

  const cancel = useCallback(() => {
    const wasRunning = runningRef.current;
    requestIdRef.current++;
    abortRef.current?.abort();
    abortRef.current = null;
    runningRef.current = false;
    if (!wasRunning || !mountedRef.current) return;
    const raw = rawRef.current;
    const target = targetRef.current;
    setState((s) => ({
      ...s,
      status: "error",
      error: STOPPED_MESSAGE,
      raw,
      parsed: raw && target ? parseGeneration(raw, target) : s.parsed,
    }));
  }, []);

  const reset = useCallback(() => {
    requestIdRef.current++;
    abortRef.current?.abort();
    abortRef.current = null;
    runningRef.current = false;
    rawRef.current = "";
    targetRef.current = null;
    if (mountedRef.current) setState(INITIAL);
  }, []);

  return {
    status: state.status,
    raw: state.raw,
    parsed: state.parsed,
    target: state.target,
    error: state.error,
    mode: state.mode,
    generate,
    cancel,
    reset,
  };
}
