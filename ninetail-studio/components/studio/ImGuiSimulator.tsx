"use client";

// Interactive HTML/CSS replica of a Dear ImGui dark-style window, rendered from a GuiSpec.
// Proportions follow ImGui's defaults: 22px title bar, 8px window padding, 8x4 item
// spacing, frames with 4x3 padding and labels to the RIGHT of frames.

import { AnimatePresence, motion, useDragControls, useReducedMotion } from "framer-motion";
import { AppWindow, Info } from "lucide-react";
import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import type { GuiBlip, GuiSpec, GuiWidget } from "@/lib/types";
import {
  formatNumber,
  groupRows,
  mix,
  placePopup,
  rgba,
  sliderIsInteger,
  useElementSize,
  useIsoLayoutEffect,
  usePopupList,
  useSliderControl,
  useToast,
  type PopupPlacement,
  type PopupRequest,
  type WidgetValue,
} from "./output-kit";

export interface ImGuiSimulatorProps {
  spec: GuiSpec | null;
  /** The generation is still streaming (shows a skeleton window while spec is null). */
  streaming?: boolean;
  className?: string;
}

const DEFAULT_ACCENT = "#a78bfa";
const WINDOW_BG = "#0f0f16";

export const BLIP_COLORS: Record<NonNullable<GuiBlip["kind"]>, string> = {
  enemy: "#ff5c7a",
  ally: "#67e8f9",
  objective: "#fbbf24",
};

function themeVars(accent: string): React.CSSProperties {
  return {
    "--im-accent": accent,
    "--im-text": "#f2f1f8",
    "--im-dim": "#8b88a6",
    "--im-border": "#2b2b3a",
    "--im-frame": "#1e1c2c",
    "--im-frame-h": "#2a273d",
    "--im-frame-a": "#353150",
    "--im-btn": rgba(accent, 0.4),
    "--im-btn-h": rgba(accent, 0.85),
    "--im-btn-a": mix(accent, "#ffffff", 0.12),
    "--im-header": rgba(accent, 0.31),
    "--im-header-h": rgba(accent, 0.8),
    "--im-grab": mix(accent, "#000000", 0.08),
    "--im-grab-a": mix(accent, "#ffffff", 0.3),
    "--im-title": "#13121c",
    "--im-title-a": mix(accent, WINDOW_BG, 0.56),
    "--im-tab": mix(accent, WINDOW_BG, 0.74),
    "--im-tab-h": rgba(accent, 0.8),
    "--im-tab-a": mix(accent, WINDOW_BG, 0.4),
    "--im-sep": "#3b3950",
    "--im-plot": mix(accent, "#ffffff", 0.35),
    "--im-hist": mix(accent, "#000000", 0.05),
  } as React.CSSProperties;
}

// ---------------------------------------------------------------------------
// Stage: a dark game scene behind the window
// ---------------------------------------------------------------------------

const STARS = Array.from({ length: 42 }, (_, i) => {
  // Deterministic scatter (no Math.random, so SSR and client agree).
  const x = (i * 197.3 + 53) % 800;
  const y = ((i * 89.7 + 17) % 330) * 0.95;
  const r = i % 7 === 0 ? 1.4 : i % 3 === 0 ? 1 : 0.7;
  const o = 0.25 + ((i * 37) % 50) / 100;
  return { x, y, r, o };
});

function GameScene({ accent }: { accent: string }) {
  const uid = useId().replace(/:/g, "");
  const horizon = 400;
  const vx = 400;
  const bottoms = Array.from({ length: 33 }, (_, i) => vx + (i - 16) * 110);
  const horizontals = Array.from({ length: 9 }, (_, i) => horizon + 200 * ((i + 1) / 9) ** 2);
  return (
    <svg className="absolute inset-0 h-full w-full" viewBox="0 0 800 600" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
      <defs>
        <linearGradient id={`${uid}-sky`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#05040c" />
          <stop offset="0.45" stopColor="#0f0b22" />
          <stop offset="0.64" stopColor="#221640" />
          <stop offset="0.667" stopColor="#2c1b4c" />
        </linearGradient>
        <radialGradient id={`${uid}-moon`} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="#e9e4ff" stopOpacity="0.35" />
          <stop offset="1" stopColor="#e9e4ff" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`${uid}-glow`} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor={accent} stopOpacity="0.42" />
          <stop offset="1" stopColor={accent} stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`${uid}-ground`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#0c0a18" />
          <stop offset="1" stopColor="#040309" />
        </linearGradient>
        <linearGradient id={`${uid}-fade`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#000" stopOpacity="0.85" />
          <stop offset="0.35" stopColor="#000" stopOpacity="0" />
        </linearGradient>
      </defs>
      <rect width="800" height={horizon} fill={`url(#${uid}-sky)`} />
      {STARS.map((s, i) => (
        <circle key={i} cx={s.x} cy={s.y} r={s.r} fill="#f6f4ff" opacity={s.o} />
      ))}
      <circle cx="512" cy="118" r="120" fill={`url(#${uid}-moon)`} />
      <circle cx="512" cy="118" r="28" fill="#ece8ff" opacity="0.92" />
      <circle cx="503" cy="110" r="6" fill="#d6cff5" opacity="0.6" />
      <circle cx="521" cy="128" r="4" fill="#d6cff5" opacity="0.5" />
      <ellipse cx="400" cy={horizon} rx="520" ry="90" fill={`url(#${uid}-glow)`} />
      {/* Far range */}
      <path d="M0 352 L70 318 L130 340 L210 286 L280 330 L340 300 L420 344 L500 296 L575 334 L640 304 L720 340 L800 312 L800 400 L0 400 Z" fill="#1a1232" />
      {/* Near ridge with a torii gate */}
      <path d="M0 384 L90 360 L170 372 L250 350 L330 376 L430 366 L540 384 L640 362 L730 380 L800 370 L800 400 L0 400 Z" fill="#0e0b1d" />
      <g fill="#07060e" transform="translate(262 308)">
        <path d="M-6 0 Q30 -9 66 0 L66 6 Q30 -2 -6 6 Z" />
        <rect x="2" y="12" width="56" height="4" />
        <rect x="8" y="4" width="5" height="52" />
        <rect x="47" y="4" width="5" height="52" />
        <rect x="27" y="6" width="6" height="8" />
      </g>
      <circle cx="282" cy="356" r="1.6" fill="#67e8f9" opacity="0.9" />
      <circle cx="302" cy="356" r="1.6" fill="#67e8f9" opacity="0.9" />
      <circle cx="560" cy="380" r="1.4" fill="#fbbf24" opacity="0.7" />
      <circle cx="640" cy="364" r="1.2" fill="#f0abfc" opacity="0.7" />
      {/* Floor with a perspective grid */}
      <rect y={horizon} width="800" height={600 - horizon} fill={`url(#${uid}-ground)`} />
      <g stroke={accent} strokeWidth="1" opacity="0.2">
        {bottoms.map((x) => (
          <line key={x} x1={vx} y1={horizon} x2={x} y2="600" />
        ))}
        {horizontals.map((y) => (
          <line key={y} x1="0" y1={y} x2="800" y2={y} />
        ))}
      </g>
      <line x1="0" y1={horizon} x2="800" y2={horizon} stroke={accent} strokeOpacity="0.45" strokeWidth="1" />
      <rect y={horizon} width="800" height="200" fill={`url(#${uid}-fade)`} />
    </svg>
  );
}

function HudOverlay({ overlay, accent }: { overlay: NonNullable<GuiSpec["overlay"]>; accent: string }) {
  const [fps, setFps] = useState(144);
  useEffect(() => {
    if (!overlay.fps) return;
    const t = window.setInterval(() => setFps(138 + Math.round(Math.random() * 10)), 700);
    return () => window.clearInterval(t);
  }, [overlay.fps]);
  return (
    <div className="pointer-events-none absolute inset-0 z-10 font-mono text-[11px]" aria-hidden="true">
      {overlay.fps && (
        <div className="absolute left-2 top-2 rounded-[4px] border border-white/[0.06] bg-black/45 px-2 py-[5px] text-[#e8e6f3] tabular-nums">
          FPS <span className="text-[#86efac]">{fps}</span> <span className="text-[#8b88a6]">·</span> {(1000 / fps).toFixed(1)} ms
        </div>
      )}
      {overlay.watermark && (
        <div className="absolute right-2 top-2 flex max-w-[55%] items-center gap-1.5 rounded-[4px] border border-white/[0.06] bg-black/45 px-2 py-[5px] uppercase tracking-[0.16em] text-[#f2f1f8]">
          <span className="h-1.5 w-1.5 shrink-0 rounded-[1px]" style={{ background: accent, boxShadow: `0 0 8px ${accent}` }} />
          <span className="truncate">{overlay.watermark}</span>
        </div>
      )}
      {overlay.crosshair && (
        <div className="absolute left-1/2 top-1/2 h-6 w-6 -translate-x-1/2 -translate-y-1/2">
          <span className="absolute left-1/2 top-0 h-[8px] w-[2px] -translate-x-1/2 rounded-full" style={{ background: accent, boxShadow: `0 0 6px ${accent}` }} />
          <span className="absolute bottom-0 left-1/2 h-[8px] w-[2px] -translate-x-1/2 rounded-full" style={{ background: accent, boxShadow: `0 0 6px ${accent}` }} />
          <span className="absolute left-0 top-1/2 h-[2px] w-[8px] -translate-y-1/2 rounded-full" style={{ background: accent, boxShadow: `0 0 6px ${accent}` }} />
          <span className="absolute right-0 top-1/2 h-[2px] w-[8px] -translate-y-1/2 rounded-full" style={{ background: accent, boxShadow: `0 0 6px ${accent}` }} />
          <span className="absolute left-1/2 top-1/2 h-[3px] w-[3px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-white" />
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

interface WidgetProps {
  w: GuiWidget;
  id: string;
  value: WidgetValue | undefined;
  set: (v: WidgetValue) => void;
  inRow: boolean;
  openPopup: (req: PopupRequest) => void;
  popupId: string | null;
  toast: (text: string) => void;
}

const frameCls = (inRow: boolean) => (inRow ? "min-w-0 flex-1" : "min-w-0 flex-[0_0_63%]");

function Label({ text }: { text?: string }) {
  if (!text) return null;
  return <span className="min-w-0 truncate text-[var(--im-text)]">{text}</span>;
}

function ImText({ w }: WidgetProps) {
  return <div className="min-w-0 break-words py-[2px] leading-[16px] text-[var(--im-text)]">{w.label}</div>;
}

function ImSeparator({ w }: WidgetProps) {
  if (!w.label) return <div className="my-[3px] h-px w-full bg-[var(--im-sep)]" role="separator" />;
  return (
    <div className="flex w-full items-center gap-2 pt-[5px] pb-[2px]" role="separator" aria-label={w.label}>
      <span className="h-[3px] w-3 shrink-0 bg-[var(--im-sep)]" />
      <span className="shrink-0 text-[var(--im-text)]">{w.label}</span>
      <span className="h-[3px] min-w-0 flex-1 bg-[var(--im-sep)]" />
    </div>
  );
}

function ImCheckbox({ w, value, set }: WidgetProps) {
  const on = value === true;
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={on}
      onClick={() => set(!on)}
      className="group flex min-w-0 items-center gap-[6px] rounded-[2px] text-left outline-none focus-visible:ring-1 focus-visible:ring-[var(--im-accent)]"
    >
      <span className="grid h-[17px] w-[17px] shrink-0 place-items-center rounded-[3px] bg-[var(--im-frame)] transition-colors group-hover:bg-[var(--im-frame-h)] group-active:bg-[var(--im-frame-a)]">
        {on && (
          <svg viewBox="0 0 16 16" className="h-[13px] w-[13px]" fill="none" aria-hidden="true">
            <path d="M3 8.4 6.4 11.6 13 4.6" stroke="var(--im-accent)" strokeWidth="2.4" strokeLinecap="square" />
          </svg>
        )}
      </span>
      <Label text={w.label} />
    </button>
  );
}

function ImSlider({ w, value, set, inRow }: WidgetProps) {
  const min = w.min ?? 0;
  const max = w.max ?? 100;
  const v = typeof value === "number" ? value : min;
  const integer = sliderIsInteger(w.format, min, max, typeof w.value === "number" ? w.value : min);
  const t = max > min ? (v - min) / (max - min) : 0;
  const text = formatNumber(w.format, v, integer);
  const ctl = useSliderControl({ value: v, min, max, integer, inset: 7, onChange: set });
  return (
    <div className="flex min-w-0 items-center gap-[6px]">
      <div
        role="slider"
        tabIndex={0}
        aria-label={w.label ?? "Slider"}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-valuenow={Number(v.toFixed(4))}
        aria-valuetext={text}
        {...ctl}
        className={`group relative h-[19px] cursor-pointer touch-none select-none rounded-[3px] bg-[var(--im-frame)] outline-none transition-colors hover:bg-[var(--im-frame-h)] focus-visible:ring-1 focus-visible:ring-[var(--im-accent)] active:bg-[var(--im-frame-a)] ${frameCls(inRow)}`}
      >
        <span
          className="absolute bottom-[2px] top-[2px] w-[10px] rounded-[2px] bg-[var(--im-grab)] group-active:bg-[var(--im-grab-a)]"
          style={{ left: `calc(2px + (100% - 14px) * ${t})` }}
        />
        <span className="pointer-events-none absolute inset-0 grid place-items-center tabular-nums text-[var(--im-text)]">{text}</span>
      </div>
      <Label text={w.label} />
    </div>
  );
}

function ImButton({ w, toast }: WidgetProps) {
  const label = w.label ?? "Button";
  return (
    <button
      type="button"
      onClick={() => toast(`Button pressed · ${label}`)}
      className="h-[19px] max-w-full shrink-0 truncate rounded-[3px] bg-[var(--im-btn)] px-[7px] text-[var(--im-text)] outline-none transition-colors hover:bg-[var(--im-btn-h)] focus-visible:ring-1 focus-visible:ring-[var(--im-accent)] active:bg-[var(--im-btn-a)]"
    >
      {label}
    </button>
  );
}

function ImCombo({ w, id, value, set, inRow, openPopup, popupId }: WidgetProps) {
  const options = w.options ?? [];
  const current = typeof value === "string" ? value : (options[0] ?? "");
  const open = popupId === id;
  const ref = useRef<HTMLButtonElement>(null);
  return (
    <div className="flex min-w-0 items-center gap-[6px]">
      <button
        ref={ref}
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={`${w.label ?? "Combo"}: ${current}`}
        onClick={() => ref.current && openPopup({ id, anchor: ref.current, options, value: current, onSelect: set, rowHeight: 19 })}
        onKeyDown={(e) => {
          if ((e.key === "ArrowDown" || e.key === "ArrowUp") && ref.current) {
            e.preventDefault();
            openPopup({ id, anchor: ref.current, options, value: current, onSelect: set, rowHeight: 19 });
          }
        }}
        className={`group flex h-[19px] items-center rounded-[3px] text-left outline-none transition-colors focus-visible:ring-1 focus-visible:ring-[var(--im-accent)] ${
          open ? "bg-[var(--im-frame-a)]" : "bg-[var(--im-frame)] hover:bg-[var(--im-frame-h)]"
        } ${frameCls(inRow)}`}
      >
        <span className="min-w-0 flex-1 truncate pl-[6px] text-[var(--im-text)]">{current}</span>
        <span
          className={`grid h-[19px] w-[19px] shrink-0 place-items-center rounded-r-[3px] transition-colors ${
            open ? "bg-[var(--im-btn-a)]" : "bg-[var(--im-btn)] group-hover:bg-[var(--im-btn-h)]"
          }`}
        >
          <svg viewBox="0 0 10 10" className="h-[8px] w-[8px]" aria-hidden="true">
            <path d="M1 2.5h8L5 8z" fill="var(--im-text)" />
          </svg>
        </span>
      </button>
      <Label text={w.label} />
    </div>
  );
}

function ImRadio({ w, value, set }: WidgetProps) {
  const options = w.options ?? [];
  const current = typeof value === "string" ? value : options[0];
  const onKey = (e: React.KeyboardEvent, i: number) => {
    let next = -1;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (i + 1) % options.length;
    if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (i + options.length - 1) % options.length;
    if (next < 0) return;
    e.preventDefault();
    set(options[next]);
    const group = (e.currentTarget as HTMLElement).parentElement;
    group?.querySelectorAll<HTMLButtonElement>("[role=radio]")[next]?.focus();
  };
  return (
    <div className="flex min-w-0 flex-wrap items-center gap-x-[10px] gap-y-[4px]" role="radiogroup" aria-label={w.label ?? "Options"}>
      {options.map((o, i) => {
        const on = o === current;
        return (
          <button
            key={o}
            type="button"
            role="radio"
            aria-checked={on}
            tabIndex={on ? 0 : -1}
            onClick={() => set(o)}
            onKeyDown={(e) => onKey(e, i)}
            className="group flex items-center gap-[5px] rounded-[2px] outline-none focus-visible:ring-1 focus-visible:ring-[var(--im-accent)]"
          >
            <span className="grid h-[17px] w-[17px] shrink-0 place-items-center rounded-full bg-[var(--im-frame)] transition-colors group-hover:bg-[var(--im-frame-h)] group-active:bg-[var(--im-frame-a)]">
              {on && <span className="h-[7px] w-[7px] rounded-full bg-[var(--im-accent)]" />}
            </span>
            <span className="text-[var(--im-text)]">{o}</span>
          </button>
        );
      })}
      {w.label && <span className="text-[var(--im-dim)]">{w.label}</span>}
    </div>
  );
}

function ImInput({ w, value, set, inRow }: WidgetProps) {
  return (
    <div className="flex min-w-0 items-center gap-[6px]">
      <input
        type="text"
        value={typeof value === "string" ? value : ""}
        placeholder={w.placeholder}
        onChange={(e) => set(e.target.value)}
        aria-label={w.label ?? "Text input"}
        spellCheck={false}
        className={`h-[19px] rounded-[3px] bg-[var(--im-frame)] px-[6px] font-mono text-[12px] text-[var(--im-text)] caret-[var(--im-accent)] outline-none transition-colors placeholder:text-[var(--im-dim)] hover:bg-[var(--im-frame-h)] focus:bg-[var(--im-frame-a)] focus:ring-1 focus:ring-[var(--im-accent)] ${frameCls(inRow)}`}
      />
      <Label text={w.label} />
    </div>
  );
}

/** ImGui::DragInt-like channel field ("R:167"): drag horizontally or use arrow keys. */
function DragChannel({ name, value, onChange, label }: { name: string; value: number; onChange: (v: number) => void; label: string }) {
  const start = useRef<{ x: number; v: number } | null>(null);
  return (
    <div
      role="slider"
      tabIndex={0}
      aria-label={`${label} ${name}`}
      aria-valuemin={0}
      aria-valuemax={255}
      aria-valuenow={value}
      onPointerDown={(e) => {
        start.current = { x: e.clientX, v: value };
        try {
          e.currentTarget.setPointerCapture(e.pointerId);
        } catch {
          // Ignore.
        }
      }}
      onPointerMove={(e) => {
        if (!start.current) return;
        onChange(Math.max(0, Math.min(255, Math.round(start.current.v + (e.clientX - start.current.x) * 0.6))));
      }}
      onPointerUp={() => (start.current = null)}
      onPointerCancel={() => (start.current = null)}
      onKeyDown={(e) => {
        if (e.key === "ArrowRight" || e.key === "ArrowUp") onChange(Math.min(255, value + (e.shiftKey ? 10 : 1)));
        else if (e.key === "ArrowLeft" || e.key === "ArrowDown") onChange(Math.max(0, value - (e.shiftKey ? 10 : 1)));
        else return;
        e.preventDefault();
      }}
      className="grid h-[19px] min-w-0 flex-1 cursor-ew-resize touch-none select-none place-items-center overflow-hidden rounded-[3px] bg-[var(--im-frame)] tabular-nums text-[var(--im-text)] outline-none transition-colors hover:bg-[var(--im-frame-h)] focus-visible:ring-1 focus-visible:ring-[var(--im-accent)] active:bg-[var(--im-frame-a)]"
    >
      <span className="truncate px-[2px]">
        {name}:{value}
      </span>
    </div>
  );
}

function ImColor({ w, value, set, inRow }: WidgetProps) {
  const hex = typeof value === "string" && /^#[\da-f]{6}$/i.test(value) ? value : "#a78bfa";
  const n = Number.parseInt(hex.slice(1), 16);
  const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  const setChannel = (i: number, v: number) => {
    const next = [...ch];
    next[i] = v;
    set(`#${next.map((c) => c.toString(16).padStart(2, "0")).join("")}`);
  };
  const label = w.label ?? "Color";
  return (
    <div className="flex min-w-0 items-center gap-[6px]">
      <div className={`flex items-center gap-[4px] ${frameCls(inRow)}`}>
        {(["R", "G", "B"] as const).map((name, i) => (
          <DragChannel key={name} name={name} value={ch[i]} label={label} onChange={(v) => setChannel(i, v)} />
        ))}
        <label className="relative h-[19px] w-[19px] shrink-0 cursor-pointer rounded-[3px] ring-1 ring-inset ring-black/40 focus-within:ring-[var(--im-accent)]" style={{ background: hex }}>
          <input
            type="color"
            value={hex}
            onChange={(e) => set(e.target.value.toLowerCase())}
            aria-label={`${label}: pick color`}
            className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </label>
      </div>
      <Label text={label} />
    </div>
  );
}

function ImProgress({ w, value, inRow }: WidgetProps) {
  const v = typeof value === "number" ? Math.max(0, Math.min(1, value)) : 0;
  const pct = Math.round(v * 100);
  return (
    <div className="flex min-w-0 items-center gap-[6px]">
      <div
        role="progressbar"
        aria-label={w.label ?? "Progress"}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct}
        className={`relative h-[19px] overflow-hidden rounded-[3px] bg-[var(--im-frame)] ${frameCls(inRow)}`}
      >
        <span className="absolute inset-y-0 left-0 bg-[var(--im-hist)]" style={{ width: `${pct}%` }} />
        <span className="absolute inset-0 grid place-items-center tabular-nums text-[var(--im-text)] [text-shadow:0_1px_0_rgba(0,0,0,0.6)]">{pct}%</span>
      </div>
      <Label text={w.label} />
    </div>
  );
}

function ImRadar({ w }: WidgetProps) {
  const blips = w.blips ?? [];
  const range = typeof w.value === "string" ? w.value : null;
  return (
    <div className="flex min-w-0 flex-col gap-[4px]">
      {(w.label || range) && (
        <div className="flex max-w-[220px] items-center justify-between gap-2">
          <span className="truncate text-[var(--im-text)]">{w.label ?? "Radar"}</span>
          {range && <span className="shrink-0 text-[var(--im-dim)]">{range}</span>}
        </div>
      )}
      <div
        className="relative aspect-square w-full max-w-[220px] overflow-hidden rounded-[4px] border border-[var(--im-border)] bg-[#0a0911]"
        role="img"
        aria-label={`${w.label ?? "Radar"}: ${blips.length} contacts`}
      >
        <svg viewBox="-100 -100 200 200" className="absolute inset-0 h-full w-full" aria-hidden="true">
          <circle r="90" fill="var(--im-accent)" fillOpacity="0.05" stroke="var(--im-accent)" strokeOpacity="0.45" />
          <circle r="60" fill="none" stroke="var(--im-accent)" strokeOpacity="0.22" />
          <circle r="30" fill="none" stroke="var(--im-accent)" strokeOpacity="0.22" />
          <line x1="-90" y1="0" x2="90" y2="0" stroke="var(--im-accent)" strokeOpacity="0.22" />
          <line x1="0" y1="-90" x2="0" y2="90" stroke="var(--im-accent)" strokeOpacity="0.22" />
          <line x1="-64" y1="-64" x2="64" y2="64" stroke="var(--im-accent)" strokeOpacity="0.08" />
          <line x1="64" y1="-64" x2="-64" y2="64" stroke="var(--im-accent)" strokeOpacity="0.08" />
        </svg>
        <div
          className="absolute inset-[5%] animate-spin rounded-full"
          style={{
            animationDuration: "3.2s",
            background: "conic-gradient(from 0deg, transparent 0deg, transparent 290deg, color-mix(in srgb, var(--im-accent) 45%, transparent) 360deg)",
          }}
          aria-hidden="true"
        />
        <svg viewBox="-100 -100 200 200" className="absolute inset-0 h-full w-full" aria-hidden="true">
          {blips.map((b, i) => {
            const c = BLIP_COLORS[b.kind ?? "enemy"];
            const x = b.x * 86;
            const y = b.y * 86;
            return (
              <g key={i}>
                {b.kind !== "ally" && b.kind !== "objective" && (
                  <circle cx={x} cy={y} r="9" fill={c} opacity="0.22" className="animate-soft-pulse" />
                )}
                {b.kind === "objective" ? (
                  <rect x={x - 4} y={y - 4} width="8" height="8" fill={c} transform={`rotate(45 ${x} ${y})`} />
                ) : (
                  <circle cx={x} cy={y} r="4.2" fill={c} />
                )}
              </g>
            );
          })}
          <path d="M0 -7 L5.5 6 L0 3 L-5.5 6 Z" fill="#f6f4ff" />
        </svg>
      </div>
    </div>
  );
}

function ImPlot({ w, inRow }: WidgetProps) {
  const pts = w.points && w.points.length > 1 ? w.points : [0, 0];
  const lo = w.min ?? Math.min(...pts);
  const hi = w.max ?? Math.max(...pts);
  const span = hi - lo || 1;
  const [hover, setHover] = useState<number | null>(null);
  const coords = pts.map((p, i) => [(i / (pts.length - 1)) * 100, 38 - ((p - lo) / span) * 34] as const);
  return (
    <div className="flex min-w-0 items-start gap-[6px]">
      <div
        className={`relative h-[64px] rounded-[3px] bg-[var(--im-frame)] ${frameCls(inRow)}`}
        onPointerMove={(e) => {
          const r = e.currentTarget.getBoundingClientRect();
          const i = Math.round(((e.clientX - r.left) / r.width) * (pts.length - 1));
          setHover(Math.max(0, Math.min(pts.length - 1, i)));
        }}
        onPointerLeave={() => setHover(null)}
        role="img"
        aria-label={`${w.label ?? "Plot"}: ${pts.length} points from ${formatNumber("%.2f", Math.min(...pts))} to ${formatNumber("%.2f", Math.max(...pts))}`}
      >
        <svg viewBox="0 0 100 40" preserveAspectRatio="none" className="absolute inset-[3px] h-[calc(100%-6px)] w-[calc(100%-6px)]" aria-hidden="true">
          <polyline points={coords.map(([x, y]) => `${x},${y}`).join(" ")} fill="none" stroke="var(--im-plot)" strokeWidth="1.25" vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
          {hover !== null && <line x1={coords[hover][0]} y1="0" x2={coords[hover][0]} y2="40" stroke="#ff6e59" strokeOpacity="0.5" vectorEffect="non-scaling-stroke" />}
        </svg>
        {hover !== null && (
          <span className="pointer-events-none absolute left-1 top-1 rounded-[3px] border border-[var(--im-border)] bg-[rgba(15,15,22,0.94)] px-[5px] py-[2px] tabular-nums text-[var(--im-text)]">
            {hover}: {formatNumber("%.3f", pts[hover])}
          </span>
        )}
      </div>
      <Label text={w.label} />
    </div>
  );
}

function ImStat({ w }: WidgetProps) {
  const value = typeof w.value === "number" ? w.value.toLocaleString("en-US") : String(w.value ?? "—");
  const delta = w.delta;
  const color = delta?.trim().startsWith("-") || delta?.trim().startsWith("−") ? "#ff5c7a" : delta?.trim().startsWith("+") ? "#4ade80" : "var(--im-dim)";
  return (
    <div className="min-w-0 rounded-[4px] border border-[var(--im-border)] bg-white/[0.025] px-[8px] py-[6px]">
      <div className="truncate text-[11px] text-[var(--im-dim)]">{w.label ?? "Stat"}</div>
      <div className="mt-[4px] flex min-w-0 items-baseline gap-[6px]">
        <span className="truncate text-[17px] font-semibold leading-none tabular-nums text-[var(--im-text)]">{value}</span>
        {delta && (
          <span className="shrink-0 text-[11px] tabular-nums" style={{ color }}>
            {delta}
          </span>
        )}
      </div>
    </div>
  );
}

const WIDGETS: Record<GuiWidget["type"], (p: WidgetProps) => JSX.Element | null> = {
  text: ImText,
  separator: ImSeparator,
  checkbox: ImCheckbox,
  toggle: ImCheckbox,
  slider: ImSlider,
  button: ImButton,
  combo: ImCombo,
  radio: ImRadio,
  input: ImInput,
  color: ImColor,
  progress: ImProgress,
  radar: ImRadar,
  plot: ImPlot,
  stat: ImStat,
};

const GROW_IN_ROW = new Set<GuiWidget["type"]>(["slider", "combo", "input", "color", "progress", "plot", "stat", "radar", "separator"]);

// ---------------------------------------------------------------------------
// Popup list (combo dropdown)
// ---------------------------------------------------------------------------

function ImPopupList({ popup, onClose }: { popup: PopupPlacement; onClose: () => void }) {
  const initial = Math.max(0, popup.options.indexOf(popup.value));
  const close = useCallback(() => {
    onClose();
    popup.anchor.focus();
  }, [onClose, popup.anchor]);
  const pick = (i: number) => {
    popup.onSelect(popup.options[i]);
    close();
  };
  const { active, setActive, listRef, onKeyDown } = usePopupList(true, popup.options.length, initial, pick, close, popup.anchor);
  return (
    <div
      ref={listRef}
      role="listbox"
      tabIndex={-1}
      aria-activedescendant={`${popup.id}-opt-${active}`}
      onKeyDown={onKeyDown}
      className="absolute z-40 overflow-y-auto border border-[var(--im-border)] bg-[#121119] py-[4px] font-mono text-[12px] shadow-[0_12px_30px_rgba(0,0,0,0.6)] outline-none scrollbar-thin"
      style={{ left: popup.left, top: popup.top, width: popup.width, maxHeight: popup.maxHeight }}
    >
      {popup.options.map((o, i) => {
        const selected = o === popup.value;
        return (
          <div
            key={`${o}-${i}`}
            id={`${popup.id}-opt-${i}`}
            role="option"
            aria-selected={selected}
            data-index={i}
            onPointerEnter={() => setActive(i)}
            onClick={() => pick(i)}
            className="mx-[4px] flex h-[19px] cursor-pointer items-center truncate px-[4px] text-[var(--im-text)]"
            style={{ background: i === active ? "var(--im-header-h)" : selected ? "var(--im-header)" : undefined }}
          >
            {o}
          </div>
        );
      })}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Window
// ---------------------------------------------------------------------------

function initValues(spec: GuiSpec): Record<string, WidgetValue> {
  const out: Record<string, WidgetValue> = {};
  spec.tabs.forEach((t, ti) =>
    t.widgets.forEach((w, wi) => {
      if (w.value !== undefined) out[`${ti}:${wi}`] = w.value;
    }),
  );
  return out;
}

function ImGuiWindow({
  spec,
  stage,
  stageRef,
}: {
  spec: GuiSpec;
  stage: { width: number; height: number };
  stageRef: React.RefObject<HTMLDivElement>;
}) {
  const reduce = useReducedMotion();
  const uid = useId().replace(/:/g, "");
  const accent = spec.accent ?? DEFAULT_ACCENT;
  const vars = useMemo(() => themeVars(accent), [accent]);
  const [tab, setTab] = useState(0);
  const [collapsed, setCollapsed] = useState(false);
  const [closed, setClosed] = useState(false);
  const [focused, setFocused] = useState(true);
  const [values, setValues] = useState(() => initValues(spec));
  const [popup, setPopup] = useState<PopupPlacement | null>(null);
  const { toast, show } = useToast();
  const controls = useDragControls();
  const winRef = useRef<HTMLDivElement>(null);
  const [top, setTop] = useState<number | null>(null);

  const reserveTop = spec.overlay && (spec.overlay.fps || spec.overlay.watermark) ? 40 : 12;
  const width = Math.round(Math.max(220, Math.min(spec.width ?? 440, stage.width - 24)));
  const maxH = Math.max(140, Math.min(spec.height ?? Infinity, stage.height - reserveTop - 12));
  const left = Math.round((stage.width - width) / 2);

  // Center vertically on first layout and when the stage height changes.
  // Collapsing does not re-center, so the title bar stays put like in ImGui.
  useIsoLayoutEffect(() => {
    if (!winRef.current) return;
    const h = winRef.current.offsetHeight;
    setTop(Math.max(reserveTop, Math.round((stage.height - h) / 2)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stage.height, reserveTop, closed]);

  const showTabs = spec.tabs.length > 1 || spec.tabs[0]?.label !== "Main";
  const current = spec.tabs[Math.min(tab, spec.tabs.length - 1)];
  const rows = useMemo(() => groupRows(current?.widgets ?? []), [current]);

  const openPopup = useCallback(
    (req: PopupRequest) => {
      const stageEl = stageRef.current;
      if (!stageEl) return;
      setPopup((p) => (p && p.id === req.id ? null : placePopup(req, stageEl)));
    },
    [stageRef],
  );
  const closePopup = useCallback(() => setPopup(null), []);

  const onTabKey = (e: React.KeyboardEvent, i: number) => {
    let next = -1;
    if (e.key === "ArrowRight") next = (i + 1) % spec.tabs.length;
    if (e.key === "ArrowLeft") next = (i + spec.tabs.length - 1) % spec.tabs.length;
    if (next < 0) return;
    e.preventDefault();
    setTab(next);
    setPopup(null);
    const list = (e.currentTarget as HTMLElement).parentElement;
    list?.querySelectorAll<HTMLButtonElement>("[role=tab]")[next]?.focus();
  };

  return (
    <div style={vars} className="absolute inset-0 z-20" onPointerDown={(e) => e.target === e.currentTarget && setFocused(false)}>
      <AnimatePresence>
        {!closed && (
          <motion.div
            key="win"
            ref={winRef}
            drag
            dragControls={controls}
            dragListener={false}
            dragMomentum={false}
            dragElastic={0}
            dragConstraints={stageRef}
            onDragStart={() => setPopup(null)}
            onPointerDownCapture={() => setFocused(true)}
            initial={reduce ? { opacity: 0 } : { opacity: 0, scale: 0.97 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, scale: 0.97 }}
            transition={{ duration: 0.16 }}
            role="group"
            aria-label={`${spec.title} (simulated Dear ImGui window)`}
            className="absolute flex flex-col overflow-hidden font-mono text-[12px] leading-none text-[var(--im-text)]"
            style={{
              left,
              top: top ?? reserveTop,
              width,
              maxHeight: collapsed ? undefined : maxH,
              visibility: top === null ? "hidden" : "visible",
              background: "rgba(15, 15, 22, 0.94)",
              border: "1px solid #2b2b3a",
              borderRadius: 6,
              boxShadow: focused
                ? `0 18px 48px -12px rgba(0,0,0,0.85), 0 0 0 1px rgba(0,0,0,0.4), 0 0 40px -18px ${rgba(accent, 0.6)}`
                : "0 14px 36px -12px rgba(0,0,0,0.8)",
            }}
          >
            {/* Title bar */}
            <div
              className="flex h-[22px] shrink-0 cursor-grab touch-none select-none items-center gap-[4px] pr-[2px] active:cursor-grabbing"
              style={{ background: focused ? "var(--im-title-a)" : "var(--im-title)" }}
              onPointerDown={(e) => {
                if ((e.target as HTMLElement).closest("button")) return;
                setPopup(null);
                controls.start(e);
              }}
              onDoubleClick={(e) => {
                if ((e.target as HTMLElement).closest("button")) return;
                setCollapsed((c) => !c);
                setPopup(null);
              }}
            >
              <button
                type="button"
                onClick={() => {
                  setCollapsed((c) => !c);
                  setPopup(null);
                }}
                aria-label={collapsed ? "Expand window" : "Collapse window"}
                aria-expanded={!collapsed}
                className="relative grid h-[22px] w-[22px] shrink-0 place-items-center rounded-[3px] outline-none before:absolute before:-inset-[8px] before:content-[''] hover:bg-white/10 focus-visible:ring-1 focus-visible:ring-white/60"
              >
                <svg viewBox="0 0 10 10" className={`h-[9px] w-[9px] transition-transform ${collapsed ? "-rotate-90" : ""}`} aria-hidden="true">
                  <path d="M1 2.5h8L5 8z" fill="#f2f1f8" />
                </svg>
              </button>
              <span className="min-w-0 flex-1 truncate text-[#f6f5fb]">{spec.title}</span>
              <button
                type="button"
                onClick={() => {
                  setClosed(true);
                  setPopup(null);
                }}
                aria-label="Close window"
                className="relative grid h-[18px] w-[18px] shrink-0 place-items-center rounded-[3px] text-[#f2f1f8] outline-none before:absolute before:-inset-[9px] before:content-[''] hover:bg-[var(--im-btn-h)] focus-visible:ring-1 focus-visible:ring-white/60"
              >
                <svg viewBox="0 0 10 10" className="h-[8px] w-[8px]" aria-hidden="true">
                  <path d="M1.5 1.5l7 7M8.5 1.5l-7 7" stroke="currentColor" strokeWidth="1.4" />
                </svg>
              </button>
            </div>

            {!collapsed && (
              <>
                {showTabs && (
                  <div className="shrink-0 px-[8px] pt-[6px]">
                    <div role="tablist" aria-label={`${spec.title} tabs`} className="flex items-end gap-[2px] overflow-x-auto scrollbar-none">
                      {spec.tabs.map((t, i) => {
                        const active = i === tab;
                        return (
                          <button
                            key={`${t.label}-${i}`}
                            type="button"
                            role="tab"
                            id={`${uid}-tab-${i}`}
                            aria-selected={active}
                            aria-controls={`${uid}-panel`}
                            tabIndex={active ? 0 : -1}
                            onClick={() => {
                              setTab(i);
                              setPopup(null);
                            }}
                            onKeyDown={(e) => onTabKey(e, i)}
                            className={`h-[21px] shrink-0 whitespace-nowrap rounded-t-[4px] px-[9px] text-[var(--im-text)] outline-none transition-colors focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-white/60 ${
                              active ? "bg-[var(--im-tab-a)]" : "bg-[var(--im-tab)] hover:bg-[var(--im-tab-h)]"
                            }`}
                          >
                            {t.label}
                          </button>
                        );
                      })}
                    </div>
                    <div className="h-px w-full bg-[var(--im-tab-a)]" />
                  </div>
                )}
                <div
                  id={`${uid}-panel`}
                  role={showTabs ? "tabpanel" : undefined}
                  aria-labelledby={showTabs ? `${uid}-tab-${tab}` : undefined}
                  className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-[8px] pb-[10px] pt-[6px] scrollbar-thin"
                  onScroll={() => popup && setPopup(null)}
                >
                  <div className="flex flex-col gap-[4px]">
                    {rows.length === 0 && <div className="py-[2px] text-[var(--im-dim)]">(empty)</div>}
                    {rows.map((row, ri) => {
                      const multi = row.items.length > 1;
                      return (
                        <div key={ri} className={multi ? "flex min-w-0 items-center gap-[8px]" : "min-w-0"}>
                          {row.items.map(({ w, index }) => {
                            const Comp = WIDGETS[w.type];
                            const key = `${tab}:${index}`;
                            const props: WidgetProps = {
                              w,
                              id: `${uid}-${key}`,
                              value: values[key],
                              set: (v) => setValues((s) => ({ ...s, [key]: v })),
                              inRow: multi,
                              openPopup,
                              popupId: popup?.id ?? null,
                              toast: show,
                            };
                            if (!multi) return <Comp key={index} {...props} />;
                            return (
                              <div key={index} className={GROW_IN_ROW.has(w.type) ? "min-w-0 flex-1" : "min-w-0 shrink-0"}>
                                <Comp {...props} />
                              </div>
                            );
                          })}
                        </div>
                      );
                    })}
                  </div>
                </div>
                {/* Resize grip (decorative) */}
                <svg viewBox="0 0 12 12" className="pointer-events-none absolute bottom-[1px] right-[1px] h-[12px] w-[12px]" aria-hidden="true">
                  <path d="M12 0 L12 12 L0 12 Z" fill={rgba(accent, 0.28)} />
                </svg>
              </>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {popup && <ImPopupList popup={popup} onClose={closePopup} />}

      <AnimatePresence>
        {closed && (
          <motion.button
            key="reopen"
            type="button"
            onClick={() => {
              setClosed(false);
              setCollapsed(false);
            }}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="focus-ring absolute left-1/2 top-1/2 inline-flex h-11 -translate-x-1/2 -translate-y-1/2 items-center gap-2 rounded-full border border-white/15 bg-obsidian-900/80 px-4 font-sans text-[13px] font-medium text-fox-white shadow-glass backdrop-blur-md transition hover:border-white/25 hover:bg-obsidian-800/90"
          >
            <AppWindow className="h-4 w-4 text-spirit-violet" strokeWidth={1.75} />
            Reopen window
          </motion.button>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {toast && (
          <motion.div
            key={toast.id}
            role="status"
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 4 }}
            transition={{ duration: 0.16 }}
            className="pointer-events-none absolute bottom-3 left-1/2 z-50 max-w-[calc(100%-24px)] -translate-x-1/2 truncate rounded-[4px] border border-[#2b2b3a] bg-[rgba(15,15,22,0.94)] px-[8px] py-[5px] font-mono text-[11px] text-[#f2f1f8] shadow-[0_8px_24px_rgba(0,0,0,0.6)]"
          >
            {toast.text}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

function SkeletonWindow({ stage }: { stage: { width: number; height: number } }) {
  const width = Math.min(420, stage.width - 24);
  const bar = "rounded-[3px] bg-[linear-gradient(110deg,#1e1c2c_20%,#2f2a48_40%,#1e1c2c_60%)] bg-[length:200%_100%] animate-spirit-pan";
  const style = { animationDuration: "1.6s" };
  return (
    <div className="absolute inset-0 z-20 grid place-items-center p-3">
      <div
        className="overflow-hidden font-mono text-[12px]"
        style={{ width, background: "rgba(15,15,22,0.94)", border: "1px solid #2b2b3a", borderRadius: 6, boxShadow: "0 18px 48px -12px rgba(0,0,0,0.85)" }}
        role="status"
        aria-label="Summoning preview"
      >
        <div className="flex h-[22px] items-center gap-2 px-2" style={{ background: mix(DEFAULT_ACCENT, WINDOW_BG, 0.56) }}>
          <svg viewBox="0 0 10 10" className="h-[9px] w-[9px]" aria-hidden="true">
            <path d="M1 2.5h8L5 8z" fill="#f2f1f8" />
          </svg>
          <span className="text-[#f2f1f8]">Summoning preview…</span>
        </div>
        <div className="flex flex-col gap-[6px] p-[8px]">
          <div className="flex gap-[2px]">
            {[52, 44, 60].map((w, i) => (
              <div key={i} className={`h-[19px] ${bar}`} style={{ ...style, width: w }} />
            ))}
          </div>
          {[0.7, 0.55, 0.63, 0.48, 0.63, 0.4].map((f, i) => (
            <div key={i} className="flex items-center gap-[6px]">
              <div className={`h-[19px] ${bar}`} style={{ ...style, width: `${f * 100}%` }} />
              <div className={`h-[10px] ${bar}`} style={{ ...style, width: 56 }} />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export function NoPreviewNote({ code = "code" }: { code?: string }) {
  return (
    <div className="absolute inset-0 z-20 grid place-items-center p-4">
      <div className="glass flex max-w-[300px] items-start gap-3 rounded-2xl p-4 text-[13px] text-fox-mist">
        <Info className="mt-0.5 h-4 w-4 shrink-0 text-spirit-violet" strokeWidth={1.75} />
        <p>This build has no preview payload. See the {code} tab for the full source.</p>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Public component
// ---------------------------------------------------------------------------

export function ImGuiSimulator({ spec, streaming = false, className = "" }: ImGuiSimulatorProps) {
  const [sizeRef, stage] = useElementSize<HTMLDivElement>();
  const stageRef = useRef<HTMLDivElement>(null);
  const setStage = useCallback(
    (node: HTMLDivElement | null) => {
      (stageRef as React.MutableRefObject<HTMLDivElement | null>).current = node;
      sizeRef(node);
    },
    [sizeRef],
  );
  const specKey = useMemo(() => (spec ? JSON.stringify(spec) : ""), [spec]);
  const accent = spec?.accent ?? DEFAULT_ACCENT;
  const ready = stage.width > 0 && stage.height > 0;

  return (
    <div ref={setStage} className={`relative h-full w-full overflow-hidden bg-[#05040c] ${className}`}>
      <GameScene accent={accent} />
      {spec?.overlay && <HudOverlay overlay={spec.overlay} accent={accent} />}
      {ready && spec && <ImGuiWindow key={specKey} spec={spec} stage={stage} stageRef={stageRef} />}
      {ready && !spec && (streaming ? <SkeletonWindow stage={stage} /> : <NoPreviewNote />)}
    </div>
  );
}

export default ImGuiSimulator;
