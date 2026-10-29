// "1-Click Project ZIP Export": packs a finished build into a ready-to-run folder
// and downloads it. JSZip is loaded on demand so it never weighs on first paint.

import { getTarget } from "./models";
import type { ParsedGeneration, Target } from "./types";

export interface ExportProjectOptions {
  parsed: ParsedGeneration;
  target: Target;
  prompt: string;
  modelName: string;
}

/** "My Neon Menu!" -> "my-neon-menu". Falls back to "build". */
export function slugify(input: string, max = 48): string {
  const slug = input
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, max)
    .replace(/-+$/g, "");
  return slug || "build";
}

/** The ZIP's file name for a build title. */
export function zipFileName(title: string): string {
  // "NineTail HUD Menu" -> ninetail-hud-menu.zip, not ninetail-ninetail-hud-menu.zip.
  const slug = slugify(title).replace(/^ninetail-(?=.)/, "");
  return `ninetail-${slug}.zip`;
}

function runSection(target: Target, file: string): string {
  switch (target) {
    case "web":
      return [
        "## Run it",
        "",
        `Open \`${file}\` in any modern browser. That's it: the page loads Tailwind CSS from its CDN, so there is no build step.`,
        "",
        "To put it online, drop the folder on any static host (Netlify, Vercel, GitHub Pages, Cloudflare Pages).",
      ].join("\n");
    case "imgui":
      return [
        "## Run it",
        "",
        `1. Add \`${file}\` to a project that already renders [Dear ImGui](https://github.com/ocornut/imgui).`,
        "   No project yet? Start from one of the official examples for your platform and graphics API:",
        "   https://github.com/ocornut/imgui/tree/master/examples (for example `example_glfw_opengl3` or `example_win32_directx11`).",
        "2. Call `ninetail::ApplyStyle();` once, right after `ImGui::CreateContext();`.",
        "3. Call `ninetail::RenderUI(&open);` every frame between `ImGui::NewFrame();` and `ImGui::Render();`,",
        "   where `open` is a `bool` you keep alive between frames.",
        "",
        "```cpp",
        "static bool open = true;",
        "// once, after ImGui::CreateContext():",
        "ninetail::ApplyStyle();",
        "// every frame:",
        "ninetail::RenderUI(&open);",
        "```",
        "",
        "Backends, build setup and more live in the ImGui repository: https://github.com/ocornut/imgui",
      ].join("\n");
    case "ctk":
      return [
        "## Run it",
        "",
        "Needs Python 3.9 or newer.",
        "",
        "```bash",
        "pip install -r requirements.txt",
        `python ${file}`,
        "```",
      ].join("\n");
  }
}

function buildReadme({ parsed, target, prompt, modelName }: ExportProjectOptions): string {
  const t = getTarget(target);
  const title = parsed.title.trim() || "NineTail build";
  const date = new Date().toISOString().slice(0, 10);
  const files = [`- \`${t.file}\`: the ${t.label} source (${t.sub})`];
  if (target === "ctk") files.push("- `requirements.txt`: Python dependencies");
  if (target !== "web" && parsed.gui) files.push("- `preview.json`: the layout spec behind the studio's visual preview");
  files.push("- `README.md`: this file");

  const quoted = prompt
    .trim()
    .split("\n")
    .map((line) => `> ${line}`)
    .join("\n");

  return [
    `# ${title}`,
    "",
    `Built with NineTail Studio · ${t.label} (${t.sub}) · ${modelName} · ${date}`,
    "",
    "## Prompt",
    "",
    quoted || "> (no prompt)",
    "",
    "## Files",
    "",
    ...files,
    "",
    runSection(target, t.file),
    "",
  ].join("\n");
}

/** Builds the project ZIP in the browser and triggers a download. */
export async function exportProjectZip(options: ExportProjectOptions): Promise<void> {
  const { parsed, target } = options;
  const { default: JSZip } = await import("jszip");
  const zip = new JSZip();
  const t = getTarget(target);

  const code = parsed.code.endsWith("\n") ? parsed.code : `${parsed.code}\n`;
  zip.file(t.file, code);
  zip.file("README.md", buildReadme(options));
  if (target === "ctk") zip.file("requirements.txt", "customtkinter>=5.2\n");
  if (target !== "web" && parsed.gui) zip.file("preview.json", `${JSON.stringify(parsed.gui, null, 2)}\n`);

  const blob = await zip.generateAsync({ type: "blob", mimeType: "application/zip" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = zipFileName(parsed.title);
  a.rel = "noopener";
  a.style.display = "none";
  document.body.appendChild(a);
  a.click();
  a.remove();
  // Give the browser a moment to start the download before freeing the blob.
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
}
