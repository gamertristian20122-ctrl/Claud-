"use client";

// Small helpers shared by the right-panel components (OutputPanel, WebPreview,
// ImGuiSimulator, CtkSimulator, CodeView). Not part of any cross-agent contract.

import { useReducedMotion } from "framer-motion";
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

export const useIsoLayoutEffect = typeof window !== "undefined" ? useLayoutEffect : useEffect;

export interface Size {
  width: number;
  height: number;
}

/** Tracks an element's content-box size with a ResizeObserver. 0×0 until mounted. */
export function useElementSize<T extends HTMLElement = HTMLDivElement>() {
  const [el, setEl] = useState<T | null>(null);
  const [size, setSize] = useState<Size>({ width: 0, height: 0 });
  const ref = useCallback((node: T | null) => setEl(node), []);

  useIsoLayoutEffect(() => {
    if (!el) return;
    const measure = () => {
      const r = el.getBoundingClientRect();
      setSize((s) => (Math.abs(s.width - r.width) < 0.5 && Math.abs(s.height - r.height) < 0.5 ? s : { width: r.width, height: r.height }));
    };
    measure();
    if (typeof ResizeObserver === "undefined") {
      window.addEventListener("resize", measure);
      return () => window.removeEventListener("resize", measure);
    }
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [el]);

  return [ref, size, el] as const;
}

/**
 * True once mounted on the client and the visitor allows motion. Looping
 * animations key off this so server and first client render always match.
 */
export function useLoopMotion(): boolean {
  const reduce = useReducedMotion();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  return mounted && !reduce;
}

// ---------------------------------------------------------------------------
// Color math
// ---------------------------------------------------------------------------

export function hexToRgb(hex: string): [number, number, number] {
  const m = /^#?([\da-f]{6})$/i.exec(hex.trim());
  if (!m) return [167, 139, 250];
  const n = Number.parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgbToHex(r: number, g: number, b: number): string {
  const c = (v: number) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0");
  return `#${c(r)}${c(g)}${c(b)}`;
}

export function rgba(hex: string, alpha: number): string {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/** Linear mix: t = 0 gives `a`, t = 1 gives `b`. */
export function mix(a: string, b: string, t: number): string {
  const [r1, g1, b1] = hexToRgb(a);
  const [r2, g2, b2] = hexToRgb(b);
  return rgbToHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t);
}

/** Relative luminance (0..1). */
export function luminance(hex: string): number {
  const [r, g, b] = hexToRgb(hex).map((v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** Black or white text, whichever reads better on `bg`. */
export function readableOn(bg: string): string {
  return luminance(bg) > 0.45 ? "#111118" : "#ffffff";
}

// ---------------------------------------------------------------------------
// printf-style number formatting (ImGui slider formats such as "%.1f", "%d px", "%.0f%%")
// ---------------------------------------------------------------------------

const FORMAT_RE = /%%|%([-+ 0#]*)(\d+)?(?:\.(\d+))?(l{0,2})([dfiuegEG])?/g;

export function formatIsInteger(format: string | undefined): boolean {
  return !!format && /%[-+ 0#]*\d*l{0,2}[diu]/.test(format);
}

export function formatNumber(format: string | undefined, value: number, integer = false): string {
  const fmt = format && format.includes("%") ? format : integer ? "%d" : "%.3f";
  let used = false;
  const out = fmt.replace(FORMAT_RE, (all, flags: string = "", width: string | undefined, prec: string | undefined, _l: string, conv: string | undefined) => {
    if (all === "%%") return "%";
    if (!conv || used) return all.replace(/%/, "");
    used = true;
    let s: string;
    if (conv === "d" || conv === "i" || conv === "u") s = String(Math.round(value));
    else if (conv === "e" || conv === "E") s = value.toExponential(prec !== undefined ? Math.min(Number(prec), 10) : 6);
    else if (conv === "g" || conv === "G") s = String(Number(value.toPrecision(prec ? Math.max(1, Math.min(Number(prec), 12)) : 6)));
    else s = value.toFixed(prec !== undefined ? Math.min(Number(prec), 10) : 6);
    if (flags.includes("+") && value >= 0) s = `+${s}`;
    if (width && s.length < Number(width)) s = s.padStart(Number(width), flags.includes("0") ? "0" : " ");
    return s;
  });
  return out.trim() || String(value);
}

// ---------------------------------------------------------------------------
// Clipboard
// ---------------------------------------------------------------------------

export async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // Fall through to the legacy path.
  }
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.top = "-1000px";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

/** Copy with a 1.5 s "Copied" confirmation. */
export function useCopy(timeout = 1500) {
  const [copied, setCopied] = useState(false);
  const timer = useRef<number | undefined>(undefined);
  useEffect(() => () => window.clearTimeout(timer.current), []);
  const copy = useCallback(
    async (text: string) => {
      const ok = await copyText(text);
      if (!ok) return false;
      setCopied(true);
      window.clearTimeout(timer.current);
      timer.current = window.setTimeout(() => setCopied(false), timeout);
      return true;
    },
    [timeout],
  );
  return { copied, copy };
}

// ---------------------------------------------------------------------------
// Anchored popup list (combo / option menu dropdowns inside the simulators)
// ---------------------------------------------------------------------------

export interface PopupRequest {
  id: string;
  anchor: HTMLElement;
  options: string[];
  value: string;
  onSelect: (value: string) => void;
  /** Row height in px, used to size the list. */
  rowHeight: number;
  /** Extra gap between anchor and list. */
  gap?: number;
  minWidth?: number;
}

export interface PopupPlacement extends PopupRequest {
  left: number;
  top: number;
  width: number;
  maxHeight: number;
}

/** Positions a popup list below (or above) an anchor, relative to a stage element. */
export function placePopup(req: PopupRequest, stage: HTMLElement): PopupPlacement {
  const s = stage.getBoundingClientRect();
  const a = req.anchor.getBoundingClientRect();
  const gap = req.gap ?? 2;
  const want = req.options.length * req.rowHeight + 10;
  const below = s.bottom - a.bottom - gap - 8;
  const above = a.top - s.top - gap - 8;
  const width = Math.min(Math.max(a.width, req.minWidth ?? 0), s.width - 16);
  const left = Math.max(8, Math.min(a.left - s.left, s.width - width - 8));
  if (below >= Math.min(want, 120) || below >= above) {
    return { ...req, left, top: a.bottom - s.top + gap, width, maxHeight: Math.max(60, Math.min(want, below)) };
  }
  const h = Math.min(want, above);
  return { ...req, left, top: a.top - s.top - gap - h, width, maxHeight: Math.max(60, h) };
}

/** Keyboard + outside-click handling for a listbox popup. */
export function usePopupList(
  open: boolean,
  count: number,
  initial: number,
  onPick: (i: number) => void,
  onClose: () => void,
  anchor?: HTMLElement | null,
) {
  const [active, setActive] = useState(initial);
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (open) setActive(Math.max(0, initial));
  }, [open, initial]);

  useEffect(() => {
    if (!open) return;
    const t = window.setTimeout(() => listRef.current?.focus(), 0);
    const onDown = (e: PointerEvent) => {
      const target = e.target as Node;
      if (anchor && anchor.contains(target)) return;
      if (listRef.current && !listRef.current.contains(target)) onClose();
    };
    document.addEventListener("pointerdown", onDown, true);
    return () => {
      window.clearTimeout(t);
      document.removeEventListener("pointerdown", onDown, true);
    };
  }, [open, onClose, anchor]);

  useEffect(() => {
    if (!open) return;
    const el = listRef.current?.querySelector<HTMLElement>(`[data-index="${active}"]`);
    el?.scrollIntoView({ block: "nearest" });
  }, [active, open]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((a) => Math.min(count - 1, a + 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((a) => Math.max(0, a - 1));
    } else if (e.key === "Home") {
      e.preventDefault();
      setActive(0);
    } else if (e.key === "End") {
      e.preventDefault();
      setActive(count - 1);
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      onPick(active);
    } else if (e.key === "Escape" || e.key === "Tab") {
      e.preventDefault();
      onClose();
    }
  };

  return { active, setActive, listRef, onKeyDown };
}

// ---------------------------------------------------------------------------
// Slider drag helper
// ---------------------------------------------------------------------------

/**
 * Pointer + keyboard handlers for a horizontal slider.
 * `inset` is the distance in px from each end of the track where the value is min/max.
 */
export function useSliderControl(opts: {
  value: number;
  min: number;
  max: number;
  integer: boolean;
  inset: number;
  onChange: (v: number) => void;
}) {
  const { value, min, max, integer, inset, onChange } = opts;
  const dragging = useRef(false);

  const fromClientX = (el: HTMLElement, clientX: number) => {
    const r = el.getBoundingClientRect();
    const span = Math.max(1, r.width - inset * 2);
    const t = Math.max(0, Math.min(1, (clientX - r.left - inset) / span));
    let v = min + t * (max - min);
    if (integer) v = Math.round(v);
    return Math.max(min, Math.min(max, v));
  };

  const onPointerDown = (e: React.PointerEvent<HTMLElement>) => {
    if (e.button !== 0) return;
    const el = e.currentTarget;
    dragging.current = true;
    try {
      el.setPointerCapture(e.pointerId);
    } catch {
      // Synthetic events in tests can't capture.
    }
    onChange(fromClientX(el, e.clientX));
  };
  const onPointerMove = (e: React.PointerEvent<HTMLElement>) => {
    if (!dragging.current) return;
    onChange(fromClientX(e.currentTarget, e.clientX));
  };
  const onPointerUp = (e: React.PointerEvent<HTMLElement>) => {
    dragging.current = false;
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      // Ignore.
    }
  };
  const onKeyDown = (e: React.KeyboardEvent<HTMLElement>) => {
    const step = integer ? Math.max(1, Math.round((max - min) / 100)) : (max - min) / 100;
    const big = integer ? Math.max(1, Math.round((max - min) / 10)) : (max - min) / 10;
    let next: number | null = null;
    if (e.key === "ArrowRight" || e.key === "ArrowUp") next = value + (e.shiftKey ? big : step);
    else if (e.key === "ArrowLeft" || e.key === "ArrowDown") next = value - (e.shiftKey ? big : step);
    else if (e.key === "PageUp") next = value + big;
    else if (e.key === "PageDown") next = value - big;
    else if (e.key === "Home") next = min;
    else if (e.key === "End") next = max;
    if (next === null) return;
    e.preventDefault();
    if (integer) next = Math.round(next);
    onChange(Math.max(min, Math.min(max, next)));
  };

  return { onPointerDown, onPointerMove, onPointerUp, onPointerCancel: onPointerUp, onKeyDown };
}

// ---------------------------------------------------------------------------
// Widget state shared by both simulators
// ---------------------------------------------------------------------------

export type WidgetValue = number | boolean | string;

/** Rough integer detection for sliders without a format. */
export function sliderIsInteger(format: string | undefined, min: number, max: number, value: number): boolean {
  if (format) return formatIsInteger(format);
  return Number.isInteger(min) && Number.isInteger(max) && Number.isInteger(value) && max - min >= 10;
}

/** Groups widgets into rows, honoring `sameLine`. */
export function groupRows<T extends { sameLine?: boolean }>(widgets: T[]): { items: { w: T; index: number }[] }[] {
  const rows: { items: { w: T; index: number }[] }[] = [];
  widgets.forEach((w, index) => {
    if (w.sameLine && rows.length) rows[rows.length - 1].items.push({ w, index });
    else rows.push({ items: [{ w, index }] });
  });
  return rows;
}

/** A short-lived toast message ("Clicked Save"). */
export function useToast(ms = 1600) {
  const [toast, setToast] = useState<{ id: number; text: string } | null>(null);
  const timer = useRef<number | undefined>(undefined);
  useEffect(() => () => window.clearTimeout(timer.current), []);
  const show = useCallback(
    (text: string) => {
      setToast({ id: Date.now(), text });
      window.clearTimeout(timer.current);
      timer.current = window.setTimeout(() => setToast(null), ms);
    },
    [ms],
  );
  return { toast, show };
}
