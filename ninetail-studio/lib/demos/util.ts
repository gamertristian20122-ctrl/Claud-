// Shared helpers for the demo-mode generations: prompt cleanup, title
// derivation and per-language string escaping.

import type { CodeLanguage, GuiSpec } from "../types";

/** What every demo module exports. index.ts turns it into wire format with formatOutput(). */
export interface DemoParts {
  title: string;
  language: CodeLanguage;
  code: string;
  gui: GuiSpec | null;
}

/** The longest slice of the visitor's prompt a generic demo will embed. */
export const MAX_EMBED = 280;

/** Stands in for an empty prompt inside a generic demo. */
export const EMPTY_BRIEF = "No brief yet. Describe what you want to build and hit Ignite.";

/** Shown in every generic demo so nobody mistakes it for a real generation. */
export const DEMO_NOTE = "Demo build. Connect an Anthropic or OpenRouter key to generate this for real.";

/** Lowercase, trimmed, single-spaced. Used for template matching. */
export function normalizePrompt(prompt: string): string {
  return prompt.trim().replace(/\s+/g, " ").toLowerCase();
}

/**
 * The prompt as it may be embedded in generated code: wire-format tags and the
 * stream error sentinel removed, control characters dropped, whitespace
 * collapsed to single spaces, and capped at MAX_EMBED characters.
 */
export function cleanPrompt(prompt: string): string {
  let s = String(prompt ?? "");
  // Repeat until stable so "<nt<nt-->" style nesting can't reassemble a tag.
  for (let i = 0; i < 8; i++) {
    const next = s.replace(/<\s*\/?\s*nt-/gi, "").replace(/<<\s*NINETAIL_ERROR/gi, "");
    if (next === s) break;
    s = next;
  }
  s = s.replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g, " ");
  s = s.replace(/\s+/g, " ").trim();
  if (s.length > MAX_EMBED) {
    const cut = s.slice(0, MAX_EMBED - 1);
    const space = cut.lastIndexOf(" ");
    s = (space > MAX_EMBED * 0.6 ? cut.slice(0, space) : cut).replace(/[\s.,;:!?-]+$/, "") + "…";
  }
  return s;
}

// ---------------------------------------------------------------------------
// Titles
// ---------------------------------------------------------------------------

/** Request words that say nothing about the thing being built. */
const LEAD_FILLER = new Set([
  "a", "an", "the", "me", "my", "us", "our", "i", "we", "you", "please", "pls", "can", "could", "would", "will",
  "want", "need", "like", "let's", "lets", "to", "some", "build", "make", "create", "design", "generate",
  "write", "code", "give", "show", "craft", "produce", "do", "get", "help", "just", "quick", "simple", "new",
  "hey", "hi", "hello", "ok", "okay", "so", "now", "it", "that", "this", "is", "for", "of", "with", "and",
]);

/** Small words kept lowercase inside a title. */
const SMALL = new Set(["a", "an", "the", "and", "or", "for", "of", "to", "in", "on", "with", "at", "by", "from", "vs"]);

const TITLE_MAX = 48;
const FALLBACK_TITLE = "Your Build";

function titleWord(word: string, first: boolean): string {
  const lower = word.toLowerCase();
  if (!first && SMALL.has(lower)) return lower;
  // Keep deliberate casing such as "SaaS", "HUD" or "iOS".
  if (/[A-Z]/.test(word.slice(1)) || /^[a-z]+[A-Z]/.test(word)) return word;
  return word.charAt(0).toUpperCase() + word.slice(1);
}

/**
 * A short, safe title from the prompt: the first ~5 meaningful words (tags dropped),
 * title-cased, letters/digits/spaces and a little punctuation only,
 * at most 48 characters. Falls back to "Your Build".
 */
export function deriveTitle(prompt: string): string {
  // Tags (HTML or wire-format) never make good title words.
  const words = cleanPrompt(String(prompt ?? "").replace(/<[^<>]*>/g, " "))
    .replace(/[^\p{L}\p{N}\s'&+-]/gu, " ")
    .split(/\s+/)
    .map((w) => w.replace(/^['&+-]+|['&+-]+$/g, ""))
    .filter((w) => w.length > 0);

  let start = 0;
  while (start < words.length && LEAD_FILLER.has(words[start].toLowerCase())) start++;
  const picked = words.slice(start, start + 5);
  while (picked.length > 1 && SMALL.has(picked[picked.length - 1].toLowerCase())) picked.pop();
  if (!picked.length) return FALLBACK_TITLE;

  let title = "";
  for (let i = 0; i < picked.length; i++) {
    const next = (title ? title + " " : "") + titleWord(picked[i], i === 0);
    if (next.length > TITLE_MAX) break;
    title = next;
  }
  if (!title) title = titleWord(picked[0], true).slice(0, TITLE_MAX);
  return title.trim() || FALLBACK_TITLE;
}

// ---------------------------------------------------------------------------
// Escaping
// ---------------------------------------------------------------------------

export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Body of a C++ "..." string literal (UTF-8 source). */
export function escapeCpp(text: string): string {
  return (
    text
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"')
      .replace(/\n/g, "\\n")
      .replace(/[\u0000-\u0009\u000b-\u001f\u007f]/g, "")
      // Never let "??x" read as a trigraph on old compilers: escape runs of "?".
      .replace(/\?{2,}/g, (run) => "\\?".repeat(run.length))
  );
}

/** Body of a Python "..." string literal. */
export function escapePython(text: string): string {
  return (
    text
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"')
      .replace(/\n/g, "\\n")
      .replace(/[\u0000-\u0009\u000b-\u001f\u007f]/g, "")
  );
}

/**
 * Splits text into lines of at most `max` characters at word boundaries.
 * Used to mirror a wrapped paragraph as several GuiSpec text widgets
 * (their labels are capped at 120 characters).
 */
export function wrapLines(text: string, max = 96): string[] {
  const lines: string[] = [];
  let line = "";
  for (const word of text.split(" ")) {
    if (!word) continue;
    if (word.length > max) {
      if (line) lines.push(line);
      for (let i = 0; i < word.length; i += max) lines.push(word.slice(i, i + max));
      line = "";
      continue;
    }
    if ((line ? line.length + 1 : 0) + word.length > max) {
      lines.push(line);
      line = word;
    } else {
      line = line ? line + " " + word : word;
    }
  }
  if (line) lines.push(line);
  return lines;
}

/**
 * Replaces __NT_NAME__ tokens in one pass, so a value that happens to contain
 * another token is never expanded again. Unknown tokens are left as they are.
 */
export function fill(source: string, values: Record<string, string>): string {
  return source.replace(/__NT_[A-Z]+__/g, (token) => (Object.prototype.hasOwnProperty.call(values, token) ? values[token] : token));
}
