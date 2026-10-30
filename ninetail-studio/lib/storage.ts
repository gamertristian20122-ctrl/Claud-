"use client";

// localStorage-backed state for credits ("tails"), the visitor's own key and
// their plan. Every hook instance stays in sync through a small event bus, and
// all values fall back to defaults when storage is unavailable.

import { useCallback, useSyncExternalStore } from "react";
import { detectKeyProvider } from "./models";
import type { KeyProvider, Plan } from "./types";

export const FREE_TAILS = 3;

const KEYS = {
  used: "ninetail.tails.used",
  byok: "ninetail.byok.key",
  plan: "ninetail.plan",
} as const;

const CHANGE_EVENT = "ninetail:storage";

function read(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string | null) {
  try {
    if (value === null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch {
    // Private mode or blocked storage: state just won't persist.
  }
  window.dispatchEvent(new Event(CHANGE_EVENT));
}

function subscribe(onChange: () => void) {
  window.addEventListener(CHANGE_EVENT, onChange);
  window.addEventListener("storage", onChange);
  return () => {
    window.removeEventListener(CHANGE_EVENT, onChange);
    window.removeEventListener("storage", onChange);
  };
}

function useStoredString(key: string): string | null {
  return useSyncExternalStore(
    subscribe,
    () => read(key),
    () => null,
  );
}

const noopSubscribe = () => () => {};

/**
 * False on the server and during hydration, true once stored values are in use.
 * Stored values (tails, plan, key) read as defaults until then, so UI that shows
 * them can render a neutral placeholder instead of a wrong count.
 */
export function useHydrated(): boolean {
  return useSyncExternalStore(
    noopSubscribe,
    () => true,
    () => false,
  );
}

/** Lets local testing skip the paywall entirely. */
const UNLOCK_ALL = process.env.NEXT_PUBLIC_UNLOCK_ALL === "true";

export function usePlan() {
  const raw = useStoredString(KEYS.plan);
  const plan: Plan = raw === "byok-pass" || raw === "pro" ? raw : "free";
  const setPlan = useCallback((p: Plan) => write(KEYS.plan, p === "free" ? null : p), []);
  return { plan, setPlan };
}

export function useCredits() {
  const { plan } = usePlan();
  const usedRaw = useStoredString(KEYS.used);
  const key = useStoredString(KEYS.byok);
  const used = Math.max(0, Math.min(FREE_TAILS, Number.parseInt(usedRaw ?? "0", 10) || 0));
  // Pro is hosted. The BYOK Pass only lifts the limit while a recognised key is
  // connected; without one, builds would run on the server's keys.
  const unlimited = UNLOCK_ALL || plan === "pro" || (plan === "byok-pass" && Boolean(key && detectKeyProvider(key)));
  const remaining = FREE_TAILS - used;

  /** Spend one tail after a successful build. No-op on unlimited plans. */
  const consume = useCallback(() => {
    if (unlimited) return;
    const current = Number.parseInt(read(KEYS.used) ?? "0", 10) || 0;
    write(KEYS.used, String(Math.min(FREE_TAILS, current + 1)));
  }, [unlimited]);

  /** Refill the free tails (demo/testing helper). */
  const reset = useCallback(() => write(KEYS.used, null), []);

  return {
    max: FREE_TAILS,
    remaining,
    unlimited,
    canGenerate: unlimited || remaining > 0,
    /** ZIP export is a paid feature (either plan, key or not). */
    canExport: UNLOCK_ALL || plan !== "free",
    consume,
    reset,
  };
}

export interface ByokState {
  key: string | null;
  provider: KeyProvider | null;
  /** Masked key for display, e.g. "sk-ant-…9f2c". */
  masked: string | null;
  save: (key: string) => void;
  clear: () => void;
}

export function maskKey(key: string): string {
  const k = key.trim();
  if (k.length <= 12) return "••••";
  return `${k.slice(0, 7)}…${k.slice(-4)}`;
}

export function useByok(): ByokState {
  const key = useStoredString(KEYS.byok);
  const save = useCallback((k: string) => write(KEYS.byok, k.trim()), []);
  const clear = useCallback(() => write(KEYS.byok, null), []);
  return {
    key,
    provider: key ? detectKeyProvider(key) : null,
    masked: key ? maskKey(key) : null,
    save,
    clear,
  };
}
