#!/usr/bin/env python3
"""Wax & Wane 2.0 - floor stains, gibs, small juice sprites and every enemy shot (assets/art/fx/).

Splats and gibs are drawn in a neutral three-step "ash" ramp taken from the 0x72
palette. The game recolours them per creature at runtime by exact colour index
(scripts/game/stains.gd), so one set of shapes serves goo, bone-ash, blood, wax...

    hi  #b6cbcf   wet highlight (top-left, light comes from the top-left)
    mid #7b8994   body
    lo  #314152   rim / shadow side (bottom-right)
    ink #21141b   gib outline only (splats lie flat on the floor: no outline)

No anti-aliasing, no partial alpha. Shapes come from a seeded RNG, so running the
script always writes identical PNGs.

Usage:
    python3 tools/art_fx2.py               # write the PNGs
    python3 tools/art_fx2.py --review DIR  # also a contact sheet (x8, on a floor tile)
"""
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FX = os.path.join(ROOT, "assets", "art", "fx")
OX72 = os.path.join(ROOT, "assets", "0x72", "frames")

HI = (0xB6, 0xCB, 0xCF, 255)
MID = (0x7B, 0x89, 0x94, 255)
LO = (0x31, 0x41, 0x52, 255)
INK = (0x21, 0x14, 0x1B, 255)
CLEAR = (0, 0, 0, 0)


def hexc(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


# --------------------------------------------------------------------------
# Splats: a main blob with a wobbly rim + satellite droplets.
# --------------------------------------------------------------------------
def blob_mask(W, H, cx, cy, rx, ry, wob, seed, drops):
    rnd = random.Random(seed)
    ph = [rnd.random() * math.tau for _ in range(3)]
    m = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            a = math.atan2(dy, dx)
            edge = 1.0 + wob * (0.55 * math.sin(3 * a + ph[0]) + 0.3 * math.sin(5 * a + ph[1])
                                + 0.15 * math.sin(7 * a + ph[2]))
            if math.hypot(dx, dy) <= edge:
                m[y][x] = True
    for (ddx, ddy, r) in drops:
        for y in range(H):
            for x in range(W):
                if math.hypot(x + 0.5 - (cx + ddx), y + 0.5 - (cy + ddy)) <= r:
                    m[y][x] = True
    return m


def shade(m, hi_spots):
    """Cel-shade a mask: lo on the bottom-right rim, hi on the given spots, mid elsewhere."""
    H, W = len(m), len(m[0])
    im = Image.new("RGBA", (W, H), CLEAR)
    px = im.load()

    def on(x, y):
        return 0 <= x < W and 0 <= y < H and m[y][x]

    for y in range(H):
        for x in range(W):
            if not m[y][x]:
                continue
            c = MID
            # shadow side: open to the right or below, on a body at least 2 px thick
            # (thin streaks and lone droplets stay mid so they never read as dark "legs")
            if (not on(x + 1, y) or not on(x, y + 1)) and on(x - 1, y) and on(x, y - 1):
                c = LO
            px[x, y] = c
    for (x, y) in hi_spots:
        if on(x, y) and px[x, y] == MID:
            px[x, y] = HI
    return im


def hi_patch(cx, cy, rx, ry, n):
    """A short horizontal glint up-left of the centre (light from the top-left)."""
    x0 = int(round(cx - rx * 0.45))
    y0 = int(round(cy - ry * 0.5))
    return [(x0 + i, y0) for i in range(n)]


def streak(m, x0, y0, x1, y1):
    """A 1 px splash streak between two points (Bresenham, no anti-aliasing)."""
    H, W = len(m), len(m[0])
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        if 0 <= x0 < W and 0 <= y0 < H:
            m[y0][x0] = True
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# W, H, main blob radii, wobble, seed, number of thrown droplets, throw direction (rad, None = all
# round), glint length. Droplets fly out from the blob, some with a thin streak back to it.
SPLATS = [
    (6, 5, 2.1, 1.6, 0.10, 11, 2, 0.3, 1),
    (8, 7, 2.6, 2.1, 0.18, 23, 3, None, 1),
    (10, 8, 3.0, 2.3, 0.20, 37, 4, -0.4, 2),
    (12, 9, 3.6, 2.7, 0.22, 41, 5, None, 2),
    (14, 8, 3.8, 2.2, 0.16, 53, 5, 0.1, 2),
    (16, 12, 4.8, 3.6, 0.24, 67, 7, None, 3),
    (11, 10, 2.6, 2.2, 0.30, 71, 7, None, 1),
    (16, 11, 5.2, 3.3, 0.26, 83, 8, None, 3),
    # 8, 9: the huge boss splats (one per boss death)
    (30, 20, 9.5, 6.2, 0.22, 97, 14, None, 4),
    (32, 20, 10.0, 6.4, 0.30, 131, 16, None, 4),
]


def splat(i):
    W, H, rx, ry, wob, seed, nd, throw, glint = SPLATS[i]
    rnd = random.Random(seed * 7 + 3)
    cx, cy = W / 2.0, H / 2.0
    if throw is not None:   # the blob sits back from the direction it was thrown in
        cx -= math.cos(throw) * (W / 2.0 - rx - 0.8)
        cy -= math.sin(throw) * (H / 2.0 - ry - 0.8) * 0.6
    if W >= 24:
        # big puddles: a union of overlapping discs (a single wobbly ellipse this size reads as a heart)
        lobes = []
        for k in range(6):
            a = k * math.tau / 6 + rnd.uniform(-0.5, 0.5)
            d = rnd.uniform(0.45, 0.95)
            lobes.append((math.cos(a) * rx * d, math.sin(a) * ry * d, rnd.choice([0.22, 0.3, 0.38, 0.46]) * rx))
        m = blob_mask(W, H, cx, cy, rx * 0.5, ry * 0.55, wob, seed,
                      [(dx, dy * 0.75, r * (ry / rx) ** 0.5) for (dx, dy, r) in lobes])
    else:
        m = blob_mask(W, H, cx, cy, rx, ry, wob, seed, [])
    for k in range(nd):
        if throw is None:
            a = (k + rnd.random() * 0.6) * math.tau / nd
        else:
            a = throw + rnd.uniform(-0.9, 0.9)
        far = rnd.uniform(1.15, 1.6) if W >= 24 else rnd.uniform(1.25, 1.95)
        ex, ey = cx + math.cos(a) * rx * far, cy + math.sin(a) * ry * far
        ex = min(max(ex, 0.6), W - 0.6)
        ey = min(max(ey, 0.6), H - 0.6)
        r = rnd.choice([0.5, 0.75, 1.0, 1.0])
        for y in range(H):
            for x in range(W):
                if math.hypot(x + 0.5 - ex, y + 0.5 - ey) <= r:
                    m[y][x] = True
        if rnd.random() < 0.3:   # a short tail pointing back at the blob
            streak(m, ex - math.cos(a) * 2.0 - 0.5, ey - math.sin(a) * 1.5 - 0.5, ex - 0.5, ey - 0.5)
        else:
            m[min(H - 1, max(0, int(ey)))][min(W - 1, max(0, int(ex)))] = True
    return shade(m, hi_patch(cx, cy, rx, ry, glint))


# --------------------------------------------------------------------------
# Gibs: tiny outlined chunks (they fly out, bounce once and settle into the stain).
# --------------------------------------------------------------------------
GIBS = [
    ["ii",
     "ml"],
    ["him",
     "mml"],
    [".h.",
     "hml",
     ".l."],
    ["hm.",
     "mml",
     ".ll"],
    ["hhm",
     "hml",
     "mll"],
    [".hm.",
     "hmml",
     ".ll."],
]


def gib(rows):
    """Fill grid + 1 px ink outline (4-neighbour)."""
    cmap = {"h": HI, "m": MID, "l": LO, "i": HI}
    H, W = len(rows) + 2, len(rows[0]) + 2
    im = Image.new("RGBA", (W, H), CLEAR)
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in cmap:
                px[x + 1, y + 1] = cmap[ch]
    out = im.copy()
    o = out.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H and px[X, Y][3]:
                    o[x, y] = INK
                    break
    return out


# --------------------------------------------------------------------------
# Glint: a 4-point star for "hold aloft" (2 frames: small, big). 7x7.
# --------------------------------------------------------------------------
GLINT = [
    [".......",
     "...y...",
     "..ywy..",
     ".ywwwy.",
     "..ywy..",
     "...y...",
     "......."],
    ["...y...",
     "...w...",
     "..ywy..",
     "ywwwwwy",
     "..ywy..",
     "...w...",
     "...y..."],
]


def glint(rows):
    cmap = {"y": hexc("#facb3e"), "w": hexc("#fdf7ed"), "o": hexc("#ee8e2e")}
    im = Image.new("RGBA", (len(rows[0]), len(rows)), CLEAR)
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in cmap:
                px[x, y] = cmap[ch]
    return im


OUT = []


def save(im, name):
    os.makedirs(FX, exist_ok=True)
    p = os.path.join(FX, name)
    im.save(p)
    OUT.append(p)


# --------------------------------------------------------------------------
# Enemy shots (two frames each; Shot loads fx/<kind>_f<i>, or fx/<kind>_lg_f<i> with "Enemy shots: Large").
# This file owns all eight: art_hero_fx_items.py (the orbs), art_tower.py (the cog) and art_monsters.py (the
# bolts) call build_enemy_shots() / enemy_shot_images() after their own old versions, and
# tools/design_bullets.py rebuilds and judges just these.
# Friend or foe by SHAPE and LIGHTNESS, not hue (UX-02): every enemy shot is a dark-rimmed token (1 px
# #21141b all round) with a white-hot core of at least a quarter of its inside (so it still clears 3:1
# on every lit floor, tools/design_contrast.py) and the rest in the darkest tones of its hue; Tallow's
# embers are bright flames with no dark rim. The cog is white enamel (pewter read as the Blue Flame's
# ember for colour-blind players), the ring and the bone are white with dark rims.
# v2.1 (easier to see on a phone): the shots are drawn one step bigger, 9 px (BIG_SHAPES[9], the Normal
# set) and 11 px (BIG_SHAPES[11], the Large set, same hitboxes), with a 1 px rim of their own colour just
# inside the dark outline (the orbs' rim is lit on the top-left and falls into shade on the bottom-right)
# and a bigger white-hot core; frame 1 is a gentle pulse (the core one or two pixels bigger, the ring a
# notch round, the bone or page a turn on). ENEMY_SHOTS keeps the 2.0 7 px drawings: a shot that only has
# one of those (a new shot) is grown to 9 / 11 px by grow() until it is drawn by hand in BIG_SHAPES.
# Judge: python3 tools/design_bullets.py --judge (colour distance to the player's shots under
# protanopia / deuteranopia / tritanopia, the floor contrast, and a side-by-side sheet, for both sets).
# --------------------------------------------------------------------------
SHOT_PAL = {
    "K": "#21141b", "2": "#2a2a3a", "w": "#fdf7ed", "p": "#9f294e", "v": "#5f2d56", "m": "#62232f",
    "P": "#dc4a7b", "g": "#4ba747", "G": "#3d734f", "B": "#417089", "A": "#d3bfa9", "X": "#e2b694",
    "a": "#aa8d7a", "S": "#b6cbcf",
}
ORB_SHAPE = ["""
..KKK..
.KLMMK.
KLwwMDK
KMwwwDK
KMMwDDK
.KDDDK.
..KKK..
""", """
..KKK..
.KLwMK.
KLwwwDK
KMwwMDK
KMMMDDK
.KDDDK.
..KKK..
"""]
ORB_TONES = {
    "bullet_purple": {"L": "p", "M": "v", "D": "m"},   # plum, a wine glint up-left
    "bullet_green": {"L": "g", "M": "G", "D": "2"},    # moss
    "bullet_water": {"L": "B", "M": "2", "D": "2"},    # black water, a blue glint
}
ENEMY_SHOTS = {
    # the Keeper's and the sentries' cogs: white enamel, ivory teeth turning a notch each frame
    "bolt_cog": ["""
..XKX..
.KAwAK.
XAwwwaX
KwwKwaK
XAwwaaX
.KaaaK.
..XKX..
""", """
..KXK..
.XAwAX.
KAwwwaK
XwwKwaX
KAwwaaK
.XaaaX.
..KXK..
"""],
    # a sound wave: a white ring with a dark rim inside and out
    "bolt_ring": ["""
..KKK..
.KwwwK.
KwKKKwK
KwK.KwK
KwKKKwK
.KwwwK.
..KKK..
""", """
..KKK..
.KwSwK.
KwKKKwK
KSK.KSK
KwKKKwK
.KwSwK.
..KKK..
"""],
    # rose wax: a dark plum bead with a pink glint, a white-hot heart and a drip
    "bolt_wax": ["""
..KKK..
.KPvvK.
KPwwwmK
KvwwwmK
KvvvmmK
.KvmmK.
..KmK..
""", """
..KKK..
.KvPvK.
KPwwwmK
KvwwwmK
KvvvmmK
.KmmmK.
..KmK..
"""],
    # the Sexton's bone, tumbling end over end
    "bolt_bone": ["""
.KK....
KwwK...
KwAwK..
.KwAwK.
..KwAwK
...KwwK
....KK.
""", """
....KK.
...KwwK
..KwAwK
.KwAwK.
KwAwK..
KwwK...
.KK....
"""],
    # a hymn-book page, face on and edge on
    "bolt_page": ["""
.KKKKK.
KwwwwwK
KwaaawK
KwwwwwK
KwaawwK
KwwwwwK
.KKKKK.
""", """
.......
KKKKKKK
KwaaawK
KwwwwwK
KwaawaK
KKKKKKK
.......
"""],
}
for _k, _tones in ORB_TONES.items():
    ENEMY_SHOTS[_k] = ["".join(_tones.get(ch, ch) for ch in f) for f in ORB_SHAPE]


# ---- v2.1: the 9 px (Normal) and 11 px (Large) sets. Layers: K outline, C the shot's own rim colour (E: the
# rim's shaded half), M / D body (lit side / shade), w the white-hot core; A / X / a ivory, parchment and tan.
BIG_SHAPES = {
    "orb": {9: ["""
...KKK...
.KKCCCKK.
.KCMwMEK.
KCMwwwDEK
KCwwwwDEK
KCMwwDDEK
.KEDDDEK.
.KKEEEKK.
...KKK...
""", """
...KKK...
.KKCCCKK.
.KCwwMEK.
KCwwwwDEK
KCwwwwDEK
KCMwwDDEK
.KEDDDEK.
.KKEEEKK.
...KKK...
"""], 11: ["""
....KKK....
..KKCCCKK..
.KCCMMMEEK.
.KCMwwwDEK.
KCMwwwwwDEK
KCMwwwwDDEK
KCMwwwDDDEK
.KEMwDDDEK.
.KEEDDDEEK.
..KKEEEKK..
....KKK....
""", """
....KKK....
..KKCCCKK..
.KCCMwMEEK.
.KCMwwwwEK.
KCMwwwwwDEK
KCMwwwwDDEK
KCMwwwwDDEK
.KEMwDDDEK.
.KEEDDDEEK.
..KKEEEKK..
....KKK....
"""]},
    # rose wax: the bead with a drip
    "wax": {9: ["""
...KKK...
.KKCCCKK.
.KCMwMEK.
KCMwwwDEK
KCwwwwDEK
.KCwwDEK.
.KKEDEKK.
...KEK...
....K....
""", """
...KKK...
.KKCCCKK.
.KCwwMEK.
KCwwwwDEK
KCwwwwDEK
.KCwwDEK.
.KKEDEKK.
...KEK...
....K....
"""], 11: ["""
....KKK....
..KKCCCKK..
.KCCMMMEEK.
.KCMwwwDEK.
KCMwwwwwDEK
KCMwwwwDDEK
.KCMwwDDEK.
..KEMwDEK..
...KKEEKK..
.....KEK...
.....KK....
""", """
....KKK....
..KKCCCKK..
.KCCMwMEEK.
.KCMwwwwEK.
KCMwwwwwDEK
KCMwwwwDDEK
.KCMwwDDEK.
..KEMwDEK..
...KKEEKK..
.....KEK...
.....KK....
"""]},
    # the Sexton's bone, tumbling end over end: ivory edges, a white heart
    "bone": {9: ["""
.KK......
KwwK.....
KwAAK....
.KAwAK...
..KAwAK..
...KAwAK.
....KAAwK
.....KwwK
......KK.
""", """
......KK.
.....KwwK
....KAAwK
...KAwAK.
..KAwAK..
.KAwAK...
KwAAK....
KwwK.....
.KK......
"""], 11: ["""
.KKK.......
KwwwK......
KwwwAK.....
KwwAwAK....
.KAwwwAK...
..KAwwwAK..
...KAwwwAK.
....KAwAwwK
.....KAwwwK
......KwwwK
.......KKK.
""", """
.......KKK.
......KwwwK
.....KAwwwK
....KAwAwwK
...KAwwwAK.
..KAwwwAK..
.KAwwwAK...
KwwAwAK....
KwwwAK.....
KwwwK......
.KKK.......
"""]},
    # a sound wave: a white ring with an ivory rim, dark inside and out; the two swap (it ripples)
    "ring": {9: ["""
...KKK...
.KKwwwKK.
.KwAAAwK.
KwAKKKAwK
KwAK.KAwK
KwAKKKAwK
.KwAAAwK.
.KKwwwKK.
...KKK...
""", """
...KKK...
.KKAAAKK.
.KAwwwAK.
KAwKKKwAK
KAwK.KwAK
KAwKKKwAK
.KAwwwAK.
.KKAAAKK.
...KKK...
"""], 11: ["""
....KKK....
..KKwwwKK..
.KwwwwwwwK.
.KwAAAAAwK.
KwwAKKKAwwK
KwwAK.KAwwK
KwwAKKKAwwK
.KwAAAAAwK.
.KwwwwwwwK.
..KKwwwKK..
....KKK....
""", """
....KKK....
..KKAAAKK..
.KAAwwwAAK.
.KAwwwwwAK.
KAAwKKKwAAK
KAwwK.KwwAK
KAAwKKKwAAK
.KAwwwwwAK.
.KAAwwwAAK.
..KKAAAKK..
....KKK....
"""]},
    # a hymn-book page with a parchment edge, face on and edge on
    "page": {9: ["""
.KKKKKKK.
KXXXXXXXK
KXwwwwwXK
KXwaaawXK
KXwwwwwXK
KXwaawwXK
KXwwwwwXK
KXXXXXXXK
.KKKKKKK.
""", """
.........
.........
KKKKKKKKK
KXXXXXXXK
KwaaawaaK
KXXXXXXXK
KKKKKKKKK
.........
.........
"""], 11: ["""
.KKKKKKKKK.
KXXXXXXXXXK
KXXwwwwwXXK
KXwwwwwwwXK
KXwaaaawwXK
KXwwwwwwwXK
KXwaaawaaXK
KXwwwwwwwXK
KXXwwwwwXXK
KXXXXXXXXXK
.KKKKKKKKK.
""", """
...........
...........
KKKKKKKKKKK
KXXXXXXXXXK
KXwwwwwwwXK
KwaaaawaaaK
KXwwwwwwwXK
KXXXXXXXXXK
KKKKKKKKKKK
...........
...........
"""]},
    # the Keeper's and the sentries' cogs: white enamel, ivory teeth turning a notch each frame
    "cog": {9: ["""
...XKX...
.KKAwAKK.
.KAwwwaK.
XAwwKwwaX
KwwKKKwaK
XAwwKwaaX
.KaawaaK.
.KKaaaKK.
...XKX...
""", """
...KXK...
.XKAwAKX.
.KAwwwaK.
KAwwKwwaK
XwwKKKwaX
KAwwKwaaK
.KaawaaK.
.XKaaaKX.
...KXK...
"""], 11: ["""
....XKX....
..KKXAXKK..
.KAAwwwAAK.
.KAwwwwwaK.
XXwwwKwwaXX
KAwwKKKwaaK
XXwwwKwaaXX
.KawwwwaaK.
.KaaaaaaaK.
..KKXaXKK..
....XKX....
""", """
....KXK....
..XKAAAKX..
.XXwwwwwXX.
.KAwwwwwaK.
KAwwwKwwaaK
XAwwKKKwaaX
KAwwwKwaaaK
.KawwwwaaK.
.XXaaaaaXX.
..XKaaaKX..
....KXK....
"""]},
}
BIG_BASE = {"K": "#21141b", "w": "#fdf7ed", "A": "#d3bfa9", "X": "#e2b694", "a": "#aa8d7a"}
# shape and colours per shot. The rim colours were picked with design_bullets.py --judge: every pair with
# the player's embers stays >= 30 apart for normal sight, protanopia and deuteranopia.
BIG_TONES = {
    "bullet_purple": ("orb", {"C": "#dc4a7b", "E": "#9b1a0a", "M": "#5f2d56", "D": "#9b1a0a"}),  # pink rim, plum and blood
    "bullet_green": ("orb", {"C": "#4ba747", "E": "#3d734f", "M": "#3e5442", "D": "#2a2a3a"}),   # moss
    "bullet_water": ("orb", {"C": "#72d6ce", "E": "#1f1833", "M": "#302c2b", "D": "#302c2b"}),   # black water, a lit rim
    "bolt_wax": ("wax", {"C": "#f78697", "E": "#9b1a0a", "M": "#62232f", "D": "#9b1a0a"}),       # rose wax
    "bolt_bone": ("bone", {}),
    "bolt_cog": ("cog", {}),
    "bolt_page": ("page", {}),
    "bolt_ring": ("ring", {}),
}
# file suffix -> drawn size: fx/<kind>_f<i> (Normal) and fx/<kind>_lg_f<i> (Large)
SHOT_SETS = {"": 9, "_lg": 11}


def _rows(rows):
    rows = [r.strip() for r in rows.strip().split("\n")]
    assert all(len(r) == len(rows[0]) for r in rows), rows
    return rows


def shot_image(rows, pal=None):
    """A shot drawing (any size) to an image: SHOT_PAL letters, or `pal` (letter -> "#rrggbb")."""
    rows = _rows(rows)
    pal = pal or SHOT_PAL
    im = Image.new("RGBA", (len(rows[0]), len(rows)), CLEAR)
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                px[x, y] = hexc(pal[ch])
    return im


def grow(rows, steps):
    """A 2.0 7 px drawing (SHOT_PAL letters) grown by `steps` px all round, for a shot with no hand-drawn
    9 / 11 px version yet: its old outline and the new pixels inside the new outline take its brightest
    colour (the rim), and a new #21141b outline goes round the outside."""
    rows = _rows(rows)
    lum = lambda ch: sum(hexc(SHOT_PAL[ch])[:3])
    cols = {ch for r in rows for ch in r} - {".", "K", "w"}
    rim = max(cols, key=lum) if cols else "w"
    n = len(rows) + 2 * steps
    g = [["."] * n for _ in range(n)]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                g[y + steps][x + steps] = rim if ch == "K" else ch
    for s in range(steps):
        add = []
        for y in range(n):
            for x in range(n):
                if g[y][x] == "." and any(0 <= y + dy < n and 0 <= x + dx < n and g[y + dy][x + dx] != "."
                                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    add.append((x, y))
        for x, y in add:
            g[y][x] = "K" if s == steps - 1 else rim
    return "\n".join("".join(r) for r in g)


def big_shot_frames(kind, size):
    """The two frames of an enemy shot at 9 or 11 px (hand-drawn, else grown from its 7 px drawing)."""
    if kind in BIG_TONES:
        shape, tones = BIG_TONES[kind]
        pal = dict(BIG_BASE)
        pal.update(tones)
        return [shot_image(f, pal) for f in BIG_SHAPES[shape][size]]
    return [shot_image(grow(f, (size - 7) // 2)) for f in ENEMY_SHOTS[kind]]


def enemy_shot_images(names=None, prefix=""):
    """{"<prefix><kind>[_lg]_f<i>": Image} for the given enemy shots (all of them by default), both sets."""
    out = {}
    for k in names or list(dict.fromkeys(list(ENEMY_SHOTS) + list(BIG_TONES))):
        for suffix, size in SHOT_SETS.items():
            for i, im in enumerate(big_shot_frames(k, size)):
                out["%s%s%s_f%d" % (prefix, k, suffix, i)] = im
    return out


def build_enemy_shots(names=None):
    for n, im in enemy_shot_images(names).items():
        save(im, n + ".png")


def build():
    for i in range(len(SPLATS)):
        save(splat(i), "splat_%d.png" % i)
    for i, g in enumerate(GIBS):
        save(gib(g), "gib_%d.png" % i)
    for i, g in enumerate(GLINT):
        save(glint(g), "glint_f%d.png" % i)
    build_enemy_shots()


# --------------------------------------------------------------------------
# Review: every splat in each runtime material on a 0x72 floor, x8.
# --------------------------------------------------------------------------
RAMPS = {
    "ash": ("#b6cbcf", "#7b8994", "#314152"),
    "goo": ("#4ba747", "#3d734f", "#314152"),
    "blood": ("#c56025", "#8f4029", "#62232f"),
    "red": ("#da4e38", "#9f294e", "#62232f"),
    "wax": ("#fdf7ed", "#e2b694", "#b58057"),
    "pumpkin": ("#ee8e2e", "#c56025", "#8f4029"),
    "ice": ("#72d6ce", "#417089", "#314152"),
    "soot": ("#333333", "#222222", "#111111"),
}


def recolour(im, ramp):
    m = {HI: hexc(ramp[0]), MID: hexc(ramp[1]), LO: hexc(ramp[2])}
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = px[x, y]
            if c in m:
                px[x, y] = m[c]
    return out


def review(d):
    os.makedirs(d, exist_ok=True)
    floor = Image.open(os.path.join(OX72, "floor_1.png")).convert("RGBA")
    sps = [splat(i) for i in range(len(SPLATS))] + [gib(g) for g in GIBS]
    cell = 34
    sheet = Image.new("RGBA", (cell * len(sps), cell * len(RAMPS)), (0, 0, 0, 255))
    for r, (name, ramp) in enumerate(RAMPS.items()):
        for c, s in enumerate(sps):
            tile = Image.new("RGBA", (cell, cell))
            for ty in range(0, cell, 16):
                for tx in range(0, cell, 16):
                    tile.paste(floor, (tx, ty))
            rc = recolour(s, ramp)
            tile.alpha_composite(rc, ((cell - rc.width) // 2, (cell - rc.height) // 2))
            sheet.paste(tile, (c * cell, r * cell))
    sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
    sheet.save(os.path.join(d, "fx2_review.png"))
    print("review ->", os.path.join(d, "fx2_review.png"))


if __name__ == "__main__":
    build()
    print("wrote %d files" % len(OUT))
    if "--review" in sys.argv:
        review(sys.argv[sys.argv.index("--review") + 1])
