// Shared contracts for NineTail Studio. Every module builds against these types.

/** What the studio generates. */
export type Target = "web" | "imgui" | "ctk";

export type CodeLanguage = "html" | "cpp" | "python";

export type MascotState = "idle" | "thinking" | "done";

/** Internal ids for the "Choose a Tail" model selector. See lib/models.ts. */
export type ModelId = "claude-sonnet" | "claude-haiku" | "claude-opus" | "deepseek-v3" | "gpt-4o";

export type KeyProvider = "anthropic" | "openrouter";

export type GenStatus = "idle" | "streaming" | "done" | "error";

export type GenMode = "live" | "demo";

// ---------------------------------------------------------------------------
// GUI preview spec: the "visual preview payload" for desktop targets.
// The model returns this JSON next to its C++ / Python code, and the ImGui and
// CustomTkinter simulators render it as an interactive HTML mock-up.
// ---------------------------------------------------------------------------

export type GuiWidgetType =
  | "text" // static label. `label` is the text.
  | "separator" // horizontal rule. Optional `label` renders ImGui SeparatorText style.
  | "checkbox" // `value: boolean`
  | "toggle" // switch. `value: boolean` (CTkSwitch; ImGui renders as checkbox)
  | "slider" // `value: number`, `min`, `max`, optional `format` like "%.1f" or "%d px"
  | "button" // `label`
  | "combo" // `options: string[]`, `value: string` (selected option)
  | "radio" // `options: string[]`, `value: string`
  | "input" // text field. `value: string`, optional `placeholder`
  | "color" // color picker. `value: "#rrggbb"`
  | "progress" // `value: number` between 0 and 1
  | "radar" // minimap radar. `blips`, optional `value` = range label
  | "plot" // line plot. `points: number[]`
  | "stat"; // big number card. `label`, `value` (string or number), optional `delta` like "+12%"

export interface GuiBlip {
  /** -1..1, 0 is the center of the radar. */
  x: number;
  /** -1..1, 0 is the center of the radar. */
  y: number;
  kind?: "ally" | "enemy" | "objective";
}

export interface GuiWidget {
  type: GuiWidgetType;
  label?: string;
  value?: number | boolean | string;
  min?: number;
  max?: number;
  format?: string;
  options?: string[];
  placeholder?: string;
  points?: number[];
  blips?: GuiBlip[];
  delta?: string;
  /** Lay this widget out on the same row as the previous one (ImGui::SameLine). */
  sameLine?: boolean;
}

export interface GuiTab {
  label: string;
  widgets: GuiWidget[];
}

export interface GuiSpec {
  /** Window title. */
  title: string;
  /** Preferred window size in px (simulators clamp to the preview area). */
  width?: number;
  height?: number;
  /** Accent color as "#rrggbb". */
  accent?: string;
  tabs: GuiTab[];
  /** Optional in-game overlay pieces drawn behind the ImGui window. */
  overlay?: {
    fps?: boolean;
    crosshair?: boolean;
    watermark?: string;
  };
}

// ---------------------------------------------------------------------------
// Generation
// ---------------------------------------------------------------------------

/** Body of POST /api/generate. */
export interface GenerateRequestBody {
  prompt: string;
  target: Target;
  model: ModelId;
  /** Visitor's own key (Anthropic "sk-ant-..." or OpenRouter "sk-or-..."). */
  byokKey?: string;
}

/** JSON body of a non-2xx response from POST /api/generate. */
export interface GenerateErrorBody {
  error: string;
  code: "BAD_REQUEST" | "KEY_MODEL_MISMATCH" | "RATE_LIMITED" | "UPSTREAM" | "INVALID_KEY";
}

/** GET /api/generate: which server-side keys exist (never the keys themselves). */
export interface ServerStatus {
  anthropic: boolean;
  openrouter: boolean;
}

/** A generation parsed from the (possibly still streaming) raw model output. */
export interface ParsedGeneration {
  title: string;
  language: CodeLanguage;
  code: string;
  gui: GuiSpec | null;
  /** True once the closing code tag has arrived. */
  complete: boolean;
}

// ---------------------------------------------------------------------------
// Templates (UI Remixer / Template Vault)
// ---------------------------------------------------------------------------

export type TemplateIcon = "rocket" | "gamepad" | "store" | "chart";

export interface Template {
  id: "saas-waitlist" | "imgui-mod-menu" | "link-in-bio" | "gaming-dashboard";
  name: string;
  tagline: string;
  target: Target;
  prompt: string;
  icon: TemplateIcon;
  /** Card accent as "#rrggbb". */
  accent: string;
}

// ---------------------------------------------------------------------------
// Plans
// ---------------------------------------------------------------------------

export type Plan = "free" | "byok-pass" | "pro";

export type UpgradeReason = "limit" | "export" | "manual";
