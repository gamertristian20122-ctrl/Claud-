#!/usr/bin/env python3
"""Tallow, reborn - hero concept sprites for Wax & Wane.

Re-run:  python3 draw.py
Writes, next to this file:
  sheet.png    all poses at x4 (labelled), frames/*.png at 1x
  ingame.png   Tallow at 1x on a cellar crop with a warm light pool + two 0x72 foes, then x4
  portrait.png 64x64 detailed bust for the icon / store capsule, x4

Rules: every colour is from the 0x72 DungeonTileset II sheet palette (checked at the end),
1 px dark outline (#21141b), light from the top-left, flat fills + one shade, no anti-aliasing,
and only nearest-neighbour integer scaling.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = "/home/user/Claud-/wax-and-wane"
FONT = GAME + "/assets/fonts/kenney_pixel.ttf"
FRAMES_0X72 = GAME + "/assets/0x72/frames/"
SHEET_0X72 = GAME + "/art_source/0x72_DungeonTilesetII_v1.7.png"

PAL = {
    "o": "#21141b",  # outline
    "W": "#fdf7ed",  # wax
    "s": "#e2b694",  # wax shade
    "d": "#c38d70",  # wax deep shade
    "c": "#f78697",  # cheeks (rose wax)
    "m": "#9f294e",  # open mouth
    "Y": "#facb3e",  # brass light
    "O": "#ee8e2e",  # brass mid
    "R": "#c56025",  # brass shade
    "B": "#8f4029",  # brass deep
    "r": "#da4e38",  # flame tips
    "f": "#ee8e2e",  # flame orange
    "y": "#facb3e",  # flame yellow
    "l": "#ffcc68",  # flame light
    "w": "#fdf7ed",  # flame core
    "b": "#cae6f5",  # sweat / glint
    "t": "#72d6ce",  # sweat shade
    "k": "#21141b",  # wick
    "g": "#ffcc68",  # spark
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def chk(rows):
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (r, len(r), w)
    return rows


class Spr:
    """Sparse pixel sprite.  Origin = bottom centre of the dish; y = -1 is the floor row."""

    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((x, y))

    def grid(self, x0, y0, rows, mp=None):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch == ".":
                    continue
                if mp and ch in mp:
                    ch = mp[ch]
                self.put(x0 + i, y0 + j, ch)

    def shifted(self, dx, dy):
        s = Spr()
        for (x, y), c in self.px.items():
            s.put(x + dx, y + dy, c)
        return s

    def image(self, W=32, H=34, ox=15, oy=34):
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            X, Y = ox + x, oy + y
            if 0 <= X < W and 0 <= Y < H:
                im.putpixel((X, Y), rgb(PAL[c]) + (255,))
        return im


# ------------------------------------------------------------------ flame (7 wide, base = wick tip)
FLAMES = {
    "idle": [chk(g) for g in [
        ["...r...",
         "..rr...",
         "..rfr..",
         ".rfyf..",
         ".fyyfr.",
         "rfylyf.",
         "fylwlyf",
         "fylwlyf",
         ".fyyyf.",
         "..fkf.."],
        ["...r...",
         "...rr..",
         "..rfr..",
         "..fyfr.",
         ".rfyyf.",
         ".fylyfr",
         "fylwlyf",
         "fylwlyf",
         ".fyyyf.",
         "..fkf.."],
        [".......",
         "..r....",
         "..rr...",
         ".rfyr..",
         ".fyyfr.",
         "rfylyf.",
         "fylwlyf",
         "fylwlyf",
         ".fyyyf.",
         "..fkf.."],
        ["....r..",
         "...rr..",
         "..rfr..",
         ".rfyf..",
         ".fyyfr.",
         "rfylyf.",
         "fylwlyf",
         "fylwlyf",
         ".fyyyf.",
         "..fkf.."],
    ]],
    "trail": [chk(g) for g in [  # moving right: the flame streams back to the left
        ["r......",
         ".rr....",
         ".rfr...",
         "..rfyr.",
         "..fyyf.",
         ".rfylf.",
         ".fylwyf",
         ".fylwyf",
         "..fyyf.",
         "...kf.."],
        [".r.....",
         "rrr....",
         ".rffr..",
         "..fyyr.",
         "..fyyf.",
         ".rfylf.",
         ".fylwyf",
         ".fylwyf",
         "..fyyf.",
         "...kf.."],
    ]],
    "flare": [chk(g) for g in [  # shooting / victory: tall, bright
        ["...r...",
         "...r...",
         "..rfr..",
         "..rfr..",
         ".rfyfr.",
         ".fylyf.",
         "rfylyfr",
         "fylwlyf",
         "flwwwlf",
         "flwwwlf",
         ".fylyf.",
         "..fkf.."],
    ]],
    "mid": [chk(g) for g in [
        ["..r..",
         ".rr..",
         ".rfr.",
         "rfyf.",
         "fylyf",
         "flwlf",
         ".fyf.",
         "..k.."],
        ["..r..",
         "..rr.",
         ".rfr.",
         ".fyfr",
         "fylyf",
         "flwlf",
         ".fyf.",
         "..k.."],
    ]],
    "small": [chk(g) for g in [
        [".r.",
         "rfr",
         "fyf",
         "fwf",
         ".k."],
        ["r..",
         "rr.",
         "fyr",
         "fwf",
         ".k."],
    ]],
    "blown": [chk(g) for g in [  # hurt: torn sideways
        ["rr.....",
         ".rfr...",
         "..rffr.",
         "..fyyf.",
         "...fwf.",
         "....k.."],
    ]],
}


def put_flame(s, kind, i, tip):
    g = FLAMES[kind][i % len(FLAMES[kind])]
    h, w = len(g), len(g[0])
    # the 'k' pixel of the flame sits on the wick tip
    for j, r in enumerate(g):
        if "k" in r:
            kx, ky = r.index("k"), j
    s.grid(tip[0] - kx, tip[1] - ky, g)


# ------------------------------------------------------------------ brass dish (19 wide) + ring
DISH_BACK = chk([
    ".....ooooooooo.....",  # -7
    "...ooYYYYYYYYYoo...",  # -6
    ".ooYYRRRRRRRRRYYoo.",  # -5
])
DISH_FRONT = chk([
    "oYYRRRRRRRRRRRRRYYo",  # -4  bowl in front of the body
    "oWYYYYYYYYYYYYYYYOo",  # -3  front rim (glint on the left)
    ".oOOOOOOOOOOOOOORo.",  # -2
    "..ooooooooooooooo..",  # -1
])
RING = chk([   # ring handle, hung on the dish's right end
    ".ooo.",
    "oYYOo",
    "oY.Ro",
    "oORBo",
    ".ooo.",
])


def dish_back(s):
    s.grid(-9, -7, DISH_BACK)


def dish_front(s, puddle=0):
    s.grid(-9, -4, DISH_FRONT)
    s.grid(9, -5, RING)
    if puddle >= 1:
        # melted wax collects in the bowl
        span = 5 if puddle == 1 else 7
        for x in range(-span, span + 1):
            s.put(x, -4, "W" if x < span - 1 else "s")
    if puddle >= 2:
        # ... and runs over the front of the dish (two runs, different lengths)
        for x0, n in ((-5, 2), (3, 1)):
            for k in range(n):
                s.put(x0, -3 + k, "W")
                s.put(x0 + 1, -3 + k, "s")
            s.put(x0, -3 + n, "o")
            s.put(x0 + 1, -3 + n, "o")
            s.put(x0 - 1, -3 + n - 1, "o") if n > 1 else None
            s.put(x0 + 2, -3 + n - 1, "o") if n > 1 else None


# ------------------------------------------------------------------ body
# Wavy melted edge under the lip: 1 = the lip runs one pixel lower at this column.
EDGE = {-6: 1, -5: 1, -4: 0, -3: 0, -2: 1, -1: 1, 0: 1, 1: 0, 2: 0, 3: 1, 4: 1, 5: 0, 6: 0}
# a wax tear stuck on the side of the body: 3 wide, drawn over the body's edge
TEAR_L = chk([
    "oWo",
    "oWo",
    "oWo",
    "oso",
    ".o.",
])
TEAR_R = chk([
    "oso",
    "oso",
    ".o.",
])
TEAR_LONG = chk([
    "oWo",
    "oWo",
    "oWo",
    "oWo",
    "oso",
    ".o.",
])


def build_body(n=2, w=6, look=0, face="open", mouth="v", stage="full", tears=("L", "R")):
    """Wax body, bottom fill row at y = -5 (it sits in the dish).
    stage: full (tall, two-row melted edge), mid (one-row edge), low (slumped stub).  n = extra belly rows."""
    s = Spr()
    bottom = -5
    if stage == "low":
        layout = ["pool", "lip", "eye1", "eye2", "eye3", "cheek"]
    elif stage == "mid":
        layout = ["rim", "pool", "lip", "edge1", "eye1", "eye2", "eye3", "cheek"]
    else:
        layout = ["rim", "pool", "lip", "edge1", "edge2", "eye1", "eye2", "eye3", "cheek"]
    layout += ["belly"] * n + ["bottom"]
    t = bottom - len(layout) + 1
    rowy, spans = {}, {}
    for i, kind in enumerate(layout):
        y = t + i
        rowy.setdefault(kind, y)
        # chubby: the lip overhangs and the lower half bulges like a soft gumdrop
        hw = {"rim": w - 2, "lip": w + 1, "cheek": w + 1, "belly": w + 1, "bottom": w + 1}.get(kind, w)
        if stage == "low":
            hw = {"pool": w - 1, "lip": w + 1}.get(kind, w + 1)   # soft wax spreads out
        spans[y] = (-hw, hw)
    mask = {(x, y) for y, (L, R) in spans.items() for x in range(L, R + 1)}
    for (x, y) in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in mask and p[1] <= bottom:
                s.put(p[0], p[1], "o")
    for (x, y) in mask:
        side = y >= rowy["lip"]
        shade = (x + 1, y) not in mask or (side and (x + 2, y) not in mask and spans[y][1] >= w)
        s.put(x, y, "s" if shade else "W")
    # top surface: back rim, a pool around the wick
    if "rim" in rowy:
        yr = rowy["rim"]
        L, R = spans[yr]
        for x in range(L, R):
            s.put(x, yr, "W")
    yp = rowy["pool"]
    L, R = spans[yp]
    for x in range(L + 2, R - 1):
        s.put(x, yp, "s")
    # wavy melted edge under the lip
    if "edge2" in rowy:
        for x, v in EDGE.items():
            s.put(x, rowy["edge1"] + v, "s")
    elif "edge1" in rowy:
        for x, v in EDGE.items():
            if v == 0:
                s.put(x, rowy["edge1"], "s")
    # tears down the sides (drawn over the edge, own outline)
    yl = rowy["lip"]
    if stage == "low":
        # long tears that run all the way into the dish
        for x0 in (-w - 2, w):
            for y in range(yl + 1, bottom + 1):
                s.grid(x0, y, ["oWo" if x0 < 0 else "oso"])
        s.put(-w - 1, yl, "W")
        s.put(w + 1, yl, "s")
    else:
        if "L" in tears:
            s.grid(-w - 2, yl + 1, TEAR_L if stage == "full" else TEAR_R)
            s.put(-w - 1, yl, "W")
        if "R" in tears:
            s.grid(w, yl + 1, TEAR_R)
            s.put(w + 1, yl, "s")
    cx = look
    fy = rowy["eye1"]
    draw_face(s, cx, fy, face, mouth)
    return s, dict(top=t, rowy=rowy, spans=spans, cx=cx, fy=fy, w=w)


def draw_face(s, cx, fy, face, mouth):
    """Eyes 2x3 (x cx-4..-3 and cx+3..4), cheeks, mouth.  fy = eyes' top row.
    The shape of each eye's top edge carries the mood: inner corner lower = determined,
    outer corner lower = worried."""
    le, re = cx - 4, cx + 3
    L = R = None
    if face == "open":
        L = R = ["oo", "oo", "oo"]
    elif face == "blink":
        L = R = ["..", "..", "oo"]
    elif face == "brave":       # determined: inner top corner cut
        L, R = ["o.", "oo", "oo"], [".o", "oo", "oo"]
    elif face == "worried":     # outer top corner cut
        L, R = [".o", "oo", "oo"], ["o.", "oo", "oo"]
    elif face == "tired":       # small, droopy
        L, R = ["..", ".o", "oo"], ["..", "o.", "oo"]
    if L:
        s.grid(le, fy, L)
        s.grid(re, fy, R)
        if face == "open":
            s.put(le, fy, "b")
            s.put(re, fy, "b")
        if face == "worried":
            s.put(le, fy + 1, "b")
            s.put(re, fy + 1, "b")
    elif face == "happy":             # ^ ^
        s.grid(le - 1, fy + 1, [".o.", "o.o"])
        s.grid(re, fy + 1, [".o.", "o.o"])
    elif face == "hurt":              # > <
        s.grid(le - 1, fy, ["o..", ".oo", "o.."])
        s.grid(re, fy, ["..o", "oo.", "..o"])
    if face != "hurt":
        for x in (le - 2, le - 1, re + 2, re + 3):
            s.put(x, fy + 3, "c")
    my = fy + 2
    if mouth == "v":
        s.grid(cx - 1, my, ["o.o", ".o."])
    elif mouth == "dot":
        s.put(cx, my + 1, "o")
    elif mouth == "open":
        s.grid(cx - 1, my, ["ooo", "omo", ".o."])
    elif mouth == "grin":
        s.grid(cx - 2, my, ["ooooo", ".omo.", "..o.."])
    elif mouth == "wavy":
        s.grid(cx - 2, my + 1, ["o.o.o", ".o.o."])
    elif mouth == "flat":
        s.grid(cx - 1, my + 1, ["ooo"])
    elif mouth == "ouch":
        s.grid(cx - 1, my + 1, ["ooo", "omo", "ooo"])


ARM_L = chk([".oo.", "oWWo", "oWso", ".oo."])
ARM_R = chk([".oo.", "oWso", "osso", ".oo."])
ARM_UP_L = chk([".oo.", "oWWo", "oWWo", "oWso", ".oo."])
ARM_UP_R = chk([".oo.", "oWso", "oWso", "osso", ".oo."])


def tallow(n=2, face="open", mouth="v", flame=("idle", 0), look=0, lift=0, puddle=0,
           arms=("rest", "rest"), wick="crook", stage="full", fx=(), tears=("L", "R"), w=6):
    out = Spr()
    dish_back(out)
    body, info = build_body(n=n, w=w, look=look, face=face, mouth=mouth, stage=stage, tears=tears)
    out.px.update(body.px)
    dish_front(out, puddle)
    rowy = info["rowy"]
    # arms: little stubs at the cheek row; the inner outline column sits on the body's outline
    ay = rowy["cheek"] - 1
    hw = info["spans"][rowy["eye3"]][1]
    poses = {"rest": (0, 0), "low": (0, 1), "fwd": (1, -1), "back": (0, 1), "flail": (0, -3), "cheer": (1, -4)}
    for side, pose in ((-1, arms[0]), (1, arms[1])):
        if pose is None:
            continue
        if pose == "high":      # raised beside the top of the head
            yy = rowy["lip"] - 4
            if side < 0:
                out.grid(-info["w"] - 4, yy, ARM_UP_L)
            else:
                out.grid(info["w"] + 1, yy, ARM_UP_R)
            continue
        dx, dy = poses[pose]
        if side < 0:
            out.grid(-hw - 4 - dx, ay + dy, ARM_L)
        else:
            out.grid(hw + 1 + dx, ay + dy, ARM_R)
    # crooked wick, standing in the pool
    yp = rowy["pool"]
    out.put(0, yp - 1, "k")
    if wick == "crook":
        out.put(0, yp - 2, "k")
        tip = (1, yp - 3)
    elif wick == "bent":      # low wax: the wick flops over
        tip = (1, yp - 2)
    else:
        out.put(0, yp - 2, "k")
        tip = (-1, yp - 3)
    out.put(tip[0], tip[1], "k")
    if flame:
        put_flame(out, flame[0], flame[1], tip)
    for f in fx:
        f(out, info)
    if lift:
        out = out.shifted(0, -lift)
    return out, info


# ------------------------------------------------------------------ little fx
def fx_sweat(s, info):
    y = info["fy"] - 2
    x = info["spans"][info["fy"]][1] + 2
    s.grid(x, y, [".b.", "bbt", "btt", ".o."][:0] + [".b", "bt"])


def fx_drops(s, info):
    # wax knocked off by the hit
    t = info["top"]
    for (x, y, g) in ((-12, t + 2, [".o.", "oWo", "oso", ".o."]), (10, t, [".o.", "oWo", ".o."]),
                      (-8, t - 3, [".o.", "oWo", ".o."])):
        s.grid(x, y, g)


def fx_spark(s, info):
    t = info["top"]
    for (x, y) in ((-11, t + 0), (10, t - 3), (-8, t - 7)):
        s.grid(x - 1, y - 1, [".g.", "gwg", ".g."])


def fx_shot(s, info):
    t = info["top"]
    s.grid(9, t - 5, ["..r.", ".ryr", "rywf", ".ff."])


# ------------------------------------------------------------------ frames
def all_frames():
    F = {}
    # idle: breathe (belly 2 -> 1 row), blink on the last frame
    F["idle_0"] = tallow(n=2, flame=("idle", 0))
    F["idle_1"] = tallow(n=2, flame=("idle", 1))
    F["idle_2"] = tallow(n=1, flame=("idle", 2))
    F["idle_3"] = tallow(n=1, flame=("idle", 3), face="blink")
    # run (to the right): squash, push, air, land.  The dish hops, the flame trails behind.
    F["run_0"] = tallow(n=1, flame=("trail", 0), look=1, face="brave", mouth="dot", arms=("back", "fwd"))
    F["run_1"] = tallow(n=2, flame=("trail", 1), look=1, face="brave", mouth="dot", lift=1)
    F["run_2"] = tallow(n=3, flame=("trail", 0), look=1, face="brave", mouth="dot", lift=2, arms=("fwd", "back"))
    F["run_3"] = tallow(n=2, flame=("trail", 1), look=1, face="brave", mouth="dot", lift=1)
    F["shoot"] = tallow(n=2, flame=("flare", 0), look=1, face="brave", mouth="open", arms=("rest", "fwd"),
                        fx=(fx_shot,))
    F["hurt"] = tallow(n=1, flame=("blown", 0), face="hurt", mouth="ouch", arms=("flail", "flail"),
                       fx=(fx_drops,))
    F["happy"] = tallow(n=3, flame=("flare", 0), face="happy", mouth="grin", lift=1, arms=("cheer", "cheer"),
                        fx=(fx_spark,))
    # running out: 100% / 60% / 25% (the body melts shorter, the flame shrinks, the dish fills)
    F["wax_100"] = tallow(n=2, flame=("idle", 0))
    F["wax_60"] = tallow(n=0, stage="mid", flame=("mid", 0), face="worried", mouth="flat", puddle=1)
    F["wax_25"] = tallow(n=0, stage="low", flame=("small", 0), face="tired", mouth="wavy", puddle=2,
                         wick="bent", arms=("low", "low"), fx=(fx_sweat,))
    return {k: v[0] for k, v in F.items()}


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def font():
    return ImageFont.truetype(FONT, 16)


def text(d, xy, t, col):
    d.fontmode = "1"
    d.text(xy, t, font=font(), fill=col)


# ------------------------------------------------------------------ sheet
CELL_W, CELL_H = 32, 34
BG = rgb("#2b2929") + (255,)
CELL = rgb("#3b3332") + (255,)
SHADOW = rgb("#302c2b") + (255,)
INK = rgb("#d3bfa9") + (255,)
GOLD = rgb("#facb3e") + (255,)
DIM = rgb("#775c55") + (255,)


def cell(F, key):
    im = Image.new("RGBA", (CELL_W, CELL_H), CELL)
    d = ImageDraw.Draw(im)
    # the game's ground shadow under the dish (stays on the floor when Tallow hops)
    d.rectangle([15 - 7, CELL_H - 2, 15 + 7, CELL_H - 1], fill=SHADOW)
    d.rectangle([15 - 9, CELL_H - 1, 15 + 9, CELL_H - 1], fill=SHADOW)
    im.alpha_composite(F[key].image(CELL_W, CELL_H, 15, CELL_H - 1))
    return im


def make_sheet(F):
    rows = [
        [("IDLE", ["idle_0", "idle_1", "idle_2", "idle_3"], CELL_W),
         ("RUN  (moving right)", ["run_0", "run_1", "run_2", "run_3"], CELL_W)],
        [("SHOOT", ["shoot"], 38), ("HURT", ["hurt"], 38), ("VICTORY", ["happy"], 38),
         ("RUNNING OUT  (wax left)", ["wax_100", "wax_60", "wax_25"], CELL_W)],
    ]
    sub = {"wax_100": "100%", "wax_60": "60%", "wax_25": "25%"}
    gap, pad = 8, 6
    W = pad * 2 + 8 * CELL_W + gap
    notes = [
        "Health = height: the wax melts shorter, the flame",
        "shrinks, wax fills the dish and spills over its lip.",
        "Mood lives in the eye tops: brave, worried, tired.",
    ]
    H = 14 + 2 * (11 + CELL_H + 12) + len(notes) * 9 + 4
    sh = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sh)
    text(d, (pad, 2), "TALLOW, REBORN", GOLD)
    t2 = "concept tallow2  -  all frames x4"
    text(d, (W - pad - font().getbbox(t2)[2], 2), t2, DIM)
    y = 15
    for row in rows:
        x = pad
        for label, keys, cw in row:
            text(d, (x, y), label, INK)
            for k in keys:
                c = cell(F, k)
                if cw != CELL_W:
                    c2 = Image.new("RGBA", (cw, CELL_H), CELL)
                    c2.alpha_composite(c, ((cw - CELL_W) // 2, 0))
                    c = c2
                sh.alpha_composite(c, (x, y + 10))
                lab = sub.get(k)
                if lab:
                    tw = font().getbbox(lab)[2]
                    text(d, (x + (cw - tw) // 2, y + 10 + CELL_H), lab, GOLD)
                x += cw
            x += gap if label != "VICTORY" else gap
            if label in ("SHOOT", "HURT"):
                x -= gap - 2
        y += 10 + CELL_H + 12
    for i, t in enumerate(notes):
        text(d, (pad, y + i * 9), t, DIM)
    return up(sh, 4)


# ------------------------------------------------------------------ in-game composite
def load_0x72(name):
    return Image.open(FRAMES_0X72 + name + ".png").convert("RGBA")


def make_ingame(F):
    room = Image.open(GAME + "/assets/art/rooms/room_cellar.png").convert("RGBA")
    bg = room.crop((16, 14, 256, 149))  # 240x135: a strip of the top wall + the floor
    W, H = bg.size
    # actors (feet positions)
    hero = (104, 86)
    foes = [("imp_idle_anim_f1", (146, 70)), ("goblin_run_anim_f2", (70, 108))]
    # sprites first: shadows on the floor
    layer = bg.copy()
    sd = ImageDraw.Draw(layer)
    # light: banded pool centred on the flame (the game's light is smooth; bands keep it pixel-honest)
    cx, cy = hero[0] + 1, hero[1] - 18
    bands = [(20, 1.00, (1.10, 0.97, 0.80)), (34, 0.86, (1.08, 0.95, 0.80)), (50, 0.70, (1.04, 0.93, 0.84)),
             (68, 0.56, (1.0, 0.92, 0.88))]
    amb = (0.40, (0.86, 0.88, 1.0))
    px = layer.load()

    def light_at(x, y):
        r = math.hypot(x - cx, (y - cy) * 1.1)
        for rad, k, tint in bands:
            if r <= rad:
                return k, tint
        return amb

    def lit(c, x, y):
        k, tint = light_at(x, y)
        return tuple(min(255, int(c[i] * k * tint[i])) for i in range(3)) + (255,)

    for y in range(H):
        for x in range(W):
            px[x, y] = lit(px[x, y], x, y)
    # ground shadows (darken)
    def shadow(fx, fy, hw):
        for x in range(fx - hw, fx + hw + 1):
            for y in (fy - 1, fy):
                if 0 <= x < W and 0 <= y < H:
                    c = px[x, y]
                    if y == fy - 1 and abs(x - fx) > hw - 2:
                        continue
                    px[x, y] = tuple(int(v * 0.62) for v in c[:3]) + (255,)
    shadow(hero[0], hero[1], 9)
    for name, (fx, fy) in foes:
        shadow(fx, fy, 6)
    # foes (lit by the pool like the game does)
    for name, (fx, fy) in foes:
        sp = load_0x72(name)
        sp2 = sp.copy()
        sp2px = sp2.load()
        for y in range(sp.height):
            for x in range(sp.width):
                c = sp2px[x, y]
                if c[3]:
                    gx, gy = fx - sp.width // 2 + x, fy - sp.height + y
                    k, tint = light_at(gx, gy)
                    k = max(k, 0.62)
                    sp2px[x, y] = tuple(min(255, int(c[i] * k * tint[i])) for i in range(3)) + (255,)
        layer.alpha_composite(sp2, (fx - sp.width // 2, fy - sp.height))
    # an ember shot on its way to the imp
    shot = Spr()
    shot.grid(0, 0, ["..r.", ".ryr", "rywf", ".ff."])
    layer.alpha_composite(shot.image(4, 4, 0, 0), (126, 61))
    # Tallow, unlit (he is the light), at 1x
    layer.alpha_composite(F["idle_0"].image(32, 34, 15, 33), (hero[0] - 15, hero[1] - 33))
    return up(layer, 4), layer


# ------------------------------------------------------------------ 64x64 portrait
def make_portrait():
    """64x64 bust for the app icon / store capsule.  Built from integer shape tests, hard edges only."""
    N = 64
    P = {}
    O = "#21141b"

    def put(x, y, c):
        if 0 <= x < N and 0 <= y < N:
            P[(x, y)] = c

    def outline(mask, below=N):
        for (x, y) in mask:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in mask and q[1] < below:
                    put(q[0], q[1], O)

    # background: a night-blue clock face with a pewter rim (wax = the clock)
    cx0, cy0 = 31.5, 31.5
    for y in range(N):
        for x in range(N):
            r = math.hypot(x - cx0, y - cy0)
            put(x, y, "#2a2a3a" if r <= 29.5 else ("#414859" if r <= 31.0 else O))
    for h in range(12):
        a = h * math.pi / 6
        rr = (25, 26, 27) if h % 3 == 0 else (26,)
        for k in rr:
            put(int(round(cx0 + math.sin(a) * k)), int(round(cy0 - math.cos(a) * k)),
                "#b6cbcf" if h % 3 == 0 else "#7b8994")
    # warm halo behind the flame: two hard bands
    for y in range(N):
        for x in range(N):
            if math.hypot(x - cx0, y - cy0) > 29.5:
                continue
            r = math.hypot(x - 32, (y - 14) * 0.85)
            if r <= 10.5:
                put(x, y, "#62232f")
            elif r <= 14.5:
                put(x, y, "#38262d")

    # ---- dish (ellipse 50 wide) with a 3 px front face, ring on the right
    dcx, dcy = 31.5, 51.0
    dish = {(x, y) for y in range(40, 62) for x in range(N)
            if ((x - dcx) / 24.0) ** 2 + ((y - dcy) / 5.6) ** 2 <= 1.0}
    front = {(x, y + k) for (x, y) in dish for k in (1, 2, 3)} - dish
    dall = dish | front
    outline(dall)
    for (x, y) in front:
        put(x, y, "#ee8e2e" if x < 47 else "#c56025")
    for (x, y) in front:
        if (x, y + 1) not in dall:
            put(x, y, "#c56025")          # underside
    bowl = {(x, y) for (x, y) in dish if ((x - dcx) / 20.0) ** 2 + ((y - dcy + 0.5) / 3.6) ** 2 <= 1.0}
    for (x, y) in dish:
        put(x, y, "#facb3e")
    for (x, y) in bowl:
        put(x, y, "#c56025" if y >= dcy - 1 else "#8f4029")
    for x in range(10, 15):
        put(x, 54, "#fdf7ed")             # glint on the rim
    # ring handle
    ring = {(x, y) for y in range(42, 60) for x in range(52, 64) if 2.0 <= math.hypot(x - 58.0, y - 51.0) <= 4.2}
    outline(ring)
    for (x, y) in ring:
        put(x, y, "#facb3e" if (x - 58.0) + (y - 51.0) < 0 else "#c56025")

    # ---- wax body
    L0, R0 = 18, 45
    body = {(x, y) for y in range(27, 51) for x in range(L0, R0 + 1)}
    body |= {(x, y) for y in range(19, 33) for x in range(L0 - 1, R0 + 2)
             if ((x - 31.5) / 14.0) ** 2 + ((y - 26.0) / 5.0) ** 2 <= 1.0}
    body |= {(L0 - 1, y) for y in (29, 30)} | {(R0 + 1, y) for y in (29, 30)}   # lip overhang
    # tears down the sides, round ends
    tear_l = {(L0 - 2, y) for y in range(31, 38)} | {(L0 - 3, 37), (L0 - 3, 38), (L0 - 2, 38), (L0 - 2, 39)}
    tear_r = {(R0 + 2, y) for y in range(31, 34)} | {(R0 + 3, 34), (R0 + 2, 34), (R0 + 2, 35)}
    body |= tear_l | tear_r
    body |= {(L0 - 1, y) for y in range(41, 51)} | {(R0 + 1, y) for y in range(41, 51)}  # soft gumdrop belly
    body |= {(L0 - 2, y) for y in range(47, 51)} | {(R0 + 2, y) for y in range(47, 51)}  # sags into the dish
    outline(body, below=48)
    rows = {}
    for (x, y) in body:
        rows[y] = max(rows.get(y, -1), x)
    for (x, y) in body:
        put(x, y, "#e2b694" if x >= rows[y] - 3 and y >= 29 else "#fdf7ed")
    for (x, y) in body:
        if y < 29 and x >= rows[y] - 1:
            put(x, y, "#e2b694")
    # tears sit on the side: a line between tear and body, shade at the tips
    for y in range(31, 37):
        put(L0 - 1, y, O)
    for y in range(31, 33):
        put(R0 + 1, y, O)
    for q in ((L0 - 3, 38), (L0 - 2, 39), (R0 + 2, 35), (R0 + 3, 34)):
        put(q[0], q[1], "#e2b694")
    # top surface: pool around the wick (two tones)
    for y in range(19, 33):
        for x in range(L0, R0 + 1):
            if (x, y) not in body:
                continue
            e = ((x - 31.5) / 10.5) ** 2 + ((y - 25.6) / 2.6) ** 2
            if e <= 1.0:
                put(x, y, "#e2b694")
            if e <= 0.3:
                put(x, y, "#c38d70")
    # melted edge under the lip: a wax cap with drips of different lengths; its lower edge and the
    # right side of each drip cast a one-shade shadow on the body (light from the top-left)
    bumps = [(20.5, 4, 1.5), (27.0, 2, 1.0), (34.0, 6, 1.6), (40.5, 3, 1.2)]

    def dpt(x):
        d = 0
        for bx, h, wd in bumps:
            if abs(x + 0.5 - bx - 0.5) <= wd:
                d = max(d, h if abs(x - bx) <= wd - 1 else h - 1)
        return d
    sx = rows[33] - 3
    for x in range(L0, sx):
        put(x, 32 + dpt(x), "#e2b694")
        nxt = dpt(x + 1) if x + 1 < sx else 0
        for y in range(32 + nxt, 32 + dpt(x)):
            put(x + 1, y, "#e2b694")
    # face: big eyes (4x6) with two glints, rosy cheeks, a small smile
    def eye(x0, y0):
        for y in range(y0, y0 + 6):
            for x in range(x0, x0 + 4):
                if not ((x in (x0, x0 + 3)) and (y in (y0, y0 + 5))):
                    put(x, y, O)
        for q in ((x0 + 1, y0 + 1), (x0 + 2, y0 + 1), (x0 + 1, y0 + 2)):
            put(q[0], q[1], "#fdf7ed")
        put(x0 + 2, y0 + 4, "#cae6f5")
    eye(22, 37)
    eye(38, 37)
    for x in (19, 20, 21, 42, 43, 44):
        for y in (44, 45):
            put(x, y, "#f78697")
    for q in ((29, 43), (30, 44), (31, 45), (32, 45), (33, 44), (34, 43)):
        put(q[0], q[1], O)
    # stub arms, in front of the body edge
    for ax in (L0 - 4, R0 + 1):
        arm = {(x, y) for y in range(42, 47) for x in range(ax, ax + 4)
               if not ((x in (ax, ax + 3)) and (y in (42, 46)))}
        outline(arm)
        for (x, y) in arm:
            put(x, y, "#e2b694" if (x == ax + 3 or y == 46) else "#fdf7ed")
    # crooked wick
    for q in ((32, 25), (32, 24), (32, 23), (33, 22), (33, 21)):
        put(q[0], q[1], O)
    # flame: teardrop with a curl, hard colour bands
    base = 21
    for y in range(2, base + 1):
        t = base - y
        hw = 2.6 + t * 0.75 if t <= 5 else 6.35 - (t - 5) * 0.5
        if hw <= 0:
            continue
        sway = -1.5 * math.sin((t - 6) / 13.0 * math.pi) if t > 6 else 0.0
        for x in range(18, 48):
            dx = x + 0.5 - (33.0 + sway)
            if abs(dx) > hw:
                continue
            k = abs(dx) / hw
            if k > 0.74 or t >= 15:
                c = "#da4e38"
            elif k > 0.5 or t >= 12:
                c = "#ee8e2e"
            elif k > 0.28 or t >= 9:
                c = "#facb3e"
            elif t >= 6 or t <= 1:
                c = "#ffcc68"
            else:
                c = "#fdf7ed"
            put(x, y, c)
    put(33, 21, O)
    put(33, 20, "#da4e38")
    im = Image.new("RGBA", (N, N), (0, 0, 0, 255))
    for (x, y), c in P.items():
        im.putpixel((x, y), rgb(c) + (255,))
    return im


def palette_check(images):
    sheet = set()
    a = Image.open(SHEET_0X72).convert("RGBA")
    for c in a.get_flattened_data():
        if c[3]:
            sheet.add(c[:3])
    bad = set()
    for im in images:
        for c in im.convert("RGBA").get_flattened_data():
            if c[3] and c[:3] not in sheet:
                bad.add(c[:3])
    return bad


if __name__ == "__main__":
    F = all_frames()
    os.makedirs(HERE + "/frames", exist_ok=True)
    for k, sp in F.items():
        sp.image().save(HERE + "/frames/%s.png" % k)
    bad = palette_check([sp.image() for sp in F.values()])
    print("sprite colours outside the 0x72 palette:", bad or "none")
    make_sheet(F).save(HERE + "/sheet.png")
    big, small = make_ingame(F)
    big.save(HERE + "/ingame.png")
    por = make_portrait()
    print("portrait colours outside the 0x72 palette:", palette_check([por]) or "none")
    por.save(HERE + "/frames/portrait_64.png")
    up(por, 4).save(HERE + "/portrait.png")
    print("wrote sheet.png ingame.png portrait.png")
