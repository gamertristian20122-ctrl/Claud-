import type { KeyProvider, ModelId, Target } from "./types";

export interface ModelInfo {
  id: ModelId;
  /** Full display name. */
  name: string;
  /** Short name for chips. */
  short: string;
  /** Who made the model. */
  maker: "Anthropic" | "DeepSeek" | "OpenAI";
  badge: string;
  blurb: string;
  /** Anthropic API model id. Only Claude models have one. */
  anthropicId?: string;
  /** OpenRouter model id. */
  openrouterId: string;
  /** Effort for Claude models (output_config.effort). */
  effort?: "low" | "medium" | "high";
  /** Whether the Anthropic request may use server-side refusal fallbacks. */
  serverFallback?: boolean;
}

export const MODELS: ModelInfo[] = [
  {
    id: "claude-sonnet",
    name: "Claude Sonnet 5.5",
    short: "Sonnet",
    maker: "Anthropic",
    badge: "Balanced",
    blurb: "Sharp layouts and clean code at a good speed.",
    anthropicId: "claude-sonnet-5-5",
    openrouterId: "anthropic/claude-sonnet-5.5",
    effort: "medium",
    serverFallback: true,
  },
  {
    id: "claude-haiku",
    name: "Claude Haiku 5.5",
    short: "Haiku",
    maker: "Anthropic",
    badge: "Fast",
    blurb: "Quickest tail. Great for drafts and remixes.",
    anthropicId: "claude-haiku-5-5",
    openrouterId: "anthropic/claude-haiku-5.5",
    effort: "low",
    serverFallback: false,
  },
  {
    id: "claude-opus",
    name: "Claude Opus 5.5",
    short: "Opus",
    maker: "Anthropic",
    badge: "Deepest",
    blurb: "Most capable. Best for complex, polished builds.",
    anthropicId: "claude-opus-5-5",
    openrouterId: "anthropic/claude-opus-5.5",
    effort: "medium",
    serverFallback: true,
  },
  {
    id: "deepseek-v3",
    name: "DeepSeek V3.2",
    short: "DeepSeek",
    maker: "DeepSeek",
    badge: "Open weights",
    blurb: "Strong open model via OpenRouter.",
    openrouterId: "deepseek/deepseek-v3.2",
  },
  {
    id: "gpt-4o",
    name: "GPT-4o",
    short: "GPT-4o",
    maker: "OpenAI",
    badge: "Classic",
    blurb: "OpenAI's multimodal workhorse via OpenRouter.",
    openrouterId: "openai/gpt-4o",
  },
];

export const DEFAULT_MODEL: ModelId = "claude-sonnet";

export function getModel(id: ModelId): ModelInfo {
  return MODELS.find((m) => m.id === id) ?? MODELS[0];
}

export function isModelId(value: unknown): value is ModelId {
  return typeof value === "string" && MODELS.some((m) => m.id === value);
}

/** Which provider a pasted key belongs to, or null if it isn't recognised. */
export function detectKeyProvider(key: string): KeyProvider | null {
  const k = key.trim();
  if (k.startsWith("sk-ant-")) return "anthropic";
  if (k.startsWith("sk-or-")) return "openrouter";
  return null;
}

/** Can this provider serve this model? Anthropic keys only reach Claude models. */
export function providerSupportsModel(provider: KeyProvider, id: ModelId): boolean {
  if (provider === "openrouter") return true;
  return Boolean(getModel(id).anthropicId);
}

export const TARGETS: { id: Target; label: string; sub: string; language: "html" | "cpp" | "python"; file: string }[] = [
  { id: "web", label: "Web UI", sub: "HTML · Tailwind", language: "html", file: "index.html" },
  { id: "imgui", label: "Desktop GUI", sub: "C++ · Dear ImGui", language: "cpp", file: "ninetail_menu.cpp" },
  { id: "ctk", label: "Python", sub: "CustomTkinter", language: "python", file: "app.py" },
];

export function getTarget(id: Target) {
  return TARGETS.find((t) => t.id === id) ?? TARGETS[0];
}

export function isTarget(value: unknown): value is Target {
  return value === "web" || value === "imgui" || value === "ctk";
}
