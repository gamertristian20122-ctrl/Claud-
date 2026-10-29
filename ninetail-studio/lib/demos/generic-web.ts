// Generic demo build for the Web target: a polished landing-page sketch that
// shows the visitor's brief, clearly labelled as a demo build.

import { WEB_TEMPLATE } from "./generic-sources";
import { EMPTY_BRIEF, cleanPrompt, deriveTitle, escapeHtml, fill, type DemoParts } from "./util";

export function genericWebDemo(prompt: string): DemoParts {
  const title = deriveTitle(prompt);
  const brief = cleanPrompt(prompt) || EMPTY_BRIEF;
  const initial = Array.from(title)[0]?.toUpperCase() ?? "N";
  const code = fill(WEB_TEMPLATE, {
    __NT_TITLE__: escapeHtml(title),
    __NT_PROMPT__: escapeHtml(brief),
    __NT_INITIAL__: escapeHtml(initial),
  });
  return { title, language: "html", code, gui: null };
}
