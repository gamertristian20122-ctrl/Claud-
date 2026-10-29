// Tolerant, incremental parser for the generation wire format (see lib/format.ts).
// It runs on every streaming update, so it never throws and always returns the
// best view of the output so far.

import { STREAM_ERROR_PREFIX, STREAM_ERROR_SUFFIX, TAGS } from "./format";
import type { CodeLanguage, GuiBlip, GuiSpec, GuiTab, GuiWidget, GuiWidgetType, ParsedGeneration, Target } from "./types";

export const UNTITLED = "Untitled build";

const TARGET_LANG: Record<Target, CodeLanguage> = { web: "html", imgui: "cpp", ctk: "python" };

export interface ParseOptions {
  /** The stream has ended: accept an unterminated code block as complete. */
  final?: boolean;
}

// ---------------------------------------------------------------------------
// Stream error sentinel
// ---------------------------------------------------------------------------

/**
 * Splits a trailing error sentinel (complete or still arriving) off the raw text.
 * The server only ever appends the sentinel at the very end of a stream.
 */
function splitSentinel(raw: string, final: boolean): { body: string; error: string | null } {
  const idx = raw.lastIndexOf(STREAM_ERROR_PREFIX);
  if (idx !== -1) {
    const tail = raw.slice(idx + STREAM_ERROR_PREFIX.length).trimEnd();
    const error = tail.endsWith(STREAM_ERROR_SUFFIX) ? tail.slice(0, -STREAM_ERROR_SUFFIX.length).trim() || "The build failed." : null;
    return { body: raw.slice(0, idx), error };
  }
  // A sentinel prefix that is still arriving, e.g. "...\n<<NINETA".
  const min = final ? 3 : 1;
  for (let len = Math.min(STREAM_ERROR_PREFIX.length - 1, raw.length); len >= min; len--) {
    if (raw.endsWith(STREAM_ERROR_PREFIX.slice(0, len))) return { body: raw.slice(0, raw.length - len), error: null };
  }
  return { body: raw, error: null };
}

/** The error message the server appended to a failed stream, if any. */
export function extractStreamError(raw: string): string | null {
  if (!raw) return null;
  return splitSentinel(raw, true).error;
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

/** Removes a trailing partial `tag` (e.g. "</nt-co") from streaming text. */
function stripPartialSuffix(text: string, tag: string): string {
  for (let len = Math.min(tag.length - 1, text.length); len >= 1; len--) {
    if (text.endsWith(tag.slice(0, len))) return text.slice(0, text.length - len);
  }
  return text;
}

function cleanTitle(text: string): string {
  return text
    .replace(/<[^>]*>/g, "")
    .replace(/[`*]+/g, "")
    .replace(/^\s*#+\s*/, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80)
    .trim();
}

function langFrom(attr: string | undefined | null, target: Target): CodeLanguage {
  const v = (attr ?? "").toLowerCase().trim();
  if (v === "html" || v === "htm" || v === "xhtml") return "html";
  if (v === "cpp" || v === "c++" || v === "cc" || v === "cxx" || v === "hpp" || v === "c") return "cpp";
  if (v === "python" || v === "py" || v === "python3") return "python";
  return TARGET_LANG[target] ?? "html";
}

/** Drops accidental ``` fences the model put inside the code block. */
function stripInnerFences(code: string, final: boolean): string {
  // "`" or "``" at the very start while streaming: maybe a fence, wait for more.
  if (!final && /^[ \t]*`{1,2}$/.test(code)) return "";
  const open = /^[ \t]*```[^\n`]*(\n|$)/.exec(code);
  if (!open) return code;
  // "```htm" with no newline yet: the fence line is still arriving.
  if (!open[1] && !final) return "";
  const out = code.slice(open[0].length);
  // Closing fence (final) or a closing fence that is still arriving (streaming).
  return final ? out.replace(/\n?[ \t]*```\s*$/, "") : out.replace(/\n?[ \t]*`{1,3}\s*$/, "");
}

function normalizeCode(code: string, final: boolean): string {
  let out = code.replace(/\r\n?/g, "\n");
  out = out.replace(/^[ \t]*\n/, ""); // The newline right after the open tag.
  out = stripInnerFences(out, final);
  out = out.replace(/^(?:[ \t]*\n)+/, "");
  return out.trimEnd();
}

// ---------------------------------------------------------------------------
// Code extraction
// ---------------------------------------------------------------------------

interface CodeView {
  code: string;
  language: CodeLanguage;
  closed: boolean;
}

const CODE_OPEN = /<nt-code\b([^>]*)>/i;

function codeFromTags(body: string, target: Target, final: boolean): CodeView | null {
  const open = CODE_OPEN.exec(body);
  if (!open) return null;
  const attrs = open[1] ?? "";
  const lang = /lang\s*=\s*["']?([\w+#.-]+)/i.exec(attrs)?.[1];
  const start = open.index + open[0].length;

  // The LAST close tag wins, so a stray "</nt-code>" inside the file can't cut it short.
  const closeIdx = body.lastIndexOf(TAGS.codeClose);
  const closed = closeIdx >= start;
  let inner = closed ? body.slice(start, closeIdx) : body.slice(start);
  if (!closed && !final) inner = stripPartialSuffix(inner, TAGS.codeClose);

  return { code: normalizeCode(inner, final || closed), language: langFrom(lang, target), closed };
}

/** Fallback 1: the model ignored the tags but used fenced code blocks. */
function codeFromFence(body: string, target: Target, final: boolean): CodeView | null {
  const fenceOpen = /(^|\n)[ \t]*```([\w+#.-]*)[^\n]*\n/g;
  let best: CodeView | null = null;
  let pos = 0;
  while (pos < body.length) {
    fenceOpen.lastIndex = pos;
    const open = fenceOpen.exec(body);
    if (!open) break;
    const start = open.index + open[0].length;
    const rest = body.slice(start);
    const close = /\n[ \t]*```[ \t]*(\n|$)/.exec(rest);
    let inner = close ? rest.slice(0, close.index) : rest;
    if (!close && !final) inner = inner.replace(/\n[ \t]*`{1,3}$/, "");
    const view: CodeView = { code: normalizeCode(inner, true), language: langFrom(open[2], target), closed: Boolean(close) };
    // While streaming keep the first block (stable growth); at the end pick the largest.
    if (!final) return view;
    if (!best || view.code.length > best.code.length) best = view;
    if (!close) break;
    pos = start + close.index + close[0].length - (close[1] ? 1 : 0);
  }
  return best;
}

/** Fallback 2: bare source with no tags and no fences. */
function codeFromBare(body: string, target: Target, final: boolean): CodeView | null {
  let idx = -1;
  if (target === "web") {
    const m = /<!doctype html|<html[\s>]/i.exec(body);
    idx = m ? m.index : -1;
  } else if (target === "imgui") {
    const m = /(^|\n)[ \t]*(\/\/|\/\*|#include\s*[<"])/.exec(body);
    // Only trust it once there is real C++ in sight.
    idx = m && /#include\s*[<"]/.test(body) ? m.index + m[1].length : -1;
  } else {
    const m = /(^|\n)("""|#!|import customtkinter|import \w|from \w+ import)/.exec(body);
    idx = m && /customtkinter|tkinter/.test(body) ? m.index + m[1].length : -1;
  }
  if (idx === -1) return null;
  let code = body.slice(idx);
  if (target === "web") {
    const end = code.search(/<\/html>/i);
    if (end !== -1) code = code.slice(0, end + "</html>".length);
  }
  return {
    code: normalizeCode(code, final),
    language: TARGET_LANG[target],
    closed: target === "web" ? /<\/html>/i.test(code) : false,
  };
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

/**
 * Parses raw (possibly still streaming) model output. Returns null while there
 * is nothing to show yet.
 */
export function parseGeneration(raw: string, target: Target, opts: ParseOptions = {}): ParsedGeneration | null {
  if (!raw) return null;
  const final = Boolean(opts.final);

  try {
    const { body } = splitSentinel(raw, final);

    // Title
    let title = "";
    const tOpen = body.indexOf(TAGS.titleOpen);
    if (tOpen !== -1) {
      const tStart = tOpen + TAGS.titleOpen.length;
      const found = body.indexOf(TAGS.titleClose, tStart);
      const tClose = found !== -1 && found - tStart <= 400 ? found : -1;
      const inner = tClose !== -1 ? body.slice(tStart, tClose) : stripPartialSuffix(body.slice(tStart, tStart + 400), TAGS.titleClose);
      // An unterminated title must not swallow the code that follows it.
      title = cleanTitle(tClose !== -1 ? inner : inner.split(/<nt-|\n/)[0]);
    }

    // Preview: parsed only once its closing tag has arrived.
    let gui: GuiSpec | null = null;
    const pOpen = body.indexOf(TAGS.previewOpen);
    if (pOpen !== -1) {
      const pStart = pOpen + TAGS.previewOpen.length;
      const pClose = body.indexOf(TAGS.previewClose, pStart);
      if (pClose !== -1) gui = parseGuiJson(body.slice(pStart, pClose));
    }

    // Code: tags first, then the fallbacks.
    const hasCodeTag = CODE_OPEN.test(body);
    let view = codeFromTags(body, target, final);
    if (!view && !hasCodeTag && !body.includes(TAGS.codeOpenPrefix)) {
      view = codeFromFence(body, target, final) ?? codeFromBare(body, target, final);
    }

    const code = view?.code ?? "";
    const language = view?.language ?? TARGET_LANG[target] ?? "html";

    if (!title && target === "web" && code) {
      const m = /<title[^>]*>([^<]{1,120})<\/title>/i.exec(code);
      if (m) title = cleanTitle(m[1]);
    }

    if (!title && !gui && !code) return null;

    return {
      title: title || UNTITLED,
      language,
      code,
      gui,
      complete: Boolean(view?.closed) || (final && code.length > 0),
    };
  } catch {
    // Defensive: never break the UI over a parse problem.
    const code = raw.split(STREAM_ERROR_PREFIX)[0].trim();
    return final && code ? { title: UNTITLED, language: TARGET_LANG[target] ?? "html", code, gui: null, complete: true } : null;
  }
}

// ---------------------------------------------------------------------------
// GuiSpec sanitizing
// ---------------------------------------------------------------------------

function parseGuiJson(text: string): GuiSpec | null {
  let t = text.trim();
  // Accidental ```json fences.
  t = t.replace(/^```[\w-]*\s*\n?/, "").replace(/\n?\s*```$/, "").trim();
  if (!t) return null;
  try {
    return sanitizeGuiSpec(JSON.parse(t));
  } catch {
    // Common slip: trailing commas.
    try {
      return sanitizeGuiSpec(JSON.parse(t.replace(/,\s*([}\]])/g, "$1")));
    } catch {
      return null;
    }
  }
}

const LIMITS = { tabs: 8, widgets: 40, options: 40, points: 64, blips: 64, str: 120, title: 80 } as const;

const WIDGET_TYPES: readonly GuiWidgetType[] = [
  "text",
  "separator",
  "checkbox",
  "toggle",
  "slider",
  "button",
  "combo",
  "radio",
  "input",
  "color",
  "progress",
  "radar",
  "plot",
  "stat",
];

/** Common synonyms models use for the known widget types. */
const TYPE_ALIASES: Record<string, GuiWidgetType> = {
  label: "text",
  heading: "text",
  title: "text",
  divider: "separator",
  separatortext: "separator",
  check: "checkbox",
  switch: "toggle",
  sliderfloat: "slider",
  sliderint: "slider",
  range: "slider",
  dropdown: "combo",
  select: "combo",
  optionmenu: "combo",
  combobox: "combo",
  segmented: "radio",
  radiobutton: "radio",
  textbox: "input",
  entry: "input",
  inputtext: "input",
  text_input: "input",
  coloredit: "color",
  colorpicker: "color",
  progressbar: "progress",
  minimap: "radar",
  chart: "plot",
  line: "plot",
  graph: "plot",
  plotlines: "plot",
  metric: "stat",
  kpi: "stat",
};

const HEX6 = /^#[0-9a-f]{6}$/i;

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function str(v: unknown, max: number = LIMITS.str): string | undefined {
  if (typeof v === "number" && Number.isFinite(v)) v = String(v);
  if (typeof v !== "string") return undefined;
  // eslint-disable-next-line no-control-regex
  const s = v.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").replace(/\s+/g, " ").trim();
  return s ? s.slice(0, max) : undefined;
}

function num(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : typeof v === "string" && v.trim() !== "" ? Number(v) : NaN;
  if (!Number.isFinite(n)) return undefined;
  return Math.max(-1e9, Math.min(1e9, n));
}

function bool(v: unknown): boolean {
  if (typeof v === "boolean") return v;
  if (typeof v === "number") return v !== 0;
  if (typeof v === "string") return /^(true|on|yes|1)$/i.test(v.trim());
  return false;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}

function hexColor(v: unknown): string | undefined {
  if (typeof v !== "string") return undefined;
  const s = v.trim();
  if (HEX6.test(s)) return s.toLowerCase();
  const short = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/i.exec(s);
  if (short) return `#${short[1]}${short[1]}${short[2]}${short[2]}${short[3]}${short[3]}`.toLowerCase();
  return undefined;
}

function widgetType(v: unknown): GuiWidgetType | null {
  if (typeof v !== "string") return null;
  const t = v.trim().toLowerCase();
  if ((WIDGET_TYPES as readonly string[]).includes(t)) return t as GuiWidgetType;
  return TYPE_ALIASES[t.replace(/[\s-]/g, "")] ?? TYPE_ALIASES[t] ?? null;
}

function options(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  for (const o of v) {
    const s = str(o);
    if (s) out.push(s);
    if (out.length >= LIMITS.options) break;
  }
  return out;
}

function sanitizeWidget(input: unknown): GuiWidget | null {
  if (!isRecord(input)) return null;
  const type = widgetType(input.type);
  if (!type) return null;

  const w: GuiWidget = { type };
  const label = str(input.label) ?? str(input.text) ?? str(input.name);
  if (label) w.label = label;
  if (input.sameLine === true || input.same_line === true) w.sameLine = true;

  switch (type) {
    case "text":
      if (!w.label) {
        const v = str(input.value);
        if (!v) return null;
        w.label = v;
      }
      break;
    case "separator":
    case "button":
      break;
    case "checkbox":
    case "toggle":
      w.value = bool(input.value);
      break;
    case "slider": {
      let min = num(input.min) ?? 0;
      let max = num(input.max) ?? 100;
      if (min > max) [min, max] = [max, min];
      if (min === max) max = min + 1;
      w.min = min;
      w.max = max;
      w.value = clamp(num(input.value) ?? min, min, max);
      const format = str(input.format, 24);
      if (format) w.format = format;
      break;
    }
    case "progress": {
      let v = num(input.value) ?? 0;
      if (v > 1 && v <= 100) v = v / 100;
      w.value = clamp(v, 0, 1);
      break;
    }
    case "combo":
    case "radio": {
      const opts = options(input.options ?? input.items ?? input.values);
      w.options = opts;
      const v = str(input.value);
      const idx = num(input.value);
      w.value = v && opts.includes(v) ? v : idx !== undefined && Number.isInteger(idx) && opts[idx] ? opts[idx] : (opts[0] ?? "");
      break;
    }
    case "input": {
      w.value = typeof input.value === "string" ? input.value.slice(0, LIMITS.str) : (str(input.value) ?? "");
      const ph = str(input.placeholder);
      if (ph) w.placeholder = ph;
      break;
    }
    case "color":
      w.value = hexColor(input.value) ?? "#a78bfa";
      break;
    case "radar": {
      const blips: GuiBlip[] = [];
      if (Array.isArray(input.blips)) {
        for (const b of input.blips) {
          if (!isRecord(b)) continue;
          const x = num(b.x);
          const y = num(b.y);
          if (x === undefined || y === undefined) continue;
          const blip: GuiBlip = { x: clamp(x, -1, 1), y: clamp(y, -1, 1) };
          if (b.kind === "ally" || b.kind === "enemy" || b.kind === "objective") blip.kind = b.kind;
          blips.push(blip);
          if (blips.length >= LIMITS.blips) break;
        }
      }
      w.blips = blips;
      const range = str(input.value);
      if (range) w.value = range;
      break;
    }
    case "plot": {
      const points: number[] = [];
      if (Array.isArray(input.points ?? input.values)) {
        for (const p of (input.points ?? input.values) as unknown[]) {
          const n = num(p);
          if (n !== undefined) points.push(n);
          if (points.length >= LIMITS.points) break;
        }
      }
      w.points = points;
      const min = num(input.min);
      const max = num(input.max);
      if (min !== undefined && max !== undefined && min < max) {
        w.min = min;
        w.max = max;
      }
      break;
    }
    case "stat": {
      const n = typeof input.value === "number" ? num(input.value) : undefined;
      w.value = n !== undefined ? n : (str(input.value, 40) ?? "—");
      const delta = str(input.delta, 24);
      if (delta) w.delta = delta;
      break;
    }
  }
  return w;
}

function sanitizeTab(input: unknown, index: number): GuiTab | null {
  if (!isRecord(input)) return null;
  const widgets: GuiWidget[] = [];
  const list = Array.isArray(input.widgets) ? input.widgets : Array.isArray(input.items) ? input.items : [];
  for (const raw of list) {
    const w = sanitizeWidget(raw);
    if (w) widgets.push(w);
    if (widgets.length >= LIMITS.widgets) break;
  }
  return { label: str(input.label) ?? str(input.title) ?? str(input.name) ?? `Tab ${index + 1}`, widgets };
}

/**
 * Coerces untrusted JSON into a safe GuiSpec: known widget types only, numbers
 * clamped, strings trimmed and capped. Returns null when there are no tabs.
 */
export function sanitizeGuiSpec(input: unknown): GuiSpec | null {
  if (!isRecord(input)) return null;

  let rawTabs: unknown[] | null = Array.isArray(input.tabs) ? input.tabs : null;
  // Tolerate a flat widget list without tabs.
  if (!rawTabs && Array.isArray(input.widgets)) rawTabs = [{ label: "Main", widgets: input.widgets }];
  if (!rawTabs) return null;

  const tabs: GuiTab[] = [];
  for (const t of rawTabs) {
    const tab = sanitizeTab(t, tabs.length);
    if (tab) tabs.push(tab);
    if (tabs.length >= LIMITS.tabs) break;
  }
  if (!tabs.length) return null;

  const spec: GuiSpec = { title: str(input.title, LIMITS.title) ?? "NineTail Window", tabs };

  const width = num(input.width);
  const height = num(input.height);
  if (width !== undefined) spec.width = Math.round(clamp(width, 240, 1600));
  if (height !== undefined) spec.height = Math.round(clamp(height, 160, 1200));

  if (typeof input.accent === "string" && HEX6.test(input.accent.trim())) spec.accent = input.accent.trim().toLowerCase();

  if (isRecord(input.overlay)) {
    const o = input.overlay;
    const overlay: NonNullable<GuiSpec["overlay"]> = {};
    if (o.fps !== undefined) overlay.fps = bool(o.fps);
    if (o.crosshair !== undefined) overlay.crosshair = bool(o.crosshair);
    const watermark = str(o.watermark);
    if (watermark) overlay.watermark = watermark;
    if (Object.keys(overlay).length) spec.overlay = overlay;
  }

  return spec;
}
