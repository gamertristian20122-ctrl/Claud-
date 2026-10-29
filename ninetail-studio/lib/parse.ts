import type { ParsedGeneration, Target } from "./types";

// STUB: replaced by the engine agent.
export function parseGeneration(raw: string, target: Target): ParsedGeneration | null {
  if (!raw) return null;
  return { title: "Untitled", language: target === "web" ? "html" : target === "imgui" ? "cpp" : "python", code: raw, gui: null, complete: false };
}
