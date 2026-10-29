"use client";

/**
 * KitsuneMascot, direction A: "Celestial Origami".
 * A faceted white nine-tailed fox, seated and front-facing, with nine crescent-blade
 * tails fanned behind it like a halo. Each tail tip carries a cyan to violet spirit flame.
 *
 * States: idle (tails sway in a ripple, breathing, blinks), thinking (tails flare and
 * pulse 1 to 9, eyes brighten, spirit orbs orbit), done (one-shot aura flash, sparkle
 * burst and tail bounce, then a calm glowing pose).
 *
 * Art is drawn on a 400 x 400 grid shown through a padded viewBox (-30 -30 460 460) so the
 * flared tails and the aura stay inside the frame. The tails pivot at (200, 300), behind the chest.
 */

import { AnimatePresence, motion, useReducedMotion, type TargetAndTransition, type Transition } from "framer-motion";
import { useId } from "react";
import type { MascotState } from "@/lib/types";
import type { KitsuneMascotProps } from "./types";

// ---------------------------------------------------------------------------
// Geometry (computed once at module load, deterministic for SSR)
// ---------------------------------------------------------------------------

const PIVOT_X = 200;
const PIVOT_Y = 300;
const SPREAD = 21.5; // degrees between neighbouring tails
// Indexed by distance from the centre tail (0 = centre, 4 = outermost).
const LENGTHS = [266, 256, 238, 214, 190];
const WIDTHS = [48, 50, 52, 54, 52];
const CURLS = [0, 30, 46, 58, 64]; // how far each tip curls back up toward the crown
const FLARE = [0, 3.2, 5.5, 6, 2.5]; // extra fan-out (degrees) while thinking; the outer pair stays inside the frame

type Pt = [number, number];
const r1 = (n: number) => Math.round(n * 10) / 10;
const pts = (list: Pt[]) => list.map(([x, y]) => `${r1(x)},${r1(y)}`).join(" ");

interface TailGeo {
  /** 0..8, left to right. */
  index: number;
  /** -4..4, signed distance from the centre tail. */
  k: number;
  angle: number;
  lit: string;
  shade: string;
  outline: string;
  flame: { x: number; y: number; angle: number };
}

/** One crescent blade in local space: base at (0,0), pointing up (-y), split into two facets. */
function buildTail(index: number): TailGeo {
  const k = index - 4;
  const ak = Math.abs(k);
  const L = LENGTHS[ak];
  const W = WIDTHS[ak];
  const bend = -Math.sign(k) * CURLS[ak];
  const p1: Pt = [0, -L * 0.48];
  const p2: Pt = [bend, -L];
  const at = (t: number): Pt => [2 * (1 - t) * t * p1[0] + t * t * p2[0], 2 * (1 - t) * t * p1[1] + t * t * p2[1]];
  const tangent = (t: number): Pt => {
    const dx = 2 * (1 - t) * p1[0] + 2 * t * (p2[0] - p1[0]);
    const dy = 2 * (1 - t) * p1[1] + 2 * t * (p2[1] - p1[1]);
    const m = Math.hypot(dx, dy);
    return [dx / m, dy / m];
  };
  const width = (t: number) => W * Math.pow(Math.sin(Math.PI * (0.1 + 0.9 * Math.pow(t, 0.8))), 0.8);
  const wide = bend >= 0 ? 0.62 : 0.38; // the convex side is wider, which gives the crescent
  const spine: Pt[] = [];
  const a: Pt[] = [];
  const b: Pt[] = [];
  const SEGMENTS = 7; // straight segments give the folded-paper facets
  for (let i = 0; i <= SEGMENTS; i++) {
    const t = i / SEGMENTS;
    const p = at(t);
    const [dx, dy] = tangent(t);
    const n: Pt = [-dy, dx];
    const w = width(t);
    spine.push(p);
    a.push([p[0] - n[0] * w * wide, p[1] - n[1] * w * wide]);
    b.push([p[0] + n[0] * w * (1 - wide), p[1] + n[1] * w * (1 - wide)]);
  }
  const back = spine.slice().reverse();
  const left = pts([...a, ...back]);
  const right = pts([...b, ...back]);
  // The facet that faces the fox's centre line catches the light.
  const lit = k > 0 ? left : k < 0 ? right : left;
  const shade = lit === left ? right : left;
  const [tx, ty] = tangent(1);
  const tip = spine[SEGMENTS];
  return {
    index,
    k,
    angle: k * SPREAD,
    lit,
    shade,
    outline: pts([...a, ...b.slice().reverse()]),
    flame: { x: r1(tip[0] - tx * 8), y: r1(tip[1] - ty * 8), angle: r1((Math.atan2(tx, -ty) * 180) / Math.PI) },
  };
}

const TAILS = Array.from({ length: 9 }, (_, i) => buildTail(i));
// Paint the outer tails first so the inner ones overlap them.
const PAINT_ORDER = TAILS.slice().sort((p, q) => Math.abs(q.k) - Math.abs(p.k) || p.k - q.k);

/** Mirror "x,y x,y" point lists across the vertical centre line. */
const mirror = (list: string) =>
  list
    .split(" ")
    .map((p) => {
      const [x, y] = p.split(",").map(Number);
      return `${400 - x},${y}`;
    })
    .join(" ");

// Left-hand facets of the symmetric body and head: [points, fill].
const BODY_FACETS: [string, string][] = [
  ["154,268 132,312 122,346 128,368 142,377 160,377 164,330", "#d2c7fa"], // haunch, outer
  ["154,268 164,330 160,377 184,377 182,318", "#efebfe"], // haunch, inner
  ["132,368 158,363 164,377 128,377", "#f4f1ff"], // hind paw
  ["180,296 198,300 198,370 182,370", "#ffffff"], // front leg
  ["180,296 188,298 188,370 182,370", "#e2dcfc"], // front leg shade
  ["179,366 198,366 199,378 174,378", "#f8f6ff"], // front paw
];
const RUFF_FACETS: [string, string][] = [["158,220 170,256 156,262", "#e6e0fd"]];
const HEAD_FACETS: [string, string][] = [
  ["110,196 136,204 122,222 168,228 156,198 128,152", "#e6e1fd"], // cheek ruff
  ["110,196 136,204 122,222 128,152", "#d9d1fb"], // cheek ruff, outer
  ["186,196 188,252 168,228 160,206", "#f0edfe"], // muzzle side
];

function Pair({ points, fill }: { points: string; fill: string }) {
  return (
    <>
      <polygon points={points} fill={fill} />
      <polygon points={mirror(points)} fill={fill} />
    </>
  );
}

const CUT = { stroke: "#120c2a", strokeOpacity: 0.55, strokeWidth: 3, strokeLinejoin: "round" as const };

// Eight four-point sparkles for the done burst (around the centre at radius ~140).
const SPARKLES = Array.from({ length: 8 }, (_, i) => {
  const a = ((i * 45 + 22.5) * Math.PI) / 180;
  const r = i % 2 ? 128 : 150;
  return { x: r1(200 + Math.cos(a) * r), y: r1(210 + Math.sin(a) * r), s: i % 2 ? 0.7 : 1 };
});
// Spirit-fire orbs for thinking: [cx, cy, r, fill], on two counter-rotating orbits around (200, 210).
const ORBS_A: [number, number, number, string][] = [
  [200, 22, 6, "#67e8f9"],
  [363, 304, 5, "#c4b5fd"],
  [37, 304, 4.5, "#a5f3fc"],
];
const ORBS_B: [number, number, number, string][] = [
  [66, 124, 4, "#a78bfa"],
  [334, 124, 4, "#67e8f9"],
];
const SPARKLE_PATH = "M0,-9 L2.2,-2.2 9,0 2.2,2.2 0,9 -2.2,2.2 -9,0 -2.2,-2.2 Z";

// ---------------------------------------------------------------------------
// Motion helpers
// ---------------------------------------------------------------------------

const UI_SPRING: Transition = { type: "spring", stiffness: 380, damping: 30 };
const SOFT_SPRING: Transition = { type: "spring", stiffness: 140, damping: 16 };
const PULSE = 1.2; // seconds per thinking wave
const STAGGER = 0.1; // seconds between tails in the thinking wave

const origin = (x: number, y: number) => ({ originX: `${x}px`, originY: `${y}px` });
const AT_PIVOT = origin(0, 0);
/**
 * framer-motion only measures an SVG element (needed to apply any transform) on its first
 * render if it already has a transform value, so every transformed layer gets an explicit
 * identity `initial`. Do not switch these to initial={false}: that also skips looping keyframes.
 */
const REST = { rotate: 0, scale: 1 };

/** Same targets either way (SSR-safe); reduced motion just jumps to the final keyframe. */
function target(reduce: boolean, values: TargetAndTransition, transition: Transition): TargetAndTransition {
  return { ...values, transition: reduce ? { duration: 0 } : transition };
}

function loop(duration: number, delay = 0, extra: Transition = {}): Transition {
  return { duration, delay, repeat: Infinity, ease: "easeInOut", ...extra };
}

// ---------------------------------------------------------------------------
// One tail: static base angle, then a flare layer, then a sway/pulse layer.
// ---------------------------------------------------------------------------

function Tail({ geo, state, reduce, uid }: { geo: TailGeo; state: MascotState; reduce: boolean; uid: string }) {
  const { k, index } = geo;
  const ak = Math.abs(k);

  const flare: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { rotate: 0, scale: 1 }, SOFT_SPRING),
    thinking: target(reduce, { rotate: Math.sign(k) * FLARE[ak], scale: 1.03 }, { type: "spring", stiffness: 200, damping: 17 }),
    done: target(
      reduce,
      { rotate: [null, Math.sign(k) * FLARE[ak] * 1.5, Math.sign(k) * -1, 0], scale: [null, 1.07, 0.99, 1] },
      { duration: 0.95, times: [0, 0.32, 0.68, 1], ease: "easeOut", delay: ak * 0.035 },
    ),
  };

  const sway: Record<MascotState, TargetAndTransition> = {
    idle: target(
      reduce,
      { rotate: [0, 3 + ak * 0.6, 0, -(3 + ak * 0.6), 0], scale: 1 },
      { rotate: loop(4 + ak * 0.2, index * 0.28), scale: SOFT_SPRING },
    ),
    thinking: target(
      reduce,
      { rotate: 0, scale: [1, 1.06, 1, 1] },
      { rotate: UI_SPRING, scale: loop(PULSE, index * STAGGER, { times: [0, 0.16, 0.48, 1] }) },
    ),
    done: target(reduce, { rotate: 0, scale: 1 }, UI_SPRING),
  };

  // Flames: a state layer (spring / thinking pulse / done pop) wraps a flicker loop that never
  // restarts, so switching state never snaps a flame back to a loop's first keyframe.
  const flame: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { scale: 1 }, SOFT_SPRING),
    thinking: reduce
      ? target(reduce, { scale: 1.25 }, {})
      : target(reduce, { scale: [1, 1.36, 1.04, 1] }, loop(PULSE, index * STAGGER, { times: [0, 0.16, 0.48, 1] })),
    done: target(reduce, { scale: [null, 1.5, 1.12] }, { duration: 0.9, ease: "easeOut" }),
  };
  const flicker = target(
    reduce,
    { scale: [1, 1.12, 0.93, 1.05, 1], opacity: [0.85, 1, 0.78, 0.95, 0.85] },
    loop(1.7 + (index % 3) * 0.35, index * 0.13),
  );

  return (
    <g transform={`translate(${PIVOT_X} ${PIVOT_Y}) rotate(${geo.angle})`}>
      <motion.g style={AT_PIVOT} initial={REST} animate={flare[state]}>
        <motion.g style={AT_PIVOT} initial={REST} animate={sway[state]}>
          <polygon points={geo.outline} fill="none" stroke="#120c2a" strokeOpacity={0.5} strokeWidth={3} strokeLinejoin="round" />
          <polygon points={geo.shade} fill={`url(#${uid}-shade)`} />
          <polygon points={geo.lit} fill={`url(#${uid}-lit)`} />
          <g transform={`translate(${geo.flame.x} ${geo.flame.y}) rotate(${geo.flame.angle})`}>
            <motion.g style={origin(0, 4)} initial={{ scale: 1 }} animate={flame[state]}>
              <motion.g style={origin(0, 4)} initial={{ scale: 1, opacity: 0.85 }} animate={flicker}>
                <path d="M0,6 C7,0 8,-10 0,-24 C-8,-10 -7,0 0,6 Z" fill={`url(#${uid}-flame)`} filter={`url(#${uid}-glow)`} />
                <path d="M0,3 C3,0 3.5,-5 0,-12 C-3.5,-5 -3,0 0,3 Z" fill="#ecfeff" />
              </motion.g>
            </motion.g>
          </g>
        </motion.g>
      </motion.g>
    </g>
  );
}

// ---------------------------------------------------------------------------
// The mascot
// ---------------------------------------------------------------------------

export function KitsuneMascot({ state, size = 160, className }: KitsuneMascotProps) {
  const uid = `kma${useId().replace(/:/g, "")}`;
  const reduce = useReducedMotion() ?? false;
  const compact = size < 56; // drop hairline decorations that turn to mush at icon sizes
  const url = (name: string) => `url(#${uid}-${name})`;

  const halo: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { opacity: 0.85, scale: 1 }, SOFT_SPRING),
    thinking: target(reduce, { opacity: [0.85, 1, 0.85], scale: [1, 1.05, 1] }, loop(PULSE)),
    done: target(reduce, { opacity: 1, scale: 1.06 }, SOFT_SPRING),
  };

  const fox: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { y: 0 }, SOFT_SPRING),
    thinking: target(reduce, { y: -2 }, SOFT_SPRING),
    done: target(reduce, { y: [null, -12, 0, -4, 0] }, { duration: 0.9, times: [0, 0.3, 0.6, 0.8, 1], ease: "easeOut" }),
  };

  const breathe: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { scaleY: [1, 1.014, 1] }, loop(4.2)),
    thinking: target(reduce, { scaleY: [1, 1.01, 1] }, loop(PULSE)),
    done: target(reduce, { scaleY: 1 }, SOFT_SPRING),
  };

  // Open eyes: blink in idle, hide in done (happy eyes take over).
  const eyes: Record<MascotState, TargetAndTransition> = {
    idle: target(
      reduce,
      { scaleY: [1, 1, 0.08, 1, 1], opacity: 1 },
      { scaleY: loop(5.2, 1.2, { times: [0, 0.9, 0.93, 0.96, 1], ease: "linear" }), opacity: { duration: 0.2 } },
    ),
    thinking: target(reduce, { scaleY: 1, opacity: 1 }, UI_SPRING),
    done: target(reduce, { scaleY: 0.2, opacity: 0 }, { duration: 0.18 }),
  };
  const eyeFire: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { opacity: 0 }, { duration: 0.4 }),
    thinking: target(reduce, { opacity: 1 }, { duration: 0.4 }),
    done: target(reduce, { opacity: 0 }, { duration: 0.2 }),
  };
  const happyEyes: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { opacity: 0, scaleY: 0.4 }, { duration: 0.2 }),
    thinking: target(reduce, { opacity: 0, scaleY: 0.4 }, { duration: 0.2 }),
    done: target(reduce, { opacity: 1, scaleY: 1 }, { ...UI_SPRING, delay: 0.1 }),
  };
  const mark: Record<MascotState, TargetAndTransition> = {
    idle: target(reduce, { scale: 1, opacity: [1, 0.78, 1] }, { scale: SOFT_SPRING, opacity: loop(3) }),
    thinking: target(reduce, { scale: [1, 1.35, 1], opacity: 1 }, loop(PULSE)),
    done: target(reduce, { scale: [null, 1.6, 1.15], opacity: 1 }, { duration: 0.8, ease: "easeOut" }),
  };

  return (
    <svg
      width={size}
      height={size}
      viewBox="-30 -30 460 460"
      className={className}
      role="img"
      aria-label={`NineTail fox mascot, ${state}`}
      style={{ overflow: "visible" }}
    >
      <defs>
        <radialGradient id={`${uid}-halo`}>
          <stop offset="0" stopColor="#7c3aed" stopOpacity="0.4" />
          <stop offset="0.55" stopColor="#7c3aed" stopOpacity="0.12" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`${uid}-cyanHalo`}>
          <stop offset="0" stopColor="#22d3ee" stopOpacity="0.3" />
          <stop offset="0.6" stopColor="#22d3ee" stopOpacity="0.08" />
          <stop offset="1" stopColor="#22d3ee" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`${uid}-flash`}>
          <stop offset="0" stopColor="#ffffff" stopOpacity="0.9" />
          <stop offset="0.45" stopColor="#c4b5fd" stopOpacity="0.55" />
          <stop offset="0.75" stopColor="#7c3aed" stopOpacity="0.22" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`${uid}-whiteFlash`}>
          <stop offset="0" stopColor="#ffffff" stopOpacity="0.85" />
          <stop offset="0.4" stopColor="#f6f4ff" stopOpacity="0.4" />
          <stop offset="0.75" stopColor="#c4b5fd" stopOpacity="0.08" />
          <stop offset="1" stopColor="#c4b5fd" stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`${uid}-lit`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#e4ddff" />
          <stop offset="0.5" stopColor="#ffffff" />
          <stop offset="0.8" stopColor="#f3f0ff" />
          <stop offset="1" stopColor="#b49cfb" />
        </linearGradient>
        <linearGradient id={`${uid}-shade`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#9c8ce0" />
          <stop offset="0.5" stopColor="#cdc2fb" />
          <stop offset="0.82" stopColor="#b5a3fb" />
          <stop offset="1" stopColor="#7c3aed" />
        </linearGradient>
        <linearGradient id={`${uid}-flame`} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#67e8f9" />
          <stop offset="0.45" stopColor="#22d3ee" />
          <stop offset="1" stopColor="#a78bfa" stopOpacity="0.9" />
        </linearGradient>
        <linearGradient id={`${uid}-ear`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7c3aed" />
          <stop offset="1" stopColor="#c4b5fd" />
        </linearGradient>
        <linearGradient id={`${uid}-eye`} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#22d3ee" />
          <stop offset="1" stopColor="#a5f3fc" />
        </linearGradient>
        {/* Small bloom for flames, eyes and orbs. */}
        <filter id={`${uid}-glow`} x="-60%" y="-60%" width="220%" height="220%">
          <feGaussianBlur stdDeviation="3.2" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        {/* Soft lavender rim light around the whole fox. */}
        <filter id={`${uid}-bloom`} x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur in="SourceAlpha" stdDeviation="7" result="b" />
          <feFlood floodColor="#c4b5fd" floodOpacity="0.55" />
          <feComposite in2="b" operator="in" result="g" />
          <feMerge>
            <feMergeNode in="g" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Nebula halo + celestial orbit ring */}
      <motion.circle cx="200" cy="205" r="190" fill={url("halo")} style={origin(200, 205)} initial={{ opacity: 0.85, scale: 1 }} animate={halo[state]} />
      <motion.circle
        cx="200"
        cy="205"
        r="170"
        fill={url("cyanHalo")}
        initial={{ opacity: 0 }}
        animate={target(reduce, { opacity: state === "thinking" ? 1 : 0 }, { duration: 0.5 })}
      />
      {!compact && (
        <>
          <motion.circle
            cx="200"
            cy="214"
            r="158"
            fill="none"
            stroke="#a78bfa"
            strokeOpacity="0.28"
            strokeWidth="1.5"
            strokeDasharray="2 7"
            style={origin(200, 214)}
            initial={{ rotate: 0 }}
            animate={target(reduce, { rotate: [0, 360] }, { duration: 90, repeat: Infinity, ease: "linear" })}
          />
          <path d="M60,96 l2,-7 2,7 7,2 -7,2 -2,7 -2,-7 -7,-2z" fill="#c4b5fd" opacity="0.7" />
          <path d="M340,84 l1.6,-5 1.6,5 5,1.6 -5,1.6 -1.6,5 -1.6,-5 -5,-1.6z" fill="#67e8f9" opacity="0.7" />
        </>
      )}

      {/* Done: one-shot aura flash behind the fox (remounts each time state becomes done) */}
      <AnimatePresence>
        {state === "done" && (
          <motion.g key="aura" initial={{ opacity: 1 }} animate={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.5 } }}>
            <motion.circle
              cx="200"
              cy="210"
              r="190"
              fill={url("flash")}
              style={origin(200, 210)}
              initial={{ opacity: 0, scale: 0.3 }}
              animate={target(reduce, { opacity: [0, 1, 0.45], scale: [0.3, 1.06, 1] }, { duration: 1.2, times: [0, 0.22, 1], ease: "easeOut" })}
            />
            <motion.circle
              cx="200"
              cy="210"
              r="110"
              fill="none"
              stroke="#ffffff"
              strokeWidth="5"
              filter={url("glow")}
              style={origin(200, 210)}
              initial={{ opacity: 0, scale: 0.55 }}
              animate={target(reduce, { opacity: [1, 0], scale: [0.55, 1.7] }, { duration: 1, ease: "easeOut" })}
            />
            <motion.circle
              cx="200"
              cy="210"
              r="110"
              fill="none"
              stroke="#67e8f9"
              strokeWidth="3.5"
              filter={url("glow")}
              style={origin(200, 210)}
              initial={{ opacity: 0, scale: 0.55 }}
              animate={target(reduce, { opacity: [0.9, 0], scale: [0.55, 1.55] }, { duration: 1.1, delay: 0.16, ease: "easeOut" })}
            />
            {/* The calm aura ring that stays while done (and the static ring for reduced motion). */}
            <motion.circle
              cx="200"
              cy="210"
              r="176"
              fill="none"
              stroke="#c4b5fd"
              strokeWidth="1.5"
              initial={{ opacity: 0 }}
              animate={target(reduce, { opacity: [0, 0, 0.55] }, { duration: 1.4, times: [0, 0.45, 1] })}
            />
          </motion.g>
        )}
      </AnimatePresence>

      {/* The fox: tails, body, head. Hops on done. */}
      <motion.g style={origin(200, 377)} initial={{ y: 0 }} animate={fox[state]}>
        <g filter={url("bloom")}>
          {PAINT_ORDER.map((geo) => (
            <Tail key={geo.index} geo={geo} state={state} reduce={reduce} uid={uid} />
          ))}

          <motion.g style={origin(200, 377)} initial={{ scaleY: 1 }} animate={breathe[state]}>
            {/* Body: torso, haunches, legs, chest ruff */}
            <ellipse cx="200" cy="377" rx="92" ry="6" fill="#7c3aed" opacity="0.4" />
            <polygon
              points="170,224 230,224 246,262 262,306 276,346 272,368 258,377 142,377 128,368 124,346 138,306 154,262"
              fill="#e2dbfd"
              {...CUT}
            />
            {BODY_FACETS.map(([p, fill]) => (
              <Pair key={p} points={p} fill={fill} />
            ))}
            <polygon points="158,220 242,220 244,262 230,256 226,292 213,282 200,314 187,282 174,292 170,256 156,262" fill="#ffffff" />
            {RUFF_FACETS.map(([p, fill]) => (
              <Pair key={p} points={p} fill={fill} />
            ))}
            <polygon points="200,236 226,292 213,282 200,314 187,282 174,292" fill="#eeeafe" />

            {/* Head: cut-line underlay, ears, skull, facets */}
            <polygon
              points="128,152 142,50 182,114 200,106 218,114 258,50 272,152 290,196 264,204 278,222 232,228 212,252 200,260 188,252 168,228 122,222 136,204 110,196"
              fill="#ffffff"
              {...CUT}
            />
            <Pair points="128,152 142,50 182,114" fill="#ffffff" />
            <Pair points="140,138 146,74 172,118" fill={url("ear")} />
            <Pair points="128,152 142,50 146,74 140,138" fill="#ddd6fe" />
            <polygon
              points="200,106 222,112 272,152 290,196 264,204 278,222 232,228 212,252 200,260 188,252 168,228 122,222 136,204 110,196 128,152 178,112"
              fill="#ffffff"
            />
            {HEAD_FACETS.map(([p, fill]) => (
              <Pair key={p} points={p} fill={fill} />
            ))}
            <polygon points="200,150 214,196 212,252 200,260 188,252 186,196" fill="#fbfaff" />
            <polygon points="200,106 222,112 214,150 200,166 186,150 178,112" fill="#fdfcff" />
            <polygon points="192,248 208,248 200,260" fill="#2a1f4d" />

            {/* Forehead spirit-flame mark */}
            <motion.g style={origin(200, 146)} initial={{ scale: 1, opacity: 1 }} animate={mark[state]}>
              <path d="M200,152 C206,146 206,136 200,124 C194,136 194,146 200,152 Z" fill={url("flame")} filter={url("glow")} />
            </motion.g>

            {/* Eyes: open (blinking) + thinking fire overlay */}
            <motion.g style={origin(200, 180)} initial={{ scaleY: 1, opacity: 1 }} animate={eyes[state]}>
              <g filter={url("glow")}>
                <path d="M186,188 Q172,168 148,170 Q160,188 186,188 Z" fill={url("eye")} />
                <path d="M214,188 Q228,168 252,170 Q240,188 214,188 Z" fill={url("eye")} />
              </g>
              <motion.g initial={{ opacity: 0 }} animate={eyeFire[state]} filter={url("glow")}>
                <path d="M182,185 Q171,172 154,172 Q163,184 182,185 Z" fill="#ecfeff" />
                <path d="M218,185 Q229,172 246,172 Q237,184 218,185 Z" fill="#ecfeff" />
              </motion.g>
              {!compact && (
                <>
                  <ellipse cx="172" cy="181" rx="2.6" ry="5.5" fill="#1b1340" transform="rotate(-20 172 181)" />
                  <ellipse cx="228" cy="181" rx="2.6" ry="5.5" fill="#1b1340" transform="rotate(20 228 181)" />
                </>
              )}
            </motion.g>

            {/* Happy closed eyes for done */}
            <motion.g style={origin(200, 180)} initial={{ opacity: 0, scaleY: 0.4 }} animate={happyEyes[state]} filter={url("glow")}>
              <path d="M150,184 Q168,164 186,184" fill="none" stroke="#67e8f9" strokeWidth="6" strokeLinecap="round" />
              <path d="M214,184 Q232,164 250,184" fill="none" stroke="#67e8f9" strokeWidth="6" strokeLinecap="round" />
            </motion.g>
          </motion.g>
        </g>
      </motion.g>

      {/* Thinking: spirit-fire orbs orbiting the fox */}
      <AnimatePresence>
        {state === "thinking" && (
          <motion.g
            key="orbs"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: reduce ? 0 : 0.4 }}
            filter={url("glow")}
          >
            <motion.g
              style={origin(200, 210)}
              initial={{ rotate: 0 }}
              animate={target(reduce, { rotate: [0, 360] }, { duration: 3.6, repeat: Infinity, ease: "linear" })}
            >
              {ORBS_A.map(([cx, cy, r, fill]) => (
                <g key={`${cx}-${cy}`}>
                  <circle cx={cx} cy={cy} r={r * 2.4} fill={fill} opacity="0.22" />
                  <circle cx={cx} cy={cy} r={r} fill={fill} />
                  <circle cx={cx} cy={cy} r={r * 0.45} fill="#ffffff" />
                </g>
              ))}
            </motion.g>
            <motion.g
              style={origin(200, 210)}
              initial={{ rotate: 0 }}
              animate={target(reduce, { rotate: [360, 0] }, { duration: 5.2, repeat: Infinity, ease: "linear" })}
            >
              {ORBS_B.map(([cx, cy, r, fill]) => (
                <g key={`${cx}-${cy}`}>
                  <circle cx={cx} cy={cy} r={r * 2.4} fill={fill} opacity="0.22" />
                  <circle cx={cx} cy={cy} r={r} fill={fill} />
                </g>
              ))}
            </motion.g>
          </motion.g>
        )}
      </AnimatePresence>

      {/* Done: quick white flash over the fox */}
      <AnimatePresence>
        {state === "done" && (
          <motion.circle
            key="flash"
            cx="200"
            cy="200"
            r="200"
            fill={url("whiteFlash")}
            style={origin(200, 200)}
            initial={{ opacity: 0, scale: 0.4 }}
            animate={target(reduce, { opacity: [0, 0.8, 0], scale: [0.4, 1, 1.1] }, { duration: 0.75, times: [0, 0.25, 1], ease: "easeOut" })}
            exit={{ opacity: 0 }}
            pointerEvents="none"
          />
        )}
      </AnimatePresence>

      {/* Done: sparkle burst in front */}
      <AnimatePresence>
        {state === "done" && (
          <motion.g
            key="sparkles"
            style={origin(200, 210)}
            initial={{ opacity: 0, scale: 0.35, rotate: 0 }}
            animate={target(
              reduce,
              { opacity: [0, 1, 0], scale: [0.35, 1.25], rotate: [0, 20] },
              { duration: 1.25, ease: "easeOut", opacity: { duration: 1.25, times: [0, 0.25, 1] } },
            )}
            exit={{ opacity: 0 }}
          >
            {SPARKLES.map((s, i) => (
              <path
                key={i}
                d={SPARKLE_PATH}
                transform={`translate(${s.x} ${s.y}) scale(${s.s * 1.3})`}
                fill={i % 3 === 0 ? "#67e8f9" : "#ffffff"}
              />
            ))}
          </motion.g>
        )}
      </AnimatePresence>
    </svg>
  );
}

export default KitsuneMascot;
