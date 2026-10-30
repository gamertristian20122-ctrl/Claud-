"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { KitsuneMascot } from "@/components/KitsuneMascot";
import type { GenStatus, MascotState } from "@/lib/types";
import { STOPPED_MESSAGE } from "@/lib/useGenerator";

export interface SpiritCoreProps {
  state: MascotState;
  status: GenStatus;
  /** Characters streamed so far in the current build. */
  charCount: number;
  /** Display name of the selected (or running) model. */
  modelName: string;
  error?: string | null;
  className?: string;
}

type Phase = "idle" | "thinking" | "done" | "error" | "stopped";

/** useGenerator's error message when the visitor stops a build themselves. */
export { STOPPED_MESSAGE };

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;

const PHASE_DOT: Record<Phase, string> = {
  idle: "bg-spirit-violet-soft shadow-[0_0_8px_rgba(196,181,253,.8)]",
  thinking: "bg-spirit-cyan shadow-[0_0_10px_rgba(103,232,249,.95)]",
  done: "bg-fox-white shadow-[0_0_10px_rgba(246,244,255,.95)]",
  error: "bg-spirit-pink shadow-[0_0_10px_rgba(240,171,252,.9)]",
  stopped: "bg-fox-muted",
};

const PHASE_CHIP: Record<Phase, string> = {
  idle: "Ready",
  thinking: "Live",
  done: "Done",
  error: "Error",
  stopped: "Stopped",
};

/** The glowing altar under the fox: concentric spell rings plus a ground glow. */
function Altar({ phase, reduce }: { phase: Phase; reduce: boolean }) {
  const thinking = phase === "thinking";
  const done = phase === "done";
  const error = phase === "error";
  const glow = error ? "rgba(240,171,252,.55)" : thinking ? "rgba(103,232,249,.75)" : done ? "rgba(246,244,255,.8)" : "rgba(167,139,250,.55)";

  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-x-0 bottom-0 flex justify-center">
      <div className="relative h-[64px] w-[300px] lg:h-[72px] lg:w-[340px]">
        {/* Ground glow */}
        <motion.div
          className="absolute left-1/2 top-1/2 h-[46px] w-[230px] rounded-[50%]"
          style={{ x: "-50%", y: "-50%", background: `radial-gradient(closest-side, ${glow}, transparent)` }}
          animate={
            thinking && !reduce
              ? { opacity: [0.6, 1, 0.6], scaleX: [1, 1.12, 1] }
              : { opacity: thinking || done ? 0.95 : 0.55, scaleX: 1 }
          }
          transition={thinking && !reduce ? { duration: 1.6, repeat: Infinity, ease: "easeInOut" } : { duration: 0.6 }}
        />

        <svg viewBox="0 0 300 64" className="absolute inset-0 h-full w-full overflow-visible">
          <defs>
            <linearGradient id="nt-altar-ring" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#a78bfa" stopOpacity="0" />
              <stop offset="30%" stopColor="#a78bfa" stopOpacity=".9" />
              <stop offset="55%" stopColor="#f6f4ff" stopOpacity="1" />
              <stop offset="75%" stopColor="#67e8f9" stopOpacity=".9" />
              <stop offset="100%" stopColor="#67e8f9" stopOpacity="0" />
            </linearGradient>
          </defs>

          {/* Outer ring */}
          <ellipse cx="150" cy="32" rx="142" ry="22" fill="none" stroke="url(#nt-altar-ring)" strokeOpacity={thinking ? 0.55 : 0.32} strokeWidth="1" />
          {/* Rotating dashed spell ring */}
          <motion.ellipse
            cx="150"
            cy="32"
            rx="112"
            ry="16"
            fill="none"
            stroke={thinking ? "#67e8f9" : "#c4b5fd"}
            strokeOpacity={thinking ? 0.75 : 0.35}
            strokeWidth="1"
            strokeDasharray="2 7"
            animate={{ strokeDashoffset: reduce ? 0 : [0, thinking ? -90 : -36] }}
            transition={reduce ? { duration: 0 } : { duration: thinking ? 2.2 : 9, repeat: Infinity, ease: "linear" }}
          />
          {/* Inner ring */}
          <ellipse cx="150" cy="32" rx="78" ry="10.5" fill="none" stroke="url(#nt-altar-ring)" strokeOpacity={thinking ? 0.95 : 0.55} strokeWidth="1.25" />
          {/* Core */}
          <ellipse cx="150" cy="32" rx="44" ry="5.5" fill={thinking ? "rgba(103,232,249,.22)" : "rgba(196,181,253,.16)"} stroke="rgba(246,244,255,.35)" strokeWidth=".75" />
          {/* Rune ticks on the outer ring */}
          {[-0.82, -0.5, -0.18, 0.18, 0.5, 0.82].map((t, i) => (
            <circle key={i} cx={150 + 142 * t} cy={32 + 22 * Math.sqrt(1 - t * t)} r="1.4" fill={thinking ? "#67e8f9" : "#c4b5fd"} opacity={thinking ? 0.9 : 0.5} />
          ))}
        </svg>

        {/* Done: a white ring bursts outward once. */}
        <AnimatePresence>
          {done && (
            <motion.div
              key="burst"
              className="absolute left-1/2 top-1/2 h-[22px] w-[156px] rounded-[50%] border border-fox-white/90"
              style={{ x: "-50%", y: "-50%", boxShadow: "0 0 24px rgba(246,244,255,.6), inset 0 0 12px rgba(246,244,255,.4)" }}
              initial={{ scale: 0.6, opacity: 0.95 }}
              animate={{ scale: reduce ? 0.6 : 2.1, opacity: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 1.1, ease: [0.16, 1, 0.3, 1] }}
            />
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

/** Mascot hero card at the top of the left column: the fox on its altar plus a live status line. */
export function SpiritCore({ state, status, charCount, modelName, error, className = "" }: SpiritCoreProps) {
  const reduce = Boolean(useReducedMotion());
  const phase: Phase =
    state === "thinking"
      ? "thinking"
      : status === "error"
        ? error?.trim() === STOPPED_MESSAGE
          ? "stopped"
          : "error"
        : state === "done"
          ? "done"
          : "idle";

  // Nothing here is a live region: Studio announces build status from outside
  // the views, because this card is display:none on phones during a build.
  return (
    <section
      aria-label="Spirit core"
      className={`glass relative isolate overflow-hidden rounded-3xl ${className}`}
    >
      {/* Ambient wash that reacts to the phase */}
      <motion.div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 -z-10"
        animate={{
          background:
            phase === "thinking"
              ? "radial-gradient(70% 80% at 50% 78%, rgba(34,211,238,.22), rgba(124,58,237,.14) 45%, transparent 75%)"
              : phase === "done"
                ? "radial-gradient(70% 80% at 50% 78%, rgba(246,244,255,.20), rgba(167,139,250,.14) 45%, transparent 75%)"
                : phase === "error"
                  ? "radial-gradient(70% 80% at 50% 78%, rgba(240,171,252,.16), rgba(124,58,237,.08) 45%, transparent 75%)"
                  : "radial-gradient(70% 80% at 50% 78%, rgba(124,58,237,.20), rgba(124,58,237,.06) 45%, transparent 75%)",
        }}
        transition={{ duration: 0.8 }}
      />
      {/* Faint dot lattice */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 -z-10 opacity-60"
        style={{
          backgroundImage: "radial-gradient(rgba(255,255,255,.07) 1px, transparent 1px)",
          backgroundSize: "18px 18px",
          WebkitMaskImage: "radial-gradient(60% 70% at 50% 45%, #000, transparent 80%)",
          maskImage: "radial-gradient(60% 70% at 50% 45%, #000, transparent 80%)",
        }}
      />

      {/* Header row */}
      <div className="relative z-10 flex items-center justify-between gap-3 px-4 pt-3.5 sm:px-5">
        <p className="eyebrow shrink-0 whitespace-nowrap">Spirit core</p>
        <span className="inline-flex min-w-0 items-center gap-1.5 rounded-full border border-white/10 bg-obsidian-950/50 px-2.5 py-1 font-mono text-[11px] leading-none text-fox-mist">
          <span className={`h-1.5 w-1.5 shrink-0 rounded-full ${PHASE_DOT[phase]} ${phase === "thinking" ? "animate-soft-pulse" : ""}`} aria-hidden="true" />
          <span className="text-fox-muted">{PHASE_CHIP[phase]}</span>
          <span className="text-fox-dim" aria-hidden="true">·</span>
          <span className="truncate">{modelName}</span>
        </span>
      </div>

      {/* Fox on the altar */}
      <div className="relative mx-auto -mt-2 flex h-[150px] w-full items-end justify-center lg:h-[176px]">
        <Altar phase={phase} reduce={reduce} />
        <motion.div
          className="relative"
          animate={!reduce && phase === "thinking" ? { y: [0, -4, 0] } : { y: 0 }}
          transition={!reduce && phase === "thinking" ? { duration: 2.4, repeat: Infinity, ease: "easeInOut" } : SPRING}
          style={{ marginBottom: 3 }}
        >
          {/* Rendered at the desktop size and scaled by CSS, so there's no size jump after hydration. */}
          <KitsuneMascot state={state} size={176} className="block h-[148px] w-[148px] lg:h-[176px] lg:w-[176px]" />
        </motion.div>
      </div>

      {/* Status line */}
      <div className="relative z-10 flex h-9 items-center justify-center px-4 pb-3 font-mono text-[12px] sm:text-[12.5px]">
        <AnimatePresence mode="wait" initial={false}>
          <motion.p
            key={phase}
            className="flex min-w-0 items-center gap-2 whitespace-nowrap"
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: -6 }}
            transition={{ duration: 0.22 }}
          >
            {phase === "idle" && (
              <>
                <span className="text-fox-mist">Nine tails at rest</span>
                <span className="text-fox-dim" aria-hidden="true">·</span>
                <span className="text-fox-muted">ready to build</span>
              </>
            )}
            {phase === "thinking" && (
              <>
                <span className="text-spirit-cyan">Channeling fox-fire</span>
                <span className="text-fox-dim" aria-hidden="true">·</span>
                <span className="tabular-nums text-fox-white">{charCount.toLocaleString("en-US")}</span>
                <span className="-ml-1 text-fox-muted">chars</span>
              </>
            )}
            {phase === "done" && (
              <>
                <span className="text-spirit">Build complete</span>
                <span className="text-fox-dim" aria-hidden="true">·</span>
                <span className="tabular-nums text-fox-muted">{charCount.toLocaleString("en-US")} chars</span>
              </>
            )}
            {phase === "stopped" && (
              <>
                <span className="text-fox-mist">Build stopped</span>
                <span className="text-fox-dim" aria-hidden="true">·</span>
                <span className="text-fox-muted">no tail spent</span>
              </>
            )}
            {phase === "error" && (
              <>
                <span className="text-spirit-pink">The spell fizzled</span>
                <span className="text-fox-dim" aria-hidden="true">·</span>
                <span className="text-fox-muted">try again</span>
              </>
            )}
          </motion.p>
        </AnimatePresence>
      </div>
    </section>
  );
}

export default SpiritCore;
