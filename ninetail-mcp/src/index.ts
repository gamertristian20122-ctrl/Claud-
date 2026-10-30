#!/usr/bin/env node
/**
 * ninetail-mcp: The 9 Tails of the Kitsune social suite.
 *
 * A local MCP server over stdio. stdout carries JSON-RPC and nothing else, so
 * every log line in this file goes to stderr through console.error.
 */
import { randomBytes, randomInt } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

// package.json sits one level above both src/ (tsx) and dist/ (built).
const { version: VERSION } = createRequire(import.meta.url)("../package.json") as { version: string };

const FREE_RUNS = 10;
const LICENSE_URL = "gumroad.com/l/ninetail";
const CONFIG_DIR = join(homedir(), ".ninetail");
const CONFIG_PATH = join(CONFIG_DIR, "config.json");
const TRIAL_EXPIRED_MESSAGE = `⚠️ NineTail Trial Expired (${FREE_RUNS}/${FREE_RUNS} runs used). Grab a $9/mo license key at ${LICENSE_URL} and run ninetail_activate.`;
const SIMULATION_NOTE = "🧪 Simulation mode: nothing was sent to any platform.";

const PLATFORMS = ["youtube", "tiktok", "instagram", "x"] as const;
type Platform = (typeof PLATFORMS)[number];

const PLATFORM_LABELS: Record<Platform, string> = {
  youtube: "YouTube",
  tiktok: "TikTok",
  instagram: "Instagram",
  x: "X",
};

const log = (...args: unknown[]): void => console.error("[ninetail]", ...args);

// ---------------------------------------------------------------------------
// Local metering and licensing: ~/.ninetail/config.json
// ---------------------------------------------------------------------------

interface NinetailConfig {
  licenseKey: string | null;
  runsUsed: number;
}

type AccessResult =
  | { allowed: true; licensed: boolean; remaining: number }
  | { allowed: false; message: string };

/** Placeholder rule until keys are checked against Gumroad: an `NT-` prefix or 8+ characters. */
function isValidLicenseKey(key: string | null): key is string {
  if (key === null) return false;
  const trimmed = key.trim();
  return trimmed.startsWith("NT-") || trimmed.length >= 8;
}

function saveConfig(config: NinetailConfig): void {
  mkdirSync(CONFIG_DIR, { recursive: true, mode: 0o700 });
  // Write then rename, so a crash mid-write never leaves half a JSON file behind.
  const tmpPath = `${CONFIG_PATH}.${process.pid}.tmp`;
  writeFileSync(tmpPath, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 });
  renameSync(tmpPath, CONFIG_PATH);
}

function freshConfig(): NinetailConfig {
  const config: NinetailConfig = { licenseKey: null, runsUsed: 0 };
  saveConfig(config);
  return config;
}

/** Reads the config, creating it on first use and coercing hand-edited fields back into shape. */
function loadConfig(): NinetailConfig {
  if (!existsSync(CONFIG_PATH)) return freshConfig();

  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
  } catch (err) {
    if (!(err instanceof SyntaxError)) throw err;
    // Park the broken file rather than deleting it, so a license key inside can be recovered by hand.
    const backupPath = `${CONFIG_PATH}.corrupt-${Date.now()}`;
    renameSync(CONFIG_PATH, backupPath);
    log(`${CONFIG_PATH} was not valid JSON; moved it to ${backupPath} and started a fresh config.`);
    return freshConfig();
  }

  const raw = (typeof parsed === "object" && parsed !== null ? parsed : {}) as Record<string, unknown>;
  const runsUsed = raw.runsUsed;
  return {
    licenseKey: typeof raw.licenseKey === "string" ? raw.licenseKey : null,
    runsUsed: typeof runsUsed === "number" && Number.isFinite(runsUsed) && runsUsed > 0 ? Math.floor(runsUsed) : 0,
  };
}

/**
 * Gate for every metered tool. Licensed users always pass; trial users pass
 * until they have used FREE_RUNS invocations. A pass spends one run.
 */
function checkAccess(): AccessResult {
  const config = loadConfig();
  const licensed = isValidLicenseKey(config.licenseKey);
  if (config.runsUsed >= FREE_RUNS && !licensed) {
    return { allowed: false, message: TRIAL_EXPIRED_MESSAGE };
  }
  config.runsUsed += 1;
  saveConfig(config);
  return { allowed: true, licensed, remaining: licensed ? Infinity : FREE_RUNS - config.runsUsed };
}

// ---------------------------------------------------------------------------
// Tool result helpers
// ---------------------------------------------------------------------------

function reply(body: string): CallToolResult {
  return { content: [{ type: "text", text: body }] };
}

function failure(body: string): CallToolResult {
  return { content: [{ type: "text", text: body }], isError: true };
}

function internalError(tool: string, err: unknown): CallToolResult {
  log(`${tool} failed:`, err);
  const reason = err instanceof Error ? err.message : String(err);
  return failure(`NineTail hit an error in ${tool}: ${reason}`);
}

/** Spends one run through checkAccess(), then renders the tool's reply with the run balance appended. */
function metered(tool: string, render: () => string): CallToolResult {
  try {
    const access = checkAccess();
    if (!access.allowed) return failure(access.message);
    const balance = access.licensed
      ? "🦊 NineTail Pro: unlimited runs."
      : `🦊 Trial: ${access.remaining}/${FREE_RUNS} free runs remaining.`;
    return reply(`${render()}\n\n${SIMULATION_NOTE}\n${balance}`);
  } catch (err) {
    return internalError(tool, err);
  }
}

// ---------------------------------------------------------------------------
// Formatting and mock data
// ---------------------------------------------------------------------------

function randomSlug(length: number): string {
  return randomBytes(length).toString("base64url").slice(0, length);
}

function randomDigits(length: number): string {
  let digits = String(randomInt(1, 10));
  while (digits.length < length) digits += String(randomInt(0, 10));
  return digits;
}

function mockPostUrl(platform: Platform): string {
  switch (platform) {
    case "youtube":
      return `https://youtube.com/shorts/${randomSlug(11)}`;
    case "tiktok":
      return `https://www.tiktok.com/@me/video/${randomDigits(19)}`;
    case "instagram":
      return `https://www.instagram.com/reel/${randomSlug(11)}/`;
    case "x":
      return `https://x.com/i/status/${randomDigits(19)}`;
  }
}

/**
 * Collapses whitespace and truncates to `max` code points. Counting code points rather than
 * UTF-16 units keeps emoji whole: a lone surrogate makes the JSON-RPC reply unparseable for
 * strict clients.
 */
function preview(text: string, max = 160): string {
  const chars = Array.from(text.replace(/\s+/g, " ").trim());
  if (chars.length === 0) return "(none)";
  return chars.length > max ? `${chars.slice(0, max - 1).join("")}…` : chars.join("");
}

function formatBytes(bytes: number): string {
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`;
}

function describeMedia(mediaPath: string): string {
  const fullPath = resolve(mediaPath.replace(/^~(?=$|[\\/])/, homedir()));
  try {
    const stats = statSync(fullPath);
    if (stats.isFile()) return `${basename(fullPath)} (${formatBytes(stats.size)})`;
  } catch {
    // Missing or unreadable: reported below.
  }
  return `${mediaPath} (⚠️ no file found at this path)`;
}

/** Strips leading #s and inner whitespace, drops blanks and case-insensitive duplicates. */
function normalizeTags(tags: readonly string[]): string[] {
  const seen = new Set<string>();
  const hashtags: string[] = [];
  for (const tag of tags) {
    const clean = tag.trim().replace(/^#+/, "").replace(/\s+/g, "");
    if (!clean || seen.has(clean.toLowerCase())) continue;
    seen.add(clean.toLowerCase());
    hashtags.push(`#${clean}`);
  }
  return hashtags;
}

function maskKey(key: string): string {
  const chars = Array.from(key.trim());
  const head = chars.slice(0, 3).join("");
  return chars.length > 8 ? `${head}…${chars.slice(-4).join("")}` : `${head}…`;
}

/** mulberry32, seeded from a string, so a report stays stable for the same window on the same day. */
function seededRandom(seed: string): () => number {
  let state = 2166136261;
  for (let i = 0; i < seed.length; i++) state = Math.imul(state ^ seed.charCodeAt(i), 16777619);
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function formatClock(totalSeconds: number): string {
  const seconds = Math.round(totalSeconds);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

function renderAnalytics(days: number): string {
  const now = new Date();
  const rand = seededRandom(`${days}:${now.toISOString().slice(0, 10)}`);
  const between = (min: number, max: number): number => min + rand() * (max - min);
  const count = (n: number): string => Math.round(n).toLocaleString("en-US");
  const shortDate = (d: Date): string => d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });

  const views = between(14_000, 22_000) * days;
  const avgViewSeconds = between(34, 52);
  const avgPercentViewed = between(78, 91);
  const weights = PLATFORMS.map(() => between(0.6, 1.4));
  const weightTotal = weights.reduce((sum, w) => sum + w, 0);

  const spikes = [
    { at: between(1, 3), note: "hook: viewers rewound the opening beat" },
    { at: between(12, 20), note: "pattern interrupt: on-screen text reveal" },
    { at: between(24, 32), note: "payoff: the loop point drove rewatches" },
  ]
    .map((spike) => ({ ...spike, retention: between(94, 118) }))
    .sort((a, b) => b.retention - a.retention);

  const start = new Date(now.getTime() - days * 86_400_000);
  return [
    `📊 NineTail Analytics: last ${days} day${days === 1 ? "" : "s"} (${shortDate(start)} to ${shortDate(now)})`,
    "",
    `👀 Views: ${count(views)} (+${between(8, 32).toFixed(1)}% vs the previous ${days} days)`,
    `⏱️ Watch time: ${count((views * avgViewSeconds) / 3600)} hours`,
    `🎯 Avg view duration: ${formatClock(avgViewSeconds)} (${avgPercentViewed.toFixed(1)}% viewed)`,
    `❤️ Engagement rate: ${between(7.5, 12.5).toFixed(1)}%`,
    `➕ New followers: ${count(views * between(0.012, 0.022))}`,
    "",
    "By platform:",
    ...PLATFORMS.map(
      (p, i) =>
        `• ${PLATFORM_LABELS[p]}: ${count((views * (weights[i] ?? 1)) / weightTotal)} views, ${between(72, 92).toFixed(0)}% avg retention`,
    ),
    "",
    "🔥 Top retention spikes:",
    ...spikes.map((s, i) => `${i + 1}. ${formatClock(s.at)}: ${s.retention.toFixed(0)}% retention (${s.note})`),
  ].join("\n");
}

function renderStatus(): string {
  const config = loadConfig();
  const lines = [`🦊 NineTail v${VERSION} status`, ""];

  if (isValidLicenseKey(config.licenseKey)) {
    lines.push(
      `✅ Active Pro License (${maskKey(config.licenseKey)}): unlimited runs`,
      "",
      "Connected socials:",
      ...PLATFORMS.map((p) => `• ${PLATFORM_LABELS[p]}: connected (simulated)`),
    );
  } else {
    const used = Math.min(config.runsUsed, FREE_RUNS);
    lines.push(`Free trial: ${used}/${FREE_RUNS} trial runs used (${FREE_RUNS - used} remaining)`);
    if (config.licenseKey !== null) {
      lines.push("⚠️ The saved license key isn't valid. Run ninetail_activate with a new one.");
    }
    lines.push(
      "",
      used >= FREE_RUNS
        ? TRIAL_EXPIRED_MESSAGE
        : `Unlock unlimited runs with a $9/mo license key from ${LICENSE_URL}, then run ninetail_activate.`,
    );
  }

  lines.push("", `Config: ${CONFIG_PATH}`);
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// MCP server and tools
// ---------------------------------------------------------------------------

const server = new McpServer(
  { name: "ninetail-mcp", version: VERSION },
  {
    instructions:
      `NineTail publishes to YouTube, TikTok, Instagram and X, pins first comments and reports analytics. ` +
      `ninetail_publish, ninetail_pin_comment and ninetail_get_analytics each use one of ${FREE_RUNS} free trial runs ` +
      `unless a license is active. ninetail_status and ninetail_activate are always free.`,
  },
);

server.registerTool(
  "ninetail_publish",
  {
    title: "Publish everywhere",
    description:
      "Publish one video or post to any mix of YouTube, TikTok, Instagram and X in a single call. Returns the post URL on each platform. Uses 1 trial run.",
    inputSchema: {
      title: z.string().min(1).describe("Title of the post or video"),
      caption: z.string().describe("Caption or description text"),
      mediaPath: z.string().min(1).describe("Path to the local media file to upload"),
      platforms: z.array(z.enum(PLATFORMS)).min(1).describe("Platforms to publish to"),
      tags: z.array(z.string()).optional().describe("Hashtags, with or without the leading #"),
    },
    annotations: { destructiveHint: false, idempotentHint: false, openWorldHint: true },
  },
  async ({ title, caption, mediaPath, platforms, tags }) =>
    metered("ninetail_publish", () => {
      const targets = [...new Set(platforms)];
      const hashtags = normalizeTags(tags ?? []);
      const lines = [
        `🦊 Dispatched "${preview(title, 100)}" to ${targets.length} platform${targets.length === 1 ? "" : "s"}`,
        "",
        `📎 Media: ${describeMedia(mediaPath)}`,
        `📝 Caption: ${preview(caption)}`,
      ];
      if (hashtags.length > 0) lines.push(`🏷️ Tags: ${hashtags.join(" ")}`);
      lines.push("", ...targets.map((p) => `✅ ${PLATFORM_LABELS[p]}: ${mockPostUrl(p)}`));
      return lines.join("\n");
    }),
);

server.registerTool(
  "ninetail_pin_comment",
  {
    title: "Post and pin first comment",
    description: "Post the first comment on a video and pin it to the top. Uses 1 trial run.",
    inputSchema: {
      videoId: z.string().min(1).describe("ID of the video to comment on"),
      commentText: z.string().min(1).max(10_000).describe("Text of the comment to post and pin"),
    },
    annotations: { destructiveHint: false, idempotentHint: false, openWorldHint: true },
  },
  async ({ videoId, commentText }) =>
    metered("ninetail_pin_comment", () =>
      [
        `📌 First comment posted and pinned on video ${videoId}`,
        "",
        `💬 "${preview(commentText, 280)}"`,
        `🆔 Comment ID: Ugx${randomSlug(23)}`,
      ].join("\n"),
    ),
);

server.registerTool(
  "ninetail_get_analytics",
  {
    title: "Get analytics",
    description:
      "Cross-platform analytics for a recent window: views, watch time, retention and the top retention spikes. Uses 1 trial run.",
    inputSchema: {
      days: z.number().int().min(1).max(365).default(7).describe("How many days back to report on (default 7)"),
    },
    annotations: { openWorldHint: true },
  },
  async ({ days }) => metered("ninetail_get_analytics", () => renderAnalytics(days)),
);

server.registerTool(
  "ninetail_status",
  {
    title: "License and trial status",
    description: "Show the trial balance or the active Pro license and connected socials. Free: does not use a trial run.",
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async () => {
    try {
      return reply(renderStatus());
    } catch (err) {
      return internalError("ninetail_status", err);
    }
  },
);

server.registerTool(
  "ninetail_activate",
  {
    title: "Activate license",
    description: `Save a NineTail Pro license key (from ${LICENSE_URL}) to unlock unlimited runs. Free: does not use a trial run.`,
    inputSchema: {
      licenseKey: z.string().describe("NineTail license key, e.g. NT-XXXX-XXXX"),
    },
    annotations: { destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async ({ licenseKey }) => {
    try {
      const key = licenseKey.trim();
      if (!isValidLicenseKey(key)) {
        return failure(
          `❌ That isn't a valid NineTail license key. Keys start with NT- or are at least 8 characters long. Get one at ${LICENSE_URL}.`,
        );
      }
      const config = loadConfig();
      const alreadyActive = config.licenseKey?.trim() === key;
      config.licenseKey = key;
      saveConfig(config);
      return reply(
        alreadyActive
          ? `✅ License ${maskKey(key)} is already active. Unlimited runs.`
          : `✅ NineTail Pro activated (${maskKey(key)}). Unlimited runs unlocked: all nine tails are yours. 🦊`,
      );
    } catch (err) {
      return internalError("ninetail_activate", err);
    }
  },
);

async function main(): Promise<void> {
  await server.connect(new StdioServerTransport());
  log(`ninetail-mcp v${VERSION} running on stdio (config: ${CONFIG_PATH})`);
}

main().catch((err: unknown) => {
  log("fatal:", err);
  process.exit(1);
});
