"use client";

import type { GenMode, GenStatus, MascotState, ParsedGeneration, Target } from "@/lib/types";

export type OutputTab = "preview" | "code";

export interface OutputPanelProps {
  /** Target of the shown generation (falls back to the selected target before any build). */
  target: Target;
  status: GenStatus;
  parsed: ParsedGeneration | null;
  error: string | null;
  mode: GenMode | null;
  tab: OutputTab;
  onTabChange: (tab: OutputTab) => void;
  /** Called by the "1-Click ZIP Export" button. The parent decides between download and paywall. */
  onExport: () => void;
  /** Show a lock on the export button. */
  exportLocked: boolean;
  mascotState: MascotState;
  /** Retry after an error. */
  onRetry?: () => void;
  className?: string;
}

// STUB: replaced by the right-panel agent.
export function OutputPanel({ tab }: OutputPanelProps) {
  return <div>{tab}</div>;
}
