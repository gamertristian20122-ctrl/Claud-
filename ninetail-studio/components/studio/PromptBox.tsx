"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { Flame, Infinity as InfinityIcon, LockOpen, Square } from "lucide-react";
import { useCallback, useEffect, useId, useLayoutEffect, useRef, useState, type KeyboardEvent } from "react";
import { FREE_TAILS } from "@/lib/storage";
import type { GenStatus, Target } from "@/lib/types";

export interface PromptBoxProps {
  value: string;
  onChange: (value: string) => void;
  /** Start a build (the parent checks credits). */
  onIgnite: () => void;
  /** Stop a running build. */
  onCancel: () => void;
  status: GenStatus;
  target: Target;
  remaining: number;
  unlimited: boolean;
  /** Bump this number to play an attention pulse on the Ignite button (e.g. after a template loads). */
  pulseKey?: number;
  className?: string;
}

export const PROMPT_MAX = 4000;

const PLACEHOLDERS: Record<Target, string> = {
  web: "A neon pricing page for a VPN startup with a monthly/yearly toggle…",
  imgui: "A dark overlay settings menu with tabs, sliders and a minimap radar…",
  ctk: "A desktop habit tracker with streak cards and a weekly chart…",
};

const LINE = 22; // px, matches leading-[22px]
const PAD_Y = 12 + 6; // pt-3 + pb-1.5
const MIN_H = LINE * 3 + PAD_Y;
const MAX_H = LINE * 8 + PAD_Y;

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;
const FADE_MASK = "linear-gradient(to bottom, #000 calc(100% - 30px), transparent)";

const useIsoLayoutEffect = typeof window !== "undefined" ? useLayoutEffect : useEffect;

/** Prompt input plus the hero "Ignite" button. */
export function PromptBox({
  value,
  onChange,
  onIgnite,
  onCancel,
  status,
  target,
  remaining,
  unlimited,
  pulseKey,
  className = "",
}: PromptBoxProps) {
  const inputId = useId();
  const metaId = useId();
  const reduce = useReducedMotion();
  const ref = useRef<HTMLTextAreaElement>(null);

  const streaming = status === "streaming";
  const empty = value.trim().length === 0;
  const outOfTails = !unlimited && remaining <= 0;
  const canIgnite = !empty && !streaming;
  /** Nothing typed yet: the button waits dark, then "ignites" into the gradient. */
  const dormant = empty && !streaming;

  // ---- auto-grow (3 to 8 rows, then scroll with a soft bottom fade) ----
  const [fade, setFade] = useState(false);
  const updateFade = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    setFade(el.scrollHeight > MAX_H + 1 && el.scrollTop + el.clientHeight < el.scrollHeight - 4);
  }, []);

  const resize = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "auto";
    const full = el.scrollHeight;
    el.style.height = `${Math.min(Math.max(full, MIN_H), MAX_H)}px`;
    el.style.overflowY = full > MAX_H ? "auto" : "hidden";
    updateFade();
  }, [updateFade]);

  useIsoLayoutEffect(() => {
    resize();
  }, [value, resize]);

  useEffect(() => {
    window.addEventListener("resize", resize);
    return () => window.removeEventListener("resize", resize);
  }, [resize]);

  // ---- keyboard hint, client only (avoids a hydration mismatch) ----
  const [hint, setHint] = useState<string | null>(null);
  useEffect(() => {
    try {
      if (!window.matchMedia("(pointer: fine)").matches) return;
      const mac = /Mac|iPhone|iPad|iPod/i.test(navigator.platform || navigator.userAgent);
      setHint(mac ? "⌘ ↵" : "Ctrl ↵");
    } catch {
      // No hint.
    }
  }, []);

  // ---- one-shot attention pulse when pulseKey changes (never on first render) ----
  const firstPulse = useRef(pulseKey);
  const [pulse, setPulse] = useState(0);
  useEffect(() => {
    if (pulseKey === firstPulse.current) return;
    firstPulse.current = pulseKey;
    setPulse((n) => n + 1);
  }, [pulseKey]);

  const ignite = () => {
    if (!canIgnite) return;
    onIgnite();
  };

  const onKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      ignite();
    }
  };

  const count = value.length;
  const nearLimit = count > PROMPT_MAX * 0.9;

  return (
    <div className={className}>
      <div className="mb-3.5 flex items-end justify-between gap-3">
        <div className="min-w-0">
          <p className="eyebrow" aria-hidden="true">
            Prompt
          </p>
          <label htmlFor={inputId} className="mt-1 block text-[15px] font-semibold leading-tight tracking-tight text-fox-white">
            Describe your build
          </label>
        </div>
      </div>

      {/* Input frame */}
      <div className="rounded-2xl border border-white/10 bg-obsidian-950/60 transition-[border-color,box-shadow] duration-200 focus-within:border-spirit-cyan/40 focus-within:shadow-[0_0_0_3px_rgba(103,232,249,.08),0_0_32px_-12px_rgba(103,232,249,.35)]">
        <textarea
          ref={ref}
          id={inputId}
          value={value}
          rows={3}
          maxLength={PROMPT_MAX}
          onChange={(e) => onChange(e.target.value.slice(0, PROMPT_MAX))}
          onKeyDown={onKeyDown}
          onScroll={updateFade}
          placeholder={PLACEHOLDERS[target]}
          aria-describedby={metaId}
          spellCheck
          className="block w-full resize-none bg-transparent px-3.5 pb-1.5 pt-3 text-[14px] leading-[22px] text-fox-white outline-none scrollbar-thin placeholder:text-fox-muted/60"
          style={{
            minHeight: MIN_H,
            maxHeight: MAX_H,
            ...(fade ? { WebkitMaskImage: FADE_MASK, maskImage: FADE_MASK } : null),
          }}
        />
        <div className="flex items-center justify-between gap-3 px-3.5 pb-2.5 pt-1">
          <span className="font-mono text-[11px] text-fox-muted">
            {hint ? (
              <>
                <kbd className="rounded border border-white/10 bg-white/[0.04] px-1 py-px font-mono text-[11px] text-fox-mist">{hint}</kbd>
                <span className="ml-1.5">to ignite</span>
              </>
            ) : null}
          </span>
          <span
            id={metaId}
            className={`font-mono text-[11px] tabular-nums ${nearLimit ? "text-spirit-pink" : "text-fox-muted"}`}
          >
            <span className="sr-only">Characters used: </span>
            {count.toLocaleString("en-US")} / {PROMPT_MAX.toLocaleString("en-US")}
          </span>
        </div>
      </div>

      {/* Ignite + Stop */}
      <div className="mt-3 flex gap-2">
        <div className="relative min-w-0 flex-1">
          <AnimatePresence>
            {pulse > 0 && (
              <motion.span
                key={pulse}
                aria-hidden="true"
                className="pointer-events-none absolute -inset-1 rounded-[20px] border-2 border-spirit-cyan"
                initial={{ opacity: 0.95, scale: 1 }}
                animate={reduce ? { opacity: 0 } : { opacity: 0, scale: 1.07 }}
                transition={{ duration: reduce ? 0.6 : 0.95, ease: "easeOut" }}
                onAnimationComplete={() => setPulse(0)}
              />
            )}
          </AnimatePresence>
          <motion.button
            type="button"
            onClick={ignite}
            disabled={empty && !streaming}
            aria-disabled={streaming || undefined}
            aria-busy={streaming || undefined}
            aria-label={streaming ? "Generating" : outOfTails ? "Unlock more tails" : "Ignite (generate)"}
            animate={pulse > 0 && !reduce ? { scale: [1, 1.025, 1] } : { scale: 1 }}
            whileTap={canIgnite && !reduce ? { scale: 0.985 } : { scale: 1 }}
            transition={{ duration: 0.45, ease: "easeOut" }}
            className={`focus-ring group relative flex h-14 w-full items-center justify-center overflow-hidden rounded-2xl px-4 transition-[box-shadow,color,filter] duration-300 disabled:cursor-not-allowed ${
              dormant
                ? "bg-white/[0.03] text-fox-muted shadow-[inset_0_0_0_1px_rgba(255,255,255,.09)]"
                : streaming
                  ? "cursor-progress text-obsidian-950 shadow-[0_10px_36px_-10px_rgba(124,58,237,.8),0_0_28px_-6px_rgba(103,232,249,.55)]"
                  : "text-obsidian-950 shadow-[0_10px_36px_-12px_rgba(124,58,237,.85),0_0_22px_-8px_rgba(103,232,249,.5)] hover:shadow-[0_14px_44px_-10px_rgba(124,58,237,.95),0_0_34px_-6px_rgba(103,232,249,.65)] hover:brightness-110"
            }`}
          >
            {/* Base gradient (pans while streaming, hidden while dormant) */}
            <span
              aria-hidden="true"
              className={`absolute inset-0 transition-opacity duration-500 ${dormant ? "opacity-0" : "opacity-100"} ${
                streaming ? "animate-spirit-pan" : "bg-ignite"
              }`}
              style={
                streaming
                  ? {
                      backgroundImage: "linear-gradient(110deg, #7c3aed 0%, #a78bfa 25%, #67e8f9 50%, #a78bfa 75%, #7c3aed 100%)",
                      backgroundSize: "200% 100%",
                    }
                  : undefined
              }
            />
            {/* Top highlight */}
            <span
              aria-hidden="true"
              className={`absolute inset-x-0 top-0 h-1/2 bg-gradient-to-b to-transparent transition-opacity duration-500 ${
                dormant ? "from-white/[0.04]" : "from-white/30"
              }`}
            />
            {/* Sheen: sweeps on hover, loops while streaming */}
            {streaming && !reduce ? (
              <motion.span
                aria-hidden="true"
                className="absolute inset-y-0 left-0 w-1/3 -skew-x-12 bg-gradient-to-r from-transparent via-white/60 to-transparent"
                initial={{ x: "-120%" }}
                animate={{ x: "380%" }}
                transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut", repeatDelay: 0.2 }}
              />
            ) : dormant ? null : (
              <span
                aria-hidden="true"
                className="absolute inset-y-0 left-0 w-1/3 -translate-x-[120%] -skew-x-12 bg-gradient-to-r from-transparent via-white/55 to-transparent transition-transform duration-700 ease-out group-hover:translate-x-[380%]"
              />
            )}

            <span className="relative flex items-center gap-3" aria-hidden="true">
              {streaming ? (
                <>
                  <motion.span
                    animate={reduce ? undefined : { scale: [1, 1.18, 0.95, 1.1, 1], rotate: [0, -6, 4, -2, 0] }}
                    transition={{ duration: 1.1, repeat: Infinity, ease: "easeInOut" }}
                    className="grid place-items-center"
                  >
                    <Flame className="h-5 w-5" strokeWidth={2} fill="currentColor" fillOpacity={0.25} />
                  </motion.span>
                  <span className="truncate text-[15px] font-semibold tracking-tight">Channeling fox-fire…</span>
                </>
              ) : (
                <>
                  {outOfTails ? (
                    <LockOpen className="h-5 w-5 shrink-0" strokeWidth={2} />
                  ) : (
                    <Flame className="h-5 w-5 shrink-0" strokeWidth={2} fill="currentColor" fillOpacity={0.25} />
                  )}
                  <span className="flex flex-col items-start leading-none">
                    <span className="text-[17px] font-semibold tracking-tight">{outOfTails ? "Unlock more tails" : "Ignite"}</span>
                    <span className="mt-1 font-mono text-[11px] font-medium uppercase tracking-[0.16em] opacity-70">
                      {outOfTails ? "See plans" : "Generate"}
                    </span>
                  </span>
                </>
              )}
            </span>
          </motion.button>
        </div>

        <AnimatePresence initial={false}>
          {streaming && (
            <motion.button
              key="stop"
              type="button"
              onClick={onCancel}
              aria-label="Stop build"
              initial={reduce ? { opacity: 0 } : { opacity: 0, width: 0, marginLeft: -8 }}
              animate={reduce ? { opacity: 1 } : { opacity: 1, width: 84, marginLeft: 0 }}
              exit={reduce ? { opacity: 0 } : { opacity: 0, width: 0, marginLeft: -8 }}
              transition={SPRING}
              className="focus-ring flex h-14 w-[84px] shrink-0 items-center justify-center gap-2 overflow-hidden whitespace-nowrap rounded-2xl border border-white/[0.12] bg-white/[0.05] text-[14px] font-medium text-fox-white transition-colors hover:border-white/25 hover:bg-white/[0.09]"
            >
              <Square className="h-3.5 w-3.5 shrink-0" strokeWidth={2} fill="currentColor" aria-hidden="true" />
              Stop
            </motion.button>
          )}
        </AnimatePresence>
      </div>

      {/* Tails meter */}
      <div className="mt-3 flex items-center justify-between gap-3 px-0.5" aria-live="polite">
        <p className="font-mono text-[11px] text-fox-muted">
          {unlimited ? (
            "Unlimited tails"
          ) : outOfTails ? (
            <>
              <span className="text-spirit-pink">0 of {FREE_TAILS} left</span>
              <span> · upgrade to keep building</span>
            </>
          ) : (
            <>
              Uses 1 tail · <span className="text-fox-mist">{remaining}</span> of {FREE_TAILS} left
            </>
          )}
        </p>
        <TailMeter remaining={remaining} unlimited={unlimited} />
      </div>
    </div>
  );
}

function TailMeter({ remaining, unlimited }: { remaining: number; unlimited: boolean }) {
  if (unlimited) {
    return <InfinityIcon className="h-4 w-4 text-spirit-cyan" strokeWidth={1.75} aria-hidden="true" />;
  }
  return (
    <span className="flex items-center gap-1" aria-hidden="true">
      {Array.from({ length: FREE_TAILS }, (_, i) => {
        const lit = i < remaining;
        return (
          <span
            key={i}
            className={`h-1.5 w-4 rounded-full transition-colors duration-300 ${
              lit ? "bg-gradient-to-r from-spirit-violet to-spirit-cyan shadow-[0_0_8px_rgba(167,139,250,.6)]" : "bg-white/10"
            }`}
          />
        );
      })}
    </span>
  );
}
