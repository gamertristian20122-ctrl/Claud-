"use client";

import { motion } from "framer-motion";
import { Check, Copy } from "lucide-react";
import { memo, useEffect, useMemo, useRef } from "react";
import { LANGUAGE_DOT, LANGUAGE_LABEL, TOKEN_COLORS, TOKEN_STYLES, plainLines, sameTokens, tokenizeLines, type Token } from "@/lib/highlight";
import type { CodeLanguage } from "@/lib/types";
import { useCopy, useIsoLayoutEffect, useLoopMotion } from "./output-kit";

export interface CodeViewProps {
  code: string;
  language: CodeLanguage;
  filename: string;
  /** Code is still arriving: shows a caret and follows the end of the file. */
  streaming?: boolean;
  /** Tighter header and 12px text everywhere (side-by-side layouts). */
  compact?: boolean;
  className?: string;
  /** Hide the header bar (filename, line count, copy). */
  hideHeader?: boolean;
  /** Block user scrolling (used by the collapsed code peek). */
  scrollLocked?: boolean;
  /** 0-based line to scroll to the top when not streaming. */
  focusLine?: number;
  /** Extra controls at the right end of the header. */
  headerActions?: React.ReactNode;
}

/** Files longer than this render without highlighting. */
const PLAIN_LINE_LIMIT = 4000;

const LineRow = memo(
  function LineRow({ n, tokens, gutter, caret, current }: { n: number; tokens: Token[]; gutter: number; caret: boolean; current: boolean }) {
    return (
      <div className={`flex ${current ? "bg-spirit-cyan/[0.04]" : ""}`}>
        <span
          aria-hidden="true"
          className={`sticky left-0 z-[1] shrink-0 select-none border-r border-white/[0.05] bg-[#08080f] pl-3 pr-3 text-right tabular-nums ${
            current ? "text-spirit-cyan/80" : "text-fox-dim/80"
          }`}
          style={{ width: `${gutter + 2.6}ch` }}
        >
          {n}
        </span>
        <span className="whitespace-pre pl-4 pr-8">
          {tokens.length === 0 && !caret ? " " : null}
          {tokens.map((t, i) => (
            <span key={i} style={{ color: TOKEN_COLORS[t.kind], ...TOKEN_STYLES[t.kind] }}>
              {t.text}
            </span>
          ))}
          {caret ? <Caret /> : null}
        </span>
      </div>
    );
  },
  (a, b) => a.n === b.n && a.gutter === b.gutter && a.caret === b.caret && a.current === b.current && sameTokens(a.tokens, b.tokens),
);

function Caret() {
  const blink = useLoopMotion();
  return (
    <motion.span
      aria-hidden="true"
      className="ml-px inline-block h-[1.15em] w-[0.55em] translate-y-[0.2em] rounded-[1px] bg-spirit-cyan shadow-[0_0_10px_rgba(103,232,249,0.8)]"
      initial={{ opacity: 1 }}
      animate={blink ? { opacity: [1, 1, 0.15, 0.15] } : { opacity: 1 }}
      transition={blink ? { duration: 1, repeat: Infinity, times: [0, 0.5, 0.55, 1], ease: "linear" } : undefined}
    />
  );
}

export function CopyButton({
  text,
  compact,
  label = "Copy",
  className = "",
  labelClassName = "",
}: {
  text: string;
  compact?: boolean;
  label?: string;
  className?: string;
  /** Classes for the text label, e.g. to hide it on very narrow screens. */
  labelClassName?: string;
}) {
  const { copied, copy } = useCopy();
  return (
    <button
      type="button"
      onClick={() => void copy(text)}
      disabled={!text}
      aria-label={copied ? "Copied to clipboard" : `${label} code`}
      className={`focus-ring relative inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-white/10 bg-white/[0.04] font-medium text-fox-mist transition before:absolute before:-inset-1.5 before:content-[''] hover:border-white/20 hover:bg-white/[0.08] hover:text-fox-white disabled:pointer-events-none disabled:opacity-40 ${
        compact ? "h-8 px-2.5 text-[12px]" : "h-8 px-3 text-[12px]"
      } ${className}`}
    >
      {copied ? <Check className="h-3.5 w-3.5 text-spirit-cyan" strokeWidth={2} /> : <Copy className="h-3.5 w-3.5" strokeWidth={1.75} />}
      <span aria-live="polite" className={labelClassName}>
        {copied ? "Copied" : label}
      </span>
    </button>
  );
}

export function CodeView({
  code,
  language,
  filename,
  streaming = false,
  compact = false,
  className = "",
  hideHeader = false,
  scrollLocked = false,
  focusLine,
  headerActions,
}: CodeViewProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const stickRef = useRef(true);

  const lines = useMemo(() => {
    const lineCount = code ? code.split("\n").length : 0;
    return lineCount > PLAIN_LINE_LIMIT ? plainLines(code) : tokenizeLines(code, language);
  }, [code, language]);

  const count = code ? lines.length : 0;
  const gutter = String(Math.max(count, 1)).length;

  // Follow the stream unless the reader scrolled up.
  useEffect(() => {
    if (streaming) stickRef.current = true;
  }, [streaming]);

  useIsoLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el || !streaming || !stickRef.current) return;
    el.scrollTop = el.scrollHeight;
  }, [code, streaming]);

  useIsoLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el || streaming || focusLine === undefined) return;
    const row = el.querySelector<HTMLElement>(`[data-line="${focusLine}"]`);
    el.scrollTop = row ? Math.max(0, row.offsetTop) : 0;
  }, [focusLine, streaming, code]);

  const onScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    stickRef.current = el.scrollHeight - el.scrollTop - el.clientHeight < 48;
  };

  const textSize = compact ? "text-[12px] leading-[19px]" : "text-[12px] leading-[19px] md:text-[13px] md:leading-[21px]";

  return (
    <div className={`flex min-h-0 min-w-0 flex-col overflow-hidden bg-[#08080f] ${className}`}>
      {!hideHeader && (
        <div className={`flex shrink-0 items-center gap-2 border-b border-white/[0.06] bg-white/[0.02] ${compact ? "h-11 px-2.5" : "h-12 px-3"}`}>
          <div className="flex min-w-0 items-center gap-2 rounded-lg border border-white/[0.08] bg-obsidian-950/60 px-2.5 py-1.5">
            <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: LANGUAGE_DOT[language], boxShadow: `0 0 8px ${LANGUAGE_DOT[language]}` }} />
            <span className="truncate font-mono text-[12px] text-fox-white">{filename}</span>
          </div>
          <span className="shrink-0 font-mono text-[11px] text-fox-muted">
            <span className="hidden sm:inline">{LANGUAGE_LABEL[language]} · </span>
            {count.toLocaleString("en-US")} {count === 1 ? "line" : "lines"}
          </span>
          <span className="flex-1" />
          {streaming && (
            <span className="hidden items-center gap-1.5 font-mono text-[11px] text-spirit-cyan sm:inline-flex">
              <span className="h-1.5 w-1.5 animate-soft-pulse rounded-full bg-spirit-cyan" />
              streaming
            </span>
          )}
          {headerActions}
          <CopyButton text={code} compact={compact} />
        </div>
      )}
      <div
        ref={scrollRef}
        onScroll={onScroll}
        tabIndex={scrollLocked ? -1 : 0}
        role="region"
        aria-label={`${filename} source`}
        aria-busy={streaming || undefined}
        className={`focus-ring relative min-h-0 flex-1 scrollbar-thin ${scrollLocked ? "overflow-hidden" : "overflow-auto overscroll-contain"}`}
      >
        <div className={`min-w-max py-3 font-mono ${textSize}`} style={{ tabSize: 2, MozTabSize: 2, fontVariantLigatures: "none", fontFeatureSettings: '"liga" 0, "calt" 0' } as React.CSSProperties}>
          {count === 0 && streaming ? (
            <div className="flex">
              <span className="sticky left-0 shrink-0 select-none border-r border-white/[0.05] bg-[#08080f] pl-3 pr-3 text-right text-spirit-cyan/80" style={{ width: "3.6ch" }}>
                1
              </span>
              <span className="whitespace-pre pl-4 text-fox-dim">
                <Caret />
              </span>
            </div>
          ) : (
            lines.map((tokens, i) => (
              <div key={i} data-line={i}>
                <LineRow n={i + 1} tokens={tokens} gutter={gutter} caret={streaming && i === lines.length - 1} current={streaming && i === lines.length - 1} />
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default CodeView;
