"use client";

import type { GenStatus, Target } from "@/lib/types";

export interface PromptBoxProps {
  value: string;
  onChange: (value: string) => void;
  /** Start a build (the parent checks credits). */
  onIgnite: () => void;
  /** Stop a running build. */
  onCancel: () => void;
  status: GenStatus;
  target: Target;
  remaining: number;
  unlimited: boolean;
  /** Bump this number to play an attention pulse on the Ignite button (e.g. after a template loads). */
  pulseKey?: number;
}

// STUB: replaced by the left-panel agent.
export function PromptBox({ value }: PromptBoxProps) {
  return <div>{value}</div>;
}
