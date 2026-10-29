"use client";

import type { ByokState } from "@/lib/storage";

export interface ByokModalProps {
  open: boolean;
  onClose: () => void;
  byok: ByokState;
}

// STUB: replaced by the left-panel agent.
export function ByokModal(_props: ByokModalProps) {
  return null;
}
