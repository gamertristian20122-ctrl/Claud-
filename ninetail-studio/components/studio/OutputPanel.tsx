"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { AlertTriangle, ChevronDown, Code2, Eye, FileArchive, Flame, Lock, RotateCcw } from "lucide-react";
import { useEffect, useId, useMemo, useRef, useState } from "react";
import { KitsuneMascot } from "@/components/KitsuneMascot";
import { LANGUAGE_DOT } from "@/lib/highlight";
import { getTarget } from "@/lib/models";
import type { CodeLanguage, GenMode, GenStatus, MascotState, ParsedGeneration, Target } from "@/lib/types";
import { CodeView, CopyButton } from "./CodeView";
import { CtkSimulator } from "./CtkSimulator";
import { ImGuiSimulator } from "./ImGuiSimulator";
import { useElementSize, useLoopMotion } from "./output-kit";
import { PageSkeleton, WebPreview } from "./WebPreview";

export type OutputTab = "preview" | "code";

export interface OutputPanelProps {
  /** Target of the shown generation (falls back to the selected target before any build). */
  target: Target;
  status: GenStatus;
  parsed: ParsedGeneration | null;
  error: string | null;
  mode: GenMode | null;
  tab: OutputTab;
  onTabChange: (tab: OutputTab) => void;
  /** Called by the "1-Click ZIP Export" button. The parent decides between download and paywall. */
  onExport: () => void;
  /** Show a lock on the export button. */
  exportLocked: boolean;
  mascotState: MascotState;
  /** Retry after an error. */
  onRetry?: () => void;
  className?: string;
}

const TARGET_BADGE: Record<Target, string> = { web: "WEB", imgui: "C++", ctk: "PY" };
const PEEK_LABEL: Record<Target, string> = { web: "HTML · index.html", imgui: "C++ · ImGui::Begin()", ctk: "Python · app.py" };
const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;
const UNTITLED = "Untitled build";

function compactCount(n: number): string {
  if (n < 1000) return String(n);
  if (n < 100_000) return `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k`;
  return `${Math.round(n / 1000)}k`;
}

/** Line to bring into view in code peeks: the window entry point. */
function entryLine(code: string, language: CodeLanguage): number | undefined {
  if (!code) return undefined;
  const lines = code.split("\n");
  const patterns =
    language === "cpp"
      ? [/ImGui::Begin\s*\(/, /void\s+\w*(Render|Draw)\w*\s*\(/]
      : language === "python"
        ? [/class\s+\w+\s*\(\s*ctk\.CTk\s*\)/, /ctk\.CTk\s*\(\s*\)/, /def\s+__init__/]
        : [/<body/i];
  for (const re of patterns) {
    const i = lines.findIndex((l) => re.test(l));
    if (i >= 0) return Math.max(0, i - 2);
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Header pieces
// ---------------------------------------------------------------------------

function Tabs({
  tab,
  onChange,
  short,
  streaming,
  fill,
  uid,
}: {
  tab: OutputTab;
  onChange: (t: OutputTab) => void;
  short: boolean;
  streaming: boolean;
  fill: boolean;
  uid: string;
}) {
  const reduce = useReducedMotion();
  const items: { id: OutputTab; label: string; shortLabel: string; Icon: typeof Eye }[] = [
    { id: "preview", label: "Live Visual Preview", shortLabel: "Preview", Icon: Eye },
    { id: "code", label: "Raw Code", shortLabel: "Code", Icon: Code2 },
  ];
  const onKey = (e: React.KeyboardEvent) => {
    let next: OutputTab | null = null;
    if (e.key === "ArrowRight" || e.key === "ArrowLeft") next = tab === "preview" ? "code" : "preview";
    if (e.key === "Home") next = "preview";
    if (e.key === "End") next = "code";
    if (!next) return;
    e.preventDefault();
    onChange(next);
    document.getElementById(`${uid}-tab-${next}`)?.focus();
  };
  return (
    <div
      role="tablist"
      aria-label="Output view"
      onKeyDown={onKey}
      className={`flex h-11 shrink-0 items-center rounded-xl border border-white/[0.08] bg-obsidian-950/50 p-1 ${fill ? "w-full" : ""}`}
    >
      {items.map(({ id, label, shortLabel, Icon }) => {
        const active = tab === id;
        return (
          <button
            key={id}
            id={`${uid}-tab-${id}`}
            type="button"
            role="tab"
            aria-selected={active}
            aria-controls={`${uid}-panel`}
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(id)}
            className={`focus-ring relative flex h-full items-center justify-center gap-2 whitespace-nowrap rounded-lg px-3.5 text-[13px] font-medium transition-colors before:absolute before:-inset-y-1 before:inset-x-0 before:content-[''] ${
              fill ? "flex-1" : ""
            } ${active ? "text-fox-white" : "text-fox-muted hover:text-fox-white"}`}
          >
            {active && (
              <motion.span
                layoutId={`${uid}-tab-pill`}
                className="absolute inset-0 rounded-lg border border-white/[0.12] bg-white/[0.08] shadow-[inset_0_1px_0_rgba(255,255,255,0.08),0_0_22px_-6px_rgba(167,139,250,0.65)]"
                transition={reduce ? { duration: 0 } : SPRING}
              />
            )}
            <Icon className="relative h-4 w-4 shrink-0" strokeWidth={1.75} aria-hidden="true" />
            <span className="relative">{short ? shortLabel : label}</span>
            {id === "code" && streaming && (
              <span className="relative h-1.5 w-1.5 animate-soft-pulse rounded-full bg-spirit-cyan shadow-[0_0_8px_rgba(103,232,249,0.9)]" aria-hidden="true" />
            )}
          </button>
        );
      })}
    </div>
  );
}

function ExportButton({ onExport, disabled, locked, label, tight }: { onExport: () => void; disabled: boolean; locked: boolean; label: string; tight?: boolean }) {
  const reduce = useReducedMotion();
  return (
    <motion.button
      type="button"
      onClick={onExport}
      disabled={disabled}
      aria-label={locked ? "1-Click ZIP Export (paid feature)" : "1-Click ZIP Export"}
      title={disabled ? "Finish a build to export it" : locked ? "ZIP export is part of BYOK Pass and Pro" : "Download the project as a ZIP"}
      whileHover={disabled || reduce ? undefined : { y: -1 }}
      whileTap={disabled || reduce ? undefined : { scale: 0.98 }}
      transition={SPRING}
      className={`focus-ring group relative inline-flex h-11 shrink-0 items-center rounded-xl border border-white/[0.12] bg-white/[0.05] text-[13px] ${tight ? "gap-1.5 px-3" : "gap-2 px-3.5"} font-medium text-fox-white transition-[background-color,border-color,box-shadow] hover:border-spirit-violet/45 hover:bg-white/[0.08] hover:shadow-[0_0_24px_-6px_rgba(167,139,250,0.6)] disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:border-white/[0.12] disabled:hover:bg-white/[0.05] disabled:hover:shadow-none`}
    >
      <span className={`relative grid h-5 w-5 shrink-0 place-items-center ${locked ? "mr-1.5" : ""}`}>
        <FileArchive className="h-[18px] w-[18px]" strokeWidth={1.75} aria-hidden="true" />
        {locked && (
          <span className="absolute -bottom-1 -right-1.5 grid h-[15px] w-[15px] place-items-center rounded-full bg-obsidian-900 ring-1 ring-spirit-violet/60" aria-hidden="true">
            <Lock className="h-[9px] w-[9px] text-spirit-violet-soft" strokeWidth={2.4} />
          </span>
        )}
      </span>
      <span>{label}</span>
    </motion.button>
  );
}

function TitleBlock({
  title,
  target,
  mode,
  status,
  chars,
  lines,
  compact,
}: {
  title: string;
  target: Target;
  mode: GenMode | null;
  status: GenStatus;
  chars: number;
  lines: number;
  /** Narrow header: keep the status line short. */
  compact: boolean;
}) {
  let statusText: React.ReactNode = null;
  if (status === "streaming") statusText = <span className="text-spirit-cyan">{compact ? "Weaving…" : `Weaving · ${compactCount(chars)} chars`}</span>;
  else if (status === "error") statusText = <span className="text-[#ff9aac]">{compact ? "Stopped" : "Interrupted"}</span>;
  else if (status === "done" && lines > 0) statusText = compact ? null : <span>{lines.toLocaleString("en-US")} lines</span>;
  else if (!compact || !mode) statusText = <span>{getTarget(target).sub}</span>;

  return (
    <div className="min-w-0 flex-1">
      <h2 className="truncate text-[14px] font-semibold leading-5 tracking-tight text-fox-white" title={title}>
        {title}
      </h2>
      <div className="mt-1 flex min-w-0 items-center gap-1.5 font-mono text-[11px] leading-none text-fox-muted">
        <span className="shrink-0 rounded-md border border-white/[0.12] bg-white/[0.04] px-1.5 py-[3px] font-medium tracking-wider text-fox-mist">{TARGET_BADGE[target]}</span>
        {mode === "live" && (
          <span className="inline-flex shrink-0 items-center gap-1 rounded-md border border-spirit-cyan/25 bg-spirit-cyan/[0.07] px-1.5 py-[3px] text-spirit-cyan" title="Generated by a live model">
            <span className="h-1.5 w-1.5 rounded-full bg-spirit-cyan shadow-[0_0_6px_rgba(103,232,249,0.9)]" aria-hidden="true" />
            Live
          </span>
        )}
        {mode === "demo" && (
          <span className="inline-flex shrink-0 items-center gap-1 rounded-md border border-spirit-violet/30 bg-spirit-violet/[0.08] px-1.5 py-[3px] text-spirit-violet-soft" title="Demo output: no model key connected">
            <span className="h-1.5 w-1.5 rounded-full bg-spirit-violet" aria-hidden="true" />
            Demo
          </span>
        )}
        {statusText && <span className="min-w-0 truncate pl-0.5">{statusText}</span>}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Body states
// ---------------------------------------------------------------------------

/** Nine star trails fanning out like tails, drawn as a faint constellation. */
function Constellation() {
  const twinkle = useLoopMotion();
  const cx = 260;
  const cy = 300;
  const tails = Array.from({ length: 9 }, (_, i) => {
    const a = (-162 + i * 18) * (Math.PI / 180);
    const len = 180 + (4 - Math.abs(4 - i)) * 16;
    const ex = cx + Math.cos(a) * len;
    const ey = cy + Math.sin(a) * len;
    // Each tail rises first, then curls outward at the tip (mirrored left/right).
    const side = (4 - i) / 4;
    const pa = a + side * 0.5;
    const mx = cx + Math.cos(pa) * len * 0.62;
    const my = cy + Math.sin(pa) * len * 0.62;
    const pts = [0.38, 0.62, 0.84, 1].map((t) => {
      const x = (1 - t) * (1 - t) * cx + 2 * (1 - t) * t * mx + t * t * ex;
      const y = (1 - t) * (1 - t) * cy + 2 * (1 - t) * t * my + t * t * ey;
      return [x, y] as const;
    });
    return { d: `M${cx} ${cy} Q${mx.toFixed(1)} ${my.toFixed(1)} ${ex.toFixed(1)} ${ey.toFixed(1)}`, pts };
  });
  return (
    <svg
      viewBox="0 0 520 430"
      width={520}
      height={430}
      className="pointer-events-none absolute left-1/2 max-w-none -translate-x-1/2"
      style={{ top: 28 - cy }}
      aria-hidden="true"
    >
      <defs>
        <radialGradient id="nt-constellation-core" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="#a78bfa" stopOpacity="0.35" />
          <stop offset="1" stopColor="#a78bfa" stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r="125" fill="url(#nt-constellation-core)" />
      {tails.map((t, i) => (
        <g key={i}>
          <path d={t.d} fill="none" stroke="#c4b5fd" strokeOpacity="0.16" strokeWidth="1" strokeDasharray="2 5" />
          {t.pts.map(([x, y], j) =>
            j === t.pts.length - 1 ? (
              <motion.circle
                key={j}
                cx={x}
                cy={y}
                r={2.4}
                fill={i % 3 === 1 ? "#67e8f9" : "#f6f4ff"}
                initial={{ opacity: 0.6 }}
                animate={twinkle ? { opacity: [0.25, 0.9, 0.25] } : { opacity: 0.6 }}
                transition={twinkle ? { duration: 3.2, repeat: Infinity, delay: i * 0.28, ease: "easeInOut" } : undefined}
              />
            ) : (
              <circle key={j} cx={x} cy={y} r={1.2} fill="#d9d4f5" opacity={0.28 + j * 0.08} />
            ),
          )}
        </g>
      ))}
    </svg>
  );
}

function EmptyState({ target }: { target: Target }) {
  const t = getTarget(target);
  const steps = ["Pick an output", "Choose a tail", "Ignite"];
  return (
    <div className="relative flex h-full flex-col items-center justify-center overflow-hidden rounded-2xl border border-white/[0.05] bg-obsidian-950/40 px-5 text-center">
      <div
        className="pointer-events-none absolute inset-0 [background-image:linear-gradient(rgba(167,139,250,0.07)_1px,transparent_1px),linear-gradient(90deg,rgba(167,139,250,0.07)_1px,transparent_1px)] [background-size:34px_34px] [mask-image:radial-gradient(60%_55%_at_50%_45%,black,transparent)]"
        aria-hidden="true"
      />
      <div className="relative flex flex-col items-center">
        <div className="relative">
          <Constellation />
          <div className="relative grid h-14 w-14 place-items-center rounded-2xl border border-white/[0.14] bg-obsidian-900/80 shadow-glow-violet">
            <Flame className="h-6 w-6 text-fox-white" strokeWidth={1.6} aria-hidden="true" />
          </div>
        </div>
        <p className="eyebrow relative mt-6">
          {t.label} · {t.sub}
        </p>
        <h3 className="relative mt-2.5 max-w-[16ch] text-balance text-[24px] font-semibold leading-[1.15] tracking-tight text-fox-white sm:max-w-none sm:text-[28px]">
          Your build materializes here
        </h3>
        <p className="relative mt-3 max-w-[36ch] text-[14px] leading-relaxed text-fox-muted">
          Describe a page, a mod menu or a desktop app. The live preview and the full source land in this panel.
        </p>
        <ol className="relative mt-6 flex w-full max-w-[240px] flex-col gap-2 sm:w-auto sm:max-w-none sm:flex-row sm:flex-wrap sm:justify-center" aria-label="How to start">
          {steps.map((s, i) => (
            <li key={s} className="inline-flex h-9 items-center gap-2.5 rounded-full border border-white/[0.1] bg-white/[0.03] pl-1.5 pr-3.5 text-[13px] text-fox-mist">
              <span className="grid h-6 w-6 place-items-center rounded-full bg-white/[0.07] font-mono text-[11px] text-fox-white">{i + 1}</span>
              {s}
            </li>
          ))}
        </ol>
      </div>
    </div>
  );
}

function Materializing({ chars, lastLine, dense }: { chars: number; lastLine: string; dense: boolean }) {
  return (
    <div className="relative flex h-full flex-col overflow-hidden rounded-2xl border border-white/[0.06] bg-obsidian-950/60" role="status" aria-live="polite">
      <div className="flex h-10 shrink-0 items-center gap-2 border-b border-white/[0.05] px-3">
        <span className="flex gap-1.5" aria-hidden="true">
          <span className="h-2.5 w-2.5 rounded-full bg-white/10" />
          <span className="h-2.5 w-2.5 rounded-full bg-white/10" />
          <span className="h-2.5 w-2.5 rounded-full bg-white/10" />
        </span>
        <span className="ml-1 truncate font-mono text-[11px] text-fox-muted">index.html · materializing</span>
      </div>
      <div className="relative min-h-0 flex-1 overflow-hidden">
        <PageSkeleton dense={dense} />
        <motion.div
          className="pointer-events-none absolute inset-x-0 h-24 bg-gradient-to-b from-transparent via-spirit-cyan/[0.07] to-transparent motion-reduce:hidden"
          initial={{ top: "-20%" }}
          animate={{ top: ["-20%", "100%"] }}
          transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
          aria-hidden="true"
        >
          <div className="absolute inset-x-0 top-1/2 h-px bg-gradient-to-r from-transparent via-spirit-cyan/60 to-transparent" />
        </motion.div>
      </div>
      <div className="flex shrink-0 items-center gap-2.5 border-t border-white/[0.05] px-3 py-3 font-mono text-[12px]">
        <span className="h-1.5 w-1.5 shrink-0 animate-soft-pulse rounded-full bg-spirit-cyan shadow-[0_0_8px_rgba(103,232,249,0.9)]" aria-hidden="true" />
        <span className="shrink-0 text-spirit-cyan">Weaving {chars.toLocaleString("en-US")} characters…</span>
        <span className="min-w-0 truncate text-fox-dim">{lastLine}</span>
      </div>
    </div>
  );
}

function ErrorCard({ message, onRetry, onViewCode }: { message: string; onRetry?: () => void; onViewCode?: () => void }) {
  return (
    <div className="flex h-full items-center justify-center rounded-2xl border border-white/[0.05] bg-obsidian-950/40 p-4">
      <div className="glass-strong w-full max-w-[420px] rounded-2xl p-5" role="alert">
        <div className="flex items-start gap-3">
          <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-[#ff5c7a]/10 ring-1 ring-[#ff5c7a]/30">
            <AlertTriangle className="h-[18px] w-[18px] text-[#ff9aac]" strokeWidth={1.75} aria-hidden="true" />
          </span>
          <div className="min-w-0">
            <h3 className="text-[15px] font-semibold tracking-tight text-fox-white">The build stopped early</h3>
            <p className="mt-1 break-words text-[13px] leading-relaxed text-fox-muted">{message}</p>
          </div>
        </div>
        {(onRetry || onViewCode) && (
          <div className="mt-5 flex flex-col gap-2 min-[420px]:flex-row">
            {onRetry && (
              <button
                type="button"
                onClick={onRetry}
                className="focus-ring inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-fox-white px-4 text-[13px] font-semibold text-obsidian-950 transition hover:bg-white hover:shadow-glow-white"
              >
                <RotateCcw className="h-4 w-4" strokeWidth={2} aria-hidden="true" />
                Retry
              </button>
            )}
            {onViewCode && (
              <button
                type="button"
                onClick={onViewCode}
                className="focus-ring inline-flex h-11 items-center justify-center gap-2 rounded-xl border border-white/[0.12] bg-white/[0.04] px-4 text-[13px] font-medium text-fox-white transition hover:bg-white/[0.08]"
              >
                <Code2 className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
                View partial code
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function CodePeek({
  code,
  language,
  filename,
  label,
  streaming,
  focusLine,
  bodyHeight,
}: {
  code: string;
  language: CodeLanguage;
  filename: string;
  label: string;
  streaming: boolean;
  focusLine?: number;
  bodyHeight: number;
}) {
  const reduce = useReducedMotion();
  const [open, setOpen] = useState(false);
  const id = useId();
  const lines = code ? code.split("\n").length : 0;
  const collapsedH = 44 + 12 + 6 * 19;
  const expandedH = Math.max(collapsedH + 60, Math.round(bodyHeight * 0.64));
  return (
    <motion.div
      className="relative flex shrink-0 flex-col overflow-hidden rounded-2xl border border-white/[0.06] bg-[#08080f]"
      initial={false}
      animate={{ height: open ? expandedH : collapsedH }}
      transition={reduce ? { duration: 0 } : SPRING}
    >
      <div className="flex h-11 shrink-0 items-center gap-2 border-b border-white/[0.06] bg-white/[0.02] pl-3 pr-1.5">
        <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: LANGUAGE_DOT[language], boxShadow: `0 0 8px ${LANGUAGE_DOT[language]}` }} aria-hidden="true" />
        <span className="min-w-0 truncate font-mono text-[12px] text-fox-white">{label}</span>
        <span className="hidden shrink-0 font-mono text-[11px] text-fox-muted min-[400px]:inline">{lines} lines</span>
        <span className="flex-1" />
        <CopyButton text={code} compact labelClassName="hidden min-[380px]:inline" />
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          aria-expanded={open}
          aria-controls={id}
          aria-label={open ? "Collapse code" : "Expand code"}
          className="focus-ring relative grid h-8 w-9 shrink-0 place-items-center rounded-lg text-fox-muted transition before:absolute before:-inset-1.5 before:content-[''] hover:bg-white/[0.06] hover:text-fox-white"
        >
          <ChevronDown className={`h-4 w-4 transition-transform duration-200 ${open ? "" : "rotate-180"}`} strokeWidth={1.75} />
        </button>
      </div>
      <div id={id} className="relative min-h-0 flex-1">
        <CodeView
          code={code}
          language={language}
          filename={filename}
          streaming={streaming}
          compact
          hideHeader
          scrollLocked={!open}
          focusLine={open ? undefined : focusLine}
          className="h-full"
        />
        {!open && !streaming && (
          <div className="pointer-events-none absolute inset-x-0 bottom-0 flex h-14 items-end justify-center bg-gradient-to-t from-[#08080f] via-[#08080f]/80 to-transparent pb-2">
            <button
              type="button"
              onClick={() => setOpen(true)}
              tabIndex={-1}
              aria-hidden="true"
              className="pointer-events-auto inline-flex h-7 items-center gap-1 rounded-full border border-white/[0.1] bg-obsidian-800/90 px-3 font-mono text-[11px] text-fox-mist shadow-glass transition hover:border-white/20 hover:text-fox-white"
            >
              Show full code
              <ChevronDown className="h-3 w-3" strokeWidth={2} />
            </button>
          </div>
        )}
      </div>
    </motion.div>
  );
}

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------

export function OutputPanel({
  target,
  status,
  parsed,
  error,
  mode,
  tab,
  onTabChange,
  onExport,
  exportLocked,
  mascotState,
  onRetry,
  className = "",
}: OutputPanelProps) {
  const reduce = useReducedMotion();
  const uid = useId().replace(/:/g, "");
  const [rootRef, root] = useElementSize<HTMLElement>();
  const [bodyRef, body] = useElementSize<HTMLDivElement>();

  const width = root.width;
  const tier: "narrow" | "mid" | "wide" = width === 0 || width < 560 ? "narrow" : width < 860 ? "mid" : "wide";
  const split = width >= 900;
  const streaming = status === "streaming";
  const code = parsed?.code ?? "";
  const language: CodeLanguage = parsed?.language ?? getTarget(target).language;
  const filename = getTarget(target).file;
  const lines = code ? code.split("\n").length : 0;

  const title =
    parsed && parsed.title && !(parsed.title === UNTITLED && streaming)
      ? parsed.title
      : streaming
        ? "Summoning your build…"
        : status === "error"
          ? "Build interrupted"
          : "No build yet";

  const focusLine = useMemo(() => (streaming ? undefined : entryLine(code, language)), [code, language, streaming]);
  const lastLine = useMemo(() => {
    if (!streaming || !code) return "";
    const tail = code.slice(-240).split("\n");
    for (let i = tail.length - 1; i >= 0; i--) if (tail[i].trim()) return tail[i].trim();
    return "";
  }, [code, streaming]);

  // Brief glow on the panel edge when a build lands.
  const [flash, setFlash] = useState(0);
  const prevStatus = useRef(status);
  useEffect(() => {
    if (prevStatus.current === "streaming" && status === "done") setFlash((f) => f + 1);
    prevStatus.current = status;
  }, [status]);

  // Which body view is showing. Keys stay stable across streaming → done so state survives.
  let view: "empty" | "error" | "code" | "web-wait" | "web" | "desktop";
  if (!parsed && status === "idle") view = "empty";
  else if (tab === "code") view = code || streaming ? "code" : status === "error" ? "error" : "empty";
  else if (status === "error") view = "error";
  else if (target === "web") view = code && (parsed?.complete || !streaming) ? "web" : streaming ? "web-wait" : "empty";
  else view = "desktop";

  // Partial code from a failed build is not exportable.
  const exportDisabled = !code || streaming || status === "error";

  let content: React.ReactNode;
  switch (view) {
    case "empty":
      content = <EmptyState target={target} />;
      break;
    case "error":
      content = (
        <ErrorCard
          message={error || "Something went wrong while generating. Try again."}
          onRetry={onRetry}
          onViewCode={code && tab !== "code" ? () => onTabChange("code") : undefined}
        />
      );
      break;
    case "code":
      content = (
        <div className="flex h-full min-h-0 flex-col gap-2">
          {status === "error" && (
            <div className="flex shrink-0 items-center gap-2.5 rounded-xl border border-[#ff5c7a]/25 bg-[#ff5c7a]/[0.06] py-1.5 pl-3 pr-1.5 text-[13px] text-[#ffc2cd]" role="alert">
              <AlertTriangle className="h-4 w-4 shrink-0" strokeWidth={1.75} aria-hidden="true" />
              <span className="min-w-0 flex-1 truncate">
                Partial code. {error || "The build stopped early."}
              </span>
              {onRetry && (
                <button
                  type="button"
                  onClick={onRetry}
                  className="focus-ring inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg bg-white/[0.08] px-2.5 text-[12px] font-medium text-fox-white transition hover:bg-white/[0.14]"
                >
                  <RotateCcw className="h-3.5 w-3.5" strokeWidth={2} aria-hidden="true" />
                  Retry
                </button>
              )}
            </div>
          )}
          <CodeView
            code={code}
            language={language}
            filename={filename}
            streaming={streaming}
            compact={false}
            className="min-h-0 flex-1 rounded-2xl border border-white/[0.06]"
          />
        </div>
      );
      break;
    case "web-wait":
      content = <Materializing chars={code.length} lastLine={lastLine} dense={tier === "narrow"} />;
      break;
    case "web":
      content = <WebPreview html={code} streaming={streaming} />;
      break;
    case "desktop": {
      const sim =
        target === "imgui" ? <ImGuiSimulator spec={parsed?.gui ?? null} streaming={streaming} /> : <CtkSimulator spec={parsed?.gui ?? null} streaming={streaming} />;
      content = split ? (
        <div className="flex h-full min-h-0 gap-3">
          <div className="relative min-w-0 flex-[1.35] overflow-hidden rounded-2xl border border-white/[0.06]">{sim}</div>
          <CodeView
            code={code}
            language={language}
            filename={filename}
            streaming={streaming}
            compact
            focusLine={focusLine}
            className="min-w-[320px] flex-1 rounded-2xl border border-white/[0.06]"
          />
        </div>
      ) : (
        <div className="flex h-full min-h-0 flex-col gap-2.5">
          <div className="relative min-h-0 flex-1 overflow-hidden rounded-2xl border border-white/[0.06]">{sim}</div>
          <CodePeek
            code={code}
            language={language}
            filename={filename}
            label={PEEK_LABEL[target]}
            streaming={streaming}
            focusLine={focusLine}
            bodyHeight={body.height}
          />
        </div>
      );
      break;
    }
  }

  const mascot = <KitsuneMascot state={mascotState} size={tier === "narrow" ? 38 : 40} className="shrink-0" />;
  const tabs = <Tabs tab={tab} onChange={onTabChange} short={tier !== "wide"} streaming={streaming} fill={tier === "narrow"} uid={uid} />;
  const titleBlock = <TitleBlock title={title} target={target} mode={mode} status={status} chars={code.length} lines={lines} compact={tier === "narrow"} />;
  const exportBtn = <ExportButton onExport={onExport} disabled={exportDisabled} locked={exportLocked} label={tier === "wide" ? "1-Click ZIP Export" : "ZIP Export"} tight={tier === "narrow"} />;

  return (
    <section ref={rootRef} aria-label="Build output" className={`glass relative flex h-full min-h-0 w-full min-w-0 flex-col overflow-hidden rounded-3xl ${className}`}>
      <header className="relative shrink-0 overflow-hidden border-b border-white/[0.06]">
        {tier === "narrow" ? (
          <div className="flex flex-col gap-2.5 px-3 pb-3 pt-3">
            <div className="flex items-center gap-2.5">
              {mascot}
              {titleBlock}
              {exportBtn}
            </div>
            {tabs}
          </div>
        ) : (
          <div className="flex h-[68px] items-center gap-3 px-3.5">
            {tabs}
            <span className="h-7 w-px shrink-0 bg-white/[0.08]" aria-hidden="true" />
            {mascot}
            {titleBlock}
            {exportBtn}
          </div>
        )}
        {streaming && (
          <motion.span
            className="pointer-events-none absolute bottom-0 left-0 h-px w-1/3 bg-gradient-to-r from-transparent via-spirit-cyan to-transparent motion-reduce:hidden"
            initial={{ x: "-100%" }}
            animate={{ x: ["-100%", "320%"] }}
            transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }}
            aria-hidden="true"
          />
        )}
      </header>

      <div
        ref={bodyRef}
        id={`${uid}-panel`}
        role="tabpanel"
        aria-labelledby={`${uid}-tab-${tab}`}
        className="relative min-h-0 flex-1 p-2.5 sm:p-3"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={view}
            className="h-full min-h-0"
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: -4 }}
            transition={{ duration: 0.18, ease: "easeOut" }}
          >
            {content}
          </motion.div>
        </AnimatePresence>
      </div>

      <AnimatePresence>
        {flash > 0 && (
          <motion.span
            key={flash}
            className="pointer-events-none absolute inset-0 rounded-3xl"
            style={{ boxShadow: "inset 0 0 0 1px rgba(196,181,253,0.55), inset 0 0 60px rgba(167,139,250,0.22)" }}
            initial={{ opacity: reduce ? 0 : 1 }}
            animate={{ opacity: 0 }}
            transition={{ duration: 1.4, ease: "easeOut" }}
            aria-hidden="true"
          />
        )}
      </AnimatePresence>
    </section>
  );
}

export default OutputPanel;
