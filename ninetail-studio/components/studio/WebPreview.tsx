"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { Monitor, RotateCw, ShieldCheck, Smartphone, Tablet } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useElementSize } from "./output-kit";

export type PreviewDevice = "desktop" | "tablet" | "mobile";

export interface WebPreviewProps {
  /** Full HTML document from the model. */
  html: string;
  /** While true the last committed HTML stays on screen (the iframe never reloads per chunk). */
  streaming?: boolean;
  /** Initial device. Defaults to mobile under 640px viewport width, desktop otherwise. */
  defaultDevice?: PreviewDevice;
  className?: string;
}

const TAILWIND_CDN = '<script src="https://cdn.tailwindcss.com"></script>';

/**
 * Keeps the sandboxed page inside its frame: external links and form posts would
 * otherwise navigate the iframe away to a blank page. In-page #anchors still work.
 */
const GUARD_SCRIPT = `<script>(function(){document.addEventListener("click",function(e){var a=e.target&&e.target.closest?e.target.closest("a[href]"):null;if(!a)return;var h=a.getAttribute("href")||"";if(h.charAt(0)==="#"&&h.length>1)return;e.preventDefault();},true);document.addEventListener("submit",function(e){e.preventDefault();},true);})();</script>`;

/** Injects the Tailwind CDN (when missing) and the navigation guard into <head>. */
export function prepareSrcDoc(html: string): string {
  let doc = html.trim();
  if (!doc) return "";
  const needsTailwind = !/cdn\.tailwindcss\.com|tailwindcss(@|\/|\.)/i.test(doc);
  const inject = `${needsTailwind ? TAILWIND_CDN : ""}${GUARD_SCRIPT}`;
  if (/<head[^>]*>/i.test(doc)) {
    doc = doc.replace(/<head[^>]*>/i, (m) => `${m}${inject}`);
  } else if (/<html[^>]*>/i.test(doc)) {
    doc = doc.replace(/<html[^>]*>/i, (m) => `${m}<head><meta charset="utf-8">${inject}</head>`);
  } else {
    doc = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">${inject}</head><body>${doc}</body></html>`;
  }
  return doc;
}

const DEVICES: { id: PreviewDevice; label: string; Icon: typeof Monitor }[] = [
  { id: "desktop", label: "Desktop", Icon: Monitor },
  { id: "tablet", label: "Tablet", Icon: Tablet },
  { id: "mobile", label: "Mobile", Icon: Smartphone },
];

/** The device the visitor last picked, kept for the rest of the session. */
let rememberedDevice: PreviewDevice | null = null;

const DESKTOP_MIN = 1100;
const TABLET_W = 768;
const PHONE_W = 390;
const PHONE_H = 844;
const PHONE_BEZEL = 9;
const STATUS_BAR_H = 46;
const TABLET_BEZEL = 12;

interface FrameGeometry {
  /** Logical (unscaled) iframe size. */
  iw: number;
  ih: number;
  scale: number;
  /** Scaled outer box size, including any bezel. */
  ow: number;
  oh: number;
  bezel: number;
}

function geometry(device: PreviewDevice, w: number, h: number): FrameGeometry {
  if (device === "desktop") {
    const iw = Math.max(DESKTOP_MIN, w);
    const scale = w / iw;
    return { iw, ih: h / scale, scale, ow: w, oh: h, bezel: 0 };
  }
  if (device === "tablet") {
    const pad = 12;
    const availW = w - pad * 2;
    const availH = h - pad * 2;
    const scale = Math.min(1, availW / (TABLET_W + TABLET_BEZEL * 2));
    const ih = Math.min(1180, availH / scale - TABLET_BEZEL * 2);
    return { iw: TABLET_W, ih, scale, ow: (TABLET_W + TABLET_BEZEL * 2) * scale, oh: (ih + TABLET_BEZEL * 2) * scale, bezel: TABLET_BEZEL };
  }
  const pad = 10;
  const availW = w - pad * 2;
  const availH = h - pad * 2;
  const outerW = PHONE_W + PHONE_BEZEL * 2;
  // Keep at least an iPhone SE-like aspect; otherwise use the full height.
  const scale = Math.min(1, availW / outerW, availH / (640 + PHONE_BEZEL * 2));
  const ih = Math.min(PHONE_H, availH / scale - PHONE_BEZEL * 2);
  return { iw: PHONE_W, ih, scale, ow: outerW * scale, oh: (ih + PHONE_BEZEL * 2) * scale, bezel: PHONE_BEZEL };
}

/** Phone status bar with the island, drawn above the iframe like a real browser viewport. */
function PhoneStatusBar() {
  return (
    <div className="relative flex shrink-0 items-center justify-between bg-black px-7 text-white" style={{ height: STATUS_BAR_H }} aria-hidden="true">
      <span className="w-14 pt-1 text-[15px] font-semibold tracking-tight">9:41</span>
      <span className="absolute left-1/2 top-[11px] h-[30px] w-[106px] -translate-x-1/2 rounded-full bg-[#050505] ring-1 ring-white/[0.04]" />
      <span className="flex w-14 items-center justify-end gap-1.5 pt-1">
        <span className="flex items-end gap-[2px]">
          {[4, 6, 8, 10].map((h) => (
            <span key={h} className="w-[3px] rounded-[1px] bg-white" style={{ height: h }} />
          ))}
        </span>
        <span className="relative ml-1 h-[11px] w-[22px] rounded-[3.5px] border border-white/50 p-[1.5px]">
          <span className="block h-full w-[78%] rounded-[1.5px] bg-white" />
          <span className="absolute -right-[3px] top-[3px] h-[4px] w-[1.5px] rounded-r bg-white/50" />
        </span>
      </span>
    </div>
  );
}

/** Skeleton of a web page, shown until the iframe finishes loading. */
export function PageSkeleton({ dense = false }: { dense?: boolean }) {
  const bar = "rounded-md bg-[linear-gradient(110deg,rgba(255,255,255,0.04)_20%,rgba(196,181,253,0.14)_40%,rgba(255,255,255,0.04)_60%)] bg-[length:200%_100%] animate-spirit-pan";
  const style = { animationDuration: "1.8s" };
  return (
    <div className="flex h-full w-full flex-col gap-4 overflow-hidden p-4 sm:p-6" aria-hidden="true">
      <div className="flex items-center justify-between">
        <div className={`h-4 w-24 ${bar}`} style={style} />
        <div className="flex gap-2">
          <div className={`h-4 w-10 ${bar} hidden sm:block`} style={style} />
          <div className={`h-4 w-10 ${bar} hidden sm:block`} style={style} />
          <div className={`h-6 w-16 rounded-full ${bar}`} style={style} />
        </div>
      </div>
      <div className="mt-4 flex flex-col items-start gap-3 sm:mt-8">
        <div className={`h-3 w-28 rounded-full ${bar}`} style={style} />
        <div className={`h-7 w-[86%] ${bar}`} style={style} />
        <div className={`h-7 w-[64%] ${bar}`} style={style} />
        <div className={`mt-1 h-3 w-[72%] ${bar}`} style={style} />
        <div className={`h-3 w-[54%] ${bar}`} style={style} />
        <div className="mt-2 flex gap-2">
          <div className={`h-9 w-28 rounded-full ${bar}`} style={style} />
          <div className={`h-9 w-24 rounded-full ${bar}`} style={style} />
        </div>
      </div>
      <div className={`mt-2 grid gap-3 ${dense ? "grid-cols-1" : "grid-cols-1 sm:grid-cols-3"}`}>
        {[0, 1, 2].map((i) => (
          <div key={i} className="flex flex-col gap-2 rounded-xl border border-white/[0.05] bg-white/[0.02] p-3">
            <div className={`h-6 w-6 rounded-lg ${bar}`} style={style} />
            <div className={`h-3 w-3/4 ${bar}`} style={style} />
            <div className={`h-2.5 w-full ${bar}`} style={style} />
          </div>
        ))}
      </div>
    </div>
  );
}

export function WebPreview({ html, streaming = false, defaultDevice, className = "" }: WebPreviewProps) {
  const reduce = useReducedMotion();
  const [stageRef, stage] = useElementSize<HTMLDivElement>();
  const [device, setDevice] = useState<PreviewDevice>(defaultDevice ?? "desktop");
  const [reloadKey, setReloadKey] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const chosen = useRef(Boolean(defaultDevice));

  // Pick the starting device after mount so server and client markup agree.
  useEffect(() => {
    if (chosen.current) return;
    chosen.current = true;
    if (rememberedDevice) setDevice(rememberedDevice);
    else if (window.innerWidth < 640) setDevice("mobile");
  }, []);

  const pickDevice = (d: PreviewDevice) => {
    rememberedDevice = d;
    setDevice(d);
  };

  // Freeze the document while streaming; only a finished document reaches the iframe.
  const committed = useRef(html);
  if (!streaming) committed.current = html;
  const srcDoc = useMemo(() => prepareSrcDoc(committed.current), [committed.current]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    setLoaded(false);
  }, [srcDoc, reloadKey, device]);

  // Some pages never fire load quickly (slow CDN). Don't shimmer forever.
  useEffect(() => {
    if (loaded) return;
    const t = window.setTimeout(() => setLoaded(true), 7000);
    return () => window.clearTimeout(t);
  }, [loaded, srcDoc, reloadKey]);

  const geo = stage.width > 0 && stage.height > 0 ? geometry(device, stage.width, stage.height) : null;

  const onRadioKey = (e: React.KeyboardEvent) => {
    const idx = DEVICES.findIndex((d) => d.id === device);
    let next = -1;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (idx + 1) % DEVICES.length;
    if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (idx + DEVICES.length - 1) % DEVICES.length;
    if (next < 0) return;
    e.preventDefault();
    pickDevice(DEVICES[next].id);
    const btn = (e.currentTarget as HTMLElement).querySelectorAll<HTMLButtonElement>("[role=radio]")[next];
    btn?.focus();
  };

  const renderIframe = (width: number, height: number, scale: number) => (
    <iframe
      key={`${device}-${reloadKey}`}
      title="Live preview"
      srcDoc={srcDoc}
      sandbox="allow-scripts allow-forms"
      referrerPolicy="no-referrer"
      loading="eager"
      onLoad={() => setLoaded(true)}
      className="block border-0 bg-white"
      style={{
        width,
        height,
        transform: scale === 1 ? undefined : `scale(${scale})`,
        transformOrigin: "top left",
      }}
    />
  );

  const shimmer = (
    <AnimatePresence>
      {!loaded && (
        <motion.div
          className="absolute inset-0 z-10 bg-obsidian-900"
          initial={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: reduce ? 0 : 0.35 }}
        >
          <PageSkeleton dense={device === "mobile"} />
        </motion.div>
      )}
    </AnimatePresence>
  );

  return (
    <div className={`flex h-full min-h-0 flex-col ${className}`}>
      {/* Toolbar */}
      <div className="flex shrink-0 items-center gap-2 px-1 pb-2">
        <div
          role="radiogroup"
          aria-label="Preview device"
          onKeyDown={onRadioKey}
          className="relative flex items-center rounded-xl border border-white/[0.08] bg-obsidian-950/50 p-0.5"
        >
          {/* One always-mounted pill moved by x. A layoutId pill here would never finish
              exiting inside OutputPanel's AnimatePresence mode="wait" and blank the panel. */}
          <motion.span
            aria-hidden="true"
            className="pointer-events-none absolute left-1 top-1 h-9 w-10 rounded-lg border border-white/[0.12] bg-white/[0.08] shadow-[0_0_18px_-4px_rgba(167,139,250,0.55)]"
            initial={false}
            animate={{ x: DEVICES.findIndex((d) => d.id === device) * 44 }}
            transition={reduce ? { duration: 0 } : { type: "spring", stiffness: 380, damping: 30 }}
          />
          {DEVICES.map(({ id, label, Icon }) => {
            const active = device === id;
            return (
              <button
                key={id}
                type="button"
                role="radio"
                aria-checked={active}
                aria-label={label}
                title={label}
                tabIndex={active ? 0 : -1}
                onClick={() => pickDevice(id)}
                className={`focus-ring relative grid h-10 w-11 place-items-center rounded-[10px] transition-colors ${
                  active ? "text-fox-white" : "text-fox-muted hover:text-fox-white"
                }`}
              >
                <Icon className="relative h-4 w-4" strokeWidth={1.75} />
              </button>
            );
          })}
        </div>
        <div className="flex h-10 min-w-0 flex-1 items-center gap-2 rounded-xl border border-white/[0.06] bg-obsidian-950/40 px-3">
          <ShieldCheck className="h-4 w-4 shrink-0 text-spirit-violet" strokeWidth={1.75} aria-hidden="true" />
          <span className="truncate font-mono text-[11px] text-fox-muted sm:text-[12px]">
            <span className="text-fox-mist">index.html</span>
            <span className="hidden min-[420px]:inline"> · sandboxed</span>
            {geo && (
              <span className="hidden md:inline">
                {" "}
                · {Math.round(geo.iw)}px{geo.scale < 0.995 ? ` @ ${Math.round(geo.scale * 100)}%` : ""}
              </span>
            )}
          </span>
        </div>
        <button
          type="button"
          onClick={() => setReloadKey((k) => k + 1)}
          aria-label="Reload preview"
          title="Reload preview"
          className="focus-ring grid h-10 w-11 shrink-0 place-items-center rounded-xl border border-white/[0.08] bg-obsidian-950/50 text-fox-muted transition hover:border-white/20 hover:text-fox-white"
        >
          <RotateCw className="h-4 w-4" strokeWidth={1.75} />
        </button>
      </div>

      {/* Stage */}
      <div
        ref={stageRef}
        className="relative min-h-0 flex-1 overflow-hidden rounded-2xl border border-white/[0.06] bg-obsidian-950/70 bg-[radial-gradient(rgba(167,139,250,0.10)_1px,transparent_1px)] [background-size:18px_18px]"
      >
        {geo && device === "desktop" && (
          <div className="absolute inset-0 overflow-hidden">
            {renderIframe(geo.iw, geo.ih, geo.scale)}
            {shimmer}
          </div>
        )}

        {geo && device !== "desktop" && (
          <div className="absolute inset-0 flex items-start justify-center overflow-hidden" style={{ paddingTop: Math.max(8, (stage.height - geo.oh) / 2) }}>
            <div className="relative shrink-0" style={{ width: geo.ow, height: geo.oh }}>
              <div
                className={`absolute left-0 top-0 origin-top-left bg-[#0c0b14] shadow-[0_0_0_1px_rgba(255,255,255,0.10),0_30px_70px_-20px_rgba(0,0,0,0.9),0_0_60px_-10px_rgba(124,58,237,0.35)] ${
                  device === "mobile" ? "rounded-[52px]" : "rounded-[30px]"
                }`}
                style={{
                  width: geo.iw + geo.bezel * 2,
                  height: geo.ih + geo.bezel * 2,
                  padding: geo.bezel,
                  transform: `scale(${geo.scale})`,
                }}
              >
                <div className={`relative flex h-full w-full flex-col overflow-hidden bg-black ${device === "mobile" ? "rounded-[44px]" : "rounded-[20px]"}`}>
                  {device === "mobile" && <PhoneStatusBar />}
                  <div className="relative min-h-0 flex-1">
                    {renderIframe(geo.iw, geo.ih - (device === "mobile" ? STATUS_BAR_H : 0), 1)}
                    {shimmer}
                  </div>
                </div>
                {device === "mobile" && (
                  <>
                    <span className="absolute -left-[3px] top-[150px] h-14 w-[3px] rounded-l bg-[#1b1a26]" aria-hidden="true" />
                    <span className="absolute -left-[3px] top-[220px] h-14 w-[3px] rounded-l bg-[#1b1a26]" aria-hidden="true" />
                    <span className="absolute -right-[3px] top-[180px] h-20 w-[3px] rounded-r bg-[#1b1a26]" aria-hidden="true" />
                  </>
                )}
              </div>
            </div>
          </div>
        )}

        {!geo && <PageSkeleton />}
      </div>
    </div>
  );
}

export default WebPreview;
