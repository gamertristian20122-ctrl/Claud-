import type { Target } from "../types";

// STUB: replaced by the templates agent.
// Returns a full raw generation in the lib/format.ts wire format.
export function getDemoOutput(prompt: string, target: Target): string {
  return `<nt-title>Demo</nt-title>\n<nt-code lang="html">\n<!-- ${prompt} (${target}) -->\n</nt-code>`;
}
