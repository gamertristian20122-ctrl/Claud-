"use client";

import type { KitsuneMascotProps } from "./types";

// STUB: replaced by the mascot design agent.
export function KitsuneMascot({ state, size = 160, className }: KitsuneMascotProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 200 200" className={className} role="img" aria-label={`Nine-tailed fox, ${state}`}>
      <circle cx="100" cy="100" r="60" fill="#f6f4ff" />
    </svg>
  );
}

export default KitsuneMascot;
