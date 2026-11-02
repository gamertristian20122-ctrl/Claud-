// The NineTail Studio MCP server: tools and prompts that let any MCP client
// (Claude, ChatGPT, Cursor, ...) build in NineTail's format. Mounted at /api/mcp.
//
// The client's own AI writes the build. This server never calls a model, so it
// can't spend the studio's API keys, and every tool is read-only.

import type { McpServer, ToolAnnotations } from "@modelcontextprotocol/server";
import { z } from "zod";
import { getDemoParts } from "../demos";
import { formatOutput } from "../format";
import { TARGETS, getTarget } from "../models";
import { buildSystemPrompt, buildUserPrompt } from "../prompts";
import { TEMPLATES, getTemplate } from "../templates";
import type { Template } from "../types";
import { checkBuild } from "./check-build";

/** Same cap as a studio prompt (app/api/generate/route.ts). */
export const MAX_IDEA = 4000;
/** Largest build check_build accepts, in characters. */
export const MAX_BUILD = 200_000;

export const SERVER_INFO = { name: "ninetail-studio", version: "0.1.0" } as const;

export const SERVER_INSTRUCTIONS = [
  "NineTail Studio turns a prompt into one of three builds: a Web UI (one HTML page with Tailwind), a desktop GUI in C++ Dear ImGui, or a Python CustomTkinter app.",
  "You write the build yourself. Use the build_app prompt, or call get_build_guide for the target, and answer in NineTail's tagged format (<nt-title>, <nt-preview> for desktop targets, <nt-code>).",
  "Then call check_build with your whole answer and fix every error it lists.",
  "list_templates and get_template_build return finished example builds.",
  "This server never calls an AI model.",
].join(" ");

const READ_ONLY: ToolAnnotations = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };

const targetSchema = z.enum(["web", "imgui", "ctk"]).describe("web = HTML + Tailwind page, imgui = C++ Dear ImGui window, ctk = Python CustomTkinter app");
const templateIds = TEMPLATES.map((t) => t.id) as [Template["id"], ...Template["id"][]];

function textResult(text: string, structuredContent?: Record<string, unknown>) {
  return { content: [{ type: "text" as const, text }], ...(structuredContent ? { structuredContent } : {}) };
}

function jsonResult(data: Record<string, unknown>) {
  return textResult(JSON.stringify(data, null, 2), data);
}

export function registerNinetailMcp(server: McpServer): void {
  server.registerTool(
    "list_targets",
    {
      title: "List build targets",
      description: "The three kinds of build NineTail Studio makes, with the code language and file name of each.",
      annotations: READ_ONLY,
    },
    async () =>
      jsonResult({
        targets: TARGETS.map((t) => ({
          id: t.id,
          name: t.label,
          stack: t.sub,
          language: t.language,
          file: t.file,
          livePreview: t.id === "web" ? "the page itself in a sandboxed frame" : "an interactive simulator drawn from the <nt-preview> JSON",
        })),
      }),
  );

  server.registerTool(
    "list_templates",
    {
      title: "List templates",
      description: "The Template Vault: ready-made starter briefs, each with a finished example build. Pass an id to get_template_build to see it.",
      annotations: READ_ONLY,
    },
    async () =>
      jsonResult({
        templates: TEMPLATES.map((t) => ({ id: t.id, name: t.name, tagline: t.tagline, target: t.target, prompt: t.prompt })),
      }),
  );

  server.registerTool(
    "get_template_build",
    {
      title: "Get a template build",
      description: "The finished example build for a Template Vault starter, in NineTail's tagged format. Useful as a reference for style and format.",
      inputSchema: z.object({ id: z.enum(templateIds).describe("Template id from list_templates") }),
      annotations: READ_ONLY,
    },
    async ({ id }) => {
      // The enum already limits id to known templates.
      const template = getTemplate(id) as Template;
      const parts = getDemoParts(template.prompt, template.target);
      const info = getTarget(template.target);
      return textResult(formatOutput(parts), {
        id: template.id,
        name: template.name,
        target: template.target,
        title: parts.title,
        language: parts.language,
        file: info.file,
      });
    },
  );

  server.registerTool(
    "get_build_guide",
    {
      title: "Get the build guide",
      description:
        "NineTail's full instructions for one target: the tagged output format, the GuiSpec preview JSON for desktop targets, and the design and code rules. Follow it when writing a build.",
      inputSchema: z.object({ target: targetSchema }),
      annotations: READ_ONLY,
    },
    async ({ target }) => textResult(buildSystemPrompt(target)),
  );

  server.registerTool(
    "check_build",
    {
      title: "Check a build",
      description:
        "Reads a finished build the way NineTail Studio would and lists errors (it won't display correctly) and warnings (it works but should be fixed). Pass your whole answer, tags included.",
      inputSchema: z.object({
        target: targetSchema,
        output: z.string().min(1).max(MAX_BUILD).describe("The whole build: <nt-title>, <nt-preview> (desktop only) and <nt-code>"),
      }),
      annotations: READ_ONLY,
    },
    async ({ target, output }) => {
      const report = checkBuild(output, target);
      return jsonResult({ ...report });
    },
  );

  server.registerPrompt(
    "build_app",
    {
      title: "Build with NineTail",
      description: "Loads NineTail's build guide for a target together with your idea, ready for the AI to write the build.",
      argsSchema: z.object({
        target: targetSchema,
        idea: z.string().trim().min(1).max(MAX_IDEA).describe("What to build"),
      }),
    },
    ({ target, idea }) => ({
      messages: [
        {
          role: "user" as const,
          content: {
            type: "text" as const,
            text: [
              buildSystemPrompt(target),
              "---",
              buildUserPrompt(idea, target),
              "When you're done, call the check_build tool with your whole answer and fix anything it reports.",
            ].join("\n\n"),
          },
        },
      ],
    }),
  );
}
