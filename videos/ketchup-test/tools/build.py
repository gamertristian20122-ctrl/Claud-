#!/usr/bin/env python3
"""Builds the scene files for the ketchup test short.

Characters are drawn as SVG puppets (separate head, arms, hands, props) and
posed with a small 2-bone IK solver, so the art never warps between frames.
Run:  python3 tools/build.py   (writes index.html and compositions/*.html)
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# ---------------------------------------------------------------- palette
OUT = "#2a211c"      # outline
SW = 7               # outline width
SKIN = "#fbf7f0"
BLUSH = "#f2b4a8"
MOUTH = "#5a2324"
TONGUE = "#e27a7a"
RED = "#d8322a"
RED_SH = "#ad231d"
CAP = "#f5f1e8"
LABEL = "#f6e6c4"
LEAF = "#5c9a4a"
TOTAL = 10.3
FRIEND_DUR = 4.7
DOCTOR_START = 4.7
DOCTOR_DUR = round(TOTAL - DOCTOR_START, 2)


def f(x):
    return f"{x:.2f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------- drawing helpers
def tube(d, color, w):
    return (
        f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{w + 2 * SW}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>'
    )


def mitten(r=30):
    return (
        f'<ellipse cx="0" cy="4" rx="{r + 2}" ry="{r - 2}" fill="#fff" stroke="{OUT}" stroke-width="{SW}"/>'
        f'<ellipse cx="{-r + 6}" cy="{-r * 0.45:.0f}" rx="12" ry="17" fill="#fff" stroke="{OUT}" '
        f'stroke-width="6" transform="rotate(-35 {-r + 6} {-r * 0.45:.0f})"/>'
    )


def thumbs_up():
    return (
        f'<rect x="-12" y="-62" width="26" height="54" rx="13" fill="#fff" stroke="{OUT}" stroke-width="6"/>'
        f'<rect x="-34" y="-20" width="68" height="56" rx="22" fill="#fff" stroke="{OUT}" stroke-width="{SW}"/>'
        f'<path d="M-26 -2 H18 M-26 14 H18" stroke="{OUT}" stroke-width="5" stroke-linecap="round"/>'
    )


GRIP = 55            # hand holds the bottle this far below its middle
TIP = 150 + GRIP     # hand to nozzle tip


def bottle(p, rx_label=False):
    """Squeeze bottle, nozzle pointing up (-y); the hand's grip point is (0,0)."""
    rx = ""
    if rx_label:
        rx = (
            f'<g id="{p}-rx" opacity="0">'
            f'<rect x="-46" y="-34" width="92" height="84" rx="10" fill="#fff" stroke="{OUT}" stroke-width="6"/>'
            f'<rect x="-9" y="-22" width="18" height="56" rx="3" fill="{RED}"/>'
            f'<rect x="-28" y="-3" width="56" height="18" rx="3" fill="{RED}"/>'
            f"</g>"
        )
    return (
        f'<g transform="translate(0 {-GRIP})"><g id="{p}-sq">'
        f'<path d="M-14 -120 L-6 -150 L6 -150 L14 -120 Z" fill="{CAP}" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>'
        f'<rect x="-36" y="-124" width="72" height="36" rx="9" fill="{CAP}" stroke="{OUT}" stroke-width="{SW}"/>'
        f'<rect x="-52" y="-94" width="104" height="192" rx="36" fill="{RED}" stroke="{OUT}" stroke-width="{SW}"/>'
        f'<rect x="20" y="-78" width="18" height="160" rx="9" fill="{RED_SH}"/>'
        f'<rect x="-38" y="-76" width="12" height="58" rx="6" fill="#fff" opacity="0.45"/>'
        f'<circle cx="0" cy="14" r="34" fill="{LABEL}" stroke="{OUT}" stroke-width="5"/>'
        f'<circle cx="0" cy="18" r="17" fill="{RED}" stroke="{OUT}" stroke-width="4"/>'
        f'<path d="M0 2 q-10 -10 -16 -4 q8 2 16 4 q8 -8 16 -4 q-8 2 -16 4z" fill="{LEAF}" stroke="{OUT}" stroke-width="3"/>'
        f"{rx}"
        f"</g></g>"
    )


def cone(p):
    """Ice cream cone held at its middle; scoop on top. Origin = grip point."""
    return (
        f'<g transform="translate(0 -40)">'
        f'<path d="M-50 -8 L50 -8 L0 118 Z" fill="#e2a85e" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>'
        f'<path d="M-30 -8 L18 70 M10 -8 L-22 72 M30 -8 L-6 38 M-38 22 L34 22" stroke="#b97c3c" stroke-width="5" stroke-linecap="round"/>'
        f'<circle cx="0" cy="-52" r="62" fill="#f6b3c6" stroke="{OUT}" stroke-width="{SW}"/>'
        f'<path d="M-60 -36 q14 22 30 6 q14 20 30 2 q16 20 30 0 q14 16 26 -6" fill="none" stroke="{OUT}" stroke-width="6" stroke-linecap="round"/>'
        f'<path d="M26 -96 a50 50 0 0 1 26 40" fill="none" stroke="#e48fab" stroke-width="12" stroke-linecap="round"/>'
        # ketchup blob + drips, grown by the timeline
        f'<g id="{p}-blob" opacity="0">'
        f'<path d="M-46 -92 q-6 -34 34 -34 q22 -18 40 6 q26 2 18 30 q-10 18 -40 12 q-30 12 -52 -14z" fill="{RED}" stroke="{OUT}" stroke-width="6"/>'
        f'<path d="M-20 -110 q8 -6 16 0" stroke="#fff" stroke-width="6" stroke-linecap="round" opacity="0.6" fill="none"/>'
        f"</g>"
        f'<g id="{p}-drip1" opacity="0"><rect x="-44" y="-86" width="18" height="60" rx="9" fill="{RED}" stroke="{OUT}" stroke-width="5"/></g>'
        f'<g id="{p}-drip2" opacity="0"><rect x="22" y="-82" width="16" height="44" rx="8" fill="{RED}" stroke="{OUT}" stroke-width="5"/></g>'
        f"</g>"
    )


def arm(p, sx, sy, L1, L2, color, hand_svg, prop_svg="", w=50, extra_hand=""):
    """FK arm: shoulder at (sx,sy). Groups p-up, p-fo, p-wr rotate about their own (0,0)."""
    return (
        f'<g transform="translate({f(sx)} {f(sy)})"><g id="{p}-up">'
        f"{tube(f'M0 0 L0 {L1}', color, w)}"
        f'<g transform="translate(0 {L1})"><g id="{p}-fo">'
        f"{tube(f'M0 0 L0 {L2}', color, w * 0.9)}"
        f'<g transform="translate(0 {L2})"><g id="{p}-wr">'
        f"{prop_svg}<g id=\"{p}-hand\">{hand_svg}</g>{extra_hand}"
        f"</g></g></g></g></g></g>"
    )


def ik(S, T, L1, L2, bend=1):
    """Angles (deg, SVG clockwise) for a 2-bone arm whose rest direction is +y."""
    dx, dy = T[0] - S[0], T[1] - S[1]
    d = math.hypot(dx, dy)
    d = max(abs(L1 - L2) + 1, min(L1 + L2 - 1, d))
    base = math.degrees(math.atan2(-dx, dy))
    a = math.degrees(math.acos((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))
    b = math.degrees(math.acos((L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2)))
    return base + bend * a, -bend * (180 - b)


def fk(S, L1, L2, t1, t2):
    r1, r12 = math.radians(t1), math.radians(t1 + t2)
    e = (S[0] - L1 * math.sin(r1), S[1] + L1 * math.cos(r1))
    return (e[0] - L2 * math.sin(r12), e[1] + L2 * math.cos(r12))


def along(P, phi, dist):
    """Point dist along a prop's local -y axis when the prop's world angle is phi."""
    r = math.radians(phi)
    return (P[0] + dist * math.sin(r), P[1] - dist * math.cos(r))


def eyes(p, xs, y, rx=12, ry=18):
    normal = "".join(
        f'<g class="{p}-eye"><ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{OUT}"/>'
        f'<circle cx="{x - 4}" cy="{y - 7}" r="4" fill="#fff"/></g>'
        for x in xs
    )
    happy = "".join(
        f'<path d="M{x - 17} {y + 6} Q{x} {y - 16} {x + 17} {y + 6}" fill="none" stroke="{OUT}" '
        f'stroke-width="8" stroke-linecap="round"/>'
        for x in xs
    )
    wide = "".join(
        f'<circle cx="{x}" cy="{y}" r="27" fill="#fff" stroke="{OUT}" stroke-width="6"/>'
        f'<circle cx="{x}" cy="{y + 2}" r="10" fill="{OUT}"/>'
        for x in xs
    )
    shut = "".join(
        f'<path d="M{x - 17} {y} Q{x} {y + 10} {x + 17} {y}" fill="none" stroke="{OUT}" '
        f'stroke-width="7" stroke-linecap="round"/>'
        for x in xs
    )
    return (
        f'<g id="{p}-eyes">{normal}</g>'
        f'<g id="{p}-eyes-happy" opacity="0">{happy}</g>'
        f'<g id="{p}-eyes-wide" opacity="0">{wide}</g>'
        f'<g id="{p}-eyes-shut" opacity="0">{shut}</g>'
    )


def mouths(p, x, y, s=1.0, default="grin"):
    def S(v):
        return f(v * s)

    grin = (
        f'<path d="M{x - 60 * s} {y} Q{x} {y + 78 * s} {x + 60 * s} {y} Z" fill="{MOUTH}" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>'
        f'<path d="M{x - 30 * s} {y + 32 * s} Q{x} {y + 14 * s} {x + 30 * s} {y + 32 * s} Q{x} {y + 46 * s} {x - 30 * s} {y + 32 * s} Z" fill="{TONGUE}"/>'
        f'<path d="M{x - 52 * s} {y + 3} H{x + 52 * s}" stroke="#fff" stroke-width="{S(9)}"/>'
    )
    smile = f'<path d="M{x - 42 * s} {y} Q{x} {y + 34 * s} {x + 42 * s} {y}" fill="none" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/>'
    o = f'<ellipse cx="{x}" cy="{y + 14 * s}" rx="{S(20)}" ry="{S(26)}" fill="{MOUTH}" stroke="{OUT}" stroke-width="6"/>'
    gasp = f'<ellipse cx="{x}" cy="{y + 20 * s}" rx="{S(30)}" ry="{S(40)}" fill="{MOUTH}" stroke="{OUT}" stroke-width="6"/><ellipse cx="{x}" cy="{y + 42 * s}" rx="{S(16)}" ry="{S(9)}" fill="{TONGUE}"/>'
    queasy = f'<path d="M{x - 40 * s} {y + 10} q10 -12 20 0 q10 12 20 0 q10 -12 20 0 q10 12 20 0" fill="none" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/>'
    parts = {"grin": grin, "smile": smile, "o": o, "gasp": gasp, "queasy": queasy}
    return "".join(
        f'<g id="{p}-m-{k}"{"" if k == default else " opacity=\"0\""}>{v}</g>' for k, v in parts.items()
    )


def star(cx, cy, r, color="#fff6c8"):
    k = r * 0.28
    return (
        f'<path d="M{cx} {cy - r} Q{cx + k} {cy - k} {cx + r} {cy} Q{cx + k} {cy + k} {cx} {cy + r} '
        f'Q{cx - k} {cy + k} {cx - r} {cy} Q{cx - k} {cy - k} {cx} {cy - r} Z" fill="{color}" stroke="{OUT}" stroke-width="5" stroke-linejoin="round"/>'
    )


# ---------------------------------------------------------------- timeline writer
TRANSFORM_KEYS = {"x", "y", "scale", "scaleX", "scaleY", "rotation"}


class TL:
    """Collects GSAP calls. Every animated value is keyed with explicit from/to so seeking is exact."""

    def __init__(self):
        self.lines = []
        self.state = {}

    def _js(self, v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, str):
            return '"' + v + '"'
        return f(v)

    def init(self, sel, origin=None, **props):
        o = dict(props)
        if origin:
            o["svgOrigin"] = origin
        for k, v in props.items():
            self.state[(sel, k)] = v
        self.lines.insert(0, f'gsap.set("{sel}", {self._obj(o)});')

    def _obj(self, o):
        parts = []
        for k, v in o.items():
            parts.append(f"{k}: {self._js(v)}")
        return "{" + ", ".join(parts) + "}"

    def to(self, sel, t, dur, ease="power2.inOut", origin=None, **props):
        frm, to = {}, {}
        for k, v in props.items():
            prev = self.state.get((sel, k), v)
            if k == "rotation":
                # take the short way round, never a full spin from an angle wrap
                v = prev + ((v - prev + 180) % 360 - 180)
            frm[k] = prev
            to[k] = v
            self.state[(sel, k)] = v
        if origin and any(k in TRANSFORM_KEYS for k in props):
            frm["svgOrigin"] = origin
            to["svgOrigin"] = origin
        to["duration"] = dur
        to["ease"] = ease
        self.lines.append(("tween", sel, frm, to, t))

    def swap(self, t, show, hide):
        for s in hide:
            self.lines.append(f'tl.set("{s}", {{opacity: 0}}, {f(t)});')
        for s in show:
            self.lines.append(f'tl.set("{s}", {{opacity: 1}}, {f(t)});')

    def raw(self, line):
        self.lines.append(line)

    def js(self):
        # The earliest tween per target renders its from-values immediately (the baseline);
        # every later one waits for the playhead, so any seek lands on the same frame.
        first = {}
        for i, ln in enumerate(self.lines):
            if isinstance(ln, tuple):
                sel, t = ln[1], ln[4]
                if sel not in first or t < self.lines[first[sel]][4]:
                    first[sel] = i
        out = []
        for i, ln in enumerate(self.lines):
            if isinstance(ln, tuple):
                _, sel, frm, to, t = ln
                to = dict(to)
                if first[sel] != i:
                    to["immediateRender"] = False
                out.append(f'tl.fromTo("{sel}", {self._obj(frm)}, {self._obj(to)}, {f(t)});')
            else:
                out.append(ln)
        return "\n      ".join(out)


def pose_arm(tl, p, S, L1, L2, t, dur, target, phi, bend=1, ease="power2.inOut", lag=0.03, init=False):
    t1, t2 = ik(S, target, L1, L2, bend)
    tw = phi - (t1 + t2)
    hand = fk(S, L1, L2, t1, t2)
    if init:
        tl.init(f"#{p}-up", origin="0 0", rotation=t1)
        tl.init(f"#{p}-fo", origin="0 0", rotation=t2)
        tl.init(f"#{p}-wr", origin="0 0", rotation=tw)
    else:
        tl.to(f"#{p}-up", t, dur, ease, origin="0 0", rotation=t1)
        tl.to(f"#{p}-fo", t + lag, dur, ease, origin="0 0", rotation=t2)
        tl.to(f"#{p}-wr", t + lag * 2, dur, ease, origin="0 0", rotation=tw)
    return hand


def blink(tl, sel, t, origin=None):
    tl.to(sel, t, 0.06, "power2.in", scaleY=0.1)
    tl.to(sel, t + 0.07, 0.08, "power2.out", scaleY=1)


# ---------------------------------------------------------------- scene shell
def scene(comp_id, bg, svg_inner, timeline_js, extra_css=""):
    return f"""<template>
  <style>
    #root {{
      position: absolute;
      inset: 0;
      overflow: hidden;
      background: {bg};
    }}
    #{comp_id}-svg {{
      position: absolute;
      left: 0;
      top: 0;
      width: 1080px;
      height: 1920px;
    }}
    {extra_css}
  </style>
  <div id="root" data-composition-id="{comp_id}" data-width="1080" data-height="1920">
    <svg id="{comp_id}-svg" viewBox="0 0 1080 1920" xmlns="http://www.w3.org/2000/svg">
      {svg_inner}
    </svg>
  </div>
  <script>
    (function () {{
      const tl = gsap.timeline({{ paused: true }});
      {timeline_js}
      window.__timelines["{comp_id}"] = tl;
    }})();
  </script>
</template>
"""


# ================================================================ SCENE 1: the friend (0 - 4.7 s)
def build_friend():
    p = "f"
    HEAD = (540, 760)
    NECK = (540, 925)
    L1, L2 = 150, 140
    SA = (300, 1055)   # shoulder, screen-left arm (cone)
    SB = (780, 1055)   # shoulder, screen-right arm (bottle)
    HOOD, HOOD_SH = "#5e9f6f", "#4c8a5d"

    # --- poses
    cone_hand = (335, 1200)
    bottle_hand_aim = (650, 975)
    phi_aim = -120
    cone_hand_low = (300, 1365)
    bottle_hand_mouth = (800, 905)
    phi_mouth = -80

    tip_aim = along(bottle_hand_aim, phi_aim, TIP)
    scoop_top = (cone_hand[0], cone_hand[1] - 40 - 52 - 62 + 8)
    tip_mouth = along(bottle_hand_mouth, phi_mouth, TIP)
    mouth_pt = (556, 866)

    stream1 = (
        f"M{f(tip_aim[0])} {f(tip_aim[1])} Q{f((tip_aim[0] + scoop_top[0]) / 2)} "
        f"{f(min(tip_aim[1], scoop_top[1]) - 70)} {f(scoop_top[0] + 12)} {f(scoop_top[1] + 4)}"
    )
    stream2 = (
        f"M{f(tip_mouth[0])} {f(tip_mouth[1])} Q{f((tip_mouth[0] + mouth_pt[0]) / 2)} "
        f"{f(tip_mouth[1] - 24)} {f(mouth_pt[0])} {f(mouth_pt[1])}"
    )

    def stream(id_, d, w):
        return (
            f'<g id="{id_}">'
            f'<path d="{d}" pathLength="1" stroke-dasharray="1 1.2" stroke-dashoffset="1.1" fill="none" stroke="{OUT}" stroke-width="{w + 12}" stroke-linecap="round"/>'
            f'<path d="{d}" pathLength="1" stroke-dasharray="1 1.2" stroke-dashoffset="1.1" fill="none" stroke="{RED}" stroke-width="{w}" stroke-linecap="round"/>'
            f"</g>"
        )

    bg = f"""
      <rect x="-300" y="-300" width="1680" height="2520" fill="#f2dfc4"/>
      <rect x="-300" y="1500" width="1680" height="800" fill="#e6cdaa"/>
      <!-- window -->
      <rect x="170" y="230" width="740" height="560" rx="10" fill="#bfe3f2" stroke="{OUT}" stroke-width="{SW}"/>
      <path d="M170 600 Q330 520 470 600 T910 590 V790 H170 Z" fill="#cfe7c4"/>
      <path d="M250 640 h120 v-90 l60 -50 l60 50 v90 h40 v-70 h110 v70 H250 Z" fill="#f4efe6" stroke="{OUT}" stroke-width="5"/>
      <rect x="400" y="560" width="22" height="26" fill="#8fb6d1"/><rect x="456" y="560" width="22" height="26" fill="#8fb6d1"/>
      <circle cx="790" cy="560" r="80" fill="#86b86a" stroke="{OUT}" stroke-width="5"/>
      <circle cx="730" cy="610" r="56" fill="#77ab5c" stroke="{OUT}" stroke-width="5"/>
      <rect x="770" y="620" width="20" height="90" fill="#8b6243"/>
      <rect x="152" y="212" width="776" height="596" rx="16" fill="none" stroke="#9a6c4f" stroke-width="30"/>
      <rect x="137" y="197" width="806" height="626" rx="22" fill="none" stroke="{OUT}" stroke-width="{SW}"/>
      <rect x="167" y="227" width="746" height="566" rx="8" fill="none" stroke="{OUT}" stroke-width="5"/>
      <rect x="532" y="227" width="16" height="566" fill="#9a6c4f" stroke="{OUT}" stroke-width="5"/>
      <rect x="120" y="808" width="840" height="36" rx="8" fill="#b98059" stroke="{OUT}" stroke-width="{SW}"/>
      <!-- shelf, left -->
      <rect x="-40" y="1010" width="190" height="26" fill="#b98059" stroke="{OUT}" stroke-width="6"/>
      <rect x="20" y="930" width="46" height="80" rx="10" fill="#e9c46a" stroke="{OUT}" stroke-width="6"/>
      <rect x="82" y="950" width="40" height="60" rx="8" fill="#9ccfd8" stroke="{OUT}" stroke-width="6"/>
      <!-- fridge, right -->
      <rect x="960" y="880" width="220" height="1100" rx="26" fill="#eef1f2" stroke="{OUT}" stroke-width="{SW}"/>
      <rect x="985" y="1010" width="16" height="140" rx="8" fill="#b8c2c6" stroke="{OUT}" stroke-width="5"/>
      <circle cx="1030" cy="930" r="18" fill="#ef8f6f" stroke="{OUT}" stroke-width="5"/>
    """

    body = f"""
      <path d="M240 2300 L240 1160 Q240 975 420 962 L660 962 Q840 975 840 1160 L840 2300 Z" fill="{HOOD}" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
      <path d="M760 990 Q840 1040 838 1160 L838 2300 L760 2300 Z" fill="{HOOD_SH}"/>
      <path d="M240 1160 Q240 975 420 962 L660 962 Q840 975 840 1160" fill="none" stroke="{OUT}" stroke-width="{SW}"/>
      <path d="M380 958 Q540 1080 700 958 Q540 1010 380 958 Z" fill="{HOOD_SH}" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>
      <path d="M498 1010 L492 1130 M582 1010 L588 1130" stroke="{OUT}" stroke-width="15" stroke-linecap="round"/>
      <path d="M498 1010 L492 1130 M582 1010 L588 1130" stroke="#f3efe6" stroke-width="8" stroke-linecap="round"/>
      <path d="M372 1380 L708 1380 L752 1590 L328 1590 Z" fill="{HOOD_SH}" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>
      <path d="M372 1380 L330 1590 M708 1380 L750 1590" stroke="{OUT}" stroke-width="6"/>
      <path d="M392 1400 L676 1400" stroke="#6fb07f" stroke-width="6" stroke-linecap="round"/>
    """

    hx, hy = HEAD
    head = f"""
      <g id="{p}-head">
        <ellipse cx="{hx - 186}" cy="{hy + 20}" rx="30" ry="38" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{hx + 186}" cy="{hy + 20}" rx="30" ry="38" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{hx}" cy="{hy}" rx="185" ry="168" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{hx - 102}" cy="{hy + 52}" rx="30" ry="16" fill="{BLUSH}" opacity="0.6"/>
        <ellipse cx="{hx + 102}" cy="{hy + 52}" rx="30" ry="16" fill="{BLUSH}" opacity="0.6"/>
        <path d="M356 760 C340 610 440 560 540 562 C650 558 742 612 724 762 C712 712 690 676 662 660 L668 712 L618 652 L584 700 L556 640 L512 700 L478 648 L440 708 L430 660 Q380 690 356 760 Z" fill="#3b2a22" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
        <path d="M470 600 Q520 584 560 592" fill="none" stroke="#6b5040" stroke-width="10" stroke-linecap="round"/>
        <g id="{p}-brows"><path d="M444 722 L498 712 M582 712 L636 722" stroke="{OUT}" stroke-width="11" stroke-linecap="round"/></g>
        {eyes(p, [472, 608], 778)}
        {mouths(p, 540, 848)}
        <g id="{p}-sweat" opacity="0"><path d="M742 650 q-22 34 0 46 q22 -12 0 -46z" fill="#bfe6ff" stroke="{OUT}" stroke-width="5"/></g>
      </g>
    """

    armA = arm(f"{p}-a", SA[0], SA[1], L1, L2, HOOD, mitten(), cone(p), w=52)
    armB = arm(f"{p}-b", SB[0], SB[1], L1, L2, HOOD, mitten(), bottle(p, rx_label=True), w=52)

    svg = f"""
      <g id="{p}-cam">
        {bg}
        <g id="{p}-body">{body}</g>
        {head}
        {stream("f-s1", stream1, 20)}
        {armA}
        {armB}
        {stream("f-s2", stream2, 16)}
        <g id="{p}-pop" opacity="0">{star(250, 820, 34)}{star(860, 700, 26)}</g>
      </g>
    """

    tl = TL()
    # ---- initial pose
    tl.init(f"#{p}-cam", origin="540 1000", scale=1.04, x=0, y=-130)
    tl.init(f"#{p}-head", origin=f"{NECK[0]} {NECK[1]}", rotation=0, y=0)
    pose_arm(tl, f"{p}-a", SA, L1, L2, 0, 0, cone_hand, 0, bend=-1, init=True)
    pose_arm(tl, f"{p}-b", SB, L1, L2, 0, 0, bottle_hand_aim, phi_aim + 8, bend=-1, init=True)
    tl.init(f"#{p}-b-sq", origin="0 0", scaleX=1, scaleY=1)
    tl.init(f"#{p}-blob", origin="0 -100", scale=0.2, opacity=0)
    tl.init(f"#{p}-drip1", origin="-35 -86", scaleY=0.1, opacity=0)
    tl.init(f"#{p}-drip2", origin="30 -82", scaleY=0.1, opacity=0)
    tl.init(f"#{p}-rx", origin="0 8", scale=2.4, rotation=-28, opacity=0)
    tl.init(f"#{p}-brows", origin="540 717", y=0)
    tl.init(f"#{p}-sweat", origin="742 670", y=0, opacity=0)
    tl.init(f"#{p}-pop", origin="540 760", scale=0.4, opacity=0)
    tl.init(f".{p}-eye", scaleY=1, transformOrigin="50% 50%")

    # camera: slow push, punch on "everything"
    tl.to(f"#{p}-cam", 0.0, 1.7, "sine.inOut", origin="540 1000", scale=1.09)
    tl.to(f"#{p}-cam", 1.75, 0.14, "power3.out", origin="540 1000", scale=1.17)
    tl.to(f"#{p}-cam", 1.9, 0.6, "sine.out", origin="540 1000", scale=1.2)

    # anticipation, then squeeze on "ketchup" (1.14)
    pose_arm(tl, f"{p}-b", SB, L1, L2, 0.55, 0.4, (668, 958), phi_aim + 14, bend=-1, ease="power2.inOut")
    pose_arm(tl, f"{p}-b", SB, L1, L2, 1.0, 0.14, bottle_hand_aim, phi_aim, bend=-1, ease="back.out(2)")
    tl.to(f"#{p}-b-sq", 1.08, 0.08, "power2.in", origin="0 0", scaleX=1.16, scaleY=0.86)
    tl.to(f"#{p}-b-sq", 1.5, 0.18, "back.out(3)", origin="0 0", scaleX=1, scaleY=1)
    tl.raw(f'tl.fromTo("#f-s1 path", {{attr: {{"stroke-dashoffset": 1.1}}}}, {{attr: {{"stroke-dashoffset": 0}}, duration: 0.2, ease: "power1.out", immediateRender: false}}, 1.1);')
    tl.raw(f'tl.fromTo("#f-s1 path", {{attr: {{"stroke-dashoffset": 0}}}}, {{attr: {{"stroke-dashoffset": -1.1}}, duration: 0.22, ease: "power1.in", immediateRender: false}}, 1.62);')
    tl.to(f"#{p}-blob", 1.26, 0.01, "none", origin="0 -100", opacity=1)
    tl.to(f"#{p}-blob", 1.26, 0.34, "back.out(2.2)", origin="0 -100", scale=1.0)
    tl.to(f"#{p}-drip1", 1.55, 0.01, "none", origin="-35 -86", opacity=1)
    tl.to(f"#{p}-drip1", 1.55, 0.8, "power1.out", origin="-35 -86", scaleY=1)
    tl.to(f"#{p}-drip2", 1.75, 0.01, "none", origin="30 -82", opacity=1)
    tl.to(f"#{p}-drip2", 1.75, 0.7, "power1.out", origin="30 -82", scaleY=1)

    # face: blink, then delight on "everything"
    blink(tl, f".{p}-eye", 0.62, None)
    tl.swap(1.78, [f"#{p}-eyes-happy"], [f"#{p}-eyes"])
    tl.to(f"#{p}-head", 1.74, 0.16, "power2.out", origin=f"{NECK[0]} {NECK[1]}", rotation=5, y=-8)
    tl.to(f"#{p}-head", 1.9, 0.4, "back.out(2)", origin=f"{NECK[0]} {NECK[1]}", rotation=3, y=0)
    tl.to(f"#{p}-brows", 1.74, 0.14, "power2.out", origin="540 717", y=-10)
    tl.to(f"#{p}-pop", 1.78, 0.01, "none", origin="540 760", opacity=1)
    tl.to(f"#{p}-pop", 1.78, 0.25, "back.out(3)", origin="540 760", scale=1)
    tl.to(f"#{p}-pop", 2.3, 0.2, "power2.in", origin="540 760", scale=0.5, opacity=0)

    # ---- 2.55: punch to a close-up; he squirts it straight into his mouth
    tl.to(f"#{p}-cam", 2.5, 0.16, "power3.inOut", origin="540 1000", scale=1.62, y=116)
    pose_arm(tl, f"{p}-a", SA, L1, L2, 2.5, 0.3, cone_hand_low, 10, bend=-1)
    pose_arm(tl, f"{p}-b", SB, L1, L2, 2.5, 0.3, (790, 930), phi_mouth - 10, bend=-1)
    pose_arm(tl, f"{p}-b", SB, L1, L2, 2.86, 0.22, bottle_hand_mouth, phi_mouth, bend=-1, ease="back.out(2)")
    tl.to(f"#{p}-head", 2.5, 0.3, "power2.inOut", origin=f"{NECK[0]} {NECK[1]}", rotation=-4, y=0)
    tl.swap(2.62, [f"#{p}-eyes-shut", f"#{p}-m-o"], [f"#{p}-eyes-happy", f"#{p}-m-grin"])
    tl.to(f"#{p}-brows", 2.62, 0.2, "power2.out", origin="540 717", y=4)
    tl.to(f"#{p}-b-sq", 3.02, 0.08, "power2.in", origin="0 0", scaleX=1.14, scaleY=0.88)
    tl.to(f"#{p}-b-sq", 3.62, 0.18, "back.out(3)", origin="0 0", scaleX=1, scaleY=1)
    tl.raw(f'tl.fromTo("#f-s2 path", {{attr: {{"stroke-dashoffset": 1.1}}}}, {{attr: {{"stroke-dashoffset": 0}}, duration: 0.12, ease: "power1.out", immediateRender: false}}, 3.04);')
    tl.raw(f'tl.fromTo("#f-s2 path", {{attr: {{"stroke-dashoffset": 0}}}}, {{attr: {{"stroke-dashoffset": -1.1}}, duration: 0.14, ease: "power1.in", immediateRender: false}}, 3.66);')
    # happy gulps
    for i, t in enumerate([3.12, 3.32, 3.52]):
        tl.to(f"#{p}-head", t, 0.09, "power2.out", origin=f"{NECK[0]} {NECK[1]}", rotation=-4, y=-6)
        tl.to(f"#{p}-head", t + 0.1, 0.09, "power2.in", origin=f"{NECK[0]} {NECK[1]}", rotation=-4, y=0)

    # ---- "medicine" (4.07): a pharmacy label slaps onto the bottle, and he notices
    tl.to(f"#{p}-rx", 3.98, 0.01, "none", origin="0 8", opacity=1)
    tl.to(f"#{p}-rx", 3.98, 0.15, "back.out(2.6)", origin="0 8", scale=1, rotation=-6)
    tl.to(f"#{p}-cam", 4.0, 0.05, "power2.out", origin="540 1000", x=10)
    tl.to(f"#{p}-cam", 4.05, 0.05, "power2.inOut", origin="540 1000", x=-8)
    tl.to(f"#{p}-cam", 4.10, 0.07, "power2.out", origin="540 1000", x=0)
    tl.swap(4.2, [f"#{p}-eyes-wide", f"#{p}-m-gasp"], [f"#{p}-eyes-shut", f"#{p}-m-o"])
    tl.to(f"#{p}-brows", 4.17, 0.12, "back.out(3)", origin="540 717", y=-26)
    tl.to(f"#{p}-head", 4.17, 0.14, "back.out(2)", origin=f"{NECK[0]} {NECK[1]}", rotation=2, y=-10)
    pose_arm(tl, f"{p}-b", SB, L1, L2, 4.14, 0.2, (735, 930), -12, bend=-1, ease="back.out(2)")
    tl.to(f"#{p}-sweat", 4.24, 0.01, "none", origin="742 670", opacity=1)
    tl.to(f"#{p}-sweat", 4.24, 0.4, "power1.in", origin="742 670", y=40)

    # ---- whip out
    tl.to(f"#{p}-cam", 4.56, 0.14, "power3.in", origin="540 1000", x=-260)
    tl.raw('tl.fromTo("#friend-svg", {filter: "blur(0px)"}, {filter: "blur(14px)", duration: 0.14, ease: "power2.in", immediateRender: false}, 4.56);')
    tl.raw('tl.set("#friend-svg", {filter: "blur(0px)"}, 0);')

    return scene("friend", "#f2dfc4", svg, tl.js())


# ================================================================ SCENE 2: the 1830s doctor + customer (4.7 - 10.3 s)
def build_doctor():
    p = "d"
    COAT, COAT_SH = "#4b3d57", "#3a2f45"
    WOOD, WOOD_D = "#a7714c", "#86583a"
    L1, L2 = 165, 160
    # doctor
    DH = (540, 840)
    DNECK = (540, 985)
    DSR = (660, 1085)   # bottle arm shoulder (screen right)
    DSL = (420, 1085)
    d_rest_hand = (712, 1300)
    d_up_hand = (800, 760)
    d_l_rest = (372, 1300)
    d_l_out = (300, 1060)
    # customer
    CX = 1650
    CH = (CX, 860)
    CNECK = (CX, 1000)
    CSR = (CX + 150, 1095)  # bottle arm
    CSL = (CX - 150, 1095)  # tummy arm
    c_rest_hand = (CX + 185, 1305)
    c_drink_hand = (CX + 172, 842)
    c_tummy_hand = (CX - 40, 1240)
    c_thumb_hand = (CX - 205, 915)
    phi_drink = -118

    bg = f"""
      <rect x="-500" y="-300" width="3300" height="2520" fill="#f1e0b8"/>
      <path d="M-500 760 Q200 640 700 740 T1900 700 T2800 760 V1600 H-500 Z" fill="#dcc596"/>
      <!-- storefront -->
      <rect x="-120" y="250" width="1300" height="1320" fill="{WOOD}" stroke="{OUT}" stroke-width="{SW}"/>
      {''.join(f'<path d="M{x} 330 V1560" stroke="{WOOD_D}" stroke-width="5"/>' for x in range(-40, 1180, 92))}
      <rect x="-160" y="232" width="1380" height="90" fill="{WOOD_D}" stroke="{OUT}" stroke-width="{SW}"/>
      <rect x="200" y="372" width="680" height="170" rx="14" fill="#ead5a6" stroke="{OUT}" stroke-width="{SW}"/>
      <text x="540" y="482" text-anchor="middle" font-family="Archivo Black" font-size="66" fill="#8c2f26" letter-spacing="2">TOMATO TONIC</text>
      <circle cx="240" cy="457" r="0" fill="{RED}"/>
      <!-- shop window with bottles -->
      <rect x="40" y="700" width="300" height="420" rx="8" fill="#e9dcc0" stroke="{OUT}" stroke-width="{SW}"/>
      <rect x="40" y="910" width="300" height="20" fill="{WOOD_D}" stroke="{OUT}" stroke-width="5"/>
      {''.join(f'<g transform="translate({x} {y}) scale(0.38)">{bottle("d-shop" + str(i))}</g>' for i, (x, y) in enumerate([(100, 860), (190, 860), (280, 860), (145, 1070), (235, 1070)]))}
      <rect x="40" y="700" width="300" height="420" rx="8" fill="none" stroke="#6e4730" stroke-width="16"/>
      <!-- door -->
      <rect x="880" y="820" width="230" height="740" rx="10" fill="#6e4730" stroke="{OUT}" stroke-width="{SW}"/>
      <circle cx="1080" cy="1200" r="12" fill="#e2b04a" stroke="{OUT}" stroke-width="4"/>
      <!-- second building, customer side -->
      <rect x="1180" y="420" width="1300" height="1150" fill="#c9a274" stroke="{OUT}" stroke-width="{SW}"/>
      {''.join(f'<path d="M1180 {y} H2480" stroke="#b08a5f" stroke-width="5"/>' for y in range(480, 1560, 70))}
      <rect x="1240" y="560" width="250" height="330" rx="8" fill="#e9dcc0" stroke="{OUT}" stroke-width="{SW}"/>
      <path d="M1365 560 V890 M1240 725 H1490" stroke="#8a6a45" stroke-width="12"/>
      <rect x="1840" y="560" width="250" height="330" rx="8" fill="#e9dcc0" stroke="{OUT}" stroke-width="{SW}"/>
      <path d="M1965 560 V890 M1840 725 H2090" stroke="#8a6a45" stroke-width="12"/>
      <!-- street -->
      <rect x="-500" y="1550" width="3300" height="700" fill="#d2ad7c" stroke="{OUT}" stroke-width="{SW}"/>
      {''.join(f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 0.6:.0f}" fill="#bf9767"/>' for x, y, r in [(120, 1700, 18), (330, 1820, 12), (860, 1760, 16), (1270, 1690, 14), (1500, 1860, 20), (2050, 1720, 15), (2300, 1830, 12)])}
      <!-- crate -->
      <rect x="370" y="1440" width="340" height="250" rx="8" fill="#b7804f" stroke="{OUT}" stroke-width="{SW}"/>
      <path d="M370 1523 H710 M370 1606 H710 M390 1460 L690 1670" stroke="#8a5a34" stroke-width="7"/>
    """

    # ---------- doctor
    hx, hy = DH
    doctor_body = f"""
      <rect x="468" y="1320" width="62" height="130" fill="#3a3133" stroke="{OUT}" stroke-width="{SW}"/>
      <rect x="552" y="1320" width="62" height="130" fill="#3a3133" stroke="{OUT}" stroke-width="{SW}"/>
      <ellipse cx="492" cy="1448" rx="52" ry="20" fill="#241d1e" stroke="{OUT}" stroke-width="{SW}"/>
      <ellipse cx="592" cy="1448" rx="52" ry="20" fill="#241d1e" stroke="{OUT}" stroke-width="{SW}"/>
      <path d="M400 1070 Q400 990 470 980 L610 980 Q680 990 680 1070 L712 1390 Q540 1420 368 1390 Z" fill="{COAT}" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
      <path d="M620 1000 Q676 1010 680 1070 L712 1390 L650 1398 Z" fill="{COAT_SH}"/>
      <path d="M484 984 L540 1160 L596 984 Z" fill="#f4ecdc" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>
      <path d="M500 1040 L540 1160 L580 1040 L580 1330 L500 1330 Z" fill="#c9a45b" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>
      <circle cx="540" cy="1215" r="7" fill="{OUT}"/><circle cx="540" cy="1265" r="7" fill="{OUT}"/>
      <path d="M484 984 L520 1120 L470 1060 Z M596 984 L560 1120 L610 1060 Z" fill="{COAT_SH}" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>
      <path d="M540 1000 L500 978 L500 1022 Z M540 1000 L580 978 L580 1022 Z" fill="#a2302a" stroke="{OUT}" stroke-width="5" stroke-linejoin="round"/>
      <circle cx="540" cy="1000" r="9" fill="#a2302a" stroke="{OUT}" stroke-width="5"/>
    """
    doctor_head = f"""
      <g id="d-dhead">
        <ellipse cx="{hx - 150}" cy="{hy + 18}" rx="26" ry="34" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{hx + 150}" cy="{hy + 18}" rx="26" ry="34" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{hx}" cy="{hy}" rx="152" ry="142" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <path d="M392 800 q-10 -50 30 -70 M688 800 q10 -50 -30 -70" stroke="#d9d3ca" stroke-width="26" stroke-linecap="round" fill="none"/>
        <ellipse cx="{hx - 88}" cy="{hy + 40}" rx="24" ry="13" fill="{BLUSH}" opacity="0.6"/>
        <ellipse cx="{hx + 88}" cy="{hy + 40}" rx="24" ry="13" fill="{BLUSH}" opacity="0.6"/>
        <g id="d-dbrows"><path d="M462 778 Q490 762 516 774 M564 774 Q590 762 618 778" stroke="{OUT}" stroke-width="11" stroke-linecap="round" fill="none"/></g>
        {eyes("d-d", [490, 590], 812, 11, 16)}
        {mouths("d-d", 540, 912, 0.7)}
        <path d="M540 872 C500 846 452 852 424 884 C410 900 396 892 392 874 C390 912 444 930 540 900 C636 930 690 912 688 874 C684 892 670 900 656 884 C628 852 580 846 540 872 Z" fill="#fbf7f0" stroke="{OUT}" stroke-width="6" stroke-linejoin="round"/>
        <path d="M470 878 q30 -8 56 4 M554 882 q26 -12 56 -4" stroke="#d9d3ca" stroke-width="5" fill="none" stroke-linecap="round"/>
        <g id="d-hat">
          <ellipse cx="540" cy="712" rx="168" ry="28" fill="#2f2a2e" stroke="{OUT}" stroke-width="{SW}"/>
          <path d="M438 712 L446 500 Q540 486 634 500 L642 712 Z" fill="#2f2a2e" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
          <path d="M442 650 L638 650 L640 694 L440 694 Z" fill="#8c3b2f" stroke="{OUT}" stroke-width="6"/>
          <path d="M462 520 Q470 600 466 690" stroke="#4a4248" stroke-width="12" stroke-linecap="round" fill="none"/>
        </g>
      </g>
    """
    d_armR = arm("d-r", DSR[0], DSR[1], L1, L2, COAT, mitten(), bottle("d-db"), w=50)
    d_armL = arm("d-l", DSL[0], DSL[1], L1, L2, COAT, mitten(), w=50)
    d_spark = f'<g id="d-spark" opacity="0">{star(0, 0, 40)}{star(70, 40, 20)}{star(-60, 30, 16)}</g>'

    # ---------- customer
    cx, cy = CH
    SHIRT, OVER, OVER_SH = "#c4563f", "#5c7fae", "#4b6a95"
    cust_body = f"""
      <path d="M{CX - 220} 1960 L{CX - 220} 1180 Q{CX - 220} 1010 {CX - 90} 1000 L{CX + 90} 1000 Q{CX + 220} 1010 {CX + 220} 1180 L{CX + 220} 1960 Z" fill="{SHIRT}" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
      <path d="M{CX - 220} 1230 H{CX + 220} M{CX - 220} 1400 H{CX + 220} M{CX - 130} 1010 V1960 M{CX + 130} 1010 V1960" stroke="#a3402d" stroke-width="10"/>
      <path d="M{CX - 130} 1960 L{CX - 130} 1150 L{CX + 130} 1150 L{CX + 130} 1960 Z" fill="{OVER}" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
      <rect x="{CX - 70}" y="1200" width="140" height="110" rx="14" fill="{OVER_SH}" stroke="{OUT}" stroke-width="5"/>
      <path d="M{CX - 130} 1150 L{CX - 175} 1010 M{CX + 130} 1150 L{CX + 175} 1010" stroke="{OUT}" stroke-width="36" stroke-linecap="round"/>
      <path d="M{CX - 130} 1150 L{CX - 175} 1010 M{CX + 130} 1150 L{CX + 175} 1010" stroke="{OVER}" stroke-width="24" stroke-linecap="round"/>
      <circle cx="{CX - 112}" cy="1168" r="13" fill="#e2b04a" stroke="{OUT}" stroke-width="5"/>
      <circle cx="{CX + 112}" cy="1168" r="13" fill="#e2b04a" stroke="{OUT}" stroke-width="5"/>
      <g id="d-rumble" opacity="0">
        <path d="M{CX + 60} 1250 q14 -14 28 0 q14 14 28 0" fill="none" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/>
        <path d="M{CX + 74} 1300 q14 -14 28 0 q14 14 28 0" fill="none" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/>
        <path d="M{CX - 250} 1230 q-14 -14 -28 0 q-14 14 -28 0" fill="none" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/>
      </g>
    """
    cust_head = f"""
      <g id="d-chead">
        <ellipse cx="{cx - 160}" cy="{cy + 22}" rx="28" ry="36" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{cx + 160}" cy="{cy + 22}" rx="28" ry="36" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <ellipse cx="{cx}" cy="{cy}" rx="162" ry="148" fill="{SKIN}" stroke="{OUT}" stroke-width="{SW}"/>
        <g id="d-sick"><ellipse cx="{cx}" cy="{cy}" rx="158" ry="144" fill="#b4d68f" opacity="0.9"/></g>
        <ellipse cx="{cx - 92}" cy="{cy + 44}" rx="26" ry="14" fill="{BLUSH}" opacity="0.55"/>
        <ellipse cx="{cx + 92}" cy="{cy + 44}" rx="26" ry="14" fill="{BLUSH}" opacity="0.55"/>
        <g id="d-cbrows-sad"><path d="M{cx - 82} 798 L{cx - 36} 784 M{cx + 36} 784 L{cx + 82} 798" stroke="{OUT}" stroke-width="10" stroke-linecap="round"/></g>
        <g id="d-cbrows-happy" opacity="0"><path d="M{cx - 84} 780 Q{cx - 60} 762 {cx - 34} 776 M{cx + 34} 776 Q{cx + 60} 762 {cx + 84} 780" stroke="{OUT}" stroke-width="10" stroke-linecap="round" fill="none"/></g>
        {eyes("d-c", [cx - 58, cx + 58], 836, 11, 17)}
        {mouths("d-c", cx, 920, 0.8, default="queasy")}
        <g id="d-chat">
          <path d="M{cx - 120} 740 Q{cx - 116} 610 {cx} 604 Q{cx + 116} 610 {cx + 120} 740 Z" fill="#e8c878" stroke="{OUT}" stroke-width="{SW}" stroke-linejoin="round"/>
          <path d="M{cx - 118} 712 H{cx + 118} L{cx + 120} 740 H{cx - 120} Z" fill="#b5452f" stroke="{OUT}" stroke-width="5"/>
          <ellipse cx="{cx}" cy="744" rx="240" ry="42" fill="#e8c878" stroke="{OUT}" stroke-width="{SW}"/>
          <path d="M{cx - 200} 744 Q{cx} 770 {cx + 200} 744" stroke="#c9a65a" stroke-width="6" fill="none"/>
        </g>
      </g>
    """
    c_armR = arm("d-cr", CSR[0], CSR[1], L1, L2, SHIRT, mitten(), bottle("d-cb"), w=48)
    c_armL = arm("d-cl", CSL[0], CSL[1], L1, L2, SHIRT, mitten(), w=48,
                 extra_hand=f'<g id="d-cl-thumb" opacity="0">{thumbs_up()}</g>')
    c_spark = f'<g id="d-cspark" opacity="0">{star(CX - 250, 700, 38)}{star(CX + 250, 660, 30)}{star(CX + 280, 1000, 22)}{star(CX - 300, 1080, 18)}</g>'

    # film look (outside the camera)
    film = f"""
      <defs>
        <radialGradient id="d-vig" cx="50%" cy="45%" r="75%">
          <stop offset="55%" stop-color="#2a1a0c" stop-opacity="0"/>
          <stop offset="100%" stop-color="#2a1a0c" stop-opacity="0.55"/>
        </radialGradient>
      </defs>
      <rect x="0" y="0" width="1080" height="1920" fill="#c69a5e" opacity="0.14"/>
      <rect x="0" y="0" width="1080" height="1920" fill="url(#d-vig)"/>
      <rect id="d-scr1" x="300" y="0" width="3" height="1920" fill="#3a2a1a" opacity="0.25"/>
      <rect id="d-scr2" x="760" y="0" width="2" height="1920" fill="#fff6e0" opacity="0.3"/>
    """

    svg = f"""
      <g id="d-cam"><g id="d-zoom">
        {bg}
        <g id="d-doc">
          {doctor_body}
          {d_armL}
          {doctor_head}
          {d_armR}
          <g transform="translate({d_up_hand[0]} {d_up_hand[1] - 190})">{d_spark}</g>
        </g>
        <g id="d-cust">
          {cust_body}
          {cust_head}
          {c_armR}
          {c_armL}
          {c_spark}
        </g>
      </g></g>
      {film}
    """

    tl = TL()
    tl.init("#d-cam", origin="540 1000", x=240, y=-40, scale=1.26)
    tl.init("#d-dhead", origin=f"{DNECK[0]} {DNECK[1]}", rotation=0, y=0)
    tl.init("#d-hat", origin="540 712", y=0, rotation=0)
    tl.init("#d-dbrows", origin="540 776", y=0)
    tl.init("#d-spark", origin="0 0", scale=0.2, rotation=0, opacity=0)
    tl.init("#d-chead", origin=f"{CNECK[0]} {CNECK[1]}", rotation=4, y=0)
    tl.init("#d-sick", origin=f"{cx} {cy}", opacity=1)
    tl.init("#d-rumble", origin=f"{CX} 1260", scale=0.8, opacity=0)
    tl.init("#d-cspark", origin=f"{CX} 860", scale=0.3, opacity=0)
    tl.init("#d-zoom", origin=f"{CX} 940", scale=1)
    tl.init("#d-cl-hand", opacity=1)
    tl.init(".d-d-eye", scaleY=1, transformOrigin="50% 50%")
    tl.init(".d-c-eye", scaleY=1, transformOrigin="50% 50%")
    pose_arm(tl, "d-r", DSR, L1, L2, 0, 0, d_rest_hand, 0, bend=1, init=True)
    pose_arm(tl, "d-l", DSL, L1, L2, 0, 0, d_l_rest, 20, bend=-1, init=True)
    pose_arm(tl, "d-cr", CSR, L1, L2, 0, 0, c_rest_hand, 0, bend=-1, init=True)
    pose_arm(tl, "d-cl", CSL, L1, L2, 0, 0, c_tummy_hand, -60, bend=1, init=True)
    tl.raw('tl.set("#doctor-svg", {filter: "blur(0px)"}, 0);')

    # whip in
    tl.to("#d-cam", 0.0, 0.18, "power3.out", origin="540 1000", x=0)
    tl.raw('tl.fromTo("#doctor-svg", {filter: "blur(14px)"}, {filter: "blur(0px)", duration: 0.18, ease: "power2.out", immediateRender: false}, 0);')
    tl.to("#d-cam", 0.2, 2.8, "sine.inOut", origin="540 1000", scale=1.32)

    # "1830s" (0.78): hat pops up in greeting
    tl.to("#d-hat", 0.74, 0.16, "power2.out", origin="540 712", y=-46, rotation=-10)
    tl.to("#d-hat", 0.96, 0.3, "bounce.out", origin="540 712", y=0, rotation=0)
    tl.to("#d-dbrows", 0.74, 0.14, "power2.out", origin="540 776", y=-14)
    tl.to("#d-dbrows", 1.2, 0.2, "power2.inOut", origin="540 776", y=0)
    tl.to("#d-dhead", 0.74, 0.18, "power2.out", origin=f"{DNECK[0]} {DNECK[1]}", rotation=-4)
    tl.to("#d-dhead", 1.0, 0.3, "back.out(2)", origin=f"{DNECK[0]} {DNECK[1]}", rotation=0)
    blink(tl, ".d-d-eye", 1.5, None)
    # "doctor" (1.83): eyebrow wiggle
    for t in (1.84, 2.0):
        tl.to("#d-dbrows", t, 0.07, "power2.out", origin="540 776", y=-14)
        tl.to("#d-dbrows", t + 0.08, 0.07, "power2.in", origin="540 776", y=0)

    # "sold ketchup" (2.3): bottle up, left hand presents
    pose_arm(tl, "d-r", DSR, L1, L2, 2.12, 0.12, (712, 1335), 6, bend=1, ease="power2.in")
    pose_arm(tl, "d-r", DSR, L1, L2, 2.26, 0.3, d_up_hand, 0, bend=1, ease="back.out(1.8)")
    pose_arm(tl, "d-l", DSL, L1, L2, 2.3, 0.3, d_l_out, -70, bend=-1, ease="back.out(1.6)")
    tl.to("#d-dhead", 2.3, 0.3, "back.out(2)", origin=f"{DNECK[0]} {DNECK[1]}", rotation=5)
    tl.to("#d-spark", 2.55, 0.01, "none", origin="0 0", opacity=1)
    tl.to("#d-spark", 2.55, 0.22, "back.out(3)", origin="0 0", scale=1, rotation=20)
    tl.to("#d-spark", 2.9, 0.18, "power2.in", origin="0 0", scale=0.3, opacity=0)
    # shake it (wrist), rest of the arm stays put
    t1, t2 = ik(DSR, d_up_hand, L1, L2, 1)
    base = -(t1 + t2)
    for i, t in enumerate([2.62, 2.72, 2.82, 2.92]):
        tl.to("#d-r-wr", t, 0.09, "sine.inOut", origin="0 0", rotation=base + (14 if i % 2 == 0 else -14))
    tl.to("#d-r-wr", 3.02, 0.1, "sine.out", origin="0 0", rotation=base)

    # whip pan to the customer (3.12)
    tl.to("#d-cam", 3.1, 0.32, "power3.inOut", origin="540 1000", x=-1110 * 1.26, scale=1.26)
    tl.raw('tl.fromTo("#doctor-svg", {filter: "blur(0px)"}, {filter: "blur(16px)", duration: 0.15, ease: "power2.in", immediateRender: false}, 3.1);')
    tl.raw('tl.fromTo("#doctor-svg", {filter: "blur(16px)"}, {filter: "blur(0px)", duration: 0.17, ease: "power2.out", immediateRender: false}, 3.25);')

    # customer: queasy, rumbling tummy
    tl.to("#d-rumble", 3.35, 0.01, "none", origin=f"{CX} 1260", opacity=1)
    for i, t in enumerate([3.35, 3.5, 3.65]):
        tl.to("#d-rumble", t, 0.07, "power2.out", origin=f"{CX} 1260", scale=1.1)
        tl.to("#d-rumble", t + 0.07, 0.07, "power2.in", origin=f"{CX} 1260", scale=0.85)
        tl.to("#d-chead", t, 0.07, "sine.inOut", origin=f"{CNECK[0]} {CNECK[1]}", rotation=7)
        tl.to("#d-chead", t + 0.07, 0.07, "sine.inOut", origin=f"{CNECK[0]} {CNECK[1]}", rotation=3)
    tl.to("#d-rumble", 3.8, 0.1, "power2.in", origin=f"{CX} 1260", opacity=0)

    # "indigestion" (3.91): drinks the tonic
    pose_arm(tl, "d-cr", CSR, L1, L2, 3.78, 0.26, c_drink_hand, phi_drink, bend=-1, ease="back.out(1.5)")
    tl.to("#d-chead", 3.8, 0.26, "power2.out", origin=f"{CNECK[0]} {CNECK[1]}", rotation=-6, y=-4)
    tl.swap(3.92, ["#d-c-m-o", "#d-c-eyes-shut"], ["#d-c-m-queasy", "#d-c-eyes"])
    for t in (4.08, 4.26, 4.44):
        tl.to("#d-chead", t, 0.08, "power2.out", origin=f"{CNECK[0]} {CNECK[1]}", rotation=-8, y=-10)
        tl.to("#d-chead", t + 0.09, 0.08, "power2.in", origin=f"{CNECK[0]} {CNECK[1]}", rotation=-6, y=-4)

    # payoff (4.75): cured!
    pose_arm(tl, "d-cr", CSR, L1, L2, 4.7, 0.22, c_rest_hand, 0, bend=-1, ease="power2.out")
    tl.to("#d-sick", 4.74, 0.24, "power2.out", origin=f"{cx} {cy}", opacity=0)
    tl.swap(4.76, ["#d-c-m-grin", "#d-c-eyes-happy", "#d-cbrows-happy"], ["#d-c-m-o", "#d-c-eyes-shut", "#d-cbrows-sad"])
    tl.to("#d-chead", 4.74, 0.3, "back.out(2.5)", origin=f"{CNECK[0]} {CNECK[1]}", rotation=-3, y=-14)
    pose_arm(tl, "d-cl", CSL, L1, L2, 4.78, 0.24, c_thumb_hand, 0, bend=-1, ease="back.out(2)")
    tl.swap(4.86, ["#d-cl-thumb"], ["#d-cl-hand"])
    tl.to("#d-zoom", 4.8, 0.3, "back.out(1.6)", origin=f"{CX} 940", scale=1.12)
    tl.to("#d-cspark", 4.84, 0.01, "none", origin=f"{CX} 860", opacity=1)
    tl.to("#d-cspark", 4.84, 0.3, "back.out(2.5)", origin=f"{CX} 860", scale=1)
    tl.to("#d-cspark", 5.3, 0.25, "sine.inOut", origin=f"{CX} 860", scale=0.92)
    blink(tl, ".d-c-eye", 5.35, None)

    # film scratches, 12 times a second, from a seeded generator (same every render)
    seed = 1830
    k = 0
    while k / 12 < DOCTOR_DUR:
        seed = (seed * 1103515245 + 12345) % (2 ** 31)
        x1 = 60 + seed % 960
        seed = (seed * 1103515245 + 12345) % (2 ** 31)
        o1 = (seed % 30) / 100
        seed = (seed * 1103515245 + 12345) % (2 ** 31)
        x2 = 60 + seed % 960
        tl.raw(f'tl.set("#d-scr1", {{attr: {{x: {x1}}}, opacity: {o1:.2f}}}, {k / 12:.3f});')
        tl.raw(f'tl.set("#d-scr2", {{attr: {{x: {x2}}}, opacity: {0.3 - o1:.2f}}}, {k / 12:.3f});')
        k += 1

    return scene("doctor", "#f1e0b8", svg, tl.js())


# ================================================================ captions
WORDS = [
    # (text, start, red?)
    [("If", 0.10), ("your", 0.15), ("friend", 0.42)],
    [("puts", 0.85), ("ketchup", 1.14), ("on", 1.63), ("everything", 1.77)],
    [("they're", 2.58), ("basically", 3.03)],
    [("taking", 3.68), ("medicine", 4.07, True)],
    [("Because", 4.70), ("in", 5.13), ("the", 5.25), ("1830s", 5.48)],
    [("a", 6.52), ("doctor", 6.56), ("sold", 7.0), ("ketchup", 7.27)],
    [("as", 7.90), ("a", 8.0), ("cure", 8.08, True), ("for", 8.38), ("indigestion", 8.61)],
]
GROUP_END = [0.85, 2.56, 3.68, 4.70, 6.48, 7.88, 10.0]


def build_captions():
    groups, js = [], []
    for gi, words in enumerate(WORDS):
        start = words[0][1]
        end = GROUP_END[gi]
        spans = []
        for wi, w in enumerate(words):
            cls = "cap-w red" if (len(w) > 2 and w[2]) else "cap-w"
            spans.append(f'<span id="c-g{gi}-w{wi}" class="{cls}">{w[0].upper()}</span>')
            js.append(
                f'tl.fromTo("#c-g{gi}-w{wi}", {{opacity: 0, scale: 0.6}}, '
                f'{{opacity: 1, scale: 1, duration: 0.1, ease: "back.out(3)", immediateRender: false}}, {f(w[1])});'
            )
        groups.append(
            f'<div id="c-g{gi}" class="clip cap-group" data-start="{f(start)}" data-duration="{f(end - start)}" data-track-index="{gi % 2}">'
            + " ".join(spans)
            + "</div>"
        )
    init = "" 
    shadow = ", ".join(
        f"{f(6 * math.cos(a))}px {f(6 * math.sin(a))}px 0 #1d1712"
        for a in [i * math.pi / 8 for i in range(16)]
    ) + ", 0 10px 0 #1d1712"
    return f"""<template>
  <style>
    #root {{
      position: absolute;
      inset: 0;
    }}
    .cap-group {{
      position: absolute;
      left: 0;
      right: 0;
      top: 1150px;
      padding: 0 110px;
      text-align: center;
      font-family: "Archivo Black", sans-serif;
      font-size: 82px;
      line-height: 1.08;
      letter-spacing: 1px;
      color: #ffffff;
      overflow: visible;
    }}
    .cap-w {{
      display: inline-block;
      opacity: 0;
      text-shadow: {shadow};
    }}
    .cap-w.red {{
      color: #ff4d3a;
    }}
  </style>
  <div id="root" data-composition-id="captions" data-width="1080" data-height="1920">
    {chr(10).join('    ' + g for g in groups)}
  </div>
  <script>
    (function () {{
      const tl = gsap.timeline({{ paused: true }});
      {init}
      {chr(10).join('      ' + j for j in js)}
      window.__timelines["captions"] = tl;
    }})();
  </script>
</template>
"""


SFX = [
    # (id, file, global start, volume)
    ("sfx-squirt1", "squirt", 1.06, 0.55),
    ("sfx-whoosh1", "whoosh", 2.44, 0.45),
    ("sfx-squirt2", "squirt", 3.0, 0.45),
    ("sfx-gulp1", "glug", 3.14, 0.3),
    ("sfx-gulp2", "glug", 3.34, 0.3),
    ("sfx-gulp3", "glug", 3.54, 0.3),
    ("sfx-pop", "pop", 3.97, 0.7),
    ("sfx-whoosh2", "whoosh", 4.5, 0.5),
    ("sfx-boing", "boing", 5.43, 0.4),
    ("sfx-ding1", "ding", 7.24, 0.35),
    ("sfx-whoosh3", "whoosh", 7.76, 0.5),
    ("sfx-glug1", "glug", 8.78, 0.45),
    ("sfx-glug2", "glug", 8.96, 0.45),
    ("sfx-glug3", "glug", 9.14, 0.45),
    ("sfx-ding2", "ding", 9.52, 0.45),
]
SFX_LEN = {"squirt": 0.4, "whoosh": 0.4, "glug": 0.2, "pop": 0.2, "boing": 0.5, "ding": 0.8}


def sfx_tags():
    out = []
    for i, (id_, name, t, vol) in enumerate(SFX):
        dur = min(SFX_LEN[name], TOTAL - t)
        out.append(
            f'<audio id="{id_}" src="assets/sfx/{name}.wav" data-start="{f(t)}" data-duration="{f(dur)}" '
            f'data-track-index="{4 + i % 3}" data-volume="{vol}"></audio>'
        )
    return "\n      ".join(out)


def build_index():
    return f"""<!doctype html>
<html lang="en" data-resolution="portrait">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1080, height=1920" />
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"></script>
    <style>
      * {{
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }}
      html,
      body {{
        margin: 0;
        width: 1080px;
        height: 1920px;
        overflow: hidden;
        background: #000;
      }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}" data-width="1080" data-height="1920">
      <div id="friend" data-composition-id="friend" data-composition-src="compositions/friend.html"
        data-start="0" data-duration="{FRIEND_DUR}" data-track-index="1" data-track-kind="graphics"
        data-width="1080" data-height="1920" style="z-index: 1"></div>
      <div id="doctor" data-composition-id="doctor" data-composition-src="compositions/doctor.html"
        data-start="{DOCTOR_START}" data-duration="{DOCTOR_DUR}" data-track-index="1" data-track-kind="graphics"
        data-width="1080" data-height="1920" style="z-index: 2"></div>
      <div id="captions" data-composition-id="captions" data-composition-src="compositions/captions.html"
        data-start="0" data-duration="{TOTAL}" data-track-index="3" data-track-kind="captions"
        data-width="1080" data-height="1920" style="z-index: 10"></div>
      <audio id="vo" src="assets/voice.wav" data-start="0" data-duration="9.56" data-track-index="2" data-volume="1"></audio>
      {sfx_tags()}
    </div>
    <script>
      window.__timelines["main"] = gsap.timeline({{ paused: true }});
    </script>
  </body>
</html>
"""


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "compositions"), exist_ok=True)
    out = {
        "index.html": build_index(),
        "compositions/friend.html": build_friend(),
        "compositions/doctor.html": build_doctor(),
        "compositions/captions.html": build_captions(),
    }
    for name, text in out.items():
        with open(os.path.join(ROOT, name), "w") as fh:
            fh.write(text)
        print("wrote", name, len(text))
