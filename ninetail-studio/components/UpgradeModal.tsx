"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { ArrowUpRight, Check, Crown, Info, KeyRound, RotateCcw } from "lucide-react";
import { useEffect, useId, useState } from "react";
import { Modal } from "@/components/ui/Modal";
import type { UpgradeReason } from "@/lib/types";

export interface UpgradeModalProps {
  open: boolean;
  reason: UpgradeReason;
  onClose: () => void;
  /** "Already have a key? Connect it": the parent closes this modal and opens the BYOK modal. */
  onOpenByok: () => void;
  /** Refill the free tails (demo / development helper). */
  onRefill?: () => void;
}

type Billing = "lifetime" | "monthly";

// Literal process.env reads so Next inlines them at build time.
const CHECKOUT = {
  byokLifetime: process.env.NEXT_PUBLIC_CHECKOUT_BYOK_LIFETIME_URL?.trim() || "",
  byokMonthly: process.env.NEXT_PUBLIC_CHECKOUT_BYOK_MONTHLY_URL?.trim() || "",
  pro: process.env.NEXT_PUBLIC_CHECKOUT_PRO_URL?.trim() || "",
};

const SHOW_REFILL = process.env.NEXT_PUBLIC_SHOW_DEMO_RESET === "true" || process.env.NODE_ENV === "development";

const COPY: Record<UpgradeReason, { title: string; description: string }> = {
  limit: {
    title: "You've used all 3 free tails",
    description: "Keep building with your own key, or let NineTail host every model for you.",
  },
  export: {
    title: "1-Click ZIP export is a Pro spell",
    description: "Download any build as a ready-to-run project folder with either plan.",
  },
  manual: {
    title: "Unlock unlimited tails",
    description: "Two ways to keep the fox-fire burning. Pick the one that fits.",
  },
};

const BYOK_FEATURES = [
  "Unlimited builds with your own Claude or OpenRouter key",
  "All five tails",
  "1-Click ZIP export",
  "Your key stays in your browser",
];

const PRO_FEATURES = [
  "Hosted access to every tail, no key needed",
  "Smart Claude prompt caching for faster repeat builds",
  "Unlimited builds (fair use)",
  "1-Click ZIP export",
  "Priority queue",
];

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;

function FeatureList({ items, accent }: { items: string[]; accent: "violet" | "cyan" }) {
  return (
    <ul className="space-y-2 text-[13px] leading-snug text-fox-mist sm:space-y-2.5 sm:text-[13.5px]">
      {items.map((item) => (
        <li key={item} className="flex items-start gap-2.5">
          <span
            className={`mt-px grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full ${
              accent === "cyan" ? "bg-spirit-cyan/15 text-spirit-cyan" : "bg-spirit-violet/15 text-spirit-violet-soft"
            }`}
            aria-hidden="true"
          >
            <Check className="h-3 w-3" strokeWidth={2.5} />
          </span>
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}

/** Inline note shown when a checkout link has not been configured. */
function MissingCheckoutNote({ show, id }: { show: boolean; id: string }) {
  const reduce = useReducedMotion();
  return (
    <div id={id} role="status" aria-live="polite">
      <AnimatePresence initial={false}>
        {show && (
          <motion.p
            initial={reduce ? { opacity: 0 } : { opacity: 0, height: 0 }}
            animate={reduce ? { opacity: 1 } : { opacity: 1, height: "auto" }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, height: 0 }}
            transition={{ duration: 0.22 }}
            className="overflow-hidden"
          >
            <span className="mt-2.5 flex items-start gap-2 rounded-xl border border-spirit-pink/25 bg-spirit-pink/[0.06] px-3 py-2.5 text-[12.5px] leading-snug text-fox-mist">
              <Info className="mt-px h-4 w-4 shrink-0 text-spirit-pink" strokeWidth={1.75} aria-hidden="true" />
              <span>
                Checkout isn&apos;t connected yet — add a payment link in <code className="font-mono text-[12px] text-fox-white">.env</code> (see README).
              </span>
            </span>
          </motion.p>
        )}
      </AnimatePresence>
    </div>
  );
}

/** A checkout CTA: a real link when configured, otherwise a button that explains what's missing. */
function CheckoutCta({
  href,
  children,
  variant,
  noteId,
  onMissing,
}: {
  href: string;
  children: React.ReactNode;
  variant: "primary" | "secondary";
  noteId: string;
  onMissing: () => void;
}) {
  const base =
    "focus-ring group inline-flex h-12 w-full items-center justify-center gap-2 rounded-xl px-4 text-[14px] font-semibold transition";
  const look =
    variant === "primary"
      ? "bg-fox-white text-obsidian-950 shadow-[0_0_0_1px_rgba(255,255,255,.35),0_14px_40px_-12px_rgba(196,181,253,.7)] hover:-translate-y-px hover:bg-white hover:shadow-[0_0_0_1px_rgba(255,255,255,.45),0_18px_48px_-12px_rgba(167,139,250,.85)] active:translate-y-0"
      : "border border-white/15 bg-white/[0.06] text-fox-white hover:-translate-y-px hover:border-white/25 hover:bg-white/[0.1] active:translate-y-0";
  const icon = <ArrowUpRight className="h-4 w-4 transition group-hover:-translate-y-px group-hover:translate-x-px" strokeWidth={1.75} aria-hidden="true" />;

  if (href) {
    return (
      <a href={href} target="_blank" rel="noopener noreferrer" className={`${base} ${look}`}>
        {children}
        {icon}
        <span className="sr-only">(opens checkout in a new tab)</span>
      </a>
    );
  }
  return (
    <button type="button" onClick={onMissing} aria-describedby={noteId} className={`${base} ${look}`}>
      {children}
      {icon}
    </button>
  );
}

function BillingToggle({ value, onChange }: { value: Billing; onChange: (b: Billing) => void }) {
  const reduce = useReducedMotion();
  const options: { id: Billing; label: string }[] = [
    { id: "lifetime", label: "Lifetime" },
    { id: "monthly", label: "Monthly" },
  ];
  const onKeyDown = (e: React.KeyboardEvent<HTMLButtonElement>) => {
    if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(e.key)) {
      e.preventDefault();
      const next: Billing = value === "lifetime" ? "monthly" : "lifetime";
      onChange(next);
      (e.currentTarget.parentElement?.querySelector(`[data-billing="${next}"]`) as HTMLButtonElement | null)?.focus();
    }
  };
  return (
    <div role="radiogroup" aria-label="Billing" className="relative inline-grid grid-cols-2 rounded-full border border-white/10 bg-obsidian-950/60 p-1">
      {/* One always-mounted pill moved by x. A layoutId pill inside the Modal's
          AnimatePresence would keep the dialog from finishing its exit. */}
      <motion.span
        aria-hidden="true"
        className="pointer-events-none absolute bottom-1 left-1 top-1 w-[calc(50%-4px)] rounded-full bg-spirit-violet-soft"
        initial={false}
        animate={{ x: value === "monthly" ? "100%" : "0%" }}
        transition={reduce ? { duration: 0 } : SPRING}
      />
      {options.map((o) => {
        const active = o.id === value;
        return (
          <button
            key={o.id}
            type="button"
            role="radio"
            aria-checked={active}
            tabIndex={active ? 0 : -1}
            data-billing={o.id}
            onClick={() => onChange(o.id)}
            onKeyDown={onKeyDown}
            className={`focus-ring relative h-8 rounded-full px-3.5 text-[12px] font-medium transition-colors ${active ? "text-obsidian-950" : "text-fox-muted hover:text-fox-white"}`}
          >
            <span className="relative">{o.label}</span>
          </button>
        );
      })}
    </div>
  );
}

function Price({ amount, unit }: { amount: string; unit: string }) {
  const reduce = useReducedMotion();
  return (
    <div className="flex items-baseline gap-1.5" aria-live="polite">
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.span
          key={amount}
          className="text-[30px] font-semibold leading-none tracking-tight text-fox-white sm:text-[34px]"
          initial={reduce ? { opacity: 0 } : { opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={reduce ? { opacity: 0 } : { opacity: 0, y: 10 }}
          transition={SPRING}
        >
          {amount}
        </motion.span>
      </AnimatePresence>
      <span className="text-[13px] text-fox-muted">{unit}</span>
    </div>
  );
}

export function UpgradeModal({ open, reason, onClose, onOpenByok, onRefill }: UpgradeModalProps) {
  const reduce = useReducedMotion();
  const uid = useId().replace(/:/g, "");
  const [billing, setBilling] = useState<Billing>("lifetime");
  const [missing, setMissing] = useState<"byok" | "pro" | null>(null);

  // Fresh state each time the dialog opens.
  useEffect(() => {
    if (open) setMissing(null);
  }, [open]);

  const copy = COPY[reason];
  const byokHref = billing === "lifetime" ? CHECKOUT.byokLifetime : CHECKOUT.byokMonthly;
  const byokNoteId = `${uid}-byok-note`;
  const proNoteId = `${uid}-pro-note`;

  return (
    <Modal open={open} onClose={onClose} title={copy.title} description={copy.description} widthClass="sm:max-w-3xl">
      <div className="grid gap-3 sm:grid-cols-2 sm:gap-4">
        {/* Tier 1: BYOK Pass */}
        <article aria-labelledby={`${uid}-byok`} className="flex flex-col rounded-2xl border border-white/10 bg-white/[0.03] p-4 sm:p-5">
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-center gap-3">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl border border-spirit-violet/25 bg-spirit-violet/10 text-spirit-violet-soft" aria-hidden="true">
                <KeyRound className="h-[18px] w-[18px]" strokeWidth={1.75} />
              </span>
              <div>
                <h3 id={`${uid}-byok`} className="text-[15px] font-semibold tracking-tight text-fox-white">
                  BYOK Pass
                </h3>
                <p className="text-[12.5px] text-fox-muted">Bring your own key</p>
              </div>
            </div>
          </div>

          <div className="mt-4 flex flex-wrap items-end justify-between gap-3 sm:mt-5">
            <Price amount={billing === "lifetime" ? "$19" : "$9"} unit={billing === "lifetime" ? "lifetime" : "/ mo"} />
            <BillingToggle value={billing} onChange={setBilling} />
          </div>
          <p className="mt-2 text-[12.5px] text-fox-muted">
            {billing === "lifetime" ? "Pay once, keep it forever." : "Billed monthly. Cancel anytime."}
          </p>

          <div className="my-4 h-px bg-white/[0.07] sm:my-5" />
          <FeatureList items={BYOK_FEATURES} accent="violet" />

          <div className="mt-auto pt-5 sm:pt-6">
            <CheckoutCta href={byokHref} variant="secondary" noteId={byokNoteId} onMissing={() => setMissing("byok")}>
              Get BYOK Pass
            </CheckoutCta>
            <MissingCheckoutNote show={missing === "byok"} id={byokNoteId} />
            <button
              type="button"
              onClick={onOpenByok}
              className="focus-ring mt-1.5 flex h-11 w-full items-center justify-center gap-1.5 rounded-xl text-[13px] font-medium text-fox-muted transition hover:text-fox-white"
            >
              Already have a key? <span className="text-spirit-violet-soft underline decoration-spirit-violet/40 underline-offset-4">Connect it</span>
            </button>
          </div>
        </article>

        {/* Tier 2: NineTail Pro (highlighted) */}
        <article aria-labelledby={`${uid}-pro`} className="relative isolate overflow-hidden rounded-2xl p-px">
          {/* Animated gradient border: a rotating conic gradient behind a 1px inset card. */}
          <div aria-hidden="true" className="absolute inset-0 -z-10 bg-spirit-violet/45" />
          <motion.div
            aria-hidden="true"
            className="absolute left-1/2 top-1/2 -z-10 aspect-square w-[180%] -translate-x-1/2 -translate-y-1/2"
            style={{
              background:
                "conic-gradient(from 0deg, rgba(124,58,237,.0) 0deg, #a78bfa 60deg, #f6f4ff 100deg, #67e8f9 140deg, rgba(103,232,249,0) 200deg, rgba(124,58,237,0) 260deg, #f0abfc 320deg, rgba(124,58,237,0) 360deg)",
            }}
            animate={{ rotate: reduce ? 0 : 360 }}
            transition={reduce ? { duration: 0 } : { duration: 7, repeat: Infinity, ease: "linear" }}
          />
          <div className="relative flex h-full flex-col rounded-[15px] bg-[linear-gradient(180deg,rgba(28,22,52,.97),rgba(12,11,22,.98))] p-4 sm:p-5">
            <div aria-hidden="true" className="pointer-events-none absolute inset-x-0 top-0 h-28 rounded-t-[15px] bg-[radial-gradient(80%_100%_at_50%_0%,rgba(167,139,250,.22),transparent)]" />

            <div className="relative flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-fox-white text-spirit-violet-deep shadow-glow-white" aria-hidden="true">
                  <Crown className="h-[18px] w-[18px]" strokeWidth={1.75} />
                </span>
                <div>
                  <h3 id={`${uid}-pro`} className="text-[15px] font-semibold tracking-tight text-fox-white">
                    NineTail Pro
                  </h3>
                  <p className="whitespace-nowrap text-[12.5px] text-fox-muted">Every tail, hosted</p>
                </div>
              </div>
              <span className="shrink-0 whitespace-nowrap rounded-full border border-spirit-violet/40 bg-spirit-violet/15 px-2.5 py-[5px] text-[11px] font-semibold leading-none tracking-wide text-spirit-violet-soft shadow-[0_0_16px_-4px_rgba(167,139,250,.6)]">
                Most powerful
              </span>
            </div>

            <div className="relative mt-4 flex min-h-[36px] items-end sm:mt-5">
              <Price amount="$15" unit="/ mo" />
            </div>
            <p className="relative mt-2 text-[12.5px] text-fox-muted">Billed monthly. Cancel anytime.</p>

            <div className="relative my-4 h-px bg-white/[0.08] sm:my-5" />
            <div className="relative">
              <FeatureList items={PRO_FEATURES} accent="cyan" />
            </div>

            <div className="relative mt-auto pt-5 sm:pt-6">
              <CheckoutCta href={CHECKOUT.pro} variant="primary" noteId={proNoteId} onMissing={() => setMissing("pro")}>
                Go Pro
              </CheckoutCta>
              <MissingCheckoutNote show={missing === "pro"} id={proNoteId} />
            </div>
          </div>
        </article>
      </div>

      <div className="mt-5 flex flex-col items-center justify-between gap-2 text-center sm:flex-row sm:text-left">
        <p className="text-[12.5px] text-fox-muted">Payments are handled securely by the checkout provider. Cancel anytime.</p>
        {SHOW_REFILL && onRefill && (
          <button
            type="button"
            onClick={onRefill}
            className="focus-ring inline-flex h-10 shrink-0 items-center gap-1.5 rounded-lg px-2.5 font-mono text-[12px] text-fox-muted transition hover:bg-white/5 hover:text-fox-white"
          >
            <RotateCcw className="h-3.5 w-3.5" strokeWidth={1.75} aria-hidden="true" />
            Refill demo tails
          </button>
        )}
      </div>
    </Modal>
  );
}

export default UpgradeModal;
