"use client";

import type { Template } from "@/lib/types";

export interface TemplateVaultProps {
  onSelect: (template: Template) => void;
  activeId?: Template["id"] | null;
  disabled?: boolean;
}

// STUB: replaced by the left-panel agent.
export function TemplateVault(_props: TemplateVaultProps) {
  return null;
}
