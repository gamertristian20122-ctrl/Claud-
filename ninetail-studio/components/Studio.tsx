"use client";

import { AnimatePresence, animate, motion, useReducedMotion } from "framer-motion";
import { ArrowDown, Eye, Flame, SlidersHorizontal, Square } from "lucide-react";
import { useCallback, useEffect, useLayoutEffect, useRef, useState, type KeyboardEvent } from "react";

import { Backdrop } from "@/components/Backdrop";
import { Navbar } from "@/components/Navbar";
import { UpgradeModal } from "@/components/UpgradeModal";
import { ByokModal } from "@/components/studio/ByokModal";
import { ModelSelector } from "@/components/studio/ModelSelector";
import { OutputPanel, type OutputTab } from "@/components/studio/OutputPanel";
import { PromptBox } from "@/components/studio/PromptBox";
import { STOPPED_MESSAGE, SpiritCore } from "@/components/studio/SpiritCore";
import { TargetToggle } from "@/components/studio/TargetToggle";
import { TemplateVault } from "@/components/studio/TemplateVault";
import { DEFAULT_MODEL, getModel, providerSupportsModel } from "@/lib/models";
import { useByok, useCredits } from "@/lib/storage";
import { getTemplate } from "@/lib/templates";
import type { MascotState, ModelId, ServerStatus, Target, Template, UpgradeReason } from "@/lib/types";
import { STATIC_DEMO, useGenerator } from "@/lib/useGenerator";
import { exportProjectZip } from "@/lib/zip";

type MobileView = "build" | "output";

interface RunOptions {
  prompt: string;
  target: Target;
  model: ModelId;
}

const SPRING = { type: "spring", stiffness: 380, damping: 30 } as const;
const DONE_MS = 2600;
/** The dock and IgniteBar buttons flip to Stop at once; ignore Stop this soon after Ignite (double-taps). */
const STOP_GRACE_MS = 500;
const DESKTOP_QUERY = "(min-width: 1024px)";

const useIsoLayoutEffect = typeof window !== "undefined" ? useLayoutEffect : useEffect;

function isDesktop(): boolean {
  try {
    return window.matchMedia(DESKTOP_QUERY).matches;
  } catch {
    return false;
  }
}

const SECTION = "glass rounded-3xl p-4 sm:p-5";

// Mobile geometry (px). The dock floats above the home indicator.
const NAV_H = 56;
const DOCK_H = 64;
const DOCK_GAP = 18; // space between the output panel and the dock (the Ignite button pokes up into it)
const DOCK_BOTTOM = "max(12px, env(safe-area-inset-bottom))";

const LAYOUT_VARS = {
  "--nt-dock-bottom": DOCK_BOTTOM,
  "--nt-out-h": `calc(100dvh - ${NAV_H}px - env(safe-area-inset-top) - 12px - ${DOCK_GAP}px - ${DOCK_H}px - ${DOCK_BOTTOM})`,
  "--nt-build-pb": `calc(${DOCK_H + DOCK_GAP + 28}px + ${DOCK_BOTTOM})`,
} as React.CSSProperties;

// ---------------------------------------------------------------------------
// Mobile bottom dock: Build tab · raised Ignite button · Output tab
// ---------------------------------------------------------------------------

interface DockProps {
  view: MobileView;
  onView: (v: MobileView) => void;
  streaming: boolean;
  hasPrompt: boolean;
  unseen: boolean;
  onIgnite: () => void;
  onCancel: () => void;
}

function MobileDock({ view, onView, streaming, hasPrompt, unseen, onIgnite, onCancel }: DockProps) {
  const reduce = useReducedMotion();
  const tabs: { id: MobileView; label: string; Icon: typeof Eye }[] = [
    { id: "build", label: "Build", Icon: SlidersHorizontal },
    { id: "output", label: "Output", Icon: Eye },
  ];

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight" && e.key !== "Home" && e.key !== "End") return;
    e.preventDefault();
    const next: MobileView = e.key === "Home" ? "build" : e.key === "End" ? "output" : view === "build" ? "output" : "build";
    onView(next);
    document.getElementById(`nt-dock-tab-${next}`)?.focus();
  };

  const live = hasPrompt || streaming;

  return (
    <nav
      aria-label="Studio"
      className="fixed inset-x-3 z-50 lg:hidden"
      style={{ bottom: "var(--nt-dock-bottom)" }}
    >
      <div className="glass-strong relative h-16 rounded-3xl bg-[rgba(15,13,28,0.95)] shadow-[inset_0_1px_0_rgba(255,255,255,.08),0_18px_50px_-12px_rgba(0,0,0,.9),0_0_0_1px_rgba(196,181,253,.14)]">
        {/* top hairline highlight */}
        <div aria-hidden="true" className="pointer-events-none absolute inset-x-6 top-0 h-px bg-gradient-to-r from-transparent via-white/25 to-transparent" />

        <div role="tablist" aria-label="Studio view" className="grid h-full grid-cols-[1fr_88px_1fr] items-stretch px-1.5">
          {tabs.map(({ id, label, Icon }, i) => {
            const active = view === id;
            const dot = id === "output" && (streaming || unseen);
            return (
              <button
                key={id}
                id={`nt-dock-tab-${id}`}
                type="button"
                role="tab"
                aria-selected={active}
                aria-controls={`nt-view-${id}`}
                tabIndex={active ? 0 : -1}
                onClick={() => onView(id)}
                onKeyDown={onKeyDown}
                className={`focus-ring relative my-1.5 flex flex-col items-center justify-center gap-1 rounded-2xl text-[11px] font-medium tracking-wide transition-colors ${
                  i === 0 ? "col-start-1" : "col-start-3"
                } ${active ? "text-fox-white" : "text-fox-muted hover:text-fox-mist"}`}
              >
                {active && (
                  <motion.span
                    layoutId="nt-dock-pill"
                    aria-hidden="true"
                    className="absolute inset-0 rounded-2xl border border-white/[0.08] bg-white/[0.06]"
                    transition={reduce ? { duration: 0 } : SPRING}
                  />
                )}
                <span className="relative">
                  <Icon className="h-[18px] w-[18px]" strokeWidth={1.75} aria-hidden="true" />
                  {dot && (
                    <span aria-hidden="true" className="absolute -right-1.5 -top-1 flex h-2 w-2">
                      {streaming && <span className="absolute inset-0 animate-ping rounded-full bg-spirit-cyan/70" />}
                      <span className="relative h-2 w-2 rounded-full bg-spirit-cyan shadow-[0_0_0_2px_#110f1f,0_0_8px_rgba(103,232,249,.9)]" />
                    </span>
                  )}
                </span>
                <span className="relative">
                  {label}
                  {dot && <span className="sr-only">{streaming ? " (building)" : " (new build ready)"}</span>}
                </span>
              </button>
            );
          })}
        </div>

        {/* Raised Ignite / Stop button */}
        <div className="absolute left-1/2 top-0 flex -translate-x-1/2 -translate-y-[18px] flex-col items-center">
          <motion.button
            type="button"
            onClick={streaming ? onCancel : onIgnite}
            aria-label={streaming ? "Stop build" : "Ignite: generate build"}
            whileTap={reduce ? undefined : { scale: 0.92 }}
            transition={SPRING}
            className={`focus-ring relative grid h-[60px] w-[60px] place-items-center rounded-full text-white transition-[box-shadow] duration-300 ${
              live
                ? "bg-ignite shadow-[0_0_0_4px_rgba(10,9,20,.95),0_0_0_5px_rgba(196,181,253,.45),0_12px_30px_-6px_rgba(124,58,237,.85),0_0_44px_rgba(103,232,249,.35)]"
                : "shadow-[0_0_0_4px_rgba(10,9,20,.95),0_12px_30px_-10px_rgba(124,58,237,.7),0_0_28px_-4px_rgba(167,139,250,.45)]"
            }`}
            style={
              live
                ? undefined
                : {
                    // Dormant: dark core inside a thin spirit-fire ring. It "ignites" once there's a prompt.
                    background:
                      "radial-gradient(80% 80% at 50% 30%, #1d1a33, #0c0b16) padding-box, linear-gradient(140deg, #f6f4ff, #a78bfa 45%, #67e8f9) border-box",
                    border: "1.5px solid transparent",
                  }
            }
          >
            {/* Spinning spirit ring while streaming */}
            {streaming && (
              <span
                aria-hidden="true"
                className="pointer-events-none absolute -inset-[6px] animate-[spin_1.1s_linear_infinite] rounded-full"
                style={{
                  background: "conic-gradient(from 0deg, transparent 0deg, rgba(103,232,249,.0) 40deg, #67e8f9 220deg, #f6f4ff 300deg, transparent 360deg)",
                  WebkitMask: "radial-gradient(farthest-side, transparent calc(100% - 2.5px), #000 calc(100% - 2px))",
                  mask: "radial-gradient(farthest-side, transparent calc(100% - 2.5px), #000 calc(100% - 2px))",
                }}
              />
            )}
            {/* Inner sheen */}
            <span aria-hidden="true" className="pointer-events-none absolute inset-[3px] rounded-full bg-[radial-gradient(70%_60%_at_35%_25%,rgba(255,255,255,.35),transparent_70%)]" />
            {streaming ? (
              <Square className="relative h-[18px] w-[18px] fill-current text-obsidian-950" strokeWidth={1.75} aria-hidden="true" />
            ) : (
              <Flame
                className={`relative h-6 w-6 ${live ? "fill-obsidian-950/10 text-obsidian-950" : "text-spirit-violet-soft"}`}
                strokeWidth={1.75}
                aria-hidden="true"
              />
            )}
          </motion.button>
          <span aria-hidden="true" className={`mt-[6px] font-mono text-[11px] leading-none tracking-wide ${streaming ? "text-spirit-cyan" : live ? "text-fox-white" : "text-fox-muted"}`}>
            {streaming ? "Stop" : "Ignite"}
          </span>
        </div>
      </div>
    </nav>
  );
}

// ---------------------------------------------------------------------------
// Desktop: a slim Ignite bar pinned to the bottom of the controls column while
// the prompt box is scrolled out of view, so Ignite is always one click away.
// ---------------------------------------------------------------------------

interface IgniteBarProps {
  visible: boolean;
  prompt: string;
  streaming: boolean;
  onJump: () => void;
  onIgnite: () => void;
  onCancel: () => void;
}

function IgniteBar({ visible, prompt, streaming, onJump, onIgnite, onCancel }: IgniteBarProps) {
  const reduce = useReducedMotion();
  const text = prompt.trim();
  return (
    <div className="pointer-events-none sticky bottom-0 z-20 hidden h-0 lg:-mt-4 lg:block">
      <AnimatePresence>
        {visible && (
          <motion.div
            key="ignite-bar"
            className="pointer-events-auto absolute inset-x-0 bottom-3"
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: 18 }}
            transition={SPRING}
          >
            <div className="glass-strong flex items-center gap-2 rounded-2xl bg-[rgba(15,13,28,0.92)] p-2 pl-2.5 shadow-[inset_0_1px_0_rgba(255,255,255,.08),0_18px_44px_-10px_rgba(0,0,0,.9),0_0_0_1px_rgba(196,181,253,.14)]">
              <button
                type="button"
                onClick={onJump}
                className="focus-ring group flex min-w-0 flex-1 items-center gap-2.5 rounded-xl px-1.5 py-1 text-left transition hover:bg-white/[0.04]"
              >
                <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg border border-white/10 bg-white/[0.04] text-fox-muted transition group-hover:text-fox-white" aria-hidden="true">
                  <ArrowDown className="h-4 w-4" strokeWidth={1.75} />
                </span>
                <span className="min-w-0">
                  <span className="eyebrow block leading-4">Prompt</span>
                  <span className={`block truncate text-[13px] leading-5 ${text ? "text-fox-mist" : "text-fox-muted"}`}>{text || "Describe your build"}</span>
                </span>
              </button>
              <button
                type="button"
                onClick={streaming ? onCancel : onIgnite}
                aria-label={streaming ? "Stop build" : text ? "Ignite: generate build" : "Ignite: write a prompt first"}
                className={`focus-ring inline-flex h-11 shrink-0 items-center gap-2 rounded-xl px-4 text-[13px] font-semibold transition hover:-translate-y-px active:translate-y-0 ${
                  streaming
                    ? "border border-spirit-cyan/40 bg-spirit-cyan/10 text-spirit-cyan"
                    : text
                      ? "bg-ignite text-obsidian-950 shadow-[0_10px_28px_-8px_rgba(124,58,237,.8),0_0_24px_-6px_rgba(103,232,249,.5)]"
                      : "border border-white/10 bg-white/[0.05] text-fox-mist hover:border-white/20 hover:text-fox-white"
                }`}
              >
                {streaming ? (
                  <Square className="h-3.5 w-3.5 fill-current" strokeWidth={1.75} aria-hidden="true" />
                ) : (
                  <Flame className="h-4 w-4" strokeWidth={1.75} aria-hidden="true" />
                )}
                {streaming ? "Stop" : "Ignite"}
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Studio
// ---------------------------------------------------------------------------

export function Studio() {
  const reduce = useReducedMotion();
  const gen = useGenerator();
  const { generate, cancel: cancelBuild } = gen;
  const credits = useCredits();
  const byok = useByok();

  const [target, setTarget] = useState<Target>("web");
  const [model, setModel] = useState<ModelId>(DEFAULT_MODEL);
  const [prompt, setPrompt] = useState("");
  const [activeTemplateId, setActiveTemplateId] = useState<Template["id"] | null>(null);
  const [outputTab, setOutputTab] = useState<OutputTab>("preview");
  const [mobileView, setMobileView] = useState<MobileView>("build");
  const [byokOpen, setByokOpen] = useState(false);
  const [upgrade, setUpgrade] = useState<{ open: boolean; reason: UpgradeReason }>({ open: false, reason: "manual" });
  const [pulseKey, setPulseKey] = useState(0);
  const [server, setServer] = useState<ServerStatus | null>(null);
  const [celebrating, setCelebrating] = useState(false);
  const [unseen, setUnseen] = useState(false);
  const [runModel, setRunModel] = useState<ModelId | null>(null);
  const [promptInView, setPromptInView] = useState(true);
  const [promptFocused, setPromptFocused] = useState(false);

  const streaming = gen.status === "streaming";
  const mascotState: MascotState = streaming ? "thinking" : celebrating ? "done" : "idle";

  // Latest values for async callbacks.
  const creditsRef = useRef(credits);
  creditsRef.current = credits;
  const byokKeyRef = useRef(byok.key);
  byokKeyRef.current = byok.key;
  const mobileViewRef = useRef(mobileView);
  mobileViewRef.current = mobileView;

  const lastRunRef = useRef<RunOptions | null>(null);
  const ignitedAtRef = useRef(0);
  /** Set when a build starts with focus inside the (soon hidden) mobile build view. */
  const focusOutputRef = useRef(false);
  const doneTimerRef = useRef<number | null>(null);
  const promptSectionRef = useRef<HTMLElement>(null);
  const buildViewRef = useRef<HTMLDivElement>(null);
  const outputViewRef = useRef<HTMLDivElement>(null);
  const buildScrollRef = useRef(0);

  // ---- server keys (which tails the house can serve) ----
  useEffect(() => {
    if (STATIC_DEMO) {
      setServer({ anthropic: false, openrouter: false });
      return;
    }
    let alive = true;
    fetch("/api/generate", { method: "GET", cache: "no-store" })
      .then((res) => (res.ok ? res.json() : Promise.reject(new Error(String(res.status)))))
      .then((s: Partial<ServerStatus>) => {
        if (alive) setServer({ anthropic: Boolean(s?.anthropic), openrouter: Boolean(s?.openrouter) });
      })
      .catch(() => {
        if (alive) setServer({ anthropic: false, openrouter: false });
      });
    return () => {
      alive = false;
    };
  }, []);

  // ---- desktop: is the prompt box visible inside the scrolling controls column? ----
  useEffect(() => {
    const root = buildViewRef.current;
    const el = promptSectionRef.current;
    if (!root || !el || typeof IntersectionObserver === "undefined") return;
    const io = new IntersectionObserver(([entry]) => setPromptInView(entry.intersectionRatio >= 0.3), {
      root,
      threshold: [0, 0.3, 1],
    });
    io.observe(el);
    return () => io.disconnect();
  }, []);

  // ---- a saved Anthropic key can't reach the OpenRouter-only tails ----
  useEffect(() => {
    if (byok.key && byok.provider && !providerSupportsModel(byok.provider, model)) setModel(DEFAULT_MODEL);
  }, [byok.key, byok.provider, model]);

  // ---- celebration timer cleanup ----
  useEffect(
    () => () => {
      if (doneTimerRef.current) window.clearTimeout(doneTimerRef.current);
    },
    [],
  );

  const stopCelebrating = useCallback(() => {
    if (doneTimerRef.current) window.clearTimeout(doneTimerRef.current);
    doneTimerRef.current = null;
    setCelebrating(false);
  }, []);

  const openUpgrade = useCallback((reason: UpgradeReason) => setUpgrade({ open: true, reason }), []);
  const closeUpgrade = useCallback(() => setUpgrade((u) => ({ ...u, open: false })), []);
  const openByok = useCallback(() => setByokOpen(true), []);
  const closeByok = useCallback(() => setByokOpen(false), []);
  const upgradeToByok = useCallback(() => {
    setUpgrade((u) => ({ ...u, open: false }));
    setByokOpen(true);
  }, []);
  const refillTails = useCallback(() => {
    creditsRef.current.reset();
    setUpgrade((u) => ({ ...u, open: false }));
  }, []);

  // ---- mobile view switching: keep both views mounted, animate the incoming one ----
  const changeView = useCallback((next: MobileView) => {
    if (next === mobileViewRef.current) return;
    if (!isDesktop() && next === "output") buildScrollRef.current = window.scrollY;
    setMobileView(next);
  }, []);

  const shownViewRef = useRef(mobileView);
  useIsoLayoutEffect(() => {
    // Only react to real view changes (not the first render, nor StrictMode's effect replay).
    if (shownViewRef.current === mobileView) return;
    shownViewRef.current = mobileView;
    if (isDesktop()) return;
    const el = mobileView === "build" ? buildViewRef.current : outputViewRef.current;
    window.scrollTo({ top: mobileView === "build" ? buildScrollRef.current : 0, behavior: "auto" });
    if (mobileView === "output") setUnseen(false);
    if (mobileView === "output" && focusOutputRef.current) outputViewRef.current?.focus({ preventScroll: true });
    focusOutputRef.current = false;
    if (!el || reduce) return;
    const dx = mobileView === "output" ? 28 : -28;
    const controls = animate(el, { opacity: [0, 1], x: [dx, 0] }, SPRING);
    return () => {
      controls.stop();
      el.style.opacity = "";
      el.style.transform = "";
    };
  }, [mobileView, reduce]);

  // ---- builds ----
  const runBuild = useCallback(
    async (opts: RunOptions) => {
      const text = opts.prompt.trim();
      if (!text) return;
      if (!creditsRef.current.canGenerate) {
        openUpgrade("limit");
        return;
      }
      stopCelebrating();
      lastRunRef.current = { ...opts, prompt: text };
      setRunModel(opts.model);
      setUnseen(false);
      // Desktop GUI specs arrive first, so the simulator can show while code streams.
      // Web builds show the code streaming in, then flip to the live preview.
      setOutputTab(opts.target === "web" ? "code" : "preview");
      // Phones: the build view is about to hide, so focus would drop to <body>. Move it to the output.
      if (!isDesktop() && buildViewRef.current?.contains(document.activeElement)) focusOutputRef.current = true;
      changeView("output");

      ignitedAtRef.current = performance.now();
      const ok = await generate({ prompt: text, target: opts.target, model: opts.model, byokKey: byokKeyRef.current });
      if (!ok) return;

      creditsRef.current.consume();
      setOutputTab("preview");
      setCelebrating(true);
      doneTimerRef.current = window.setTimeout(() => {
        doneTimerRef.current = null;
        setCelebrating(false);
      }, DONE_MS);
      if (!isDesktop() && mobileViewRef.current !== "output") setUnseen(true);
    },
    // generate is stable; credits, key and view are read through refs.
    [generate, openUpgrade, stopCelebrating, changeView],
  );

  const scrollToPrompt = useCallback(
    (focus: boolean) => {
      const el = promptSectionRef.current;
      if (!el) return;
      window.requestAnimationFrame(() => {
        el.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "center" });
        if (focus) el.querySelector<HTMLTextAreaElement>("textarea")?.focus({ preventScroll: true });
      });
    },
    [reduce],
  );

  const onIgnite = useCallback(() => {
    // At 0 tails every Ignite opens the plans, prompt or not.
    if (!creditsRef.current.canGenerate) {
      openUpgrade("limit");
      return;
    }
    if (!prompt.trim()) {
      changeView("build");
      scrollToPrompt(true);
      return;
    }
    void runBuild({ prompt, target, model });
  }, [prompt, target, model, runBuild, changeView, scrollToPrompt, openUpgrade]);

  const onCancel = useCallback(() => cancelBuild(), [cancelBuild]);
  /** For the buttons that toggle Ignite/Stop in place: the second tap of a double-tap is not a Stop. */
  const onToggleCancel = useCallback(() => {
    if (performance.now() - ignitedAtRef.current < STOP_GRACE_MS) return;
    cancelBuild();
  }, [cancelBuild]);

  const onRetry = useCallback(() => {
    const last = lastRunRef.current;
    if (!last) return;
    // A key swapped since the failed run may not reach its model; the selector has already moved on.
    const retryModel = byok.provider && !providerSupportsModel(byok.provider, last.model) ? model : last.model;
    void runBuild({ ...last, model: retryModel });
    // The Retry button unmounts once the build starts; keep keyboard focus in the output region.
    requestAnimationFrame(() => document.getElementById("nt-view-output")?.focus({ preventScroll: true }));
  }, [runBuild, byok.provider, model]);

  // ---- templates & prompt ----
  const onTemplate = useCallback(
    (t: Template) => {
      setTarget(t.target);
      setPrompt(t.prompt);
      setActiveTemplateId(t.id);
      setPulseKey((k) => k + 1);
      changeView("build");
      scrollToPrompt(false);
    },
    [changeView, scrollToPrompt],
  );

  const onPromptChange = useCallback(
    (value: string) => {
      setPrompt(value);
      if (activeTemplateId && getTemplate(activeTemplateId)?.prompt !== value) setActiveTemplateId(null);
    },
    [activeTemplateId],
  );

  // ---- export ----
  const onExport = useCallback(() => {
    if (!credits.canExport) {
      openUpgrade("export");
      return;
    }
    const parsed = gen.parsed;
    if (!parsed?.code || gen.status === "streaming") return;
    const last = lastRunRef.current;
    exportProjectZip({
      parsed,
      target: gen.target ?? target,
      prompt: last?.prompt ?? prompt,
      modelName: getModel(last?.model ?? model).name,
      mode: gen.mode,
    }).catch((err: unknown) => {
      console.warn("[NineTail] ZIP export failed", err);
    });
  }, [credits.canExport, gen.parsed, gen.status, gen.target, gen.mode, target, prompt, model, openUpgrade]);

  const modelName = getModel(streaming && runModel ? runModel : model).name;
  const outputTarget = gen.target ?? target;

  // Screen-reader build status. It lives outside both views, since on phones the
  // build view (and its status card) is display:none while a build runs.
  const tailsLeft = credits.unlimited ? "" : ` ${credits.remaining} of ${credits.max} tails left.`;
  const announcement = streaming
    ? `Building with ${modelName}.`
    : gen.status === "done"
      ? `Build complete.${tailsLeft}`
      : gen.status === "error"
        ? gen.error?.trim() === STOPPED_MESSAGE
          ? "Build stopped. No tail spent."
          : `Build failed${gen.error ? `: ${gen.error}` : "."}`
        : "";

  return (
    <div className="relative isolate min-h-[100dvh] overflow-x-clip" style={LAYOUT_VARS}>
      <Backdrop />

      <Navbar
        mascotState={mascotState}
        remaining={credits.remaining}
        max={credits.max}
        unlimited={credits.unlimited}
        byokConnected={Boolean(byok.key)}
        onOpenUpgrade={() => openUpgrade("manual")}
        onOpenByok={openByok}
      />

      <main className="mx-auto w-full max-w-[1760px] lg:grid lg:h-[calc(100dvh-4rem)] lg:grid-cols-[minmax(380px,440px)_minmax(0,1fr)] lg:grid-rows-[minmax(0,1fr)] lg:gap-5 lg:overflow-hidden lg:px-5">
        <h1 className="sr-only">NineTail Studio: describe a UI, ignite it, get a live preview and code</h1>

        {/* LEFT: controls */}
        <div
          id="nt-view-build"
          ref={buildViewRef}
          aria-label="Build controls"
          role="region"
          className={`${mobileView === "build" ? "flex" : "max-lg:hidden lg:flex"} mx-auto w-full max-w-xl flex-col gap-3 [&>*]:shrink-0 px-3 pt-3 max-lg:pb-[var(--nt-build-pb)] sm:gap-4 sm:px-4 sm:pt-4 lg:mx-0 lg:h-full lg:max-w-none lg:overflow-y-auto lg:overscroll-contain lg:px-0 lg:py-5 lg:pr-1 scrollbar-thin`}
        >
          <SpiritCore state={mascotState} status={gen.status} charCount={gen.raw.length} modelName={modelName} error={gen.error} />

          <section aria-label="Output target" className={SECTION}>
            <TargetToggle value={target} onChange={setTarget} disabled={streaming} />
          </section>

          <section aria-label="Model" className={SECTION}>
            <ModelSelector value={model} onChange={setModel} byok={byok} server={server} onOpenByok={openByok} disabled={streaming} />
          </section>

          <section aria-label="Templates" className={SECTION}>
            <TemplateVault onSelect={onTemplate} activeId={activeTemplateId} disabled={streaming} />
          </section>

          <section
            ref={promptSectionRef}
            aria-label="Prompt"
            className={`${SECTION} scroll-mt-20 scroll-mb-32`}
            onFocus={() => setPromptFocused(true)}
            onBlur={(e) => {
              if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setPromptFocused(false);
            }}
          >
            <PromptBox
              value={prompt}
              onChange={onPromptChange}
              onIgnite={onIgnite}
              onCancel={onCancel}
              status={gen.status}
              target={target}
              remaining={credits.remaining}
              unlimited={credits.unlimited}
              pulseKey={pulseKey}
            />
          </section>

          <IgniteBar
            visible={!promptInView && !promptFocused}
            prompt={prompt}
            streaming={streaming}
            onJump={() => scrollToPrompt(true)}
            onIgnite={onIgnite}
            onCancel={onToggleCancel}
          />
        </div>

        {/* RIGHT: output */}
        <div
          id="nt-view-output"
          ref={outputViewRef}
          aria-label="Output"
          role="region"
          tabIndex={-1}
          className={`${mobileView === "output" ? "block" : "max-lg:hidden lg:block"} outline-none px-3 pt-3 max-lg:h-[var(--nt-out-h)] max-lg:box-content sm:px-4 lg:h-full lg:min-h-0 lg:min-w-0 lg:px-0 lg:py-5`}
        >
          <OutputPanel
            className="h-full"
            target={outputTarget}
            status={gen.status}
            parsed={gen.parsed}
            error={gen.error}
            mode={gen.mode}
            tab={outputTab}
            onTabChange={setOutputTab}
            onExport={onExport}
            exportLocked={!credits.canExport}
            mascotState={mascotState}
            onRetry={lastRunRef.current ? onRetry : undefined}
          />
        </div>
      </main>

      <MobileDock
        view={mobileView}
        onView={changeView}
        streaming={streaming}
        hasPrompt={prompt.trim().length > 0}
        unseen={unseen}
        onIgnite={onIgnite}
        onCancel={onToggleCancel}
      />

      <p className="sr-only" role="status" aria-live="polite">
        {announcement}
      </p>

      <ByokModal open={byokOpen} onClose={closeByok} byok={byok} />
      <UpgradeModal open={upgrade.open} reason={upgrade.reason} onClose={closeUpgrade} onOpenByok={upgradeToByok} onRefill={refillTails} />
    </div>
  );
}

export default Studio;
