"use client";

import type { ByokState } from "@/lib/storage";
import type { ModelId, ServerStatus } from "@/lib/types";

export interface ModelSelectorProps {
  value: ModelId;
  onChange: (model: ModelId) => void;
  byok: ByokState;
  /** Which server-side keys exist; null while loading. */
  server: ServerStatus | null;
  onOpenByok: () => void;
  disabled?: boolean;
}

// STUB: replaced by the left-panel agent.
export function ModelSelector({ value }: ModelSelectorProps) {
  return <div>{value}</div>;
}
