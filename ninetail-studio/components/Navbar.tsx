"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { Crown, Infinity as InfinityIcon, KeyRound } from "lucide-react";
import { KitsuneMascot } from "@/components/KitsuneMascot";
import { useHydrated } from "@/lib/storage";
import type { MascotState } from "@/lib/types";

export interface NavbarProps {
  mascotState: MascotState;
  remaining: number;
  max: number;
  unlimited: boolean;
  byokConnected: boolean;
  onOpenUpgrade: () => void;
  onOpenByok: () => void;
  className?: string;
}

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;

/** A tiny spirit-flame. Filled = a tail you still have, hollow = spent. */
function TailPip({ filled, warn, index }: { filled: boolean; warn: boolean; index: number }) {
  const reduce = useReducedMotion();
  const id = `nt-pip-${index}`;
  return (
    <motion.svg
      viewBox="0 0 10 14"
      className="h-3.5 w-2.5 shrink-0 overflow-visible"
      aria-hidden="true"
      initial={false}
      animate={filled || reduce ? { scale: 1, y: 0 } : { scale: [1, 1.5, 0.92], y: [0, -2, 0] }}
      transition={{ duration: 0.5, ease: "easeOut" }}
    >
      <defs>
        <linearGradient id={id} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0%" stopColor="#a78bfa" />
          <stop offset="60%" stopColor="#c4b5fd" />
          <stop offset="100%" stopColor="#67e8f9" />
        </linearGradient>
      </defs>
      <path
        d="M5 .8C6.6 3.3 9 5.3 9 8.4A4 4 0 0 1 1 8.4C1 6.6 2 5.4 2.9 4.5c.1 1.3.6 2 1.3 2.3C4 4.6 4.3 2.6 5 .8Z"
        fill={filled ? `url(#${id})` : "none"}
        stroke={filled ? "rgba(246,244,255,.55)" : warn ? "rgba(240,171,252,.75)" : "rgba(217,212,245,.35)"}
        strokeWidth={filled ? 0.6 : 1.1}
        style={filled ? { filter: "drop-shadow(0 0 3px rgba(167,139,250,.75))" } : undefined}
      />
    </motion.svg>
  );
}

/** The navbar's "Tails Remaining" pill. Opens the upgrade modal; a plain badge on unlimited plans. */
function TailsCounter({
  remaining,
  max,
  unlimited,
  onClick,
}: {
  remaining: number;
  max: number;
  unlimited: boolean;
  onClick: () => void;
}) {
  const reduce = useReducedMotion();
  // The stored count is unknown until hydration (the server renders defaults):
  // until then show no number and unlit pips. `unlimited` is already right on the
  // server, since only UNLOCK_ALL can make it true there.
  const hydrated = useHydrated();
  const pending = !hydrated && !unlimited;
  const empty = !pending && !unlimited && remaining <= 0;
  const pill =
    "relative inline-flex h-10 shrink-0 items-center gap-2 rounded-full border px-3 text-[12px] font-medium sm:gap-2.5 sm:px-3.5 sm:text-[13px]";

  if (unlimited) {
    // Nothing left to buy, so not a button into the upsell.
    return (
      <span title="Unlimited tails" className={`${pill} border-white/10 bg-white/[0.04] text-fox-mist`}>
        <InfinityIcon className="h-4 w-4 text-spirit-cyan" strokeWidth={1.75} aria-hidden="true" />
        <span className="sr-only">Unlimited tails</span>
        <span aria-hidden="true">
          <span className="hidden min-[380px]:inline">Unlimited tails</span>
          <span className="min-[380px]:hidden">Unlimited</span>
        </span>
      </span>
    );
  }

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={pending ? "Tails remaining" : `Tails remaining: ${remaining} of ${max}`}
      title="View plans"
      className={`focus-ring group ${pill} transition-colors before:absolute before:-inset-y-1 before:inset-x-0 before:content-[''] ${
        empty
          ? "border-spirit-pink/45 bg-spirit-pink/[0.08] text-spirit-pink hover:bg-spirit-pink/[0.14]"
          : "border-white/10 bg-white/[0.04] text-fox-mist hover:border-white/20 hover:bg-white/[0.07]"
      }`}
    >
      {empty && (
        <span aria-hidden="true" className="pointer-events-none absolute inset-0 animate-soft-pulse rounded-full shadow-[0_0_0_1px_rgba(240,171,252,.35),0_0_18px_rgba(240,171,252,.35)]" />
      )}

      <span className={`hidden items-center gap-[3px] min-[372px]:flex ${pending ? "opacity-50" : ""}`} aria-hidden="true">
        {Array.from({ length: max }, (_, i) => (
          // Remounted with the stored count, so `initial={false}` shows it without replaying a spend.
          <TailPip key={`${hydrated}-${i}`} index={i} filled={!pending && i < remaining} warn={empty} />
        ))}
      </span>
      <span aria-hidden="true" className="flex items-center gap-1.5 whitespace-nowrap">
        <span className="hidden sm:inline">Tails Remaining:</span>
        <span className="sm:hidden">Tails</span>
        <span className={`relative inline-flex font-mono tabular-nums ${empty ? "text-spirit-pink" : "text-fox-white"}`}>
          {pending ? (
            <span className="text-fox-muted">–</span>
          ) : (
            <AnimatePresence mode="popLayout" initial={false}>
              <motion.span
                key={remaining}
                initial={reduce ? { opacity: 0 } : { y: -10, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={reduce ? { opacity: 0 } : { y: 10, opacity: 0 }}
                transition={SPRING}
              >
                {remaining}
              </motion.span>
            </AnimatePresence>
          )}
          <span className={empty ? "text-spirit-pink/70" : "text-fox-muted"}>/{max}</span>
        </span>
      </span>
    </button>
  );
}

export function Navbar({ mascotState, remaining, max, unlimited, byokConnected, onOpenUpgrade, onOpenByok, className = "" }: NavbarProps) {
  return (
    <header
      className={`sticky top-0 z-40 bg-obsidian-950/80 pt-[env(safe-area-inset-top)] shadow-[inset_0_-1px_0_rgba(255,255,255,.07)] backdrop-blur-xl backdrop-saturate-150 ${className}`}
    >
      {/* Hairline glow along the bottom edge. */}
      <div aria-hidden="true" className="pointer-events-none absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-spirit-violet/35 to-transparent" />

      <div className="mx-auto flex h-14 items-center justify-between gap-2 px-3 sm:px-5 lg:h-16">
        {/* Brand */}
        <div className="flex min-w-0 items-center gap-2">
          <span className="relative grid h-9 w-9 shrink-0 place-items-center">
            <span aria-hidden="true" className="absolute inset-0 rounded-full bg-spirit-violet/20 blur-md" />
            <KitsuneMascot state={mascotState} size={36} className="relative" />
          </span>
          <span className="flex min-w-0 items-baseline gap-1.5 whitespace-nowrap text-[15px] font-semibold tracking-tight sm:text-base">
            <span className="text-spirit">NineTail</span>
            <span className="text-fox-mist">Studio</span>
          </span>
          <span className="hidden rounded-md border border-spirit-violet/30 bg-spirit-violet/10 px-1.5 py-px font-mono text-[11px] lowercase leading-4 text-spirit-violet-soft sm:inline-block">
            beta
          </span>
        </div>

        {/* Actions */}
        <div className="flex shrink-0 items-center gap-1.5 sm:gap-2">
          <TailsCounter remaining={remaining} max={max} unlimited={unlimited} onClick={onOpenUpgrade} />

          <button
            type="button"
            onClick={onOpenByok}
            aria-label={byokConnected ? "Your API key is connected. Manage key" : "Connect your own API key"}
            title={byokConnected ? "Key connected" : "Bring your own key"}
            className="focus-ring relative grid h-10 w-10 shrink-0 place-items-center rounded-full border border-white/10 bg-white/[0.04] text-fox-mist transition hover:border-white/20 hover:bg-white/[0.08] hover:text-fox-white before:absolute before:-inset-0.5 before:content-['']"
          >
            <KeyRound className="h-[17px] w-[17px]" strokeWidth={1.75} aria-hidden="true" />
            {byokConnected && (
              <span aria-hidden="true" className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-spirit-cyan shadow-[0_0_0_2px_#07070d,0_0_8px_rgba(103,232,249,.9)]" />
            )}
          </button>

          {!unlimited && (
            <button
              type="button"
              onClick={onOpenUpgrade}
              className="focus-ring hidden h-10 shrink-0 items-center gap-1.5 rounded-full bg-fox-white px-4 text-[13px] font-semibold text-obsidian-950 shadow-[0_0_0_1px_rgba(255,255,255,.3),0_8px_28px_-6px_rgba(196,181,253,.55)] transition hover:-translate-y-px hover:bg-white hover:shadow-[0_0_0_1px_rgba(255,255,255,.4),0_10px_34px_-6px_rgba(196,181,253,.75)] active:translate-y-0 sm:inline-flex"
            >
              <Crown className="h-4 w-4 text-spirit-violet-deep" strokeWidth={1.75} aria-hidden="true" />
              Upgrade
            </button>
          )}
        </div>
      </div>
    </header>
  );
}

export default Navbar;
