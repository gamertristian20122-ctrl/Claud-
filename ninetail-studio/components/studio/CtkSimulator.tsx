"use client";

// Interactive HTML/CSS replica of a CustomTkinter dark-theme app window, rendered
// from a GuiSpec. Colors follow CustomTkinter's "dark-blue" theme defaults; the
// accent replaces the blue when the spec provides one.

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { AppWindow, Check } from "lucide-react";
import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import type { GuiSpec, GuiWidget } from "@/lib/types";
import { BLIP_COLORS, NoPreviewNote } from "./ImGuiSimulator";
import {
  formatNumber,
  groupRows,
  mix,
  placePopup,
  readableOn,
  rgba,
  sliderIsInteger,
  useElementSize,
  usePopupList,
  useSliderControl,
  useToast,
  type PopupPlacement,
  type PopupRequest,
  type WidgetValue,
} from "./output-kit";

export interface CtkSimulatorProps {
  spec: GuiSpec | null;
  /** The generation is still streaming (shows a skeleton window while spec is null). */
  streaming?: boolean;
  className?: string;
}

const DEFAULT_ACCENT = "#1f6aa5";

function themeVars(accent: string): React.CSSProperties {
  return {
    "--ck-accent": accent,
    "--ck-accent-h": mix(accent, "#000000", 0.3),
    "--ck-on-accent": readableOn(accent),
    "--ck-text": "#dce4ee",
    "--ck-muted": "#a3a9b0",
    "--ck-bg": "#242424",
    "--ck-frame": "#2b2b2b",
    "--ck-frame-2": "#333333",
    "--ck-track": "#4a4d50",
    "--ck-border": "#565b5e",
    "--ck-entry": "#343638",
    "--ck-check-border": "#949a9f",
  } as React.CSSProperties;
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

const focusCls = "outline-none focus-visible:ring-2 focus-visible:ring-[var(--ck-accent)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--ck-frame)]";

function FieldLabel({ text, right }: { text?: string; right?: React.ReactNode }) {
  if (!text && !right) return null;
  return (
    <div className="mb-1.5 flex min-w-0 items-baseline justify-between gap-3">
      <span className="min-w-0 truncate text-[12.5px] text-[var(--ck-muted)]">{text}</span>
      {right}
    </div>
  );
}

function CText({ w }: WidgetProps) {
  return <p className="min-w-0 break-words text-[13px] leading-[1.45] text-[var(--ck-text)]">{w.label}</p>;
}

function CSeparator({ w }: WidgetProps) {
  if (!w.label) return <div className="my-0.5 h-px w-full bg-white/[0.08]" role="separator" />;
  return (
    <div className="flex items-center gap-2.5 pt-1" role="separator" aria-label={w.label}>
      <span className="shrink-0 text-[11.5px] font-semibold uppercase tracking-[0.12em] text-[var(--ck-muted)]">{w.label}</span>
      <span className="h-px min-w-0 flex-1 bg-white/[0.08]" />
    </div>
  );
}

function CCheckbox({ w, value, set }: WidgetProps) {
  const on = value === true;
  return (
    <button type="button" role="checkbox" aria-checked={on} onClick={() => set(!on)} className={`group flex min-h-[28px] min-w-0 items-center gap-2.5 rounded-md text-left ${focusCls}`}>
      <span
        className={`grid h-[22px] w-[22px] shrink-0 place-items-center rounded-[6px] border-[3px] transition-colors ${
          on ? "border-[var(--ck-accent)] bg-[var(--ck-accent)] group-hover:border-[var(--ck-accent-h)] group-hover:bg-[var(--ck-accent-h)]" : "border-[var(--ck-check-border)] group-hover:border-[#b5bbc0]"
        }`}
      >
        {on && <Check className="h-3.5 w-3.5 text-[var(--ck-on-accent)]" strokeWidth={3.2} />}
      </span>
      <span className="min-w-0 truncate text-[13px] text-[var(--ck-text)]">{w.label}</span>
    </button>
  );
}

function CSwitch({ w, value, set }: WidgetProps) {
  const on = value === true;
  return (
    <button type="button" role="switch" aria-checked={on} onClick={() => set(!on)} className={`group flex min-h-[28px] min-w-0 items-center gap-2.5 rounded-md text-left ${focusCls}`}>
      <span className={`relative h-[18px] w-[36px] shrink-0 rounded-full transition-colors ${on ? "bg-[var(--ck-accent)]" : "bg-[var(--ck-track)] group-hover:bg-[#5a5d60]"}`}>
        <span
          className="absolute top-[1px] h-4 w-4 rounded-full bg-[#d5d9de] shadow-[0_1px_2px_rgba(0,0,0,0.35)] transition-transform duration-200"
          style={{ transform: `translateX(${on ? 19 : 1}px)` }}
        />
      </span>
      <span className="min-w-0 truncate text-[13px] text-[var(--ck-text)]">{w.label}</span>
    </button>
  );
}

function CSlider({ w, value, set }: WidgetProps) {
  const min = w.min ?? 0;
  const max = w.max ?? 100;
  const v = typeof value === "number" ? value : min;
  const integer = sliderIsInteger(w.format, min, max, typeof w.value === "number" ? w.value : min);
  const t = max > min ? (v - min) / (max - min) : 0;
  const text = formatNumber(w.format, v, integer);
  const ctl = useSliderControl({ value: v, min, max, integer, inset: 9, onChange: set });
  return (
    <div className="min-w-0">
      <FieldLabel text={w.label} right={<span className="shrink-0 text-[12.5px] tabular-nums text-[var(--ck-text)]">{text}</span>} />
      <div
        role="slider"
        tabIndex={0}
        aria-label={w.label ?? "Slider"}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-valuenow={Number(v.toFixed(4))}
        aria-valuetext={text}
        {...ctl}
        className={`group relative h-[22px] cursor-pointer touch-none select-none rounded-full ${focusCls}`}
      >
        <span className="absolute inset-x-[2px] top-1/2 h-[6px] -translate-y-1/2 rounded-full bg-[var(--ck-track)]" />
        <span className="absolute left-[2px] top-1/2 h-[6px] -translate-y-1/2 rounded-full bg-[var(--ck-accent)]" style={{ width: `calc((100% - 18px) * ${t} + 7px)` }} />
        <span
          className="absolute top-1/2 h-[18px] w-[18px] -translate-y-1/2 rounded-full bg-[var(--ck-accent)] shadow-[0_1px_3px_rgba(0,0,0,0.4)] transition-colors group-hover:bg-[var(--ck-accent-h)]"
          style={{ left: `calc((100% - 18px) * ${t})` }}
        />
      </div>
    </div>
  );
}

function CButton({ w, inRow, toast }: WidgetProps) {
  const label = w.label ?? "Button";
  return (
    <button
      type="button"
      onClick={() => toast(`${label} clicked`)}
      className={`h-[32px] truncate rounded-[6px] bg-[var(--ck-accent)] px-4 text-[13px] font-medium text-[var(--ck-on-accent)] transition-colors hover:bg-[var(--ck-accent-h)] active:translate-y-px ${focusCls} ${
        inRow ? "w-full" : "min-w-[140px] max-w-full"
      }`}
    >
      {label}
    </button>
  );
}

function COptionMenu({ w, id, value, set, openPopup, popupId }: WidgetProps) {
  const options = w.options ?? [];
  const current = typeof value === "string" ? value : (options[0] ?? "");
  const open = popupId === id;
  const ref = useRef<HTMLButtonElement>(null);
  const req = (): PopupRequest | null => (ref.current ? { id, anchor: ref.current, options, value: current, onSelect: set, rowHeight: 30, gap: 4 } : null);
  return (
    <div className="min-w-0">
      <FieldLabel text={w.label} />
      <button
        ref={ref}
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={`${w.label ?? "Option"}: ${current}`}
        onClick={() => {
          const r = req();
          if (r) openPopup(r);
        }}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown" || e.key === "ArrowUp") {
            e.preventDefault();
            const r = req();
            if (r) openPopup(r);
          }
        }}
        className={`group flex h-[32px] w-full min-w-0 items-center overflow-hidden rounded-[6px] bg-[var(--ck-accent)] text-left text-[13px] text-[var(--ck-on-accent)] ${focusCls}`}
      >
        <span className="min-w-0 flex-1 truncate px-3 transition-colors group-hover:bg-[var(--ck-accent-h)]">
          <span className="block truncate leading-[32px]">{current}</span>
        </span>
        <span className="grid h-full w-8 shrink-0 place-items-center bg-[var(--ck-accent-h)]">
          <svg viewBox="0 0 10 10" className={`h-2.5 w-2.5 transition-transform ${open ? "rotate-180" : ""}`} aria-hidden="true">
            <path d="M1.5 3.2h7L5 7.4z" fill="currentColor" />
          </svg>
        </span>
      </button>
    </div>
  );
}

function CRadio({ w, value, set }: WidgetProps) {
  const options = w.options ?? [];
  const current = typeof value === "string" ? value : options[0];
  const onKey = (e: React.KeyboardEvent, i: number) => {
    let next = -1;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (i + 1) % options.length;
    if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (i + options.length - 1) % options.length;
    if (next < 0) return;
    e.preventDefault();
    set(options[next]);
    (e.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>("[role=radio]")[next])?.focus();
  };
  return (
    <div className="min-w-0">
      <FieldLabel text={w.label} />
      <div role="radiogroup" aria-label={w.label ?? "Options"} className="flex flex-wrap gap-x-4 gap-y-2">
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
              className={`group flex min-h-[28px] items-center gap-2 rounded-md ${focusCls}`}
            >
              <span
                className={`h-[22px] w-[22px] shrink-0 rounded-full transition-all ${
                  on ? "border-[6px] border-[var(--ck-accent)] group-hover:border-[var(--ck-accent-h)]" : "border-[3px] border-[var(--ck-check-border)] group-hover:border-[#b5bbc0]"
                }`}
              />
              <span className="text-[13px] text-[var(--ck-text)]">{o}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function CEntry({ w, value, set }: WidgetProps) {
  return (
    <label className="block min-w-0">
      <FieldLabel text={w.label} />
      <input
        type="text"
        value={typeof value === "string" ? value : ""}
        placeholder={w.placeholder}
        onChange={(e) => set(e.target.value)}
        spellCheck={false}
        className="h-[32px] w-full min-w-0 rounded-[6px] border-2 border-[var(--ck-border)] bg-[var(--ck-entry)] px-2.5 text-[13px] text-[var(--ck-text)] caret-[var(--ck-accent)] outline-none transition-colors placeholder:text-[#8e9297] focus:border-[var(--ck-accent)]"
      />
    </label>
  );
}

function CColor({ w, value, set }: WidgetProps) {
  const hex = typeof value === "string" && /^#[\da-f]{6}$/i.test(value) ? value : "#1f6aa5";
  const [draft, setDraft] = useState<string | null>(null);
  const label = w.label ?? "Color";
  return (
    <div className="min-w-0">
      <FieldLabel text={label} />
      <div className="flex items-center gap-2">
        <label className="relative h-[32px] w-[40px] shrink-0 cursor-pointer rounded-[6px] border-2 border-[var(--ck-border)] focus-within:border-[var(--ck-accent)]" style={{ background: hex }}>
          <input type="color" value={hex} onChange={(e) => set(e.target.value.toLowerCase())} aria-label={`${label}: pick color`} className="absolute inset-0 h-full w-full cursor-pointer opacity-0" />
        </label>
        <input
          type="text"
          value={draft ?? hex}
          onChange={(e) => {
            setDraft(e.target.value);
            if (/^#[\da-f]{6}$/i.test(e.target.value.trim())) set(e.target.value.trim().toLowerCase());
          }}
          onBlur={() => setDraft(null)}
          aria-label={`${label}: hex value`}
          spellCheck={false}
          className="h-[32px] w-full min-w-0 rounded-[6px] border-2 border-[var(--ck-border)] bg-[var(--ck-entry)] px-2.5 font-mono text-[12.5px] uppercase text-[var(--ck-text)] outline-none focus:border-[var(--ck-accent)]"
        />
      </div>
    </div>
  );
}

function CProgress({ w, value }: WidgetProps) {
  const v = typeof value === "number" ? Math.max(0, Math.min(1, value)) : 0;
  const pct = Math.round(v * 100);
  return (
    <div className="min-w-0">
      <FieldLabel text={w.label ?? "Progress"} right={<span className="shrink-0 text-[12.5px] tabular-nums text-[var(--ck-text)]">{pct}%</span>} />
      <div role="progressbar" aria-label={w.label ?? "Progress"} aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} className="h-2 overflow-hidden rounded-full bg-[var(--ck-track)]">
        <div className="h-full rounded-full bg-[var(--ck-accent)] transition-[width] duration-300" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function Card({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`min-w-0 rounded-[8px] bg-[var(--ck-frame-2)] p-3 ${className}`}>{children}</div>;
}

function CRadar({ w }: WidgetProps) {
  const blips = w.blips ?? [];
  const range = typeof w.value === "string" ? w.value : null;
  const counts = { enemy: 0, ally: 0, objective: 0 };
  blips.forEach((b) => (counts[b.kind ?? "enemy"] += 1));
  return (
    <Card>
      <div className="mb-2 flex items-baseline justify-between gap-2">
        <span className="truncate text-[13px] font-medium text-[var(--ck-text)]">{w.label ?? "Radar"}</span>
        {range && <span className="shrink-0 text-[12px] text-[var(--ck-muted)]">{range}</span>}
      </div>
      <div className="flex items-center gap-4">
        <div className="relative aspect-square w-full max-w-[170px] shrink-0" role="img" aria-label={`${w.label ?? "Radar"}: ${blips.length} contacts`}>
          <svg viewBox="-100 -100 200 200" className="absolute inset-0 h-full w-full" aria-hidden="true">
            <circle r="94" fill="#2b2b2b" />
            {[94, 64, 34].map((r) => (
              <circle key={r} r={r} fill="none" stroke="#4a4d50" strokeWidth="1.5" />
            ))}
            <line x1="-94" y1="0" x2="94" y2="0" stroke="#4a4d50" strokeWidth="1.5" />
            <line x1="0" y1="-94" x2="0" y2="94" stroke="#4a4d50" strokeWidth="1.5" />
          </svg>
          <div
            className="absolute inset-[3%] animate-spin rounded-full"
            style={{ animationDuration: "4s", background: "conic-gradient(from 0deg, transparent 0deg, transparent 300deg, color-mix(in srgb, var(--ck-accent) 40%, transparent) 360deg)" }}
            aria-hidden="true"
          />
          <svg viewBox="-100 -100 200 200" className="absolute inset-0 h-full w-full" aria-hidden="true">
            {blips.map((b, i) => (
              <circle key={i} cx={b.x * 88} cy={b.y * 88} r="6" fill={BLIP_COLORS[b.kind ?? "enemy"]} stroke="#2b2b2b" strokeWidth="2" />
            ))}
            <circle r="5" fill="#dce4ee" />
          </svg>
        </div>
        <ul className="hidden min-w-0 flex-col gap-1.5 text-[12.5px] text-[var(--ck-muted)] min-[340px]:flex">
          {(["enemy", "ally", "objective"] as const).map((k) =>
            counts[k] ? (
              <li key={k} className="flex items-center gap-2">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: BLIP_COLORS[k] }} />
                <span className="capitalize">{k === "enemy" ? "Enemies" : k === "ally" ? "Allies" : "Objectives"}</span>
                <span className="tabular-nums text-[var(--ck-text)]">{counts[k]}</span>
              </li>
            ) : null,
          )}
        </ul>
      </div>
    </Card>
  );
}

function CPlot({ w }: WidgetProps) {
  const uid = useId().replace(/:/g, "");
  const pts = w.points && w.points.length > 1 ? w.points : [0, 0];
  const lo = w.min ?? Math.min(...pts);
  const hi = w.max ?? Math.max(...pts);
  const span = hi - lo || 1;
  const [hover, setHover] = useState<number | null>(null);
  const W = 300;
  const H = 110;
  const pad = 6;
  const coords = pts.map((p, i) => [(i / (pts.length - 1)) * W, pad + (1 - (p - lo) / span) * (H - pad * 2)] as const);
  const line = coords.map(([x, y], i) => `${i ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)}`).join(" ");
  const area = `${line} L${W} ${H} L0 ${H} Z`;
  const shown = hover ?? pts.length - 1;
  const fmt = (n: number) => (Math.abs(n) >= 100 || Number.isInteger(n) ? Math.round(n).toLocaleString("en-US") : n.toFixed(2));
  return (
    <Card>
      <div className="mb-2 flex items-baseline justify-between gap-2">
        <span className="truncate text-[13px] font-medium text-[var(--ck-text)]">{w.label ?? "Chart"}</span>
        <span className="shrink-0 text-[12.5px] tabular-nums text-[var(--ck-muted)]">
          {hover !== null ? `#${hover + 1} · ` : "Latest · "}
          <span className="text-[var(--ck-text)]">{fmt(pts[shown])}</span>
        </span>
      </div>
      <div className="flex gap-2">
        <div className="flex shrink-0 flex-col justify-between py-0.5 text-right text-[11px] tabular-nums text-[var(--ck-muted)]" aria-hidden="true">
          <span>{fmt(hi)}</span>
          <span>{fmt(lo)}</span>
        </div>
        <div
          className="relative h-[110px] min-w-0 flex-1"
          onPointerMove={(e) => {
            const r = e.currentTarget.getBoundingClientRect();
            setHover(Math.max(0, Math.min(pts.length - 1, Math.round(((e.clientX - r.left) / r.width) * (pts.length - 1)))));
          }}
          onPointerLeave={() => setHover(null)}
          role="img"
          aria-label={`${w.label ?? "Chart"}: ${pts.length} points, latest ${fmt(pts[pts.length - 1])}`}
        >
          <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" className="absolute inset-0 h-full w-full overflow-visible" aria-hidden="true">
            <defs>
              <linearGradient id={`${uid}-area`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor="var(--ck-accent)" stopOpacity="0.38" />
                <stop offset="1" stopColor="var(--ck-accent)" stopOpacity="0" />
              </linearGradient>
            </defs>
            {[0, 1, 2, 3].map((i) => (
              <line key={i} x1="0" x2={W} y1={pad + (i * (H - pad * 2)) / 3} y2={pad + (i * (H - pad * 2)) / 3} stroke="#4a4d50" strokeOpacity="0.55" strokeDasharray="3 4" vectorEffect="non-scaling-stroke" />
            ))}
            <path d={area} fill={`url(#${uid}-area)`} />
            <path d={line} fill="none" stroke="var(--ck-accent)" strokeWidth="2.2" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
            {hover !== null && <line x1={coords[hover][0]} x2={coords[hover][0]} y1="0" y2={H} stroke="#dce4ee" strokeOpacity="0.35" vectorEffect="non-scaling-stroke" />}
          </svg>
          <span
            className="pointer-events-none absolute h-2.5 w-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-[var(--ck-frame-2)] bg-[var(--ck-accent)]"
            style={{ left: `${(coords[shown][0] / W) * 100}%`, top: `${(coords[shown][1] / H) * 100}%` }}
          />
        </div>
      </div>
    </Card>
  );
}

function CStat({ w }: WidgetProps) {
  const value = typeof w.value === "number" ? w.value.toLocaleString("en-US") : String(w.value ?? "—");
  const d = w.delta?.trim();
  const down = !!d && (d.startsWith("-") || d.startsWith("−"));
  const up = !!d && d.startsWith("+");
  return (
    <Card className="h-full [container-type:inline-size]">
      <div className="truncate text-[12px] text-[var(--ck-muted)]">{w.label ?? "Metric"}</div>
      {/* Long values shrink with the card (cqw) before wrapping; 22px stays the cap and the fallback. */}
      <div
        className="mt-1 line-clamp-2 break-words text-[22px] font-semibold leading-tight tracking-tight tabular-nums text-white"
        style={{ fontSize: `clamp(14px, ${(170 / Math.max(value.length, 1)).toFixed(1)}cqw, 22px)` }}
      >
        {value}
      </div>
      {d && (
        <span
          className="mt-1.5 inline-flex rounded-full px-2 py-0.5 text-[11px] font-medium tabular-nums"
          style={{
            color: down ? "#ff8a9e" : up ? "#5ee39a" : "var(--ck-muted)",
            background: down ? "rgba(255,92,122,0.14)" : up ? "rgba(46,204,113,0.14)" : "rgba(255,255,255,0.06)",
          }}
        >
          {d}
        </span>
      )}
    </Card>
  );
}

const WIDGETS: Record<GuiWidget["type"], (p: WidgetProps) => React.JSX.Element | null> = {
  text: CText,
  separator: CSeparator,
  checkbox: CCheckbox,
  toggle: CSwitch,
  slider: CSlider,
  button: CButton,
  combo: COptionMenu,
  radio: CRadio,
  input: CEntry,
  color: CColor,
  progress: CProgress,
  radar: CRadar,
  plot: CPlot,
  stat: CStat,
};

// ---------------------------------------------------------------------------
// Option menu dropdown
// ---------------------------------------------------------------------------

function CtkPopupList({ popup, onClose }: { popup: PopupPlacement; onClose: () => void }) {
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
    <motion.div
      ref={listRef}
      role="listbox"
      tabIndex={-1}
      aria-activedescendant={`${popup.id}-opt-${active}`}
      onKeyDown={onKeyDown}
      initial={{ opacity: 0, y: -4 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.12 }}
      className="absolute z-40 overflow-y-auto rounded-[6px] border border-white/[0.08] bg-[#2b2b2b] p-1 font-sans text-[13px] shadow-[0_14px_36px_rgba(0,0,0,0.6)] outline-none scrollbar-thin"
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
            className={`flex h-[30px] cursor-pointer items-center justify-between gap-2 rounded-[4px] px-2.5 text-[var(--ck-text)] ${i === active ? "bg-white/[0.09]" : ""}`}
          >
            <span className="truncate">{o}</span>
            {selected && <Check className="h-3.5 w-3.5 shrink-0 text-[var(--ck-accent)]" strokeWidth={2.4} />}
          </div>
        );
      })}
    </motion.div>
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

const CARD_TYPES = new Set<GuiWidget["type"]>(["stat", "plot", "radar"]);

function CtkWindow({ spec, stage, stageRef }: { spec: GuiSpec; stage: { width: number; height: number }; stageRef: React.RefObject<HTMLDivElement | null> }) {
  const reduce = useReducedMotion();
  const uid = useId().replace(/:/g, "");
  const accent = spec.accent ?? DEFAULT_ACCENT;
  const vars = useMemo(() => themeVars(accent), [accent]);
  const [tab, setTab] = useState(0);
  const [minimized, setMinimized] = useState(false);
  const [maximized, setMaximized] = useState(false);
  const [closed, setClosed] = useState(false);
  const [values, setValues] = useState(() => initValues(spec));
  const [popup, setPopup] = useState<PopupPlacement | null>(null);
  const { toast, show } = useToast();
  const closeRef = useRef<HTMLButtonElement>(null);
  const reopenRef = useRef<HTMLButtonElement>(null);
  const refocus = useRef(false);

  // Close and Reopen unmount themselves: hand keyboard focus to the other one.
  useEffect(() => {
    if (!refocus.current) return;
    refocus.current = false;
    (closed ? reopenRef : closeRef).current?.focus();
  }, [closed]);

  const width = maximized ? stage.width - 16 : Math.round(Math.max(240, Math.min(spec.width ?? 480, stage.width - 24)));
  const maxH = maximized ? stage.height - 16 : Math.max(160, Math.min(spec.height ?? Infinity, stage.height - 24));
  const showTabs = spec.tabs.length > 1 || spec.tabs[0]?.label !== "Main";
  const current = spec.tabs[Math.min(tab, spec.tabs.length - 1)];
  const rows = useMemo(() => groupRows(current?.widgets ?? []), [current]);

  const openPopup = useCallback(
    (req: PopupRequest) => {
      const el = stageRef.current;
      if (!el) return;
      setPopup((p) => (p && p.id === req.id ? null : placePopup(req, el)));
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
    e.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>("[role=tab]")[next]?.focus();
  };

  const chromeBtn =
    "relative grid h-8 w-10 shrink-0 place-items-center text-[#c9ced4] outline-none transition-colors hover:bg-white/[0.08] focus-visible:bg-white/[0.12]";

  return (
    <div style={vars} className="absolute inset-0 z-20 flex items-center justify-center">
      <AnimatePresence>
        {!closed && (
          <motion.div
            key="win"
            role="group"
            aria-label={`${spec.title} (simulated CustomTkinter window)`}
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 10, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, scale: 0.97 }}
            transition={{ type: "spring", stiffness: 380, damping: 30 }}
            className="relative flex flex-col overflow-hidden rounded-[10px] font-sans"
            style={{
              width,
              maxHeight: maxH,
              background: "var(--ck-bg)",
              boxShadow: `0 0 0 1px rgba(255,255,255,0.07), 0 30px 70px -20px rgba(0,0,0,0.9), 0 0 80px -30px ${rgba(accent, 0.55)}`,
            }}
          >
            {/* OS title bar */}
            <div className="flex h-8 shrink-0 select-none items-center bg-[#1c1c1c] pl-3" onDoubleClick={() => setMaximized((m) => !m)}>
              <svg viewBox="0 0 16 16" className="mr-2 h-4 w-4 shrink-0" aria-hidden="true">
                <rect x="1" y="1" width="14" height="14" rx="3.5" fill={accent} />
                <path d="M5 11.5c1.5-4 3.6-6.2 6.5-7-1.2 1.6-2 3.3-2.4 5.3" stroke={readableOn(accent)} strokeWidth="1.4" fill="none" strokeLinecap="round" />
              </svg>
              <span className="min-w-0 flex-1 truncate text-[12.5px] text-[#dce4ee]">{spec.title}</span>
              <button type="button" aria-label={minimized ? "Restore window" : "Minimize window"} onClick={() => setMinimized((m) => !m)} className={chromeBtn}>
                <svg viewBox="0 0 10 10" className="h-2.5 w-2.5" aria-hidden="true">
                  <path d="M0.5 5h9" stroke="currentColor" strokeWidth="1" />
                </svg>
              </button>
              <button type="button" aria-label={maximized ? "Restore size" : "Maximize window"} onClick={() => setMaximized((m) => !m)} className={chromeBtn}>
                <svg viewBox="0 0 10 10" className="h-2.5 w-2.5" aria-hidden="true">
                  {maximized ? (
                    <>
                      <rect x="0.5" y="2.5" width="7" height="7" rx="1" fill="none" stroke="currentColor" strokeWidth="1" />
                      <path d="M2.5 2.5V1.5a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-1" fill="none" stroke="currentColor" strokeWidth="1" />
                    </>
                  ) : (
                    <rect x="0.5" y="0.5" width="9" height="9" rx="1" fill="none" stroke="currentColor" strokeWidth="1" />
                  )}
                </svg>
              </button>
              <button
                ref={closeRef}
                type="button"
                aria-label="Close window"
                onClick={(e) => {
                  refocus.current = document.activeElement === e.currentTarget;
                  setClosed(true);
                  setPopup(null);
                }}
                className={`${chromeBtn} hover:!bg-[#c42b1c] hover:text-white`}
              >
                <svg viewBox="0 0 10 10" className="h-2.5 w-2.5" aria-hidden="true">
                  <path d="M0.8 0.8l8.4 8.4M9.2 0.8l-8.4 8.4" stroke="currentColor" strokeWidth="1" />
                </svg>
              </button>
            </div>

            {!minimized && (
              <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain p-3 scrollbar-thin sm:p-4" onScroll={() => popup && setPopup(null)}>
                {showTabs && (
                  <div className="relative z-[1] -mb-[15px] flex justify-center">
                    <div role="tablist" aria-label={`${spec.title} tabs`} className="flex max-w-full overflow-x-auto rounded-[7px] bg-[var(--ck-track)] p-[2px] scrollbar-none">
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
                            className={`h-[26px] shrink-0 whitespace-nowrap rounded-[6px] px-3 text-[13px] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-white/70 ${
                              active ? "bg-[var(--ck-accent)] text-[var(--ck-on-accent)] hover:bg-[var(--ck-accent-h)]" : "text-[var(--ck-text)] hover:bg-[#5c5f62]"
                            }`}
                          >
                            {t.label}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
                <div
                  id={`${uid}-panel`}
                  role={showTabs ? "tabpanel" : undefined}
                  aria-labelledby={showTabs ? `${uid}-tab-${tab}` : undefined}
                  className={`flex flex-col gap-3 rounded-[8px] bg-[var(--ck-frame)] px-3 pb-3.5 sm:px-4 ${showTabs ? "pt-7" : "pt-3.5"}`}
                >
                  {rows.length === 0 && <p className="text-[13px] text-[var(--ck-muted)]">This tab is empty.</p>}
                  {rows.map((row, ri) => {
                    const multi = row.items.length > 1;
                    const allCards = row.items.every(({ w }) => CARD_TYPES.has(w.type));
                    return (
                      <div
                        key={ri}
                        className={multi ? (allCards ? "grid min-w-0 gap-2.5" : "flex min-w-0 flex-wrap items-end gap-x-3 gap-y-2") : "min-w-0"}
                        style={multi && allCards ? { gridTemplateColumns: `repeat(${Math.min(row.items.length, width < 380 ? 2 : 4)}, minmax(0, 1fr))` } : undefined}
                      >
                        {row.items.map(({ w, index }) => {
                          // Spec types are untrusted: render own WIDGETS keys only ("constructor" must not resolve to Object).
                          const Comp = Object.prototype.hasOwnProperty.call(WIDGETS, w.type) ? WIDGETS[w.type] : null;
                          if (!Comp) return null;
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
                          if (!multi || allCards) return <Comp key={index} {...props} />;
                          return (
                            <div key={index} className="min-w-[120px] flex-1">
                              <Comp {...props} />
                            </div>
                          );
                        })}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {popup && <CtkPopupList popup={popup} onClose={closePopup} />}

      <AnimatePresence>
        {closed && (
          <motion.button
            key="reopen"
            ref={reopenRef}
            type="button"
            onClick={(e) => {
              refocus.current = document.activeElement === e.currentTarget;
              setClosed(false);
              setMinimized(false);
            }}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="focus-ring absolute left-1/2 top-1/2 inline-flex h-11 -translate-x-1/2 -translate-y-1/2 items-center gap-2 rounded-full border border-white/15 bg-obsidian-900/80 px-4 text-[13px] font-medium text-fox-white shadow-glass backdrop-blur-md transition hover:border-white/25"
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
            className="pointer-events-none absolute bottom-3 left-1/2 z-50 max-w-[calc(100%-24px)] -translate-x-1/2 truncate rounded-[6px] border border-white/[0.08] bg-[#2b2b2b] px-3 py-1.5 text-[12px] text-[#dce4ee] shadow-[0_8px_24px_rgba(0,0,0,0.6)]"
          >
            {toast.text}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Stage + empty states
// ---------------------------------------------------------------------------

function DeskStage({ accent }: { accent: string }) {
  return (
    <div className="absolute inset-0" aria-hidden="true">
      <div
        className="absolute inset-0"
        style={{
          background: `radial-gradient(70% 55% at 50% -5%, ${rgba("#c4b5fd", 0.16)}, transparent 70%), radial-gradient(60% 45% at 50% 108%, ${rgba(accent, 0.14)}, transparent 70%), linear-gradient(180deg, #0c0b13 0%, #07070c 70%, #050508 100%)`,
        }}
      />
      <div className="absolute inset-0 opacity-60 [background-image:radial-gradient(rgba(255,255,255,0.06)_1px,transparent_1px)] [background-size:22px_22px] [mask-image:radial-gradient(80%_70%_at_50%_40%,black,transparent)]" />
      {/* Desk surface */}
      <div className="absolute inset-x-0 bottom-0 h-[26%] bg-gradient-to-b from-[#0f0e17] to-[#060609]">
        <div className="h-px w-full bg-gradient-to-r from-transparent via-white/[0.12] to-transparent" />
      </div>
      <div className="absolute bottom-[14%] left-1/2 h-10 w-[70%] -translate-x-1/2 rounded-[50%] bg-black/60 blur-2xl" />
    </div>
  );
}

function SkeletonWindow({ stage }: { stage: { width: number; height: number } }) {
  const width = Math.min(440, stage.width - 24);
  const bar = "rounded-[6px] bg-[linear-gradient(110deg,#2f2f2f_20%,#3d3d44_40%,#2f2f2f_60%)] bg-[length:200%_100%] animate-spirit-pan";
  const style = { animationDuration: "1.6s" };
  return (
    <div className="absolute inset-0 z-20 grid place-items-center p-3">
      <div className="overflow-hidden rounded-[10px] bg-[#242424] shadow-[0_0_0_1px_rgba(255,255,255,0.07),0_30px_70px_-20px_rgba(0,0,0,0.9)]" style={{ width }} role="status" aria-label="Summoning preview">
        <div className="flex h-8 items-center gap-2 bg-[#1c1c1c] px-3 text-[12.5px] text-[#dce4ee]">
          <span className="h-4 w-4 rounded-[4px] bg-[#1f6aa5]" />
          Summoning preview…
        </div>
        <div className="p-4">
          <div className="mx-auto -mb-3 flex w-max gap-1 rounded-[7px] bg-[#4a4d50] p-[2px]">
            {[64, 56, 60].map((w, i) => (
              <div key={i} className={`h-[26px] ${bar}`} style={{ ...style, width: w }} />
            ))}
          </div>
          <div className="flex flex-col gap-3 rounded-[8px] bg-[#2b2b2b] p-4 pt-7">
            <div className="grid grid-cols-2 gap-2.5">
              <div className={`h-16 ${bar}`} style={style} />
              <div className={`h-16 ${bar}`} style={style} />
            </div>
            <div className={`h-24 ${bar}`} style={style} />
            <div className={`h-3 w-2/3 ${bar}`} style={style} />
            <div className={`h-3 w-1/2 ${bar}`} style={style} />
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Public component
// ---------------------------------------------------------------------------

export function CtkSimulator({ spec, streaming = false, className = "" }: CtkSimulatorProps) {
  const [sizeRef, stage] = useElementSize<HTMLDivElement>();
  const stageRef = useRef<HTMLDivElement>(null);
  const setStage = useCallback(
    (node: HTMLDivElement | null) => {
      stageRef.current = node;
      sizeRef(node);
    },
    [sizeRef],
  );
  const specKey = useMemo(() => (spec ? JSON.stringify(spec) : ""), [spec]);
  const accent = spec?.accent ?? DEFAULT_ACCENT;
  const ready = stage.width > 0 && stage.height > 0;
  return (
    <div ref={setStage} className={`relative h-full w-full overflow-hidden bg-[#07070c] ${className}`}>
      <DeskStage accent={accent} />
      {ready && spec && <CtkWindow key={specKey} spec={spec} stage={stage} stageRef={stageRef} />}
      {ready && !spec && (streaming ? <SkeletonWindow stage={stage} /> : <NoPreviewNote />)}
    </div>
  );
}

export default CtkSimulator;
