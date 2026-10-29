// Demo mode: a full raw generation in the lib/format.ts wire format, without
// calling any model. Template prompts (and close remixes of them) get their
// handcrafted build; anything else gets a generic build for the target that
// shows the visitor's brief and is clearly labelled as a demo.

import { formatOutput } from "../format";
import { TEMPLATES } from "../templates";
import type { Target, Template } from "../types";
import { gamingDashboardDemo } from "./gaming-dashboard";
import { genericCtkDemo } from "./generic-ctk";
import { genericImguiDemo } from "./generic-imgui";
import { genericWebDemo } from "./generic-web";
import { imguiModMenuDemo } from "./imgui-mod-menu";
import { linkInBioDemo } from "./link-in-bio";
import { saasWaitlistDemo } from "./saas-waitlist";
import { normalizePrompt, type DemoParts } from "./util";

export type { DemoParts } from "./util";

const TEMPLATE_DEMOS: Record<Template["id"], DemoParts> = {
  "saas-waitlist": saasWaitlistDemo,
  "imgui-mod-menu": imguiModMenuDemo,
  "link-in-bio": linkInBioDemo,
  "gaming-dashboard": gamingDashboardDemo,
};

/**
 * Distinctive keywords per template. A prompt matches when every pattern in
 * at least one group matches the normalized prompt.
 */
const KEYWORDS: Record<Template["id"], RegExp[][]> = {
  "saas-waitlist": [[/\bwait[\s-]?list\b/]],
  "imgui-mod-menu": [[/\b(mod menu|hud)\b/, /\b(radar|minimap|mini-map|crosshair)\b/]],
  "link-in-bio": [
    [/\blink[\s-]?in[\s-]?bio\b/],
    [/\blinktree\b/],
    [/\bcreator\b/, /\b(store|shop|cart)\b/, /\b(bio|links)\b/],
  ],
  "gaming-dashboard": [[/\b(gaming|game|games|match|matches|esports?)\b/, /\b(stats?|k\/d|win rate|rank)\b/, /\b(dashboard|tracker)\b/]],
};

const STOPWORDS = new Set([
  "the", "and", "for", "with", "that", "this", "from", "into", "your", "you", "are", "its", "it's", "has", "have",
  "make", "build", "create", "want", "please", "page", "app", "plus", "each", "some", "all", "any", "but",
]);

function tokens(text: string): Set<string> {
  return new Set(text.split(/[^a-z0-9/]+/).filter((w) => w.length > 2 && !STOPWORDS.has(w)));
}

const TEMPLATE_TOKENS = new Map<Template["id"], Set<string>>(TEMPLATES.map((t) => [t.id, tokens(normalizePrompt(t.prompt))]));

/** Share of the template's words the prompt kept, and share of the prompt that is template. */
function overlap(prompt: Set<string>, template: Set<string>): { kept: number; share: number } {
  if (!prompt.size || !template.size) return { kept: 0, share: 0 };
  let common = 0;
  prompt.forEach((w) => {
    if (template.has(w)) common++;
  });
  return { kept: common / template.size, share: common / prompt.size };
}

/**
 * The template whose demo fits this prompt and target, or null. Matches the
 * exact template prompt, the template name, a light remix of the prompt, or the
 * template's distinctive keywords. The template's target must equal `target`.
 */
export function matchTemplate(prompt: string, target: Target): Template | null {
  const text = normalizePrompt(prompt);
  if (!text) return null;
  const candidates = TEMPLATES.filter((t) => t.target === target);

  for (const t of candidates) {
    if (text === normalizePrompt(t.prompt) || text === normalizePrompt(t.name)) return t;
  }

  const words = tokens(text);
  for (const t of candidates) {
    const { kept, share } = overlap(words, TEMPLATE_TOKENS.get(t.id) ?? new Set());
    if (kept >= 0.6 && share >= 0.5) return t;
  }

  for (const t of candidates) {
    if (KEYWORDS[t.id].some((group) => group.every((re) => re.test(text)))) return t;
  }
  return null;
}

/** The demo parts (title, language, code, GuiSpec) for a prompt and target. */
export function getDemoParts(prompt: string, target: Target): DemoParts {
  const template = matchTemplate(prompt, target);
  if (template) return TEMPLATE_DEMOS[template.id];
  switch (target) {
    case "imgui":
      return genericImguiDemo(prompt);
    case "ctk":
      return genericCtkDemo(prompt);
    default:
      return genericWebDemo(prompt);
  }
}

/** Returns a full raw generation in the lib/format.ts wire format. */
export function getDemoOutput(prompt: string, target: Target): string {
  return formatOutput(getDemoParts(String(prompt ?? ""), target));
}
