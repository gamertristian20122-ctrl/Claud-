"use client";

/**
 * KitsuneMascot, direction B: "Spirit Ink".
 * A white nine-tailed fox in a seated 3/4 pose, chin raised, drawn like a sumi-e ink study.
 * Nine S-curved brush-stroke tails rise behind it like flames, in two layers (long back
 * tails, shorter front tails), fading from white to violet and ending in cyan spirit fire.
 * Violet flame sigil on the forehead, violet cheek marks, luminous cyan eye.
 *
 * Motion is driven by a few spring-smoothed "drive" values (sway, flare, pulse, glow, kick)
 * plus one shared clock, so state changes blend smoothly instead of restarting loops.
 *   idle      tails ripple in a slow wave, breathing, blinks, flame tips flicker
 *   thinking  fan opens, tails pulse 1 to 9 (0.1 s stagger, 1.2 s loop), eye and sigil
 *             brighten, foxfire orbs orbit
 *   done      one-shot aura flash (rings, bloom, sparkle burst), happy tail bounce and
 *             squint, then a calm glow
 * Reduced motion: no clock-driven motion; a static pose per state.
 */

import { useEffect, useId, useRef, useState } from "react";
import {
  AnimatePresence,
  animate,
  motion,
  useMotionValue,
  useReducedMotion,
  useSpring,
  useTime,
  useTransform,
  type AnimationPlaybackControls,
  type MotionValue,
} from "framer-motion";
import type { MascotState } from "@/lib/types";
import type { KitsuneMascotProps } from "./types";

/* ------------------------------------------------------------------------------------------ */
/* Tail geometry. Generated once at module load from a few numbers per tail.                   */
/* ------------------------------------------------------------------------------------------ */

type Pt = [number, number];
type Sample = { p: Pt; h: number; t: number };

const TAU = Math.PI * 2;
const rad = (deg: number) => (deg * Math.PI) / 180;
/** Unit vector for a heading in degrees, clockwise from "up". */
const dir = (deg: number): Pt => [Math.sin(rad(deg)), -Math.cos(rad(deg))];
const r1 = (n: number) => Math.round(n * 10) / 10;
const rot = ([x, y]: Pt, deg: number): Pt => {
  const c = Math.cos(rad(deg));
  const s = Math.sin(rad(deg));
  return [x * c - y * s, x * s + y * c];
};

/** Smooth path through points (Catmull-Rom written as cubic Beziers). */
function smooth(pts: Pt[], cmd: "M" | "L" = "M"): string {
  let d = `${cmd}${r1(pts[0][0])} ${r1(pts[0][1])}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = i > 0 ? pts[i - 1] : pts[i];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = i + 2 < pts.length ? pts[i + 2] : p2;
    d +=
      `C${r1(p1[0] + (p2[0] - p0[0]) / 6)} ${r1(p1[1] + (p2[1] - p0[1]) / 6)} ` +
      `${r1(p2[0] - (p3[0] - p1[0]) / 6)} ${r1(p2[1] - (p3[1] - p1[1]) / 6)} ${r1(p2[0])} ${r1(p2[1])}`;
  }
  return d;
}

/** Walk a brush stroke: heading eases from a0 to a1, with an S-wiggle and a flicked tip. */
function walk(a0: number, a1: number, len: number, wig: number, hook: number, n = 40): Sample[] {
  const out: Sample[] = [];
  let p: Pt = [0, 0];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const k = t < 0.78 ? 0 : (t - 0.78) / 0.22;
    const h = a0 + (a1 - a0) * t + wig * Math.sin(TAU * t) + hook * k * k;
    out.push({ p, h, t });
    const [dx, dy] = dir(h);
    p = [p[0] + (dx * len) / n, p[1] + (dy * len) / n];
  }
  return out;
}

/** Plume width profile: swells to a full belly, then tapers into a flame point. */
const plume = (t: number) =>
  t < 0.56
    ? 0.5 + 0.5 * Math.sin((t / 0.56) * (Math.PI / 2))
    : Math.pow(Math.max(0, Math.cos(Math.min(1, (t - 0.56) / 0.44) * (Math.PI / 2))), 0.85);

/** Point offset sideways from a spine sample (k > 0 is the right-hand side). */
const side = ({ p, h }: Sample, k: number): Pt => {
  const [dx, dy] = dir(h);
  return [p[0] - dy * k, p[1] + dx * k];
};

/** Closed ribbon around a spine with per-side half-widths. */
function ribbon(spine: Sample[], width: (t: number) => [number, number]): { d: string; right: Pt[] } {
  const left = spine.map((s) => side(s, -width(s.t)[0]));
  const right = spine.map((s) => side(s, width(s.t)[1]));
  return { d: `${smooth(left)}${smooth([...right].reverse(), "L")}Z`, right };
}

interface TailGeo {
  x: number;
  y: number;
  chord: number;
  fur: string;
  shade: string;
  strands: string;
  flame: string;
  fx: number;
  fy: number;
  fr: number;
}

function buildTail([x, y, a0, a1, len, w, wig, hook]: number[]): TailGeo {
  const spine = walk(a0, a1, len, wig, hook);
  const tip = spine[spine.length - 1].p;
  const chord = (Math.atan2(tip[0], -tip[1]) * 180) / Math.PI;
  // Local frame: base at 0,0 and base-to-tip pointing up, so one gradient fits every tail.
  const loc = spine.map((s) => ({ p: rot(s.p, -chord), h: s.h - chord, t: s.t }));
  const half = (t: number) => (w / 2) * plume(t);
  const fur = ribbon(loc, (t) => {
    const twist = 0.12 * Math.sin(Math.PI * t);
    return [half(t) * (1 + twist), half(t) * (1 - twist)];
  });
  const shade = `${smooth(loc.map((s) => side(s, half(s.t) * 0.15)))}${smooth([...fur.right].reverse(), "L")}Z`;
  const strand = (k: number, from: number, to: number) =>
    smooth(loc.filter((s) => s.t >= from && s.t <= to).map((s) => side(s, half(s.t) * k)));
  // Spirit-fire tongue: starts 80% along the tail and licks past the tip. Own frame, pointing up.
  const at = spine[32];
  const tongue = walk(at.h, at.h + hook * 0.6 + (a1 - a0) * 0.3, len * 0.27, 0, hook * 0.8, 24).map((s) => ({
    p: rot(s.p, -at.h),
    h: s.h - at.h,
    t: s.t,
  }));
  const flame = ribbon(tongue, (t) => {
    const k = half(0.8) * Math.pow(Math.max(0, 1 - t), 0.8);
    const twist = 0.25 * Math.sin(Math.PI * t);
    return [k * (1 + twist), k * (1 - twist)];
  });
  return {
    x,
    y,
    chord: r1(chord),
    fur: fur.d,
    shade,
    strands: strand(-0.42, 0.18, 0.74) + strand(0.12, 0.3, 0.86),
    flame: flame.d,
    fx: r1(loc[32].p[0]),
    fy: r1(loc[32].p[1]),
    fr: r1(loc[32].h),
  };
}

// Per tail, in fan order (left to right): base x, base y, start heading, end heading,
// length, width, S-wiggle, tip flick. Even tails are the long back layer, odd tails the front.
const TAIL_SPECS = [
  [216, 330, 8.3, -17.7, 286, 48, 12, -26],
  [218, 330, 20.1, -9.9, 267, 58, 18, -30],
  [220, 331, 28, -6, 324, 50, 12, -28],
  [222, 332, 40, 0, 276, 60, 18, -32],
  [224, 333, 47.6, 1.6, 322, 50, 12, -30],
  [226, 334, 58.7, 6.7, 244, 58, 18, -34],
  [228, 336, 67.7, 9.7, 263, 46, 12, -32],
  [228, 338, 75.4, 13.4, 188, 52, 18, -34],
  [228, 340, 97, 31, 187, 44, 12, -34],
];
const TAILS = TAIL_SPECS.map(buildTail);
const DRAW_ORDER = [0, 2, 4, 6, 8, 1, 3, 5, 7];

/* ------------------------------------------------------------------------------------------ */
/* Fox body: hand-drawn paths on the same 400 x 400 grid.                                      */
/* ------------------------------------------------------------------------------------------ */

const FOX = {
  farEar: "M96 120C98 98 102 80 108 60C118 76 126 94 130 112Z",
  farEarInner: "M104 112C105 98 107 86 110 74C116 86 120 98 122 110Z",
  farLeg: "M134 320C142 318 152 320 158 326L159 368C160 375 156 379 149 379L134 379Z",
  body:
    "M40 152C54 142 74 128 98 118C106 114 113 110 120 106C124 88 132 68 144 46C154 66 162 88 168 108" +
    "C174 116 180 126 184 136C188 144 194 150 202 154C196 157 193 162 192 170C193 196 200 220 212 244" +
    "C228 272 244 300 246 330C248 360 236 378 214 379L180 379C172 379 169 371 175 365C182 352 180 338 168 334" +
    "C160 332 148 334 139 340L138 370C139 376 134 379 128 379L104 379C96 379 94 372 102 368" +
    "C108 365 112 358 113 344L116 300C108 292 103 286 100 278C96 279 91 280 85 282C86 270 86 260 92 250" +
    "C88 249 84 249 78 251C80 236 84 226 92 216C89 214 86 214 82 214C86 202 92 194 100 188" +
    "C92 182 84 178 74 174C62 170 50 163 44 158C41 156 39 154 40 152Z",
  haunch: "M175 365C170 332 184 306 212 300C230 298 242 310 246 330C248 360 236 378 214 379L180 379C172 379 169 371 175 365Z",
  thigh: "M175 364C170 332 184 306 212 300C230 298 242 308 246 324",
  chestFur: "M104 236C110 246 112 256 110 266M110 206C116 214 118 222 116 230",
  innerEar: "M128 104C132 90 137 76 144 60C150 76 155 90 158 106C148 102 138 102 128 104Z",
  cheeks: "M128 150C142 150 156 146 170 138M132 161C144 161 156 158 166 152",
  mouth: "M46 158C56 164 68 168 82 168",
  eye: "M97 145Q105 128 127 127Q117 142 97 145Z",
  sigil:
    "M0 0C-5 -5 -5 -12 0 -20C1 -13 5 -9 3 -2ZM-4 1C-9 -1 -10 -6 -9 -10C-7 -6 -5 -4 -4 1Z" +
    "M4 1C9 -1 10 -6 9 -10C7 -6 5 -4 4 1Z",
};
const INK = "#1a1033";
const SPARKLE = "M0 -10C1 -3 3 -1 10 0C3 1 1 3 0 10C-1 3 -3 1 -10 0C-3 -1 -1 -3 0 -10Z";
const CENTER: Pt = [206, 218];

/* ------------------------------------------------------------------------------------------ */
/* Motion drives.                                                                              */
/* ------------------------------------------------------------------------------------------ */

interface Drives {
  time: MotionValue<number>;
  sway: MotionValue<number>; // idle ripple amount
  flare: MotionValue<number>; // thinking: fan opens
  pulse: MotionValue<number>; // thinking: sequential pulse and foxfire
  glow: MotionValue<number>; // eye, sigil and halo brightness
  kick: MotionValue<number>; // done: one-shot bounce (0 -> 1 -> -0.3 -> 0)
  live: number; // 1 normally, 0 with reduced motion (kills clock-driven motion)
}

const POSE: Record<MascotState, { sway: number; flare: number; pulse: number; glow: number }> = {
  idle: { sway: 1, flare: 0, pulse: 0, glow: 0 },
  thinking: { sway: 0.35, flare: 1, pulse: 1, glow: 1 },
  done: { sway: 0.6, flare: 0.15, pulse: 0, glow: 0.8 },
};
const SPRING = { stiffness: 90, damping: 17, mass: 1 };
const LABEL: Record<MascotState, string> = { idle: "idle", thinking: "thinking", done: "done" };

/** Sequential pulse: a short bump that walks across tails 0..8 every 1.2 s. */
function pulseAt(ms: number, i: number) {
  const u = ((((ms / 1000 - i * 0.1) / 1.2) % 1) + 1) % 1;
  const x = (u - 0.22) / 0.1;
  return Math.exp(-x * x);
}

/* ------------------------------------------------------------------------------------------ */
/* Pieces.                                                                                     */
/* ------------------------------------------------------------------------------------------ */

function Tail({ i, d, id, tiny }: { i: number; d: Drives; id: string; tiny: boolean }) {
  const g = TAILS[i];
  const rotate = useTransform(() => {
    const s = d.time.get() / 1000;
    const ripple = 3.6 * Math.sin((TAU * s) / 4.2 - i * 0.5) + 1 * Math.sin((TAU * s) / 2.3 + i * 1.7);
    const flutter = 1.3 * Math.sin(TAU * s * 1.7 + i * 1.3);
    return (
      d.live * (d.sway.get() * ripple + d.pulse.get() * flutter) +
      d.flare.get() * (i - 4) * 1.5 +
      d.kick.get() * (i - 4) * 1.6
    );
  });
  const scale = useTransform(
    () => 1 + d.flare.get() * 0.03 + d.live * d.pulse.get() * 0.07 * pulseAt(d.time.get(), i) + d.kick.get() * 0.03,
  );
  // Spirit-fire excitation: flicker, the thinking pulse and the done kick all feed one number.
  const fire = useTransform(() => {
    const s = d.time.get() / 1000;
    const flicker = 0.07 * Math.sin(TAU * s * 1.3 + i * 2.1) + 0.045 * Math.sin(TAU * s * 3.1 + i);
    return d.live * (flicker + d.pulse.get() * 0.42 * pulseAt(d.time.get(), i)) + d.glow.get() * 0.12 + d.kick.get() * 0.45;
  });
  const flameY = useTransform(() => 1 + 0.55 * fire.get());
  const flameX = useTransform(() => 1 + 0.45 * fire.get());
  const flameOpacity = useTransform(() => Math.min(1, 0.84 + 0.4 * fire.get()));

  return (
    <g transform={`translate(${g.x} ${g.y}) rotate(${g.chord})`}>
      <motion.g style={{ rotate, scale, originX: "0px", originY: "0px" }}>
        <path d={g.fur} fill={`url(#${id}-fur)`} stroke={`url(#${id}-ink)`} strokeWidth={2.2} strokeLinejoin="round" />
        <path d={g.shade} fill="#8b5cf6" fillOpacity={i % 2 === 0 ? 0.2 : 0.08} />
        {!tiny && (
          <path d={g.strands} fill="none" stroke="#a78bfa" strokeOpacity={0.38} strokeWidth={1.4} strokeLinecap="round" />
        )}
        <g transform={`translate(${g.fx} ${g.fy}) rotate(${g.fr})`}>
          <motion.path
            d={g.flame}
            fill={`url(#${id}-flame)`}
            filter={`url(#${id}-fire)`}
            style={{ scaleX: flameX, scaleY: flameY, opacity: flameOpacity, originX: "0px", originY: "0px" }}
          />
        </g>
      </motion.g>
    </g>
  );
}

function Fox({ d, id, tiny }: { d: Drives; id: string; tiny: boolean }) {
  const breathe = useTransform(() => 1 + d.live * 0.012 * Math.sin((TAU * d.time.get()) / 4200));
  const hop = useTransform(() => -8 * d.kick.get());
  const eyeY = useTransform(() => {
    const s = (d.time.get() / 1000) % 5.4;
    const blink = d.live * Math.exp(-(((s - 5.0) / 0.06) ** 2));
    return (1 - 0.9 * blink) * (1 - 0.45 * Math.max(0, d.kick.get()));
  });
  const eyeGlow = useTransform(() => 0.18 + 0.82 * d.glow.get());
  const eyeGlowScale = useTransform(() => 0.85 + 0.25 * d.glow.get());
  const sigilOpacity = useTransform(() => 0.72 + 0.28 * d.glow.get());
  const sigilScale = useTransform(() => 1.15 * (1 + 0.14 * d.glow.get()));

  return (
    <motion.g style={{ scaleY: breathe, y: hop, originX: "150px", originY: "379px" }}>
      {/* far ear and far front leg sit behind the body for the 3/4 turn */}
      <path d={FOX.farEar} fill="#d6ccfa" stroke={INK} strokeWidth={2} strokeLinejoin="round" />
      <path d={FOX.farEarInner} fill={`url(#${id}-ear)`} opacity={0.7} />
      <path d={FOX.farLeg} fill="#cfc3f8" stroke={INK} strokeWidth={2} strokeLinejoin="round" />
      <path d={FOX.body} fill={`url(#${id}-body)`} stroke={INK} strokeWidth={2.4} strokeLinejoin="round" />
      <path d={FOX.haunch} fill="#a78bfa" fillOpacity={0.14} />
      <path d={FOX.innerEar} fill={`url(#${id}-ear)`} />
      <path d={FOX.thigh} fill="none" stroke="#a78bfa" strokeOpacity={0.6} strokeWidth={2} strokeLinecap="round" />
      {!tiny && (
        <path d={FOX.chestFur} fill="none" stroke="#a78bfa" strokeOpacity={0.45} strokeWidth={1.8} strokeLinecap="round" />
      )}
      <path d={FOX.cheeks} fill="none" stroke="#8b5cf6" strokeWidth={2.6} strokeLinecap="round" />
      <path d={FOX.mouth} fill="none" stroke={INK} strokeWidth={2} strokeLinecap="round" />
      <ellipse cx={43} cy={153} rx={6} ry={4.5} transform="rotate(-30 43 153)" fill={INK} />
      {/* eye: cyan halo brightens while thinking; blinks and squints on the done bounce */}
      {/* rotation lives on a wrapper: a CSS transform on the motion element would replace the attribute */}
      <g transform="rotate(-24 112 136)">
        <motion.ellipse
          cx={112}
          cy={136}
          rx={16}
          ry={8.5}
          fill="#67e8f9"
          filter={`url(#${id}-fire)`}
          style={{ opacity: eyeGlow, scale: eyeGlowScale, originX: "112px", originY: "136px" }}
        />
      </g>
      <motion.path
        d={FOX.eye}
        fill={`url(#${id}-eye)`}
        filter={`url(#${id}-fire)`}
        style={{ scaleY: eyeY, originX: "112px", originY: "137px" }}
      />
      {/* forehead flame sigil */}
      <g transform="translate(137 128) rotate(24)">
        <motion.path
          d={FOX.sigil}
          fill="#b69cff"
          filter={`url(#${id}-fire)`}
          style={{ opacity: sigilOpacity, scale: sigilScale, originX: "0px", originY: "0px" }}
        />
      </g>
    </motion.g>
  );
}

/** Kitsunebi: foxfire orbs on a tilted orbit, visible while thinking. */
function Orb({ k, d, id }: { k: number; d: Drives; id: string }) {
  const angle = useTransform(() => (TAU * d.time.get()) / 3600 + (k * TAU) / 4);
  const depth = useTransform(() => (Math.sin(angle.get()) + 1) / 2);
  const x = useTransform(() => {
    const a = angle.get();
    return CENTER[0] + 162 * Math.cos(a) * Math.cos(rad(-14)) - 56 * Math.sin(a) * Math.sin(rad(-14));
  });
  const y = useTransform(() => {
    const a = angle.get();
    return CENTER[1] + 20 + 162 * Math.cos(a) * Math.sin(rad(-14)) + 56 * Math.sin(a) * Math.cos(rad(-14));
  });
  const scale = useTransform(() => 0.6 + 0.55 * depth.get());
  const opacity = useTransform(() => d.live * d.pulse.get() * (0.35 + 0.65 * depth.get()));
  return (
    <motion.g style={{ x, y, scale, opacity, originX: "0px", originY: "0px" }}>
      <circle r={19} fill={`url(#${id}-${k % 2 ? "orbv" : "orbc"})`} />
      <circle r={3.4} fill="#ffffff" />
    </motion.g>
  );
}

/** One-shot celebration, remounted every time the state becomes "done". */
function DoneBurst({ id, still, layer }: { id: string; still: boolean; layer: "back" | "front" }) {
  const origin = { originX: `${CENTER[0]}px`, originY: `${CENTER[1]}px` };
  if (layer === "front") {
    if (still) return null;
    return (
      <g transform={`translate(${CENTER[0]} ${CENTER[1]})`} filter={`url(#${id}-fire)`}>
        {Array.from({ length: 8 }, (_, k) => {
          const a = (k / 8) * TAU + 0.3;
          const r = k % 2 ? 128 : 172;
          return (
            <motion.path
              key={k}
              d={SPARKLE}
              fill={["#ffffff", "#67e8f9", "#c4b5fd"][k % 3]}
              style={{ originX: "0px", originY: "0px" }}
              initial={{ x: Math.cos(a) * 60, y: Math.sin(a) * 60, scale: 0, opacity: 0, rotate: 0 }}
              animate={{
                x: Math.cos(a) * r,
                y: Math.sin(a) * r,
                scale: [0, 1.7, 1.2, 0],
                opacity: [0, 1, 1, 0],
                rotate: 140,
              }}
              transition={{
                default: { duration: 1.1, delay: 0.04 + k * 0.03, ease: [0.12, 0.9, 0.3, 1] },
                scale: { duration: 1.1, delay: 0.04 + k * 0.03, times: [0, 0.25, 0.6, 1] },
                opacity: { duration: 1.1, delay: 0.04 + k * 0.03, times: [0, 0.25, 0.6, 1] },
              }}
            />
          );
        })}
      </g>
    );
  }
  return (
    <motion.g initial={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.6 } }}>
      <motion.circle
        cx={CENTER[0]}
        cy={CENTER[1]}
        r={186}
        fill={`url(#${id}-bloom-fill)`}
        style={origin}
        initial={still ? { opacity: 0.4, scale: 1 } : { opacity: 0, scale: 0.55 }}
        animate={still ? { opacity: 0.4, scale: 1 } : { opacity: [0, 1, 0.42], scale: [0.55, 1.04, 1] }}
        transition={still ? { duration: 0 } : { duration: 1.4, times: [0, 0.22, 1], ease: "easeOut" }}
      />
      {[0, 1].map((k) => (
        <motion.circle
          key={k}
          cx={CENTER[0]}
          cy={CENTER[1]}
          r={176 - k * 10}
          fill="none"
          stroke={k ? "#67e8f9" : `url(#${id}-ring)`}
          strokeWidth={k ? 2 : 3.5}
          style={origin}
          initial={still ? { opacity: k ? 0 : 0.55, scale: 1 } : { opacity: 0, scale: 0.3 }}
          animate={still ? { opacity: k ? 0 : 0.55, scale: 1 } : { opacity: [0, 1, 0], scale: [0.3, 1] }}
          transition={still ? { duration: 0 } : { duration: 1.1 + k * 0.25, delay: k * 0.16, ease: [0.2, 0.7, 0.3, 1] }}
        />
      ))}
    </motion.g>
  );
}

/* ------------------------------------------------------------------------------------------ */
/* Component.                                                                                  */
/* ------------------------------------------------------------------------------------------ */

export function KitsuneMascot({ state, size = 160, className }: KitsuneMascotProps) {
  const id = `k${useId().replace(/:/g, "")}`;
  // Read the motion preference only after hydration so server and first client render match.
  const prefersReduced = useReducedMotion() === true;
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => setHydrated(true), []);
  const reduced = hydrated && prefersReduced;
  const tiny = size < 56;
  const pose = POSE[state];

  const time = useTime();
  const sway = useSpring(pose.sway, SPRING);
  const flare = useSpring(pose.flare, { stiffness: 120, damping: 15 });
  const pulse = useSpring(pose.pulse, SPRING);
  const glow = useSpring(pose.glow, SPRING);
  const kick = useMotionValue(0);
  const d: Drives = { time, sway, flare, pulse, glow, kick, live: reduced ? 0 : 1 };

  // A fresh key every time the state becomes "done" remounts the one-shot burst.
  const burst = useRef({ key: state === "done" ? 1 : 0, last: state });
  if (burst.current.last !== state) {
    if (state === "done") burst.current.key += 1;
    burst.current.last = state;
  }

  const kickAnim = useRef<AnimationPlaybackControls | null>(null);
  useEffect(() => {
    const target = POSE[state];
    const springs: [MotionValue<number>, number][] = [
      [sway, target.sway],
      [flare, target.flare],
      [pulse, target.pulse],
      [glow, target.glow],
    ];
    for (const [mv, v] of springs) {
      if (reduced) mv.jump(v);
      else mv.set(v);
    }
    kickAnim.current?.stop();
    if (state === "done" && !reduced) {
      kickAnim.current = animate(kick, [0, 1, -0.3, 0.1, 0], {
        duration: 1.3,
        times: [0, 0.2, 0.5, 0.76, 1],
        ease: "easeInOut",
      });
    } else if (reduced) {
      kick.jump(0);
    } else {
      // Leaving "done" early (for example straight back to thinking): ease out, never snap.
      kickAnim.current = animate(kick, 0, { type: "spring", stiffness: 220, damping: 26 });
    }
    return () => kickAnim.current?.stop();
  }, [state, reduced, sway, flare, pulse, glow, kick]);

  const halo = useTransform(() => 0.55 + 0.45 * glow.get() + d.live * 0.08 * Math.sin((TAU * time.get()) / 4200));

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 400 400"
      className={className}
      role="img"
      aria-label={`NineTail fox mascot, ${LABEL[state]}`}
    >
      <defs>
        {/* tails are drawn in a local frame (base at the bottom, tip at the top) */}
        <linearGradient id={`${id}-fur`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset=".55" stopColor="#faf8ff" />
          <stop offset=".74" stopColor="#e6ddff" />
          <stop offset=".88" stopColor="#c4b5fd" />
          <stop offset="1" stopColor="#a78bfa" />
        </linearGradient>
        <linearGradient id={`${id}-ink`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#24164a" stopOpacity="0" />
          <stop offset=".22" stopColor="#24164a" stopOpacity=".15" />
          <stop offset=".5" stopColor="#24164a" stopOpacity=".85" />
          <stop offset="1" stopColor="#24164a" stopOpacity=".9" />
        </linearGradient>
        <linearGradient id={`${id}-flame`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#a78bfa" stopOpacity="0" />
          <stop offset=".34" stopColor="#a78bfa" stopOpacity=".55" />
          <stop offset=".62" stopColor="#22d3ee" stopOpacity=".92" />
          <stop offset=".82" stopColor="#a5f3fc" stopOpacity=".88" />
          <stop offset="1" stopColor="#67e8f9" stopOpacity="0" />
        </linearGradient>
        <linearGradient id={`${id}-body`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset=".6" stopColor="#f6f4ff" />
          <stop offset="1" stopColor="#e4dcff" />
        </linearGradient>
        <linearGradient id={`${id}-ear`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#c4b5fd" stopOpacity=".5" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity=".9" />
        </linearGradient>
        <radialGradient id={`${id}-eye`} cx=".5" cy=".5" r=".6">
          <stop offset="0" stopColor="#ecfeff" />
          <stop offset=".5" stopColor="#67e8f9" />
          <stop offset="1" stopColor="#0891b2" />
        </radialGradient>
        <radialGradient id={`${id}-halo`}>
          <stop offset="0" stopColor="#7c3aed" stopOpacity=".34" />
          <stop offset=".55" stopColor="#7c3aed" stopOpacity=".12" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`${id}-bloom-fill`}>
          <stop offset="0" stopColor="#ffffff" stopOpacity=".55" />
          <stop offset=".45" stopColor="#c4b5fd" stopOpacity=".38" />
          <stop offset=".8" stopColor="#7c3aed" stopOpacity=".16" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`${id}-ring`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset=".5" stopColor="#c4b5fd" />
          <stop offset="1" stopColor="#67e8f9" />
        </linearGradient>
        {(["orbc", "orbv"] as const).map((o) => (
          <radialGradient key={o} id={`${id}-${o}`}>
            <stop offset="0" stopColor="#ffffff" />
            <stop offset=".22" stopColor={o === "orbc" ? "#a5f3fc" : "#ddd6fe"} stopOpacity=".95" />
            <stop offset=".5" stopColor={o === "orbc" ? "#22d3ee" : "#a78bfa"} stopOpacity=".45" />
            <stop offset="1" stopColor={o === "orbc" ? "#22d3ee" : "#7c3aed"} stopOpacity="0" />
          </radialGradient>
        ))}
        {/* soft violet bloom around the whole figure */}
        <filter id={`${id}-bloom`} x="-15%" y="-15%" width="130%" height="130%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="7" result="b" />
          <feColorMatrix in="b" type="matrix" values=".6 0 0 0 0  0 .45 0 0 0  0 0 1 0 0  0 0 0 .75 0" result="g" />
          <feMerge>
            <feMergeNode in="g" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        {/* tight glow for spirit fire, eye, sigil and sparkles */}
        <filter id={`${id}-fire`} x="-60%" y="-60%" width="220%" height="220%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="3" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* spirit halo behind the fox */}
      <motion.circle cx={CENTER[0] + 20} cy={CENTER[1]} r={196} fill={`url(#${id}-halo)`} style={{ opacity: halo }} />

      <AnimatePresence>
        {state === "done" && <DoneBurst key={burst.current.key} id={id} still={reduced} layer="back" />}
      </AnimatePresence>

      {/* the figure: art is drawn at full size, then inset so flared tails and the aura stay in frame */}
      <g transform="translate(192 207) scale(.9) translate(-200 -200)" filter={`url(#${id}-bloom)`}>
        <g>
          {DRAW_ORDER.map((i) => (
            <Tail key={i} i={i} d={d} id={id} tiny={tiny} />
          ))}
        </g>
        <Fox d={d} id={id} tiny={tiny} />
      </g>

      {!reduced && [0, 1, 2, 3].map((k) => <Orb key={k} k={k} d={d} id={id} />)}

      <AnimatePresence>
        {state === "done" && <DoneBurst key={burst.current.key} id={id} still={reduced} layer="front" />}
      </AnimatePresence>
    </svg>
  );
}

export default KitsuneMascot;
