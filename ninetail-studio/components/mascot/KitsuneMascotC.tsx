"use client";

/**
 * NineTail mascot, direction C ("Hero Mascot").
 *
 * A front-facing seated white kitsune with a big friendly head, cyan almond eyes and a
 * fluffy chest tuft. Nine plump plumes fan out behind it in a crown, each ending in a
 * violet-to-cyan spirit flame.
 *
 * Motion model: one animation-frame loop drives a set of MotionValues (transforms and
 * opacity only). Per-state parameters (spread, sway, pulse, glow...) ease towards their
 * targets every frame, so state changes blend smoothly instead of snapping. The done
 * flash is a keyed one-shot that replays every time `state` becomes "done".
 */

import { motion, motionValue, useAnimationFrame, useReducedMotion } from "framer-motion";
import { useCallback, useEffect, useId, useRef, useState } from "react";
import type { MascotState } from "@/lib/types";
import type { KitsuneMascotProps } from "./types";

/* ------------------------------------------------------------------------------------
 * Geometry (viewBox 0 0 400 400)
 * ---------------------------------------------------------------------------------- */

/** Where every tail joins the body (hidden behind the rump). Tails rotate about it. */
const PIVOT = { x: 200, y: 300 };
/** The fox is drawn at full size and scaled about its base so the tails can fan around it. */
const FOX_BASE = { x: 200, y: 358 };
const FOX_SCALE = 0.84;
/** Whole scene is shrunk a touch so the flare and the done aura fit inside the frame. */
const SCENE_SCALE = 0.92;

const TAIL_ANGLES = [-100, -75, -50, -25, 0, 25, 50, 75, 100];
const TAIL_LEN = [238, 222, 184, 153, 150]; // by distance from the centre tail
const TAIL_CURL = [0, 8, 12, 14, 14]; // tips curl outward

/** One plume, drawn pointing up from (0,0) for a length of 200. [command, ...x,y pairs] */
const PLUME: [string, ...number[]][] = [
  ["M", -6, 8],
  ["C", -12, -20, -31, -44, -33, -80],
  ["C", -34, -104, -31, -124, -25, -140],
  ["C", -32, -147, -30, -160, -20, -165], // soft fur scallop
  ["C", -14, -180, -7, -194, 0, -202],
  ["C", 7, -194, 14, -180, 20, -165],
  ["C", 30, -160, 32, -147, 25, -140], // soft fur scallop
  ["C", 31, -124, 34, -104, 33, -80],
  ["C", 31, -44, 12, -20, 6, 8],
  ["Z"],
];

/** Stretch the plume to length r and bend its tip sideways by `curl`. */
function plumePath(r: number, curl: number): string {
  const k = r / 200;
  const kx = 0.7 + 0.3 * k;
  return PLUME.map(([cmd, ...n]) => {
    const pts: string[] = [];
    for (let i = 0; i < n.length; i += 2) {
      const t = Math.max(0, -n[i + 1] / 200);
      pts.push(`${(n[i] * kx + curl * t * t).toFixed(1)} ${(n[i + 1] * k).toFixed(1)}`);
    }
    return cmd + pts.join(" ");
  }).join(" ");
}

interface TailGeom {
  angle: number;
  r: number;
  curl: number;
  tilt: number;
  d: string;
}

const TAILS: TailGeom[] = TAIL_ANGLES.map((angle, i) => {
  const dist = Math.abs(i - 4);
  const r = TAIL_LEN[dist];
  const curl = TAIL_CURL[dist] * (i < 4 ? -1 : 1);
  return { angle, r, curl, tilt: (Math.atan2(2 * curl, r) * 180) / Math.PI, d: plumePath(r, curl) };
});
/** Outermost tails first so the centre tail sits in front. */
const DRAW_ORDER = TAILS.map((_, i) => i).sort((a, b) => Math.abs(b - 4) - Math.abs(a - 4));

// Spirit flame drawn around a plume tip at (0,0).
const FLAME = "M -18,34 C -26,16 -17,2 -9,-7 C -3,-13 0,-17 4,-27 C 9,-16 19,-7 20,6 C 23,18 20,28 17,34 C 7,41 -8,41 -18,34 Z";
const FLAME_CORE = "M -5,22 C -8,12 -3,2 2,-11 C 6,0 9,12 6,22 C 3,26 -2,26 -5,22 Z";

// Fox parts, drawn at full size (before FOX_SCALE).
const EAR_L = "M 136,148 C 124,116 116,88 120,56 C 144,66 168,88 186,116 Z";
const EAR_R = "M 264,148 C 276,116 284,88 280,56 C 256,66 232,88 214,116 Z";
const EAR_L_IN = "M 145,134 C 137,112 132,94 132,74 C 147,84 161,100 171,118 Z";
const EAR_R_IN = "M 255,134 C 263,112 268,94 268,74 C 253,84 239,100 229,118 Z";
const EAR_L_TUFT = "M 144,138 Q 146,124 143,112 Q 151,120 155,128 Q 157,118 156,108 Q 163,118 166,128 Q 169,121 172,116 L 176,134 Z";
const EAR_R_TUFT = "M 256,138 Q 254,124 257,112 Q 249,120 245,128 Q 243,118 244,108 Q 237,118 234,128 Q 231,121 228,116 L 224,134 Z";
const HEAD = `M 200,104 C 170,104 146,114 134,132 C 122,150 114,166 112,182
  Q 104,198 88,210 Q 106,212 116,210 Q 108,222 100,234 Q 120,234 136,228
  C 154,242 176,250 200,252 C 224,250 246,242 264,228
  Q 280,234 300,234 Q 292,222 284,210 Q 294,212 312,210 Q 296,198 288,182
  C 286,166 278,150 266,132 C 254,114 230,104 200,104 Z`;
const TORSO = "M 166,234 C 152,254 142,280 140,306 C 138,330 146,350 160,356 L 240,356 C 254,350 262,330 260,306 C 258,280 248,254 234,234 Z";
const HAUNCH_L = "M 160,300 C 132,300 116,322 120,342 C 124,356 146,358 170,356 Z";
const HAUNCH_R = "M 240,300 C 268,300 284,322 280,342 C 276,356 254,358 230,356 Z";
const LEGS = "M 170,280 C 168,310 168,334 168,350 L 198,350 C 198,330 199,306 199,284 Z M 230,280 C 232,310 232,334 232,350 L 202,350 C 202,330 201,306 201,284 Z";
const CHEST = "M 160,236 C 166,258 166,278 174,296 L 184,286 L 190,306 L 200,290 L 210,306 L 216,286 L 226,296 C 234,278 234,258 240,236 Z";
const EYE_L = "M 188,187 C 181,168 157,162 143,171 C 149,188 172,196 188,187 Z";
const EYE_R = "M 212,187 C 219,168 243,162 257,171 C 251,188 228,196 212,187 Z";
const HAPPY_EYES = "M 147,183 Q 165,163 186,181 M 214,181 Q 235,163 253,183";
const MARK_L = "M 143,171 C 134,170 124,166 116,158 C 127,160 137,162 147,165 Z";
const MARK_R = "M 257,171 C 266,170 276,166 284,158 C 273,160 263,162 253,165 Z";
const FOREHEAD = "M 200,122 C 206,132 209,141 206,149 C 204,155 196,155 194,149 C 191,141 194,132 200,122 Z";
const NOSE = "M 190,214 Q 200,208 210,214 Q 207,224 200,226 Q 193,224 190,214 Z";
const MOUTH = "M 200,226 L 200,231 M 188,231 Q 194,238 200,231 Q 206,238 212,231";
const MOUTH_OPEN = "M 186,229 Q 200,227 214,229 Q 210,246 200,247 Q 190,246 186,229 Z";
const HEAD_SILHOUETTE = [EAR_L, EAR_R, HEAD];
const BODY_SILHOUETTE = [TORSO, HAUNCH_L, HAUNCH_R];

const SPARKLE = "M 0,-17 C 2,-5 5,-2 17,0 C 5,2 2,5 0,17 C -2,5 -5,2 -17,0 C -5,-2 -2,-5 0,-17 Z";
const SPARKLE_COLORS = ["#ffffff", "#67e8f9", "#c4b5fd", "#ffffff", "#a78bfa", "#67e8f9", "#ffffff", "#c4b5fd"];
const EMBERS = 4;
const EASE_OUT = [0.16, 1, 0.3, 1] as const;
const OUTLINE = "#07060f";

/* ------------------------------------------------------------------------------------
 * Per-state targets. The loop eases the live parameters towards these.
 * ---------------------------------------------------------------------------------- */

interface Params {
  spread: number; // fan width multiplier
  sway: number; // sway amplitude, degrees
  swayHz: number; // sway cycles per second
  scale: number; // tail scale
  pulse: number; // sequential pulse strength (thinking)
  glow: number; // eyes + forehead mark
  think: number; // 0..1 thinking pose (eyes look up, head tilt)
  happy: number; // 0..1 done face
  embers: number; // ember opacity
  halo: number; // backdrop glow opacity
}

const TARGETS: Record<MascotState, Params> = {
  idle: { spread: 1, sway: 4.5, swayHz: 1 / 4.2, scale: 1, pulse: 0, glow: 0.3, think: 0, happy: 0, embers: 0.4, halo: 0.75 },
  thinking: { spread: 1.08, sway: 2.4, swayHz: 1 / 1.6, scale: 1.04, pulse: 1, glow: 1, think: 1, happy: 0, embers: 1, halo: 1 },
  done: { spread: 1.03, sway: 3, swayHz: 1 / 3.4, scale: 1.02, pulse: 0, glow: 0.75, think: 0, happy: 1, embers: 0.35, halo: 1 },
};
const PARAM_KEYS = Object.keys(TARGETS.idle) as (keyof Params)[];

type Rig = ReturnType<typeof createRig>;

function createRig(state: MascotState) {
  const mv = (v: number) => motionValue(v);
  const list = (n: number, v: number) => Array.from({ length: n }, () => mv(v));
  const rig = {
    tailRot: list(9, 0),
    tailScale: list(9, 1),
    flameScale: list(9, 1),
    flameOpacity: list(9, 1),
    foxScale: mv(1),
    foxY: mv(0),
    headRot: mv(0),
    blink: mv(1),
    irisX: mv(0),
    irisY: mv(0),
    eyeGlow: mv(0),
    markGlow: mv(0),
    calmFace: mv(1),
    happyFace: mv(0),
    halo: mv(0.75),
    aura: mv(0),
    emberX: list(EMBERS, 0),
    emberY: list(EMBERS, 0),
    emberOpacity: list(EMBERS, 0),
    emberScale: list(EMBERS, 1),
  };
  applyPose(rig, TARGETS[state]);
  return rig;
}

/** Static pose for a set of parameters (also the whole story under reduced motion). */
function applyPose(rig: Rig, p: Params) {
  TAILS.forEach((tail, i) => {
    rig.tailRot[i].set(tail.angle * (p.spread - 1));
    rig.tailScale[i].set(p.scale);
    rig.flameScale[i].set(1 + 0.08 * p.pulse);
    rig.flameOpacity[i].set(1);
  });
  rig.foxScale.set(1);
  rig.foxY.set(0);
  rig.headRot.set(-3 * p.think);
  rig.blink.set(1);
  rig.irisX.set(2.5 * p.think);
  rig.irisY.set(-3.5 * p.think);
  rig.eyeGlow.set(p.glow);
  rig.markGlow.set(p.glow);
  rig.calmFace.set(1 - p.happy);
  rig.happyFace.set(p.happy);
  rig.halo.set(p.halo);
  rig.aura.set(0.85 * p.happy);
  for (let k = 0; k < EMBERS; k++) rig.emberOpacity[k].set(0);
}

/** Smooth 0..1..0 hump for x in [0,1], zero elsewhere. */
const hump = (x: number) => (x > 0 && x < 1 ? Math.sin(Math.PI * x) ** 2 : 0);
const deg = Math.PI / 180;

/* ------------------------------------------------------------------------------------
 * Component
 * ---------------------------------------------------------------------------------- */

export function KitsuneMascot({ state, size = 160, className }: KitsuneMascotProps) {
  const uid = useId().replace(/:/g, "");
  const id = (name: string) => `${uid}-${name}`;
  const url = (name: string) => `url(#${uid}-${name})`;
  const reduce = useReducedMotion() ?? false;

  const [rig] = useState(() => createRig(state));
  const stateRef = useRef(state);
  stateRef.current = state;

  // Simulation state for the frame loop (never rendered directly).
  const sim = useRef({
    p: { ...TARGETS[state] },
    phase: 0,
    clock: 0,
    prev: null as MascotState | null,
    doneAt: -10,
    nextBlink: 2.2,
    blinkAt: -1,
    ember: Array.from({ length: EMBERS }, (_, k) => ({ life: k / EMBERS, tail: (k * 5 + 1) % 9 })),
    staticFor: null as MascotState | null,
  });

  // Replay the celebratory flash every time we enter "done".
  const [burst, setBurst] = useState(0);
  useEffect(() => {
    if (state === "done") setBurst((b) => b + 1);
  }, [state]);

  const tick = useCallback(
    (time: number, delta: number) => {
      const s = sim.current;
      const current = stateRef.current;
      const target = TARGETS[current];

      if (reduce) {
        if (s.staticFor !== current) {
          s.staticFor = current;
          s.p = { ...target };
          applyPose(rig, target);
        }
        return;
      }
      s.staticFor = null;

      const t = time / 1000;
      const dt = Math.min(delta / 1000, 1 / 20);
      const p = s.p;
      const ease = 1 - Math.exp(-dt / 0.32);
      for (const key of PARAM_KEYS) p[key] += (target[key] - p[key]) * ease;

      s.phase += dt * p.swayHz * Math.PI * 2;
      s.clock += dt;
      if (current === "done" && s.prev !== "done") s.doneAt = t;
      s.prev = current;

      // Done: springy outward tail kick + a little hop.
      const since = t - s.doneAt;
      const bounce = since < 1.8 ? Math.exp(-since / 0.42) * Math.sin((since * Math.PI * 2) / 0.46) : 0;
      const hop = since < 0.44 ? Math.sin((Math.PI * since) / 0.44) : 0;

      for (let i = 0; i < 9; i++) {
        const a = TAILS[i].angle;
        const side = a === 0 ? 0.4 : Math.sign(a);
        const sway = p.sway * Math.sin(s.phase - i * 0.6);
        // Thinking: a glow/scale wave runs tail 1 -> 9 (0.1 s stagger, 1.2 s loop).
        const wave = p.pulse * hump((((s.clock - i * 0.1) % 1.2) + 1.2) % 1.2 / 0.36);
        const flicker = 0.5 * Math.sin(t * 7.3 + i * 1.9) + 0.5 * Math.sin(t * 11.7 + i * 0.8);
        rig.tailRot[i].set(a * (p.spread - 1) + sway + 7 * bounce * side);
        rig.tailScale[i].set(p.scale + 0.03 * wave + 0.025 * hop);
        rig.flameScale[i].set(1 + 0.05 * flicker + 0.24 * wave + 0.08 * p.pulse);
        rig.flameOpacity[i].set(0.86 + 0.1 * flicker + 0.14 * wave);
      }

      // Breathing, head bob and the done hop.
      rig.foxScale.set(1 + 0.012 * Math.sin((t * Math.PI * 2) / 3.6));
      rig.foxY.set(-16 * hop);
      rig.headRot.set(1.4 * Math.sin((t * Math.PI * 2) / 6.4) * (1 - p.think) - 3.5 * p.think + 2.5 * bounce);

      // Blink every ~4-6 s (sometimes twice).
      if (t >= s.nextBlink) {
        s.blinkAt = t;
        s.nextBlink = t + (Math.random() < 0.18 ? 0.34 : 3.8 + Math.random() * 2.4);
      }
      const bu = (t - s.blinkAt) / 0.17;
      rig.blink.set(1 - 0.92 * (bu >= 0 && bu <= 1 ? Math.sin(Math.PI * bu) : 0));

      rig.irisX.set(2.5 * p.think);
      rig.irisY.set(-3.5 * p.think);
      const shimmer = 0.85 + 0.15 * Math.sin(t * 5.2);
      rig.eyeGlow.set(p.glow * shimmer);
      rig.markGlow.set(Math.min(1, p.glow * shimmer + 0.15));
      rig.calmFace.set(1 - p.happy);
      rig.happyFace.set(p.happy);
      rig.halo.set(p.halo * (0.92 + 0.08 * Math.sin(t * 1.3)));
      rig.aura.set(p.happy * (0.75 + 0.25 * Math.sin(t * 2.4)));

      // Embers: spirit-fire sparks drifting off the tail tips.
      const period = 3.2 - 1.8 * p.think;
      for (let k = 0; k < EMBERS; k++) {
        const e = s.ember[k];
        e.life += dt / period;
        if (e.life >= 1) {
          e.life -= 1;
          e.tail = (e.tail + 2 + Math.floor(Math.random() * 5)) % 9;
        }
        const tail = TAILS[e.tail];
        const ang = (tail.angle + rig.tailRot[e.tail].get()) * deg;
        const reach = tail.r * rig.tailScale[e.tail].get() + 14 + 48 * e.life;
        const wobble = 5 * Math.sin(e.life * Math.PI * 3 + k);
        rig.emberX[k].set(PIVOT.x + Math.sin(ang) * reach + Math.cos(ang) * wobble);
        rig.emberY[k].set(PIVOT.y - Math.cos(ang) * reach + Math.sin(ang) * wobble);
        rig.emberOpacity[k].set(p.embers * hump(e.life));
        rig.emberScale[k].set(1.15 - 0.6 * e.life);
      }
    },
    [reduce, rig],
  );
  useAnimationFrame(tick);

  const origin = (x: number, y: number) => ({ originX: `${x}px`, originY: `${y}px` });

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 400 400"
      className={className}
      role="img"
      aria-label={`NineTail fox mascot, ${state}`}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <radialGradient id={id("halo")} cx="200" cy="210" r="196" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#7c3aed" stopOpacity=".36" />
          <stop offset=".55" stopColor="#7c3aed" stopOpacity=".13" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={id("bloom")} cx=".5" cy=".5" r=".5">
          <stop offset="0" stopColor="#ffffff" stopOpacity=".95" />
          <stop offset=".4" stopColor="#f5f3ff" stopOpacity=".7" />
          <stop offset=".72" stopColor="#a78bfa" stopOpacity=".28" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        <linearGradient id={id("auraStroke")} x1="0" y1="20" x2="0" y2="390" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#e9e3ff" />
          <stop offset=".45" stopColor="#a78bfa" />
          <stop offset=".8" stopColor="#67e8f9" stopOpacity=".5" />
          <stop offset="1" stopColor="#67e8f9" stopOpacity="0" />
        </linearGradient>
        <linearGradient id={id("fur")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#ab98f3" />
          <stop offset=".35" stopColor="#e0d9ff" />
          <stop offset=".72" stopColor="#f7f5ff" />
          <stop offset="1" stopColor="#ffffff" />
        </linearGradient>
        <linearGradient id={id("furshade")} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#8b5cf6" stopOpacity=".26" />
          <stop offset=".3" stopColor="#8b5cf6" stopOpacity="0" />
          <stop offset=".7" stopColor="#8b5cf6" stopOpacity="0" />
          <stop offset="1" stopColor="#8b5cf6" stopOpacity=".2" />
        </linearGradient>
        <linearGradient id={id("flame")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#7c3aed" stopOpacity="0" />
          <stop offset=".3" stopColor="#8b5cf6" stopOpacity=".95" />
          <stop offset=".64" stopColor="#22d3ee" />
          <stop offset="1" stopColor="#a5f3fc" />
        </linearGradient>
        <linearGradient id={id("core")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#ffffff" stopOpacity="0" />
          <stop offset=".45" stopColor="#cffafe" stopOpacity=".55" />
          <stop offset="1" stopColor="#ffffff" stopOpacity=".9" />
        </linearGradient>
        <radialGradient id={id("head")} cx="200" cy="168" r="112" gradientUnits="userSpaceOnUse">
          <stop offset=".55" stopColor="#ffffff" />
          <stop offset="1" stopColor="#d8ccff" />
        </radialGradient>
        <linearGradient id={id("body")} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#c9bbfa" />
          <stop offset=".32" stopColor="#f5f2ff" />
          <stop offset=".68" stopColor="#f5f2ff" />
          <stop offset="1" stopColor="#c9bbfa" />
        </linearGradient>
        <linearGradient id={id("ear")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#c4b5fd" />
          <stop offset="1" stopColor="#7c3aed" />
        </linearGradient>
        <linearGradient id={id("mark")} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor="#8b5cf6" />
          <stop offset="1" stopColor="#67e8f9" />
        </linearGradient>
        <radialGradient id={id("iris")} cx=".5" cy=".5" r=".5">
          <stop offset="0" stopColor="#ecfeff" />
          <stop offset=".45" stopColor="#67e8f9" />
          <stop offset="1" stopColor="#0e7490" />
        </radialGradient>
        <radialGradient id={id("ground")} cx=".5" cy=".5" r=".5">
          <stop offset="0" stopColor="#a78bfa" stopOpacity=".45" />
          <stop offset="1" stopColor="#7c3aed" stopOpacity="0" />
        </radialGradient>
        {/* Bloom for flames, eyes and embers. */}
        <filter id={id("glow")} x="-60%" y="-60%" width="220%" height="220%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="5" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        {/* Soft back-glow around the fox silhouette. */}
        <filter id={id("soft")} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="10" />
        </filter>
        <clipPath id={id("eyeL")}>
          <path d={EYE_L} />
        </clipPath>
        <clipPath id={id("eyeR")}>
          <path d={EYE_R} />
        </clipPath>
      </defs>

      <g transform={`translate(200 200) scale(${SCENE_SCALE}) translate(-200 -200)`}>
        {/* Backdrop glow, ground glow and the calm "done" aura ring */}
        <motion.ellipse cx="200" cy="210" rx="198" ry="190" fill={url("halo")} style={{ opacity: rig.halo }} />
        <ellipse cx="200" cy="362" rx="120" ry="16" fill={url("ground")} />
        <motion.g style={{ opacity: rig.aura }}>
          <circle cx="200" cy="205" r="182" fill="none" stroke={url("auraStroke")} strokeWidth="14" filter={url("soft")} />
          <circle cx="200" cy="205" r="184" fill="none" stroke={url("auraStroke")} strokeWidth="2.5" />
        </motion.g>

        {/* Nine tails. Each rotates about PIVOT: static base angle + animated delta. */}
        {DRAW_ORDER.map((i) => {
          const tail = TAILS[i];
          return (
            <g key={i} transform={`translate(${PIVOT.x} ${PIVOT.y}) rotate(${tail.angle})`}>
              <motion.g style={{ rotate: rig.tailRot[i], scale: rig.tailScale[i], ...origin(0, 0) }}>
                <path d={tail.d} fill={url("fur")} stroke={OUTLINE} strokeWidth="6" strokeLinejoin="round" paintOrder="stroke" />
                <path d={tail.d} fill={url("furshade")} />
                <g transform={`translate(${tail.curl} ${-tail.r}) rotate(${tail.tilt.toFixed(2)})`}>
                  <motion.g
                    filter={url("glow")}
                    style={{ scale: rig.flameScale[i], opacity: rig.flameOpacity[i], ...origin(0, 22) }}
                  >
                    <path d={FLAME} fill={url("flame")} />
                    <path d={FLAME_CORE} fill={url("core")} />
                  </motion.g>
                </g>
              </motion.g>
            </g>
          );
        })}

        {!reduce && burst > 0 && <DoneRings key={`rings-${burst}`} url={url} />}

        {/* The fox: scaled about its base; breathes and hops as one piece. */}
        <g transform={`translate(${FOX_BASE.x} ${FOX_BASE.y}) scale(${FOX_SCALE})`}>
          <motion.g style={{ scale: rig.foxScale, y: rig.foxY, ...origin(0, 0) }}>
            <g transform={`translate(${-FOX_BASE.x} ${-FOX_BASE.y})`}>
              {/* Soft back-glow + knockout outline that separates the fox from the tails.
                  The head copy shares the head's tilt so the outline never drifts. */}
              <g filter={url("soft")} opacity=".35">
                {BODY_SILHOUETTE.map((d, k) => (
                  <path key={k} d={d} fill="#c4b5fd" />
                ))}
                <motion.g style={{ rotate: rig.headRot, ...origin(200, 246) }}>
                  {HEAD_SILHOUETTE.map((d, k) => (
                    <path key={k} d={d} fill="#c4b5fd" />
                  ))}
                </motion.g>
              </g>
              {BODY_SILHOUETTE.map((d, k) => (
                <path key={k} d={d} fill={OUTLINE} stroke={OUTLINE} strokeWidth="7" strokeLinejoin="round" />
              ))}
              <motion.g style={{ rotate: rig.headRot, ...origin(200, 246) }}>
                {HEAD_SILHOUETTE.map((d, k) => (
                  <path key={k} d={d} fill={OUTLINE} stroke={OUTLINE} strokeWidth="7" strokeLinejoin="round" />
                ))}
              </motion.g>

              {/* Body: haunches, torso, front legs, paws, chest tuft */}
              <path d={HAUNCH_L} fill="#e2dafc" />
              <path d={HAUNCH_R} fill="#e2dafc" />
              <path d={TORSO} fill={url("body")} />
              <path d={LEGS} fill="#fbfaff" stroke="#cbbdf7" strokeWidth="2" />
              <ellipse cx="183" cy="351" rx="18" ry="8.5" fill="#fff" stroke="#cbbdf7" strokeWidth="2" />
              <ellipse cx="217" cy="351" rx="18" ry="8.5" fill="#fff" stroke="#cbbdf7" strokeWidth="2" />
              <path d={CHEST} fill="#ffffff" />
              <ellipse cx="200" cy="252" rx="46" ry="9" fill="#a78bfa" opacity=".22" />

              {/* Head + ears tilt together about the neck */}
              <motion.g style={{ rotate: rig.headRot, ...origin(200, 246) }}>
                <path d={EAR_L} fill="#f6f4ff" />
                <path d={EAR_R} fill="#f6f4ff" />
                <path d={EAR_L_IN} fill={url("ear")} />
                <path d={EAR_R_IN} fill={url("ear")} />
                <path d={EAR_L_TUFT} fill="#ffffff" />
                <path d={EAR_R_TUFT} fill="#ffffff" />
                <path d={HEAD} fill={url("head")} />
                <ellipse cx="146" cy="205" rx="14" ry="8" fill="#f0abfc" opacity=".3" />
                <ellipse cx="254" cy="205" rx="14" ry="8" fill="#f0abfc" opacity=".3" />
                <path d={MARK_L} fill={url("mark")} opacity=".9" />
                <path d={MARK_R} fill={url("mark")} opacity=".9" />
                <path d={FOREHEAD} fill={url("mark")} />
                <motion.path d={FOREHEAD} fill="#a5f3fc" filter={url("glow")} style={{ opacity: rig.markGlow }} />

                {/* Calm face: almond eyes (blink + look) and a small smile */}
                <motion.g style={{ opacity: rig.calmFace }}>
                  <motion.g style={{ scaleY: rig.blink, ...origin(200, 179) }}>
                    <motion.g filter={url("glow")} style={{ opacity: rig.eyeGlow }}>
                      <path d={EYE_L} fill="#67e8f9" />
                      <path d={EYE_R} fill="#67e8f9" />
                    </motion.g>
                    <path d={EYE_L} fill="#130d2b" />
                    <path d={EYE_R} fill="#130d2b" />
                    {[
                      { clip: "eyeL", cx: 168 },
                      { clip: "eyeR", cx: 232 },
                    ].map(({ clip, cx }) => (
                      <g key={clip} clipPath={url(clip)}>
                        <motion.g style={{ x: rig.irisX, y: rig.irisY }}>
                          <circle cx={cx} cy="179" r="10.5" fill={url("iris")} />
                          <circle cx={cx} cy="180" r="4.6" fill="#0b0720" />
                          <circle cx={cx + 4} cy="175" r="3" fill="#fff" />
                          <circle cx={cx - 4.5} cy="184" r="1.4" fill="#fff" opacity=".85" />
                        </motion.g>
                      </g>
                    ))}
                  </motion.g>
                  <path d={MOUTH} stroke="#7d70b3" strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                </motion.g>

                {/* Happy face for "done": closed ^ ^ eyes and an open smile */}
                <motion.g style={{ opacity: rig.happyFace }}>
                  <path d={HAPPY_EYES} stroke="#130d2b" strokeWidth="6.5" fill="none" strokeLinecap="round" />
                  <path d={MOUTH_OPEN} fill="#2a1d4f" />
                  <ellipse cx="200" cy="241" rx="6" ry="3.6" fill="#f0abfc" />
                </motion.g>

                <path d={NOSE} fill="#1a1433" />
                <ellipse cx="197" cy="214" rx="3.2" ry="1.8" fill="#fff" opacity=".7" />
              </motion.g>
            </g>
          </motion.g>
        </g>

        {/* Embers drifting off the tail tips */}
        {rig.emberX.map((x, k) => (
          <motion.g
            key={k}
            filter={url("glow")}
            style={{ x, y: rig.emberY[k], opacity: rig.emberOpacity[k], scale: rig.emberScale[k], ...origin(0, 0) }}
          >
            <circle r="12" fill={k % 2 ? "#22d3ee" : "#8b5cf6"} opacity=".55" />
            <circle r="5.5" fill={k % 2 ? "#cffafe" : "#ede9fe"} />
          </motion.g>
        ))}

        {/* Done: one-shot celebratory flash, replayed on every entry into "done" */}
        {!reduce && burst > 0 && <DoneSparks key={`sparks-${burst}`} url={url} />}
      </g>
    </svg>
  );
}

/** Shockwave rings: rendered between the tails and the fox so they emerge from behind it. */
function DoneRings({ url }: { url: (name: string) => string }) {
  return (
    <g pointerEvents="none" filter={url("glow")}>
      {[
        { color: "#ffffff", delay: 0, from: 0.7, to: 1.6, w: 8 },
        { color: "#67e8f9", delay: 0.14, from: 0.7, to: 1.8, w: 4 },
      ].map((ring) => (
        <motion.circle
          key={ring.color}
          cx="200"
          cy="215"
          r="112"
          fill="none"
          stroke={ring.color}
          strokeWidth={ring.w}
          initial={{ opacity: 0, scale: ring.from }}
          animate={{ opacity: [0, 1, 0], scale: [ring.from, 1.15, ring.to] }}
          transition={{ duration: 1.05, delay: ring.delay, times: [0, 0.2, 1], ease: EASE_OUT }}
        />
      ))}
    </g>
  );
}

/** Bloom flash + sparkle burst, drawn over everything. */
function DoneSparks({ url }: { url: (name: string) => string }) {
  return (
    <g pointerEvents="none">
      <motion.circle
        cx="200"
        cy="205"
        r="175"
        fill={url("bloom")}
        initial={{ opacity: 0, scale: 0.5 }}
        animate={{ opacity: [0, 0.85, 0], scale: [0.5, 1, 1.12] }}
        transition={{ duration: 1.1, times: [0, 0.2, 1], ease: "easeOut" }}
        style={{ mixBlendMode: "screen" }}
      />
      <g transform="translate(200 210)" filter={url("glow")}>
        {SPARKLE_COLORS.map((color, j) => {
          const a = (j * 45 + 22.5) * deg;
          const dist = j % 2 ? 150 : 178;
          return (
            <motion.path
              key={j}
              d={SPARKLE}
              fill={color}
              initial={{ x: Math.cos(a) * 60, y: Math.sin(a) * 60, scale: 0, opacity: 0, rotate: 0 }}
              animate={{ x: Math.cos(a) * dist, y: Math.sin(a) * dist, scale: [0, 1.3, 0], opacity: [0, 1, 0], rotate: 140 }}
              transition={{ duration: 1.15, delay: 0.05 + j * 0.02, ease: EASE_OUT }}
              style={{ originX: "0px", originY: "0px" }}
            />
          );
        })}
      </g>
    </g>
  );
}

export default KitsuneMascot;
