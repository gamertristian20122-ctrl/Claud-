"use client";

import { useCallback, useState } from "react";
import type { GenMode, GenStatus, ModelId, ParsedGeneration, Target } from "./types";

export interface GenerateOptions {
  prompt: string;
  target: Target;
  model: ModelId;
  byokKey?: string | null;
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

// STUB: replaced by the engine agent.
export function useGenerator(): Generator {
  const [status] = useState<GenStatus>("idle");
  const generate = useCallback(async (_opts: GenerateOptions) => false, []);
  const noop = useCallback(() => {}, []);
  return { status, raw: "", parsed: null, target: null, error: null, mode: null, generate, cancel: noop, reset: noop };
}
