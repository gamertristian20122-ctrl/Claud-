// Generic demo build for the CustomTkinter target: a general app window titled
// from the brief, plus the GuiSpec that mirrors it.

import type { GuiSpec, GuiWidget } from "../types";
import { CTK_TEMPLATE } from "./generic-sources";
import { DEMO_NOTE, EMPTY_BRIEF, cleanPrompt, deriveTitle, escapePython, fill, wrapLines, type DemoParts } from "./util";

export function genericCtkDemo(prompt: string): DemoParts {
  const title = deriveTitle(prompt);
  const brief = cleanPrompt(prompt) || EMPTY_BRIEF;
  const code = fill(CTK_TEMPLATE, {
    __NT_TITLE__: escapePython(title),
    __NT_BRIEF__: escapePython(brief),
  });

  const briefLines: GuiWidget[] = wrapLines(brief).map((line) => ({ type: "text", label: line }));
  const gui: GuiSpec = {
    title,
    width: 880,
    height: 620,
    accent: "#a78bfa",
    tabs: [
      {
        label: "Home",
        widgets: [
          { type: "separator", label: "Quick actions" },
          { type: "input", label: "Search", value: "", placeholder: "Search..." },
          { type: "radio", label: "View", options: ["Cards", "List"], value: "Cards", sameLine: true },
          { type: "button", label: "New item", sameLine: true },
          { type: "button", label: "Import", sameLine: true },
          { type: "separator", label: "This week" },
          { type: "plot", label: "Sessions", points: [3, 5, 4, 7, 6, 9, 8, 11, 9, 12, 10, 14, 13, 15], min: 0, max: 15 },
          { type: "progress", label: "Daily goal", value: 0.62 },
        ],
      },
      {
        label: "Settings",
        widgets: [
          { type: "separator", label: "Preferences" },
          { type: "toggle", label: "Dark mode", value: true },
          { type: "toggle", label: "Notifications", value: true },
          { type: "checkbox", label: "Start on login", value: false },
          { type: "slider", label: "Text size", value: 14, min: 10, max: 22, format: "%d px" },
          { type: "slider", label: "Volume", value: 70, min: 0, max: 100, format: "%d%%" },
          { type: "combo", label: "Language", options: ["English", "Español", "Deutsch", "Français"], value: "English" },
          { type: "button", label: "Save settings" },
        ],
      },
      {
        label: "Brief",
        widgets: [{ type: "text", label: DEMO_NOTE }, { type: "separator", label: "Your brief" }, ...briefLines],
      },
    ],
  };

  return { title, language: "python", code, gui };
}
