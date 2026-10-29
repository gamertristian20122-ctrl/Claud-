// The wire format every generation uses, from the model and from demo mode alike.
//
//   <nt-title>Short title</nt-title>
//   <nt-preview>{ ...GuiSpec JSON... }</nt-preview>   (desktop targets only, before the code)
//   <nt-code lang="html|cpp|python">
//   ...the full source file...
//   </nt-code>
//
// Plain tags (not JSON) keep large code blocks free of escaping, and putting the
// small preview first lets the desktop simulators render while code still streams.

import type { CodeLanguage, GuiSpec } from "./types";

export const TAGS = {
  titleOpen: "<nt-title>",
  titleClose: "</nt-title>",
  previewOpen: "<nt-preview>",
  previewClose: "</nt-preview>",
  /** Followed by ` lang="..."` and `>`. */
  codeOpenPrefix: "<nt-code",
  codeClose: "</nt-code>",
} as const;

/** Appended to a stream when generation fails after the response has started. */
export const STREAM_ERROR_PREFIX = "\n<<NINETAIL_ERROR:";
export const STREAM_ERROR_SUFFIX = ">>";

export function formatOutput(parts: {
  title: string;
  language: CodeLanguage;
  code: string;
  gui?: GuiSpec | null;
}): string {
  const out = [`${TAGS.titleOpen}${parts.title}${TAGS.titleClose}`];
  if (parts.gui) out.push(`${TAGS.previewOpen}${JSON.stringify(parts.gui)}${TAGS.previewClose}`);
  out.push(`${TAGS.codeOpenPrefix} lang="${parts.language}">\n${parts.code.replace(/^\n+|\s+$/g, "")}\n${TAGS.codeClose}`);
  return out.join("\n");
}
