// Checks a finished build written in the lib/format.ts wire format, the way the
// studio would read it. Used by the MCP `check_build` tool so an outside AI can
// fix its own output before handing it over. Never throws.

import { TAGS } from "../format";
import { getTarget } from "../models";
import { parseGeneration } from "../parse";
import type { CodeLanguage, Target } from "../types";

export interface BuildCheck {
  /** True when nothing would stop the studio from showing this build. */
  ok: boolean;
  title: string | null;
  language: CodeLanguage | null;
  /** File name the studio exports this target as. */
  file: string;
  codeLines: number;
  /** What the desktop simulator would render, or null. */
  preview: { title: string; tabs: string[]; widgets: number } | null;
  errors: string[];
  warnings: string[];
}

const CODE_OPEN = /<nt-code\b[^>]*>/i;

export function checkBuild(raw: string, target: Target): BuildCheck {
  const info = getTarget(target);
  const errors: string[] = [];
  const warnings: string[] = [];
  const parsed = parseGeneration(raw, target, { final: true });
  const code = parsed?.code ?? "";

  const codeOpen = CODE_OPEN.exec(raw);
  const codeStart = codeOpen ? codeOpen.index : -1;
  const previewStart = raw.indexOf(TAGS.previewOpen);
  const previewEnd = previewStart === -1 ? -1 : raw.indexOf(TAGS.previewClose, previewStart);
  const desktop = target !== "web";

  // Title
  const titleStart = raw.indexOf(TAGS.titleOpen);
  if (titleStart === -1 || raw.indexOf(TAGS.titleClose, titleStart) === -1) {
    warnings.push("Add <nt-title>Short title</nt-title> first. Without it the studio shows a fallback title.");
  }

  // Code
  if (!code) {
    errors.push(`No code found. Put the full file inside <nt-code lang="${info.language}"> ... </nt-code>.`);
  } else if (!codeOpen) {
    warnings.push(`No <nt-code> tag. The studio guessed where the code is; wrap it in <nt-code lang="${info.language}"> ... </nt-code>.`);
  }
  if (codeOpen && raw.lastIndexOf(TAGS.codeClose) < codeStart) {
    errors.push("The code block never closes with </nt-code>, so the build looks cut off.");
  }
  if (code && parsed && parsed.language !== info.language) {
    errors.push(`The code is ${parsed.language} but the ${info.label} target needs ${info.language}. Use lang="${info.language}".`);
  }

  // Preview (desktop targets only)
  if (desktop) {
    if (previewStart === -1) {
      errors.push("Desktop builds need <nt-preview>{GuiSpec JSON}</nt-preview> before the code, or the simulator has nothing to show.");
    } else if (previewEnd === -1) {
      errors.push("The preview never closes with </nt-preview>.");
    } else if (!parsed?.gui) {
      errors.push("The preview JSON didn't parse, or it has no tabs with known widget types.");
    } else if (codeStart !== -1 && previewStart > codeStart) {
      warnings.push("Put <nt-preview> before <nt-code> so the simulator can draw while the code streams.");
    }
  } else if (previewStart !== -1) {
    warnings.push("Web builds don't use <nt-preview>; the studio ignores it.");
  }

  // Target-specific sanity checks
  if (code) {
    if (target === "web") {
      if (!/<!doctype html/i.test(code)) warnings.push("Start the page with <!DOCTYPE html>.");
      if (!/<\/html>\s*$/i.test(code)) errors.push("The page doesn't end with </html>, so it looks cut off.");
    } else if (target === "imgui") {
      if (!/ImGui::Begin\s*\(/.test(code)) warnings.push("No ImGui::Begin() call found. Is this Dear ImGui code?");
    } else if (!/\bcustomtkinter\b/.test(code)) {
      warnings.push("No customtkinter import found. Is this a CustomTkinter app?");
    }
  }

  const gui = parsed?.gui ?? null;
  return {
    ok: errors.length === 0,
    title: parsed ? parsed.title : null,
    language: code && parsed ? parsed.language : null,
    file: info.file,
    codeLines: code ? code.split("\n").length : 0,
    preview: gui ? { title: gui.title, tabs: gui.tabs.map((t) => t.label), widgets: gui.tabs.reduce((n, t) => n + t.widgets.length, 0) } : null,
    errors,
    warnings,
  };
}
