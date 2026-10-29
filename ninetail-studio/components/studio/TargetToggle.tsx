"use client";

import { motion, useReducedMotion } from "framer-motion";
import { Cpu, Globe, SquareTerminal, type LucideIcon } from "lucide-react";
import { Fragment, useId, useRef, type KeyboardEvent } from "react";
import { TARGETS, getTarget } from "@/lib/models";
import type { Target } from "@/lib/types";

export interface TargetToggleProps {
  value: Target;
  onChange: (target: Target) => void;
  disabled?: boolean;
  className?: string;
}

const ICONS: Record<Target, LucideIcon> = {
  web: Globe,
  imgui: Cpu,
  ctk: SquareTerminal,
};

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;

/**
 * "Output" segmented control: Web UI / Desktop GUI (Dear ImGui) / Python (CustomTkinter).
 * A radiogroup with roving focus; arrow keys move and select.
 */
export function TargetToggle({ value, onChange, disabled = false, className = "" }: TargetToggleProps) {
  const uid = useId();
  const reduce = useReducedMotion();
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const headingId = `${uid}-heading`;
  const active = getTarget(value);

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>, index: number) => {
    if (disabled) return;
    const n = TARGETS.length;
    let next: number | null = null;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (index + 1) % n;
    else if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (index - 1 + n) % n;
    else if (e.key === "Home") next = 0;
    else if (e.key === "End") next = n - 1;
    if (next === null) return;
    e.preventDefault();
    onChange(TARGETS[next].id);
    refs.current[next]?.focus();
  };

  return (
    <div className={`[container-type:inline-size] ${className}`}>
      <div className="mb-3.5 flex items-end justify-between gap-3">
        <div className="min-w-0">
          <p className="eyebrow">Output</p>
          <h2 id={headingId} className="mt-1 text-[15px] font-semibold leading-tight tracking-tight text-fox-white">
            Build target
          </h2>
        </div>
        <span className="mb-px flex min-w-0 items-center gap-1.5 truncate font-mono text-[11px] text-fox-muted" aria-hidden="true">
          <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-spirit-cyan shadow-[0_0_8px_rgba(103,232,249,.8)]" />
          {active.file}
        </span>
      </div>

      <div
        role="radiogroup"
        aria-labelledby={headingId}
        aria-disabled={disabled || undefined}
        className={`grid grid-cols-3 gap-1 rounded-2xl border border-white/[0.07] bg-obsidian-950/60 p-1 transition-opacity ${
          disabled ? "opacity-60" : ""
        }`}
      >
        {TARGETS.map((t, i) => {
          const checked = t.id === value;
          const Icon = ICONS[t.id];
          const [tech, framework] = t.sub.split(" · ");
          return (
            <button
              key={t.id}
              ref={(el) => {
                refs.current[i] = el;
              }}
              type="button"
              role="radio"
              aria-checked={checked}
              aria-label={`${t.label}, ${t.sub}`}
              tabIndex={checked ? 0 : -1}
              disabled={disabled}
              onClick={() => {
                if (!checked) onChange(t.id);
              }}
              onKeyDown={(e) => onKeyDown(e, i)}
              className={`focus-ring group relative flex min-h-[96px] min-w-0 flex-col items-start justify-start gap-2.5 rounded-xl px-2 py-2.5 text-left transition-colors disabled:cursor-not-allowed [@container(min-width:370px)]:min-h-[92px] [@container(min-width:370px)]:px-2.5 ${
                checked ? "" : "hover:bg-white/[0.035]"
              }`}
            >
              {checked && (
                <motion.span
                  layoutId={`${uid}-pill`}
                  transition={reduce ? { duration: 0 } : SPRING}
                  aria-hidden="true"
                  className="absolute inset-0 rounded-xl border border-spirit-violet/45 bg-gradient-to-b from-white/[0.10] to-white/[0.03] shadow-[inset_0_1px_0_rgba(255,255,255,.10),0_0_0_1px_rgba(167,139,250,.10),0_10px_32px_-10px_rgba(124,58,237,.75)]"
                />
              )}
              <span
                aria-hidden="true"
                className={`relative grid h-8 w-8 shrink-0 place-items-center rounded-lg border transition-colors ${
                  checked
                    ? "border-spirit-violet/40 bg-spirit-violet/20 text-fox-white shadow-[0_0_18px_rgba(167,139,250,.45)]"
                    : "border-white/[0.06] bg-white/[0.03] text-fox-muted group-hover:text-fox-mist"
                }`}
              >
                <Icon className="h-[17px] w-[17px]" strokeWidth={1.75} />
              </span>
              <span className="relative block w-full min-w-0" aria-hidden="true">
                <span
                  className={`block whitespace-nowrap text-[12px] font-semibold leading-tight tracking-tight transition-colors [@container(min-width:320px)]:text-[13px] ${
                    checked ? "text-fox-white" : "text-fox-mist"
                  }`}
                >
                  {t.label}
                </span>
                <span
                  className={`mt-1 block text-[11px] leading-[14px] transition-colors ${
                    checked ? "text-spirit-violet-soft" : "text-fox-muted"
                  }`}
                >
                  {/* Narrow: tech and framework stacked. Wide: one line with a dot. */}
                  {framework ? (
                    <>
                      <span className="block whitespace-nowrap [@container(min-width:370px)]:inline">{tech}</span>
                      <span className="hidden opacity-60 [@container(min-width:370px)]:inline"> · </span>
                      <span className="block whitespace-nowrap [@container(min-width:370px)]:inline">{framework}</span>
                    </>
                  ) : (
                    softBreak(t.sub)
                  )}
                </span>
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

/** Allow a line break inside CamelCase names ("Custom|Tkinter") when the column is narrow. */
function softBreak(text: string) {
  const parts = text.replace(/([a-z])([A-Z])/g, "$1\u0000$2").split("\u0000");
  return parts.map((part, i) => (
    <Fragment key={part}>
      {i > 0 && <wbr />}
      {part}
    </Fragment>
  ));
}
