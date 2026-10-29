"use client";

import { motion, useReducedMotion } from "framer-motion";
import { ChartLine, Check, Gamepad2, Rocket, ShoppingBag, type LucideIcon } from "lucide-react";
import { useId, type CSSProperties } from "react";
import { TEMPLATES } from "@/lib/templates";
import type { Target, Template, TemplateIcon } from "@/lib/types";

export interface TemplateVaultProps {
  onSelect: (template: Template) => void;
  activeId?: Template["id"] | null;
  disabled?: boolean;
  /** Override the starter list (lab harnesses, tests). Defaults to TEMPLATES. */
  templates?: Template[];
  className?: string;
}

const ICONS: Record<TemplateIcon, LucideIcon> = {
  rocket: Rocket,
  gamepad: Gamepad2,
  store: ShoppingBag,
  chart: ChartLine,
};

const TARGET_BADGE: Record<Target, string> = {
  web: "WEB",
  imgui: "C++",
  ctk: "PY",
};

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;

function rgba(hex: string, alpha: number): string {
  const h = hex.replace("#", "");
  const full = h.length === 3 ? h.split("").map((c) => c + c).join("") : h.padEnd(6, "0").slice(0, 6);
  const n = Number.parseInt(full, 16) || 0;
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
}

/** "UI Remixer": four one-click starter builds, each with a hand-drawn mini preview. */
export function TemplateVault({
  onSelect,
  activeId = null,
  disabled = false,
  templates = TEMPLATES,
  className = "",
}: TemplateVaultProps) {
  const uid = useId().replace(/:/g, "");
  const reduce = useReducedMotion();

  return (
    <div className={className}>
      <div className="mb-3.5 flex items-end justify-between gap-3">
        <div className="min-w-0">
          <p className="eyebrow">Template Vault</p>
          <h2 className="mt-1 truncate text-[15px] font-semibold leading-tight tracking-tight text-fox-white">UI Remixer</h2>
        </div>
        <p className="mb-px shrink-0 text-[12px] text-fox-muted">Tap to load, then remix</p>
      </div>

      <div className={`grid grid-cols-2 gap-2 sm:gap-2.5 ${disabled ? "opacity-60" : ""}`}>
        {templates.map((t) => {
          const active = t.id === activeId;
          const Icon = ICONS[t.icon] ?? Rocket;
          const vars = {
            "--tv-ring": rgba(t.accent, 0.6),
            "--tv-glow": rgba(t.accent, 0.38),
            "--tv-tint": rgba(t.accent, 0.2),
          } as CSSProperties;
          return (
            <motion.button
              key={t.id}
              type="button"
              aria-pressed={active}
              aria-label={`${t.name}. ${t.tagline}. ${TARGET_BADGE[t.target]} template${active ? ", loaded" : ""}`}
              disabled={disabled}
              onClick={() => onSelect(t)}
              // Always pass gesture props (even as no-ops): framer-motion adds tabindex for
              // whileTap, and a server/client difference would break hydration.
              whileHover={reduce || disabled ? { y: 0 } : { y: -2 }}
              whileTap={reduce || disabled ? { scale: 1 } : { scale: 0.98 }}
              transition={SPRING}
              style={vars}
              className={`focus-ring group relative flex min-w-0 flex-col overflow-hidden rounded-2xl border bg-obsidian-900/50 text-left transition-[border-color,box-shadow,background-color] duration-200 disabled:cursor-not-allowed ${
                active
                  ? "border-[color:var(--tv-ring)] shadow-[0_0_0_1px_var(--tv-ring),0_14px_36px_-12px_var(--tv-glow)]"
                  : "border-white/[0.08] hover:border-[color:var(--tv-ring)] hover:shadow-[0_14px_36px_-14px_var(--tv-glow)]"
              }`}
            >
              {/* Thumbnail: a tiny window with a chrome strip, so badges never cover the drawing. */}
              <span
                aria-hidden="true"
                className="relative block w-full overflow-hidden border-b border-white/[0.06]"
                style={{
                  background: `radial-gradient(120% 90% at 85% 0%, ${rgba(t.accent, 0.22)} 0%, transparent 60%), radial-gradient(80% 80% at 0% 100%, ${rgba(
                    t.accent,
                    0.08,
                  )} 0%, transparent 70%), #0a0a12`,
                }}
              >
                <span className="absolute inset-0 opacity-[0.35] [background-image:radial-gradient(rgba(255,255,255,.12)_1px,transparent_1px)] [background-size:10px_10px]" />
                <span className="relative flex h-7 items-center justify-between border-b border-white/[0.05] bg-obsidian-950/40 px-2">
                  <span className="flex min-w-0 items-center gap-1.5">
                    <Icon className="h-3.5 w-3.5 shrink-0" strokeWidth={1.75} style={{ color: t.accent }} />
                    <span className="font-mono text-[11px] font-medium leading-none tracking-wide text-fox-mist">{TARGET_BADGE[t.target]}</span>
                  </span>
                  {active ? (
                    <span
                      className="grid h-[18px] w-[18px] place-items-center rounded-full text-obsidian-950"
                      style={{ background: t.accent, boxShadow: `0 0 10px ${rgba(t.accent, 0.75)}` }}
                    >
                      <Check className="h-3 w-3" strokeWidth={3} />
                    </span>
                  ) : (
                    <span className="flex gap-[3px]">
                      <span className="h-[5px] w-[5px] rounded-full bg-white/15" />
                      <span className="h-[5px] w-[5px] rounded-full bg-white/15" />
                      <span className="h-[5px] w-[5px] rounded-full bg-white/15" />
                    </span>
                  )}
                </span>
                <span className="relative block h-[76px] px-1.5 py-1.5 sm:h-[82px]">
                  <span className="block h-full w-full transition-transform duration-300 group-hover:scale-[1.04]">
                    <Thumb kind={t.id} accent={t.accent} gid={`${uid}-${t.id}`} />
                  </span>
                </span>
              </span>

              {/* Copy */}
              <span className="flex min-w-0 flex-1 flex-col px-2.5 pb-2.5 pt-2 sm:px-3 sm:pb-3">
                <span className="line-clamp-2 text-[13px] font-semibold leading-[17px] tracking-tight text-fox-white">{t.name}</span>
                <span className="mt-1 line-clamp-2 text-[12px] leading-[16px] text-fox-muted">{t.tagline}</span>
              </span>
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Mini previews, drawn in SVG so they stay crisp at any card width.
// ---------------------------------------------------------------------------

function Thumb({ kind, accent, gid }: { kind: Template["id"]; accent: string; gid: string }) {
  const common = {
    viewBox: "0 0 120 68",
    className: "h-full w-full",
    preserveAspectRatio: "xMidYMid meet",
    fill: "none",
  } as const;

  if (kind === "saas-waitlist") {
    return (
      <svg {...common}>
        {/* nav */}
        <circle cx="13" cy="9" r="2.6" fill={accent} />
        <rect x="18" y="7.8" width="14" height="2.4" rx="1.2" fill="#fff" opacity=".35" />
        <rect x="93" y="5.5" width="17" height="6.5" rx="3.25" fill="#fff" opacity=".12" />
        {/* hero */}
        <rect x="10" y="20" width="54" height="5.2" rx="2.6" fill="#fff" opacity=".9" />
        <rect x="10" y="28.5" width="38" height="5.2" rx="2.6" fill={accent} />
        <rect x="10" y="38" width="48" height="2.4" rx="1.2" fill="#fff" opacity=".28" />
        {/* email capture */}
        <rect x="10" y="46" width="58" height="12" rx="6" fill="#fff" fillOpacity=".05" stroke="#fff" strokeOpacity=".2" />
        <rect x="15" y="50.8" width="20" height="2.4" rx="1.2" fill="#fff" opacity=".3" />
        <rect x="47" y="47.6" width="19.4" height="8.8" rx="4.4" fill={accent} />
        {/* app window */}
        <rect x="75" y="18" width="37" height="41" rx="4" fill="#fff" fillOpacity=".04" stroke="#fff" strokeOpacity=".15" />
        <circle cx="79.5" cy="22.4" r="1.1" fill="#fff" opacity=".35" />
        <circle cx="83" cy="22.4" r="1.1" fill="#fff" opacity=".35" />
        <circle cx="86.5" cy="22.4" r="1.1" fill="#fff" opacity=".35" />
        <rect x="79" y="28.5" width="21" height="2.4" rx="1.2" fill="#fff" opacity=".55" />
        <rect x="79" y="33.5" width="29" height="2" rx="1" fill="#fff" opacity=".2" />
        <rect x="79" y="38" width="25" height="2" rx="1" fill="#fff" opacity=".2" />
        <rect x="79" y="44.5" width="29" height="10" rx="2.5" fill={accent} fillOpacity=".16" stroke={accent} strokeOpacity=".55" />
        <rect x="82" y="48.6" width="15" height="1.8" rx=".9" fill={accent} opacity=".9" />
      </svg>
    );
  }

  if (kind === "imgui-mod-menu") {
    return (
      <svg {...common}>
        <defs>
          <linearGradient id={`${gid}-sweep`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor={accent} stopOpacity=".55" />
            <stop offset="1" stopColor={accent} stopOpacity="0" />
          </linearGradient>
        </defs>
        {/* window */}
        <rect x="14" y="4" width="92" height="60" rx="3" fill="#0b0b13" stroke="#fff" strokeOpacity=".16" />
        <path d="M14 7a3 3 0 0 1 3-3h86a3 3 0 0 1 3 3v5H14Z" fill={accent} fillOpacity=".3" />
        <rect x="18" y="7" width="24" height="2" rx="1" fill="#fff" opacity=".85" />
        <rect x="98" y="6.6" width="4" height="2.8" rx=".8" fill="#fff" opacity=".35" />
        {/* tabs */}
        <rect x="18" y="15.5" width="15" height="5" rx="1" fill={accent} />
        <rect x="35" y="15.5" width="15" height="5" rx="1" fill="#fff" fillOpacity=".1" />
        <rect x="52" y="15.5" width="15" height="5" rx="1" fill="#fff" fillOpacity=".1" />
        <rect x="18" y="22.3" width="84" height=".7" fill={accent} opacity=".5" />
        {/* checkboxes */}
        <rect x="18" y="26.5" width="5" height="5" rx="1" fill={accent} />
        <path d="m19.2 29 1.2 1.1 1.9-2.2" stroke="#0b0b13" strokeWidth=".9" strokeLinecap="round" strokeLinejoin="round" />
        <rect x="26" y="27.8" width="20" height="2.4" rx="1.2" fill="#fff" opacity=".5" />
        <rect x="18" y="34" width="5" height="5" rx="1" stroke="#fff" strokeOpacity=".35" strokeWidth=".8" />
        <rect x="26" y="35.3" width="16" height="2.4" rx="1.2" fill="#fff" opacity=".35" />
        {/* sliders */}
        <rect x="18" y="44" width="46" height="4.5" rx="1" fill="#fff" fillOpacity=".08" />
        <rect x="18" y="44" width="30" height="4.5" rx="1" fill={accent} fillOpacity=".45" />
        <rect x="46.5" y="43" width="3" height="6.5" rx="1" fill={accent} />
        <rect x="18" y="53" width="46" height="4.5" rx="1" fill="#fff" fillOpacity=".08" />
        <rect x="18" y="53" width="17" height="4.5" rx="1" fill={accent} fillOpacity=".45" />
        <rect x="33.5" y="52" width="3" height="6.5" rx="1" fill={accent} />
        {/* radar */}
        <circle cx="86" cy="43" r="14" fill={accent} fillOpacity=".05" stroke={accent} strokeOpacity=".45" strokeWidth=".8" />
        <circle cx="86" cy="43" r="8" stroke={accent} strokeOpacity=".25" strokeWidth=".6" />
        <path d="M72 43h28M86 29v28" stroke={accent} strokeOpacity=".18" strokeWidth=".5" />
        <path d="M86 43 L96 33 A14 14 0 0 1 100 43 Z" fill={`url(#${gid}-sweep)`} />
        <circle cx="93" cy="38" r="1.4" fill="#f87171" />
        <circle cx="80" cy="49" r="1.4" fill="#f87171" />
        <circle cx="89" cy="50" r="1.2" fill={accent} />
        <circle cx="86" cy="43" r="1.3" fill="#fff" />
      </svg>
    );
  }

  if (kind === "link-in-bio") {
    return (
      <svg {...common}>
        <defs>
          <linearGradient id={`${gid}-avatar`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#fff" />
            <stop offset="1" stopColor={accent} />
          </linearGradient>
        </defs>
        {/* side product cards */}
        <rect x="9" y="17" width="25" height="31" rx="3.5" fill="#fff" fillOpacity=".04" stroke="#fff" strokeOpacity=".12" transform="rotate(-6 21 32)" />
        <rect x="12.5" y="21" width="17" height="12" rx="2" fill={accent} fillOpacity=".22" transform="rotate(-6 21 32)" />
        <rect x="12.5" y="37" width="12" height="2.2" rx="1.1" fill="#fff" opacity=".4" transform="rotate(-6 21 32)" />
        <rect x="86" y="20" width="25" height="31" rx="3.5" fill="#fff" fillOpacity=".04" stroke="#fff" strokeOpacity=".12" transform="rotate(6 98 35)" />
        <rect x="89.5" y="24" width="17" height="12" rx="2" fill="#fff" fillOpacity=".1" transform="rotate(6 98 35)" />
        <rect x="89.5" y="40" width="9" height="3.4" rx="1.7" fill={accent} transform="rotate(6 98 35)" />
        {/* phone */}
        <rect x="41" y="2" width="38" height="64" rx="7" fill="#0b0b12" stroke="#fff" strokeOpacity=".24" />
        <rect x="54" y="5" width="12" height="2" rx="1" fill="#fff" opacity=".18" />
        <circle cx="60" cy="16.5" r="5.5" fill={`url(#${gid}-avatar)`} />
        <rect x="51" y="25" width="18" height="2.4" rx="1.2" fill="#fff" opacity=".75" />
        <rect x="54" y="29.4" width="12" height="1.6" rx=".8" fill="#fff" opacity=".3" />
        <rect x="46" y="34" width="28" height="7" rx="3.5" fill={accent} />
        <rect x="46" y="43.5" width="28" height="7" rx="3.5" fill="#fff" fillOpacity=".08" stroke="#fff" strokeOpacity=".14" />
        <rect x="46" y="53" width="28" height="7" rx="3.5" fill="#fff" fillOpacity=".08" stroke="#fff" strokeOpacity=".14" />
      </svg>
    );
  }

  // gaming-dashboard
  return (
    <svg {...common}>
      <defs>
        <linearGradient id={`${gid}-area`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={accent} stopOpacity=".4" />
          <stop offset="1" stopColor={accent} stopOpacity="0" />
        </linearGradient>
      </defs>
      {[8, 44, 80].map((x, i) => (
        <g key={x}>
          <rect x={x} y="5" width="32" height="18" rx="3" fill="#fff" fillOpacity=".045" stroke="#fff" strokeOpacity=".12" />
          <rect x={x + 4} y="9" width="12" height="1.8" rx=".9" fill="#fff" opacity=".35" />
          <rect x={x + 4} y="14" width={i === 0 ? 18 : i === 1 ? 14 : 20} height="4.6" rx="1.4" fill={i === 0 ? accent : "#fff"} opacity={i === 0 ? 1 : 0.8} />
        </g>
      ))}
      {/* chart */}
      <path d="M8 38h104M8 48h104M8 58h104" stroke="#fff" strokeOpacity=".07" strokeWidth=".6" />
      <path
        d="M8 56 L20 52 L32 54 L44 45 L56 48 L68 39 L80 42 L92 33 L104 35 L112 30 L112 62 L8 62 Z"
        fill={`url(#${gid}-area)`}
      />
      <path
        d="M8 56 L20 52 L32 54 L44 45 L56 48 L68 39 L80 42 L92 33 L104 35 L112 30"
        stroke={accent}
        strokeWidth="1.6"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      <circle cx="112" cy="30" r="2.2" fill={accent} />
      <circle cx="112" cy="30" r="4.2" stroke={accent} strokeOpacity=".4" />
    </svg>
  );
}
