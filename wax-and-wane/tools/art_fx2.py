#!/usr/bin/env python3
"""Wax & Wane 2.0 - floor stains, gibs and small juice sprites (assets/art/fx/).

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


def build():
    for i in range(len(SPLATS)):
        save(splat(i), "splat_%d.png" % i)
    for i, g in enumerate(GIBS):
        save(gib(g), "gib_%d.png" % i)
    for i, g in enumerate(GLINT):
        save(glint(g), "glint_f%d.png" % i)


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
