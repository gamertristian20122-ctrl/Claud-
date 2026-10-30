"use client";

import { AnimatePresence, motion } from "framer-motion";
import { ArrowUpRight, CircleAlert, Eye, EyeOff, KeyRound, ServerCog, ShieldCheck, Sparkles, Trash2 } from "lucide-react";
import { useEffect, useId, useRef, useState, type FormEvent } from "react";
import { Modal } from "@/components/ui/Modal";
import { detectKeyProvider } from "@/lib/models";
import { FREE_TAILS, type ByokState } from "@/lib/storage";
import type { KeyProvider } from "@/lib/types";

export interface ByokModalProps {
  open: boolean;
  onClose: () => void;
  byok: ByokState;
}

const PROVIDERS: {
  id: KeyProvider;
  name: string;
  prefix: string;
  unlocks: string;
  link: string;
  linkLabel: string;
}[] = [
  {
    id: "anthropic",
    name: "Anthropic",
    prefix: "sk-ant-",
    unlocks: "Unlocks the Claude tails",
    link: "https://platform.claude.com/settings/keys",
    linkLabel: "Get an Anthropic key",
  },
  {
    id: "openrouter",
    name: "OpenRouter",
    prefix: "sk-or-",
    unlocks: "Unlocks all five tails",
    link: "https://openrouter.ai/keys",
    linkLabel: "Get an OpenRouter key",
  },
];

/** "Bring your own key": paste an Anthropic or OpenRouter key, stored in this browser only. */
export function ByokModal({ open, onClose, byok }: ByokModalProps) {
  const inputId = useId();
  const hintId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [draft, setDraft] = useState("");
  const [reveal, setReveal] = useState(false);

  // Fresh, hidden input every time the dialog opens. Focus it on desktop
  // (on phones that would pop the keyboard over the explanation).
  useEffect(() => {
    if (!open) return;
    setDraft("");
    setReveal(false);
    let fine = false;
    try {
      fine = window.matchMedia("(pointer: fine)").matches;
    } catch {
      fine = false;
    }
    if (!fine) return;
    const t = window.setTimeout(() => inputRef.current?.focus(), 80);
    return () => window.clearTimeout(t);
  }, [open]);

  const trimmed = draft.trim();
  const detected = trimmed ? detectKeyProvider(trimmed) : null;
  const canSave = detected !== null;
  const hasSaved = Boolean(byok.key);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (!canSave) return;
    byok.save(trimmed);
    onClose();
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Bring your own key"
      description="Use your own Anthropic or OpenRouter key."
      widthClass="sm:max-w-[30rem]"
    >
      {hasSaved && (
        <div className="mb-5 flex items-center gap-3 rounded-2xl border border-spirit-cyan/20 bg-spirit-cyan/[0.04] py-2 pl-3 pr-2">
          <span className="relative flex h-2 w-2 shrink-0" aria-hidden="true">
            <span className="relative h-2 w-2 rounded-full bg-spirit-cyan shadow-[0_0_8px_rgba(103,232,249,.9)]" />
          </span>
          <p className="min-w-0 flex-1 text-[12px] leading-tight text-fox-muted">
            <span className="block">
              Current key
              {byok.provider && <> · {byok.provider === "anthropic" ? "Anthropic" : "OpenRouter"}</>}
            </span>
            <span className="mt-1 block truncate font-mono text-[13px] text-fox-white" data-testid="byok-current">
              {byok.masked}
            </span>
          </p>
          <button
            type="button"
            onClick={() => {
              byok.clear();
              // This button unmounts with the key; keep focus in the dialog, on the field that replaces it.
              inputRef.current?.focus();
            }}
            className="focus-ring flex min-h-[44px] shrink-0 items-center gap-1.5 rounded-xl px-3 text-[13px] font-medium text-fox-mist transition-colors hover:bg-white/[0.06] hover:text-fox-white"
          >
            <Trash2 className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
            Remove key
          </button>
        </div>
      )}

      <form onSubmit={submit} noValidate>
        <div className="mb-2 flex items-center justify-between gap-3">
          <label htmlFor={inputId} className="text-[13px] font-medium text-fox-mist">
            {hasSaved ? "Replace with a new key" : "API key"}
          </label>
          <ProviderPill value={trimmed} detected={detected} />
        </div>

        <div className="group relative">
          <span
            className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-fox-muted transition-colors group-focus-within:text-spirit-cyan"
            aria-hidden="true"
          >
            <KeyRound className="h-4 w-4" strokeWidth={1.75} />
          </span>
          <input
            ref={inputRef}
            id={inputId}
            name="ninetail-byok"
            type={reveal ? "text" : "password"}
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="sk-ant-…  or  sk-or-…"
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="none"
            spellCheck={false}
            data-1p-ignore="true"
            data-lpignore="true"
            aria-describedby={hintId}
            aria-invalid={trimmed.length > 0 && !detected ? true : undefined}
            // 16px on touch and small screens: iOS Safari zooms into smaller fields on focus.
            className="h-12 w-full rounded-xl border border-white/10 bg-obsidian-950/70 pl-10 pr-12 font-mono text-[13px] max-lg:text-[16px] [@media(pointer:coarse)]:text-[16px] text-fox-white outline-none transition placeholder:text-fox-dim focus:border-spirit-cyan/45 focus:shadow-[0_0_0_3px_rgba(103,232,249,.10)]"
          />
          <button
            type="button"
            onClick={() => setReveal((r) => !r)}
            aria-label={reveal ? "Hide key" : "Show key"}
            aria-pressed={reveal}
            aria-controls={inputId}
            className="focus-ring absolute right-0.5 top-1/2 grid h-11 w-11 -translate-y-1/2 place-items-center rounded-lg text-fox-muted transition-colors hover:text-fox-white"
          >
            {reveal ? <EyeOff className="h-4 w-4" strokeWidth={1.75} /> : <Eye className="h-4 w-4" strokeWidth={1.75} />}
          </button>
        </div>

        <p id={hintId} className="mt-2 min-h-[18px] text-[12px] text-fox-muted" aria-live="polite">
          {detected === "anthropic" && "Anthropic key. Unlocks Sonnet, Haiku and Opus."}
          {detected === "openrouter" && "OpenRouter key. Unlocks all five tails."}
          {!detected && trimmed && "Keys start with sk-ant- (Anthropic) or sk-or- (OpenRouter)."}
          {!trimmed && "Paste a key that starts with sk-ant- or sk-or-."}
        </p>

        {/* What each kind of key unlocks; the detected one lights up. */}
        <ul className="mt-3 grid gap-2">
          {PROVIDERS.map((p) => {
            const on = detected === p.id;
            return (
              <li
                key={p.id}
                className={`flex flex-wrap items-center justify-between gap-x-3 gap-y-1 rounded-xl border px-3 py-2.5 transition-colors ${
                  on
                    ? p.id === "openrouter"
                      ? "border-spirit-cyan/35 bg-spirit-cyan/[0.06]"
                      : "border-spirit-violet/40 bg-spirit-violet/[0.08]"
                    : "border-white/[0.07] bg-white/[0.02]"
                }`}
              >
                <div className="min-w-0">
                  <p className="text-[13px] font-medium text-fox-white">
                    {p.name} <span className="font-mono text-[11px] font-normal text-fox-muted">{p.prefix}…</span>
                  </p>
                  <p className="text-[12px] text-fox-muted">{p.unlocks}</p>
                </div>
                <a
                  href={p.link}
                  target="_blank"
                  rel="noreferrer"
                  className="focus-ring -mr-1 flex min-h-[36px] items-center gap-1 rounded-lg px-1 text-[12px] font-medium text-spirit-violet-soft underline-offset-4 transition-colors hover:text-fox-white hover:underline"
                >
                  {p.linkLabel}
                  <ArrowUpRight className="h-3.5 w-3.5" strokeWidth={1.75} aria-hidden="true" />
                </a>
              </li>
            );
          })}
        </ul>

        <button
          type="submit"
          disabled={!canSave}
          className="focus-ring mt-5 flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-fox-white text-[14px] font-semibold text-obsidian-950 shadow-glow-white transition hover:bg-white disabled:cursor-not-allowed disabled:border disabled:border-white/10 disabled:bg-white/[0.05] disabled:text-fox-dim disabled:shadow-none"
        >
          {hasSaved ? "Replace key" : "Save key"}
        </button>
      </form>

      <ul className="mt-5 space-y-2.5 border-t border-white/[0.07] pt-4 text-[12px] leading-snug text-fox-muted">
        <li className="flex gap-2.5">
          <ShieldCheck className="mt-px h-4 w-4 shrink-0 text-fox-mist" strokeWidth={1.75} aria-hidden="true" />
          <span>Stored only in this browser (localStorage).</span>
        </li>
        <li className="flex gap-2.5">
          <ServerCog className="mt-px h-4 w-4 shrink-0 text-fox-mist" strokeWidth={1.75} aria-hidden="true" />
          <span>
            Sent with each build to this app&apos;s server, which passes it to Anthropic or OpenRouter and doesn&apos;t
            store it.
          </span>
        </li>
        <li className="flex gap-2.5">
          <Sparkles className="mt-px h-4 w-4 shrink-0 text-fox-mist" strokeWidth={1.75} aria-hidden="true" />
          <span>
            Free accounts get {FREE_TAILS} builds. The BYOK Pass makes them unlimited.
          </span>
        </li>
      </ul>
    </Modal>
  );
}

function ProviderPill({ value, detected }: { value: string; detected: KeyProvider | null }) {
  const state = !value ? "empty" : detected ?? "unknown";
  return (
    <AnimatePresence mode="wait" initial={false}>
      {state !== "empty" && (
        <motion.span
          key={state}
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.92 }}
          transition={{ type: "spring", stiffness: 380, damping: 30 }}
          data-testid="byok-provider"
          className={`inline-flex h-6 items-center gap-1.5 rounded-full border px-2.5 font-mono text-[11px] ${
            state === "anthropic"
              ? "border-spirit-violet/40 bg-spirit-violet/15 text-spirit-violet-soft"
              : state === "openrouter"
                ? "border-spirit-cyan/35 bg-spirit-cyan/10 text-spirit-cyan"
                : "border-spirit-pink/30 bg-spirit-pink/10 text-spirit-pink"
          }`}
        >
          {state === "unknown" ? (
            <CircleAlert className="h-3 w-3" strokeWidth={2} aria-hidden="true" />
          ) : (
            <span
              aria-hidden="true"
              className={`h-1.5 w-1.5 rounded-full ${
                state === "anthropic" ? "bg-spirit-violet shadow-[0_0_6px_#a78bfa]" : "bg-spirit-cyan shadow-[0_0_6px_#67e8f9]"
              }`}
            />
          )}
          {state === "anthropic" ? "Anthropic" : state === "openrouter" ? "OpenRouter" : "Not recognised"}
        </motion.span>
      )}
    </AnimatePresence>
  );
}
