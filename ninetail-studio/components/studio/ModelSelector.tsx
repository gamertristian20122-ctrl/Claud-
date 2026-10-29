"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { ChevronRight, Info, KeyRound, Lock } from "lucide-react";
import { useEffect, useId, useRef, type KeyboardEvent } from "react";
import { DEFAULT_MODEL, MODELS, getModel, providerSupportsModel, type ModelInfo } from "@/lib/models";
import type { ByokState } from "@/lib/storage";
import type { KeyProvider, ModelId, ServerStatus } from "@/lib/types";

export interface ModelSelectorProps {
  value: ModelId;
  onChange: (model: ModelId) => void;
  byok: ByokState;
  /** Which server-side keys exist; null while loading. */
  server: ServerStatus | null;
  onOpenByok: () => void;
  disabled?: boolean;
  className?: string;
}

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;

const PROVIDER_NAME: Record<KeyProvider, string> = {
  anthropic: "Anthropic",
  openrouter: "OpenRouter",
};

/** Claude tails first (reachable with an Anthropic key), then the OpenRouter-only tails. */
const CLAUDE_TAILS = MODELS.filter((m) => m.anthropicId);
const ROUTER_TAILS = MODELS.filter((m) => !m.anthropicId);
const ORDER: ModelInfo[] = [...CLAUDE_TAILS, ...ROUTER_TAILS];

const LOCK_CAPTION = "Needs an OpenRouter key";

/** Can the server's own keys serve this model? */
function serverServes(server: ServerStatus, id: ModelId): boolean {
  return server.openrouter || (server.anthropic && providerSupportsModel("anthropic", id));
}

/**
 * "Choose a Tail": the model picker. Claude tails sit on the first row, the
 * OpenRouter-only tails on the second, so locking by key provider reads at a glance.
 */
export function ModelSelector({
  value,
  onChange,
  byok,
  server,
  onOpenByok,
  disabled = false,
  className = "",
}: ModelSelectorProps) {
  const rawId = useId();
  const uid = rawId.replace(/:/g, "");
  const reduce = useReducedMotion();
  const refs = useRef<Record<string, HTMLButtonElement | null>>({});
  const headingId = `${uid}-heading`;

  const keyProvider: KeyProvider | null = byok.key ? byok.provider : null;
  const isLocked = (id: ModelId) => keyProvider !== null && !providerSupportsModel(keyProvider, id);
  const selected = getModel(value);
  const valueLocked = isLocked(value);

  // A saved Anthropic key can't reach the OpenRouter-only tails: fall back to the default tail.
  useEffect(() => {
    if (valueLocked && !disabled) onChange(DEFAULT_MODEL);
  }, [valueLocked, disabled, onChange]);

  // Roving tabindex: the selected tail, or the first available one.
  const focusId = valueLocked ? (ORDER.find((m) => !isLocked(m.id))?.id ?? value) : value;

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>, id: ModelId) => {
    if (disabled) return;
    const available = ORDER.filter((m) => !isLocked(m.id));
    const n = available.length;
    if (!n) return;
    const index = Math.max(0, available.findIndex((m) => m.id === id));
    let next: number | null = null;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (index + 1) % n;
    else if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (index - 1 + n) % n;
    else if (e.key === "Home") next = 0;
    else if (e.key === "End") next = n - 1;
    if (next === null) return;
    e.preventDefault();
    const target = available[next].id;
    onChange(target);
    refs.current[target]?.focus();
  };

  let notice: string | null = null;
  if (byok.key && !byok.provider) {
    notice = "Your saved key isn't recognised. Reconnect it to build live.";
  } else if (!keyProvider && server) {
    if (!server.anthropic && !server.openrouter) {
      notice = "Demo mode: builds use prebuilt examples until you connect a key.";
    } else if (!serverServes(server, value)) {
      notice = "This tail runs in demo mode on this server.";
    }
  }

  const routerLocked = keyProvider === "anthropic";

  const renderChip = (m: ModelInfo) => {
    const checked = m.id === value;
    const locked = isLocked(m.id);
    return (
      <button
        key={m.id}
        ref={(el) => {
          refs.current[m.id] = el;
        }}
        type="button"
        role="radio"
        aria-checked={checked}
        aria-disabled={locked || undefined}
        aria-label={`${m.name}, ${m.maker}, ${m.badge}${locked ? `. ${LOCK_CAPTION}` : ""}`}
        title={locked ? LOCK_CAPTION : undefined}
        tabIndex={m.id === focusId ? 0 : -1}
        disabled={disabled}
        onClick={() => {
          if (!locked && !checked) onChange(m.id);
        }}
        onKeyDown={(e) => onKeyDown(e, m.id)}
        className={`focus-ring group relative flex min-h-[62px] min-w-0 flex-col justify-between gap-1.5 rounded-xl border px-2.5 py-2 text-left transition-colors disabled:cursor-not-allowed ${
          locked
            ? "cursor-not-allowed border-white/[0.05] bg-transparent"
            : checked
              ? "border-transparent"
              : "border-white/[0.07] bg-white/[0.02] hover:border-white/[0.14] hover:bg-white/[0.045]"
        }`}
      >
        {checked && !locked && (
          <motion.span
            layoutId={`${uid}-ring`}
            transition={reduce ? { duration: 0 } : SPRING}
            aria-hidden="true"
            className="absolute -inset-px rounded-xl border border-spirit-violet/70 bg-gradient-to-b from-spirit-violet/[0.16] to-spirit-violet/[0.05] shadow-[inset_0_1px_0_rgba(255,255,255,.08),0_0_0_1px_rgba(167,139,250,.18),0_0_26px_-4px_rgba(139,92,246,.6)]"
          />
        )}
        <span className="relative flex w-full items-start justify-between gap-1.5" aria-hidden="true">
          <span
            className={`truncate text-[13.5px] font-semibold leading-tight tracking-tight ${
              locked ? "text-fox-dim" : checked ? "text-fox-white" : "text-fox-mist"
            }`}
          >
            {m.short}
          </span>
          {locked ? (
            <Lock className="mt-px h-3.5 w-3.5 shrink-0 text-fox-dim" strokeWidth={1.75} />
          ) : (
            <TailGlyph lit={checked} gradientId={`${uid}-${m.id}-tail`} />
          )}
        </span>
        <span
          aria-hidden="true"
          className={`relative truncate font-mono text-[11px] uppercase leading-none tracking-[0.06em] ${
            locked ? "text-fox-dim" : checked ? "text-spirit-violet-soft" : "text-fox-muted"
          }`}
        >
          {m.badge}
        </span>
      </button>
    );
  };

  return (
    <div className={className}>
      <div className="mb-3.5 flex items-end justify-between gap-3">
        <div className="min-w-0">
          <p className="eyebrow">Choose a Tail</p>
          <h2 id={headingId} className="mt-1 text-[15px] font-semibold leading-tight tracking-tight text-fox-white">
            AI model
          </h2>
        </div>
      </div>

      <div
        role="radiogroup"
        aria-labelledby={headingId}
        aria-disabled={disabled || undefined}
        className={`space-y-3 transition-opacity ${disabled ? "opacity-60" : ""}`}
      >
        <div>
          <p className="mb-1.5 px-0.5 text-[11px] font-medium text-fox-muted" aria-hidden="true">
            Claude <span className="text-fox-dim">·</span> Anthropic
          </p>
          <div className="grid grid-cols-3 gap-1.5">{CLAUDE_TAILS.map(renderChip)}</div>
        </div>
        <div>
          <p className="mb-1.5 flex items-center justify-between gap-2 px-0.5 text-[11px] font-medium text-fox-muted" aria-hidden="true">
            <span className="whitespace-nowrap">Via OpenRouter</span>
            {routerLocked && (
              <span className="flex items-center gap-1 whitespace-nowrap text-spirit-violet-soft">
                <Lock className="h-3 w-3" strokeWidth={2} />
                {LOCK_CAPTION}
              </span>
            )}
          </p>
          <div className="grid grid-cols-2 gap-1.5">{ROUTER_TAILS.map(renderChip)}</div>
        </div>
      </div>

      {/* The selected tail, in full. */}
      <div className="mt-3.5 min-h-[44px] px-0.5">
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={selected.id}
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: -4 }}
            transition={{ duration: 0.16 }}
          >
            <p className="text-[13px] font-semibold tracking-tight text-fox-white">
              {selected.name}
              <span className="font-normal text-fox-muted"> · {selected.maker}</span>
            </p>
            <p className="mt-0.5 text-[12.5px] leading-snug text-fox-muted">{selected.blurb}</p>
          </motion.div>
        </AnimatePresence>
      </div>

      <AnimatePresence initial={false}>
        {notice && (
          <motion.p
            key={notice}
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden"
            role="status"
          >
            <span className="mt-3 flex items-start gap-2 rounded-xl border border-spirit-violet/15 bg-spirit-violet/[0.06] px-3 py-2.5 text-[12px] leading-snug text-fox-mist">
              <Info className="mt-px h-4 w-4 shrink-0 text-spirit-violet-soft" strokeWidth={1.75} aria-hidden="true" />
              {notice}
            </span>
          </motion.p>
        )}
      </AnimatePresence>

      <ByokButton byok={byok} onOpenByok={onOpenByok} />
    </div>
  );
}

function ByokButton({ byok, onOpenByok }: { byok: ByokState; onOpenByok: () => void }) {
  const connected = Boolean(byok.key && byok.provider);
  return (
    <button
      type="button"
      onClick={onOpenByok}
      aria-haspopup="dialog"
      className={`focus-ring group mt-3 flex min-h-[52px] w-full items-center gap-3 rounded-xl border px-3 py-2 text-left transition-colors ${
        connected
          ? "border-spirit-cyan/20 bg-spirit-cyan/[0.04] hover:border-spirit-cyan/35 hover:bg-spirit-cyan/[0.07]"
          : "border-dashed border-white/[0.14] bg-white/[0.015] hover:border-white/25 hover:bg-white/[0.04]"
      }`}
    >
      <span
        aria-hidden="true"
        className={`grid h-8 w-8 shrink-0 place-items-center rounded-lg border ${
          connected
            ? "border-spirit-cyan/25 bg-spirit-cyan/10 text-spirit-cyan"
            : "border-white/[0.08] bg-white/[0.04] text-fox-mist group-hover:text-fox-white"
        }`}
      >
        <KeyRound className="h-4 w-4" strokeWidth={1.75} />
      </span>
      {connected && byok.provider ? (
        <span className="min-w-0 flex-1">
          <span className="flex items-center gap-2 text-[13px] font-medium text-fox-white">
            <span className="relative flex h-2 w-2 shrink-0" aria-hidden="true">
              <span className="absolute inset-0 animate-ping rounded-full bg-spirit-cyan/60 [animation-duration:2.4s]" />
              <span className="relative h-2 w-2 rounded-full bg-spirit-cyan shadow-[0_0_8px_rgba(103,232,249,.9)]" />
            </span>
            <span className="truncate">{PROVIDER_NAME[byok.provider]}</span>
            <span className="sr-only">key connected:</span>
          </span>
          <span className="mt-0.5 block truncate font-mono text-[11px] text-fox-muted">{byok.masked}</span>
        </span>
      ) : (
        <span className="min-w-0 flex-1">
          <span className="block text-[13px] font-medium text-fox-white">Connect your own key</span>
          <span className="mt-0.5 block truncate text-[12px] text-fox-muted">Anthropic or OpenRouter</span>
        </span>
      )}
      <span className="flex shrink-0 items-center gap-0.5 text-[12px] text-fox-muted transition-colors group-hover:text-fox-white">
        {connected ? "Manage" : null}
        <ChevronRight className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
      </span>
    </button>
  );
}

/** A small bushy fox tail. Lit = the selected tail: violet base, white body, cyan spirit-fire tip. */
function TailGlyph({ lit, gradientId }: { lit: boolean; gradientId: string }) {
  return (
    <svg viewBox="0 0 20 20" className="-mr-0.5 -mt-0.5 h-5 w-5 shrink-0" aria-hidden="true">
      <defs>
        <linearGradient id={gradientId} x1="0.05" y1="0.95" x2="0.85" y2="0.05">
          <stop offset="0" stopColor="#7c3aed" />
          <stop offset="0.45" stopColor="#c4b5fd" />
          <stop offset="0.78" stopColor="#f6f4ff" />
          <stop offset="1" stopColor="#67e8f9" />
        </linearGradient>
      </defs>
      <path
        d="M2.2 18.6C8.6 19.4 15.6 15.6 17.6 8.4c.5-1.9.3-4.2-1.3-6.4-.5 2.4-2.1 3.6-3.6 5.4-1.3 1.6-2.4 3.7-3.4 5.6-1.6 2.9-3.9 4.8-7.1 5.6Z"
        fill={lit ? `url(#${gradientId})` : "rgba(255,255,255,0.16)"}
        style={lit ? { filter: "drop-shadow(0 0 4px rgba(167,139,250,.7))" } : undefined}
      />
      {lit && <circle cx="16.4" cy="2.6" r="1.5" fill="#67e8f9" style={{ filter: "drop-shadow(0 0 3px #67e8f9)" }} />}
    </svg>
  );
}
