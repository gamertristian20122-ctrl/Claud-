// Generic demo build for the Dear ImGui target: a good-looking general settings
// window titled from the brief, plus the GuiSpec that mirrors it.

import type { GuiSpec, GuiWidget } from "../types";
import { IMGUI_TEMPLATE } from "./generic-sources";
import { DEMO_NOTE, EMPTY_BRIEF, cleanPrompt, deriveTitle, escapeCpp, fill, wrapLines, type DemoParts } from "./util";

export function genericImguiDemo(prompt: string): DemoParts {
  const title = deriveTitle(prompt);
  const brief = cleanPrompt(prompt) || EMPTY_BRIEF;
  const code = fill(IMGUI_TEMPLATE, {
    __NT_TITLE__: escapeCpp(title),
    __NT_BRIEF__: escapeCpp(brief),
  });

  const briefLines: GuiWidget[] = wrapLines(brief).map((line) => ({ type: "text", label: line }));
  const gui: GuiSpec = {
    title,
    width: 520,
    height: 440,
    accent: "#a78bfa",
    tabs: [
      {
        label: "General",
        widgets: [
          { type: "separator", label: "Behavior" },
          { type: "checkbox", label: "Enabled", value: true },
          { type: "checkbox", label: "Show tooltips", value: true },
          { type: "slider", label: "Intensity", value: 0.65, min: 0, max: 1, format: "%.2f" },
          { type: "slider", label: "Refresh rate", value: 60, min: 30, max: 240, format: "%d Hz" },
          { type: "combo", label: "Mode", options: ["Balanced", "Performance", "Quality"], value: "Balanced" },
          { type: "input", label: "Profile name", value: "default" },
          { type: "button", label: "Apply" },
          { type: "button", label: "Reset", sameLine: true },
        ],
      },
      {
        label: "Appearance",
        widgets: [
          { type: "separator", label: "Theme" },
          { type: "color", label: "Accent", value: "#a78bfa" },
          { type: "combo", label: "Theme", options: ["Spirit Night", "Obsidian", "Frost"], value: "Spirit Night" },
          { type: "slider", label: "UI scale", value: 1, min: 0.75, max: 1.5, format: "%.2fx" },
          { type: "slider", label: "Corner rounding", value: 8, min: 0, max: 16, format: "%.0f px" },
          { type: "separator", label: "Activity" },
          { type: "plot", label: "Sessions this week", points: [3, 5, 4, 7, 6, 9, 8, 11, 9, 12, 10, 14, 13, 15], min: 0, max: 16 },
          { type: "progress", label: "Profile completeness", value: 0.6 },
        ],
      },
      {
        label: "Brief",
        widgets: [{ type: "text", label: DEMO_NOTE }, { type: "separator", label: "Your brief" }, ...briefLines],
      },
    ],
  };

  return { title, language: "cpp", code, gui };
}
