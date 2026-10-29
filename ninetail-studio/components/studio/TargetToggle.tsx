"use client";

import type { Target } from "@/lib/types";

export interface TargetToggleProps {
  value: Target;
  onChange: (target: Target) => void;
  disabled?: boolean;
}

// STUB: replaced by the left-panel agent.
export function TargetToggle({ value }: TargetToggleProps) {
  return <div>{value}</div>;
}
