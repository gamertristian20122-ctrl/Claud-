#!/usr/bin/env python3
"""Wax & Wane - THE LONG NIGHT, new areas batch 1 (v2.2 areas stream): THE KITCHEN, THE LIBRARY, THE ATTIC.

    python3 tools/art_areas.py                 writes every file listed below
    python3 tools/art_areas.py --review=<dir>  also writes x3 room previews and x4..x6 contact sheets

Same rules as every other art tool (tools/art_rooms.py, art_decor.py, art_tower.py, art_monsters.py): the 0x72
DungeonTileset II palette only (asserted for every file), a 1 px dark outline round every object and creature,
light from the top-left, flat fills with one shade, no anti-aliasing, no semi-transparent pixels. The only smooth
image is the attic's moonlight texture in areas/attic/light/ (a PointLight2D texture). Everything is drawn from
fixed integer maths, so every run writes the same PNGs.

Each area has its own colours, so the three read apart from each other and from the five older floors at a glance:
  Kitchen  orange brick caps, cream and blue tiled backsplash, terracotta quarry floors, copper and cast iron
  Library  green caps, dark green damask over a walnut dado, green carpet / walnut boards, books everywhere
  Attic    pine caps, plank walls with rafters, pale dusty pine boards, dust sheets, moonlight

Output
  rooms/room_<kitchen|library|attic>(_1|_2).png        backgrounds (RoomDecor.background picks one per room)
  decor/sconce_<theme>_top|side, wall_<theme>_*, side_<theme>, prop_<theme>_*   pieces RoomDecor / Room load by name
  areas/<theme>/floor_*, foot_*                          floor and wall-foot decals
  areas/kitchen/stove_*, pot*, scald_*, flour_*          the stove tops, boiling pots, scalding broth, flour clouds
  areas/library/rail_*, shelfdoor_*                      sliding-shelf rails, the hidden shelf-door
  areas/attic/lantern_*, window_round*, sheet_fly_*      lanterns you light by shooting, the round window, dust sheets
  areas/<theme>/<creature>_<idle|run|atk>_f0..3          two new lodgers per area and the area's guardian
  fx/bolt_pin_f0..1                                      the Dressmaker's Form's pins (enemy shot, UX-02 recipe)
  areas/attic/light/moon_round.png                       moonlight through the round window (smooth light texture)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_rooms as AR      # noqa: E402  room builder, palette check, 0x72 tiles
import art_monsters as AM   # noqa: E402  Canvas, render (outline pass), palette letters
import art_tower as AT      # noqa: E402  rect / line / disc / ring_lit, extra palette letters

ROOT = AR.ROOT
ART = os.path.join(ROOT, "assets", "art")

# extra palette letters (all 0x72 colours) on top of art_monsters' + art_tower's PAL
AM.PAL.update({
    "6": "#5c7a56", "7": "#55a894", "8": "#3c9f9c", "9": "#d44e52", "0": "#9b1a0a", "!": "#550f0a",
    "@": "#1d1218", "%": "#51c43f",
})
PAL = AM.PAL
Canvas = AM.Canvas
render = AM.render
rect, line, disc, ring_lit, to_img = AT.rect, AT.line, AT.disc, AT.ring_lit, AT.to_img

MADE = {}         # relative path under assets/art (no .png) -> image
MADE_LIGHT = {}   # smooth light textures (not palette-checked)
EXTRA_BUILDERS = []   # creature / gimmick builders, run by main() after the rooms and decor
CREATURES = {}        # theme -> creature names drawn for it (review sheets)


def put(name, im):
    MADE[name] = im


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def hexc(c):
    return AR.rgb(c) + (255,)


def hline(cv, x0, x1, y, ch):
    for x in range(x0, x1 + 1):
        cv.put(x, y, ch)


def vline(cv, x, y0, y1, ch):
    for y in range(y0, y1 + 1):
        cv.put(x, y, ch)


def oval(cv, cx, cy, rx, ry, ch):
    """A filled pixel ellipse centred on (cx, cy) (may be .5)."""
    for y in range(int(math.floor(cy - ry - 1)), int(math.ceil(cy + ry + 1)) + 1):
        for x in range(int(math.floor(cx - rx - 1)), int(math.ceil(cx + rx + 1)) + 1):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                cv.put(x, y, ch)


def recolour(cv, src, dst, box=None):
    x0, y0, x1, y1 = box if box else (0, 0, cv.w, cv.h)
    for y in range(max(0, y0), min(cv.h, y1)):
        for x in range(max(0, x0), min(cv.w, x1)):
            if cv.c[y][x] == src:
                cv.c[y][x] = dst


def shade_edges(cv, fill, lit=None, shade=None, bottom=None):
    """Flat 0x72 shading of one fill: lit top / left edge, shaded right edge, darker bottom row."""
    src = cv.copy()
    for y in range(cv.h):
        for x in range(cv.w):
            if src.c[y][x] != fill:
                continue
            if bottom and src.get(x, y + 1) == ".":
                cv.c[y][x] = bottom
            elif shade and src.get(x + 1, y) == ".":
                cv.c[y][x] = shade
            elif lit and (src.get(x, y - 1) == "." or src.get(x - 1, y) == "."):
                cv.c[y][x] = lit


def on_shadow(im, w=None, y=None, col="#21141b"):
    """A 1 px floor shadow line under a prop (like art_tower's long-case clock)."""
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    spx = sh.load()
    yy = im.height - 1 if y is None else y
    for x in range(1, (w or im.width)):
        spx[x, yy] = hexc(col)
    sh.alpha_composite(im)
    return sh


# =========================================================================== rooms
O, S1, S2, S3, S4 = AR.O, AR.S1, AR.S2, AR.S3, AR.S4
FX0, FY0, FX1, FY1 = AR.FX0, AR.FY0, AR.FX1, AR.FY1

AR.THEMES["kitchen"] = dict(wall={O: "#21141b", S1: "#62232f", S2: "#8f4029", S3: "#c56025", S4: "#d8a57d"},
                            floor={}, ring={}, shadow={}, seed=1311)
AR.THEMES["library"] = dict(wall={O: "#1d1218", S1: "#243f4c", S2: "#3e5442", S3: "#3d734f", S4: "#5c7a56"},
                            floor={}, ring={}, shadow={}, seed=1312)
AR.THEMES["attic"] = dict(wall={O: "#21141b", S1: "#3b3332", S2: "#483b3a", S3: "#775c55", S4: "#aa8d7a"},
                          floor={}, ring={}, shadow={}, seed=1313)

# one step darker inside each colour family (the floor's wall vignette and the cast shadow use it twice)
DARK = {
    "#fdf7ed": "#d3bfa9", "#d3bfa9": "#aa8d7a", "#aa8d7a": "#775c55", "#775c55": "#483b3a", "#483b3a": "#3b3332",
    "#3b3332": "#302c2b", "#302c2b": "#2b2929", "#2b2929": "#21141b", "#21141b": "#140c11", "#140c11": "#140c11",
    "#fccba3": "#e2b694", "#e2b694": "#c38d70", "#c38d70": "#8a503e", "#d8a57d": "#b58057", "#b58057": "#8a503e",
    "#8a503e": "#483b3a", "#ffcc68": "#facb3e", "#facb3e": "#ee8e2e", "#ffad3b": "#ee8e2e", "#ee8e2e": "#c56025",
    "#e46e33": "#c56025", "#da4e38": "#8f4029", "#c56025": "#8f4029", "#8f4029": "#62232f", "#62232f": "#38262d",
    "#38262d": "#23151d", "#23151d": "#140c11", "#9f294e": "#62232f", "#dc4a7b": "#9f294e", "#f78697": "#dc4a7b",
    "#d44e52": "#9f294e", "#9b1a0a": "#550f0a", "#550f0a": "#23151d", "#1d1218": "#140c11",
    "#97da3f": "#4ba747", "#51c43f": "#4ba747", "#4ba747": "#3d734f", "#3d734f": "#3e5442", "#5c7a56": "#3e5442",
    "#3e5442": "#243f4c", "#243f4c": "#1f1833", "#55a894": "#49a790", "#49a790": "#3d734f", "#72d6ce": "#49a790",
    "#3c9f9c": "#38607c", "#cae6f5": "#b6cbcf", "#b6cbcf": "#7b8994", "#7b8994": "#545454", "#5698cc": "#417089",
    "#417089": "#38607c", "#38607c": "#243f4c", "#314152": "#2a2a3a", "#323e4f": "#2a2a3a", "#414859": "#323e4f",
    "#2a2a3a": "#1f1833", "#1f1833": "#140c11", "#5956bd": "#5f2d56", "#5f2d56": "#38262d", "#545454": "#494949",
    "#4d4d4d": "#3f3f3f", "#494949": "#3f3f3f", "#3f3f3f": "#333333", "#333333": "#2b2929", "#222222": "#111111",
    "#111111": "#111111",
}


def vignette_maps(floor):
    """(ring, shadow) remaps for every colour a painter left on the floor (AR.build_room applies them)."""
    a = np.array(floor)[FY0:FY1, FX0:FX1].reshape(-1, 4)
    cols = {"#%02x%02x%02x" % tuple(int(v) for v in p[:3]) for p in a if p[3]}
    for c in cols:
        assert c in DARK and DARK[c] in DARK, "no darker step for " + c
    ring = {c: DARK[c] for c in cols}
    shadow = {DARK[c]: DARK[DARK[c]] for c in cols}
    return ring, shadow


def fill_floor(px, col):
    for y in range(FY0, FY1):
        for x in range(FX0, FX1):
            px[x, y] = hexc(col)


def tile_box(px, x0, y0, w, h, fill, lit, grout, chip=None, rng=None):
    """One floor tile: flat fill, lit top + left edge, 1 px grout on the right + bottom."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if not (FX0 <= x < FX1 and FY0 <= y < FY1):
                continue
            c = fill
            if x == x0 + w - 1 or y == y0 + h - 1:
                c = grout
            elif x == x0 or y == y0:
                c = lit
            px[x, y] = hexc(c)
    if chip and rng:
        for _ in range(rng.randrange(0, 3)):
            cx, cy = x0 + rng.randrange(2, w - 3), y0 + rng.randrange(2, h - 3)
            if FX0 <= cx < FX1 and FY0 <= cy < FY1:
                px[cx, cy] = hexc(chip)


# ---------------------------------------------------------------- the Kitchen
def kitchen_quarry(floor, rng):
    """Terracotta quarry tiles laid in running bond (every other row shifted half a tile), a few worn ones."""
    px = floor.load()
    fill_floor(px, "#38262d")
    for r in range(9):
        off = 8 if r % 2 else 0
        for c in range(-1, 16):
            x0, y0 = FX0 + 16 * c + off, FY0 + 16 * r
            worn = rng.random() < 0.16
            tile_box(px, x0, y0, 16, 16, "#8a503e" if worn else "#8f4029", "#c56025" if not worn else "#b58057",
                     "#38262d", "#62232f", rng)
    return vignette_maps(floor)


def kitchen_checker(floor, rng):
    """Terracotta and slate squares (the scullery): a checker on the room grid."""
    px = floor.load()
    for r in range(9):
        for c in range(15):
            x0, y0 = FX0 + 16 * c, FY0 + 16 * r
            if (r + c) % 2 == 0:
                tile_box(px, x0, y0, 16, 16, "#8a503e", "#b58057", "#23151d", "#62232f", rng)
            else:
                tile_box(px, x0, y0, 16, 16, "#483b3a", "#775c55", "#23151d", "#3b3332", rng)
    return vignette_maps(floor)


RUG_RINGS = ["#38262d", "#8f4029", "#d3bfa9", "#417089", "#c56025", "#d3bfa9", "#62232f", "#aa8d7a", "#417089", "#d8a57d"]


def kitchen_flags(floor, rng):
    """Warm stone flags round a braided rag rug in front of the range."""
    px = floor.load()
    fill_floor(px, "#3b3332")
    y = FY0
    rows = [16, 24, 16, 24, 16, 24, 24]
    for h in rows:
        if y >= FY1:
            break
        h = min(h, FY1 - y)
        x = FX0 - rng.randrange(0, 20)
        while x < FX1:
            w = rng.choice([20, 24, 28, 32])
            tile_box(px, x, y, w, h, "#775c55", "#aa8d7a", "#3b3332", "#483b3a", rng)
            x += w
        y += h
    # the rug: concentric braided rings, the outer one a dark rim
    cx, cy, rx, ry = 136.0, 104.0, 37.0, 21.0
    for y in range(int(cy - ry - 2), int(cy + ry + 2)):
        for x in range(int(cx - rx - 2), int(cx + rx + 2)):
            d = math.sqrt(((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2)
            if d <= 1.0:
                band = int((1.0 - d) * ry / 2.0)        # 2 px braids
                col = RUG_RINGS[min(band, len(RUG_RINGS) - 1)]
                if band > 0 and (x + y) % 5 == 0 and col not in ("#38262d",):
                    col = DARK[col]                     # the braid's twist
                px[x, y] = hexc(col)
    return vignette_maps(floor)


def kitchen_face(room):
    """The top wall face (y 16..31): cream tiles over a band of blue-and-white ones."""
    px = room.load()
    for x in range(16, 256):
        for y in range(16, 32):
            i, j = (x - 16) % 8, (y - 16) % 8
            row = (y - 16) // 8
            tile_n = (x - 16) // 8
            if y == 16:
                c = "#775c55"                           # in the cap's shadow
            elif y == 31:
                c = "#483b3a"                           # skirting
            elif i == 7 or j == 7:
                c = "#aa8d7a"                           # grout
            elif row == 1 and tile_n % 2 == 0:
                # a blue-and-white tile: a little cross of four petals
                c = "#cae6f5" if (i == 0 or j == 0) else "#fdf7ed"
                if (i, j) in ((3, 2), (3, 4), (2, 3), (4, 3)):
                    c = "#5698cc"
                elif (i, j) == (3, 3):
                    c = "#417089"
                elif (i, j) in ((1, 1), (5, 1), (1, 5), (5, 5)):
                    c = "#5698cc"
            else:
                c = "#fdf7ed" if (i == 0 or j == 0) else "#d3bfa9"
            px[x, y] = hexc(c)


# ---------------------------------------------------------------- the Library
def _boards_v(px, rng, fill="#38262d", hi="#483b3a", gap="#21141b", grain="#302c2b", w=8):
    """Walnut boards running north-south, joints staggered."""
    for bx in range(FX0, FX1, w):
        y = FY0 - rng.randrange(0, 48)
        while y < FY1:
            ln = rng.randrange(36, 90)
            a, b = max(y, FY0), min(y + ln, FY1)
            for yy in range(a, b):
                for xx in range(bx, bx + w):
                    c = fill
                    if xx == bx + w - 1 or yy == b - 1:
                        c = gap
                    elif xx == bx or yy == a:
                        c = hi
                    px[xx, yy] = hexc(c)
            for _ in range((b - a) // 14):
                gx = rng.randrange(bx + 2, bx + w - 2)
                gy = rng.randrange(a + 2, max(a + 3, b - 5))
                for k in range(rng.randrange(2, 5)):
                    if gy + k < b - 1:
                        px[gx, gy + k] = hexc(grain)
            y += ln


def _boards_h(px, rng, fill, hi, gap, grain, nail, h=8, dust=None):
    """Boards running east-west (the attic), joints staggered, a nail at each end."""
    for by in range(FY0, FY1, h):
        x = FX0 - rng.randrange(0, 60)
        while x < FX1:
            ln = rng.randrange(40, 110)
            a, b = max(x, FX0), min(x + ln, FX1)
            for xx in range(a, b):
                for yy in range(by, min(by + h, FY1)):
                    c = fill
                    if yy == by + h - 1 or xx == b - 1:
                        c = gap
                    elif yy == by or xx == a:
                        c = hi
                    px[xx, yy] = hexc(c)
            for _ in range((b - a) // 16):
                gx = rng.randrange(a + 2, max(a + 3, b - 6))
                gy = rng.randrange(by + 2, by + h - 2)
                for k in range(rng.randrange(2, 6)):
                    if gx + k < b - 1:
                        px[gx + k, gy] = hexc(grain)
            if b - a > 10:
                for nx in (a + 2, b - 3):
                    px[nx, by + 3] = hexc(nail)
            x += ln


def library_carpet(floor, rng):
    """A green carpet with a wine border, laid on walnut boards that show along the walls."""
    px = floor.load()
    _boards_v(px, rng)
    x0, y0, x1, y1 = FX0 + 6, FY0 + 6, FX1 - 6, FY1 - 6
    for y in range(y0, y1):
        for x in range(x0, x1):
            e = min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y)
            if e == 0:
                c = "#21141b"
            elif e <= 5:
                c = "#62232f"
                if e == 2:
                    c = "#c56025"                       # a gold line in the border
                elif e in (4,) and (x + y) % 4 == 0:
                    c = "#9f294e"
            elif e == 6:
                c = "#c56025"
            else:
                # the field: a lattice of darker lines with a lit dot in every diamond
                u, v = (x - x0 + y - y0) % 12, (x - x0 - (y - y0)) % 12
                c = "#3e5442"
                if u == 0 or v == 0:
                    c = "#243f4c"
                elif u == 6 and v == 6:
                    c = "#5c7a56"
            px[x, y] = hexc(c)
    return vignette_maps(floor)


def library_runner(floor, rng):
    """Walnut boards with a long green runner from the left door to the right door."""
    px = floor.load()
    _boards_v(px, rng)
    ry0, ry1 = FY0 + 16 * 3 + 2, FY0 + 16 * 6 - 2           # rows 3..5
    rx0, rx1 = FX0 + 18, FX1 - 18                            # it stops short of the walls, fringed
    for y in range(ry0, ry1):
        for x in range(rx0 - 2, rx1 + 2):
            e = min(y - ry0, ry1 - 1 - y)
            ex = min(x - rx0, rx1 - 1 - x)
            if ex < 0:
                c = "#d3bfa9" if (y - ry0) % 2 == 0 and 1 <= e else None   # fringe
            elif e == 0 or ex == 0:
                c = "#21141b"
            elif e == 1 or ex == 1:
                c = "#c56025"
            else:
                c = "#3e5442"
                u, v = (x - rx0 + y - ry0) % 10, (x - rx0 - (y - ry0)) % 10
                if u == 0 or v == 0:
                    c = "#3d734f"
                elif u == 5 and v == 5:
                    c = "#5c7a56"
            if c:
                px[x, y] = hexc(c)
    return vignette_maps(floor)


def library_compass(floor, rng):
    """Walnut boards and a brass-and-green compass star inlaid in the middle of the reading room."""
    px = floor.load()
    _boards_v(px, rng)
    cx, cy = 136, 104
    cv = Canvas(72, 72)
    c0 = 36
    ring_lit(cv, c0, c0, 30.5, 33.5, "c", "o", "R", "y")
    disc(cv, c0, c0, 30.5, "J")
    for k in range(8):                                   # an eight-point star, long points on the axes
        a = k * math.pi / 4
        L = 29 if k % 2 == 0 else 18
        for s in (-1, 1):
            tip = (c0 + math.sin(a) * L, c0 - math.cos(a) * L)
            side = (c0 + math.sin(a + s * math.pi / 8) * 7, c0 - math.cos(a + s * math.pi / 8) * 7)
            # fill the triangle centre-side-tip
            for t in range(0, 41):
                f = t / 40.0
                pxx, pyy = side[0] + (tip[0] - side[0]) * f, side[1] + (tip[1] - side[1]) * f
                line(cv, c0, c0, int(round(pxx - 0.5)), int(round(pyy - 0.5)),
                     ("G" if s < 0 else "6") if k % 2 == 0 else ("c" if s < 0 else "o"))
    disc(cv, c0, c0, 3.5, "y")
    disc(cv, c0, c0, 1.5, "R")
    im = to_img(cv)
    floor.alpha_composite(im, (cx - c0, cy - c0))
    return vignette_maps(floor)


def library_face(room):
    """Dark green damask over a walnut dado rail."""
    px = room.load()
    for x in range(16, 256):
        for y in range(16, 32):
            i = (x - 16) % 8
            if y == 16:
                c = "#1d1218"
            elif y <= 26:
                j = (y - 17) % 8
                c = "#3e5442"
                if (i, j) in ((3, 1), (2, 2), (4, 2), (3, 3)) or (((i + 4) % 8, (j + 4) % 8) in ((3, 1), (2, 2), (4, 2), (3, 3)) and y <= 24):
                    c = "#243f4c"
                if (i, j) == (3, 2):
                    c = "#5c7a56"
            elif y == 27:
                c = "#b58057"
            elif y == 28:
                c = "#8a503e"
            elif y == 31:
                c = "#1d1218"
            else:
                c = "#38262d" if i not in (0,) else "#483b3a"
            px[x, y] = hexc(c)


# ---------------------------------------------------------------- the Attic
PINE = dict(fill="#775c55", hi="#aa8d7a", gap="#3b3332", grain="#483b3a", nail="#302c2b")


def _dust(px, rng, n, spots):
    """Pale dust settled in flat drifts against the boards (and a trail of small boot prints)."""
    for _ in range(n):
        cx, cy = rng.randrange(FX0 + 14, FX1 - 14), rng.randrange(FY0 + 12, FY1 - 12)
        rx, ry = rng.randrange(7, 14), rng.randrange(3, 5)
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                d = ((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2
                # a wavy edge from fixed maths, so the drift is a shape and not noise
                if d <= 1.0 - 0.18 * (((x * 3 + y * 5) % 4) == 0) and FX0 <= x < FX1 and FY0 <= y < FY1:
                    px[x, y] = hexc("#aa8d7a")
        for k in range(3):
            x, y = cx - rx // 2 + k * rx // 2, cy - (1 if k % 2 else 0)
            if FX0 <= x < FX1 and FY0 <= y < FY1:
                px[x, y] = hexc("#d3bfa9")
    for (sx, sy, n2) in spots:                           # small boot prints across the dust
        for k in range(n2):
            x, y = sx + 9 * k, sy + (3 if k % 2 else 0)
            for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2), (0, 4), (1, 4)):
                if FX0 <= x + dx < FX1 and FY0 <= y + dy < FY1:
                    px[x + dx, y + dy] = hexc("#483b3a")


def attic_boards(floor, rng):
    px = floor.load()
    _boards_h(px, rng, **PINE)
    _dust(px, rng, 7, [(48, 120, 6)])
    return vignette_maps(floor)


def attic_hatch(floor, rng):
    """Boards, a closed loft hatch with its ring pull, and straw from a split mattress."""
    px = floor.load()
    _boards_h(px, rng, **PINE)
    _dust(px, rng, 4, [])
    hx, hy = FX0 + 16 * 10, FY0 + 16 * 5
    for y in range(hy, hy + 24):
        for x in range(hx, hx + 24):
            e = min(x - hx, hx + 23 - x, y - hy, hy + 23 - y)
            c = "#21141b" if e == 0 else ("#3b3332" if e == 1 else ("#483b3a" if (x - hx) % 6 == 1 else "#775c55"))
            if e == 2 and (x - hx in (2,) or y - hy in (2,)):
                c = "#aa8d7a"
            px[x, y] = hexc(c)
    for (x, y) in ((hx + 11, hy + 9), (hx + 12, hy + 9), (hx + 10, hy + 10), (hx + 13, hy + 10), (hx + 10, hy + 11),
                   (hx + 13, hy + 11), (hx + 11, hy + 12), (hx + 12, hy + 12)):
        px[x, y] = hexc("#3f3f3f")
    for (x, y) in ((hx + 11, hy + 13), (hx + 12, hy + 13)):
        px[x, y] = hexc("#545454")
    for (cx, cy) in ((FX0 + 40, FY0 + 34), (FX0 + 58, FY0 + 44), (FX0 + 30, FY0 + 50)):   # tufts of straw
        for k in range(7):
            a = -0.9 + 0.3 * k
            for r in range(1, 5 + (k % 3)):
                x, y = int(round(cx + math.cos(a) * r)), int(round(cy + math.sin(a) * r * 0.5))
                if FX0 <= x < FX1 and FY0 <= y < FY1:
                    px[x, y] = hexc("#d8a57d" if (k + r) % 3 else "#b58057")
    return vignette_maps(floor)


PATTERNS = [  # dressmaker's tissue patterns: polygons (x, y) in px, offsets added per piece
    [(0, 0), (22, 2), (26, 18), (14, 30), (2, 24)],
    [(0, 6), (12, 0), (30, 4), (28, 16), (6, 18)],
    [(2, 0), (18, 0), (20, 26), (0, 22)],
]


def _poly_inside(pts, x, y):
    inside = False
    n = len(pts)
    for i in range(n):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xi:
                inside = not inside
    return inside


def attic_patterns(floor, rng):
    """Boards with a dressmaker's tissue patterns laid out: pale paper, dashed cutting lines, notches."""
    px = floor.load()
    _boards_h(px, rng, **PINE)
    _dust(px, rng, 3, [])
    spots = [(40, 50, 0), (150, 60, 1), (90, 120, 2), (190, 118, 0)]
    for (ox, oy, k) in spots:
        pts = [(ox + FX0 + x, oy + FY0 + y) for (x, y) in PATTERNS[k]]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            for x in range(min(xs), max(xs) + 1):
                if not (FX0 <= x < FX1 and FY0 <= y < FY1):
                    continue
                if _poly_inside(pts, x + 0.5, y + 0.5):
                    edge = not all(_poly_inside(pts, x + 0.5 + dx, y + 0.5 + dy)
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    inner = not all(_poly_inside(pts, x + 0.5 + dx * 3, y + 0.5 + dy * 3)
                                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    c = "#d3bfa9"
                    if edge:
                        c = "#aa8d7a"
                    elif inner and (x + y) % 3 != 0:
                        c = "#8a503e"                    # the dashed cutting line
                    px[x, y] = hexc(c)
    return vignette_maps(floor)


def attic_face(room):
    """Pine wall planks under the roof, a dark rafter post every 48 px with a brace."""
    px = room.load()
    for x in range(16, 256):
        for y in range(16, 32):
            if y == 16 or y == 31:
                c = "#21141b"
            else:
                b = (y - 17) % 7
                c = "#483b3a"
                if b == 0:
                    c = "#775c55"
                elif b == 6:
                    c = "#302c2b"
                elif (x * 7 + y * 3) % 23 == 0:
                    c = "#3b3332"
            rx = (x - 16) % 48
            if 20 <= rx <= 25 and 16 < y < 31:
                c = "#302c2b" if rx > 20 else "#3b3332"
                if rx == 25:
                    c = "#21141b"
                if y in (19, 27) and rx == 22:
                    c = "#545454"                       # nails
            px[x, y] = hexc(c)


ROOM_VARIANTS = {
    "kitchen": [kitchen_quarry, kitchen_checker, kitchen_flags],
    "library": [library_carpet, library_runner, library_compass],
    "attic": [attic_boards, attic_hatch, attic_patterns],
}
FACES = {"kitchen": kitchen_face, "library": library_face, "attic": attic_face}


def build_rooms():
    for th, painters in ROOM_VARIANTS.items():
        for i, painter in enumerate(painters):
            AR.FLOOR_VARIANTS[th] = [painter]
            room = AR.build_room(th, variant=1)
            FACES[th](room)
            put("rooms/room_%s%s" % (th, "" if i == 0 else "_%d" % i), room)


# =========================================================================== wall lights
def build_sconces():
    # Kitchen: a brass oil lamp with a glass chimney on a wall bracket (flame "glass" at (8, 9))
    cv = Canvas(16, 16)
    rect(cv, 3, 12, 3, 2, "R")                 # bracket plate
    line(cv, 5, 12, 7, 11, "c")
    rect(cv, 6, 11, 5, 2, "c")                 # the font (oil reservoir)
    rect(cv, 6, 11, 5, 1, "o")
    rect(cv, 7, 13, 3, 1, "R")
    rect(cv, 6, 4, 5, 7, "S")                  # glass chimney
    rect(cv, 7, 5, 3, 5, "1")
    rect(cv, 6, 4, 1, 7, "h")
    rect(cv, 7, 3, 3, 1, "i")
    put("decor/sconce_kitchen_top", render(cv))
    cv = Canvas(8, 16)
    rect(cv, 0, 1, 1, 13, "R")
    line(cv, 1, 11, 2, 10, "c")
    rect(cv, 1, 10, 5, 2, "c")
    rect(cv, 1, 10, 5, 1, "o")
    rect(cv, 2, 12, 3, 1, "R")
    rect(cv, 1, 3, 5, 7, "S")
    rect(cv, 2, 4, 3, 5, "1")
    rect(cv, 1, 3, 1, 7, "h")
    rect(cv, 2, 2, 3, 1, "i")
    put("decor/sconce_kitchen_side", render(cv))
    # Library: a reading lamp: brass arm, green glass shade, flame "candle" under the shade at (8, 10)
    cv = Canvas(16, 16)
    rect(cv, 7, 12, 3, 3, "c")
    rect(cv, 7, 12, 1, 3, "o")
    line(cv, 8, 12, 8, 11, "R")
    rect(cv, 4, 5, 9, 3, "G")                  # the shade
    rect(cv, 5, 4, 7, 1, "G")
    rect(cv, 6, 3, 5, 1, "6")
    rect(cv, 4, 5, 9, 1, "6")
    rect(cv, 4, 7, 9, 1, "V")
    rect(cv, 7, 8, 3, 3, "1")                  # where the flame shows
    put("decor/sconce_library_top", render(cv))
    cv = Canvas(8, 16)
    rect(cv, 0, 2, 1, 12, "R")
    line(cv, 1, 9, 3, 8, "c")
    rect(cv, 1, 3, 6, 3, "G")
    rect(cv, 2, 2, 4, 1, "6")
    rect(cv, 1, 3, 6, 1, "6")
    rect(cv, 1, 5, 6, 1, "V")
    rect(cv, 3, 6, 2, 3, "1")
    put("decor/sconce_library_side", render(cv))
    # Attic: a tin candle holder on a nail (flame "candle" at (8, 8))
    cv = Canvas(16, 16)
    rect(cv, 7, 3, 2, 1, "H")
    rect(cv, 6, 9, 5, 1, "i")
    rect(cv, 5, 10, 7, 2, "H")
    rect(cv, 5, 10, 7, 1, "i")
    rect(cv, 7, 8, 3, 2, "w")                  # the stub
    rect(cv, 12, 9, 2, 2, "H")                 # the ring handle
    put("decor/sconce_attic_top", render(cv))
    cv = Canvas(8, 16)
    rect(cv, 0, 4, 1, 9, "H")
    rect(cv, 1, 10, 5, 2, "H")
    rect(cv, 1, 10, 5, 1, "i")
    rect(cv, 2, 8, 3, 2, "w")
    put("decor/sconce_attic_side", render(cv))


# flame spots in the mounts above (RoomDecor.SCONCE uses the same numbers)
SCONCE_SPOTS = {"kitchen": ((8, 9), (3, 8)), "library": ((8, 10), (3, 8)), "attic": ((8, 8), (3, 8))}


# =========================================================================== wall pieces, side pieces
SPINES = [("p", "m"), ("G", "V"), ("B", "s"), ("F", "R"), ("A", "a"), ("v", "@"), ("c", "R"), ("6", "V"), ("D", "F")]


def books_row(cv, x0, x1, y_top, y_bot, rng, lean=False):
    """Book spines standing on a shelf from x0..x1, tops between y_top and y_top+2, bottoms at y_bot."""
    x = x0
    while x <= x1:
        w = rng.choice([2, 2, 3])
        if x + w - 1 > x1:
            w = x1 - x + 1
            if w < 1:
                break
        fill, sh = SPINES[rng.randrange(len(SPINES))]
        top = y_top + rng.randrange(0, 3)
        rect(cv, x, top, w, y_bot - top + 1, fill)
        vline(cv, x + w - 1, top, y_bot, sh) if w > 1 else None
        if rng.random() < 0.45 and y_bot - top >= 3:
            hline(cv, x, x + w - 2 if w > 1 else x, top + 1, "y")       # a gilt band
        x += w + (1 if rng.random() < 0.18 else 0)


def build_wall_pieces():
    # ------------------------------------------------ Kitchen
    cv = Canvas(32, 16)                      # copper pans on a rail
    hline(cv, 1, 30, 1, "H")
    hline(cv, 1, 30, 2, "I")
    for x in (2, 29):
        rect(cv, x, 0, 1, 4, "3")
    for (x, r, top) in ((6, 4.5, 4), (16, 5.5, 3), (26, 3.5, 5)):
        vline(cv, x, 3, top + 2, "H")                    # hook
        rect(cv, x, top + 2, 1, 3, "J")                 # handle
        cy = top + 5 + r                                 # the flat copper bottom of a hanging pan:
        disc(cv, x + 0.5, cy, r, "c")                    # a lit rim, a pressed ring, one glint
        ring_lit(cv, x + 0.5, cy, r - 1.0, r, "c", "o", "R")
        if r > 4:
            ring_lit(cv, x + 0.5, cy, r * 0.45, r * 0.45 + 1.0, "R", "R", "o")
        cv.put(int(x - r * 0.4), int(cy - r * 0.45), "e")
    put("decor/wall_kitchen_pans", render(cv))
    cv = Canvas(32, 16)                      # a plate rack, blue-and-white plates on edge
    rect(cv, 1, 12, 30, 2, "F")
    hline(cv, 1, 30, 12, "f")
    rect(cv, 1, 3, 30, 1, "F")
    for x in (1, 30):
        rect(cv, x, 3, 1, 11, "R")
    for i, x in enumerate((6, 12, 19, 25)):
        disc(cv, x + 0.5, 8.0, 4.2, "w")
        ring_lit(cv, x + 0.5, 8.0, 2.9, 4.2, "b", "h", "B")
        disc(cv, x + 0.5, 8.0, 1.2, "b" if i % 2 else "B")
    for x in range(3, 30, 3):
        cv.put(x, 4, "f")
    put("decor/wall_kitchen_plates", render(cv))
    cv = Canvas(16, 16)                      # ladle, whisk and spoon on a little rail
    hline(cv, 1, 14, 1, "H")
    vline(cv, 4, 2, 10, "S")
    oval(cv, 4.5, 12.5, 2.4, 1.9, "i")
    oval(cv, 4.0, 12.0, 1.3, 1.0, "S")
    vline(cv, 8, 2, 7, "J")
    for k, yy in enumerate(range(8, 15)):
        w = (0, 1, 2, 2, 2, 1, 0)[k]
        cv.put(8 - w, yy, "S")
        cv.put(8 + w, yy, "i")
    cv.put(8, 14, "S")
    vline(cv, 12, 2, 9, "D")
    oval(cv, 12.5, 11.5, 1.8, 2.2, "d")
    put("decor/wall_kitchen_ladles", render(cv))
    cv = Canvas(16, 16)                      # a string of onions and a garlic bulb
    cv.put(8, 0, "H")
    vline(cv, 8, 1, 13, "D")
    for k, (dx, y, ch, hi) in enumerate(((-2, 4, "d", "X"), (2, 6, "D", "d"), (-2, 9, "w", "A"), (2, 11, "d", "X"), (-1, 13, "D", "d"))):
        oval(cv, 8 + dx + 0.5, y + 0.5, 2.2, 2.0, ch)
        cv.put(8 + dx - 1, y - 1, hi)
    put("decor/wall_kitchen_onions", render(cv))
    cv = Canvas(32, 16)                      # spice shelf
    rect(cv, 1, 11, 30, 2, "F")
    hline(cv, 1, 30, 11, "f")
    for x in (4, 27):
        rect(cv, x, 13, 2, 2, "R")
    for (x, w, h, ch) in ((3, 4, 6, "r"), (8, 5, 7, "G"), (14, 4, 5, "D"), (19, 5, 7, "y"), (25, 4, 6, "R")):
        rect(cv, x, 11 - h, w, h, "S")
        rect(cv, x + 1, 11 - h + 2, w - 2, h - 2, ch)
        vline(cv, x, 11 - h, 10, "h")
        rect(cv, x, 11 - h - 1, w, 1, "c" if x % 2 else "H")
    put("decor/wall_kitchen_spices", render(cv))
    cv = Canvas(16, 16)                      # knife board
    rect(cv, 2, 2, 12, 12, "F")
    hline(cv, 2, 13, 2, "f")
    vline(cv, 2, 2, 13, "f")
    rect(cv, 4, 4, 4, 7, "S")                # cleaver
    vline(cv, 4, 4, 10, "h")
    hline(cv, 4, 7, 10, "i")
    rect(cv, 5, 11, 2, 3, "J")
    vline(cv, 10, 3, 9, "S")                 # knife
    vline(cv, 11, 4, 9, "i")
    rect(cv, 10, 10, 2, 3, "J")
    put("decor/wall_kitchen_knives", render(cv))
    cv = Canvas(8, 16)                       # side: a dish cloth on a hook
    rect(cv, 0, 1, 2, 1, "H")
    for y in range(2, 13):
        for x in range(1, 6):
            cv.put(x, y, "r" if ((x - 1) // 2 + (y - 2) // 2) % 2 == 0 else "w")
    vline(cv, 1, 2, 12, "A")
    for x in range(1, 6):
        cv.put(x, 13, "a" if x % 2 else ".")
    put("decor/side_kitchen", render(cv))
    # ------------------------------------------------ Library
    for name, seed in (("wall_library_books", 7), ("wall_library_books_b", 19)):
        rng = random.Random(seed)
        cv = Canvas(32, 16)
        rect(cv, 0, 0, 32, 16, "J")
        rect(cv, 1, 1, 30, 6, "1")
        rect(cv, 1, 8, 30, 6, "1")
        hline(cv, 0, 31, 0, "j")
        hline(cv, 1, 30, 7, "j")
        hline(cv, 1, 30, 14, "j")
        books_row(cv, 1, 30, 1, 6, rng)
        books_row(cv, 1, 30, 8, 13, rng)
        if seed == 19:                       # a leaning book and a gap on the lower shelf
            rect(cv, 20, 8, 6, 6, "1")
            for k in range(5):
                cv.put(21 + k, 13 - k, "p")
                cv.put(22 + k, 13 - k, "m")
        vline(cv, 0, 0, 15, "j")
        put("decor/" + name, render(cv))
    rng = random.Random(23)
    cv = Canvas(16, 16)
    rect(cv, 1, 0, 14, 16, "J")
    rect(cv, 2, 1, 12, 6, "1")
    rect(cv, 2, 8, 12, 6, "1")
    hline(cv, 1, 14, 0, "j")
    hline(cv, 2, 13, 7, "j")
    hline(cv, 2, 13, 14, "j")
    books_row(cv, 2, 13, 1, 6, rng)
    books_row(cv, 2, 13, 8, 13, rng)
    put("decor/wall_library_narrow", render(cv))
    cv = Canvas(32, 16)                      # a gilt-framed portrait of a stern reader
    rect(cv, 6, 0, 20, 16, "c")
    rect(cv, 6, 0, 20, 1, "y")
    rect(cv, 6, 0, 1, 16, "y")
    rect(cv, 25, 0, 1, 16, "R")
    rect(cv, 6, 15, 20, 1, "R")
    rect(cv, 8, 2, 16, 12, "2")
    oval(cv, 16, 7.5, 3.2, 4.0, "a")
    oval(cv, 15.5, 7.0, 2.4, 3.2, "A")
    rect(cv, 14, 7, 1, 1, "1")
    rect(cv, 17, 7, 1, 1, "1")
    hline(cv, 13, 18, 6, "i")               # spectacles' bar
    hline(cv, 15, 17, 10, "5")
    rect(cv, 11, 12, 10, 2, "1")
    rect(cv, 15, 11, 2, 2, "w")
    put("decor/wall_library_portrait", render(cv))
    cv = Canvas(16, 16)                      # a framed chart of the house's grounds
    rect(cv, 1, 1, 14, 14, "F")
    hline(cv, 1, 14, 1, "f")
    vline(cv, 1, 1, 14, "f")
    rect(cv, 3, 3, 10, 10, "X")
    for (x, y) in ((4, 5), (5, 4), (6, 4), (7, 5), (8, 5), (9, 6), (9, 7), (8, 8), (6, 8), (5, 9), (4, 10)):
        cv.put(x, y, "G")
    for (x, y) in ((10, 10), (11, 11), (11, 9), (12, 4)):
        cv.put(x, y, "B")
    cv.put(11, 4, "r")
    put("decor/wall_library_map", render(cv))
    rng = random.Random(31)
    cv = Canvas(8, 16)                       # side: a bracket shelf of books
    rect(cv, 0, 10, 7, 1, "F")
    rect(cv, 0, 11, 2, 3, "R")
    books_row(cv, 1, 6, 4, 9, rng)
    put("decor/side_library", render(cv))
    # ------------------------------------------------ Attic
    cv = Canvas(16, 16)                      # a straw hat and a striped scarf on a peg
    rect(cv, 7, 0, 2, 3, "D")
    oval(cv, 8, 5.5, 6.6, 2.0, "d")          # the brim
    oval(cv, 8, 3.8, 3.2, 2.2, "D")          # the crown
    hline(cv, 5, 11, 5, "q")                 # its ribbon
    hline(cv, 3, 12, 6, "X")
    for k, y in enumerate(range(7, 16)):     # the scarf hanging down from under the brim
        cv.put(5 + (k // 4), y, "b" if (y // 2) % 2 else "w")
        cv.put(6 + (k // 4), y, "B" if (y // 2) % 2 else "A")
    put("decor/wall_attic_coat", render(cv))
    cv = Canvas(16, 16)                      # a picture hanging askew
    line(cv, 8, 0, 4, 4, "H")
    line(cv, 8, 0, 12, 3, "H")
    for k in range(10):                      # a frame tilted a little: rows shift every 4 px
        sh = k // 4
        for x in range(2, 14):
            cv.put(x + sh - 1, 4 + k, "F" if k in (0, 9) or x in (2, 13) else ("s" if k < 5 else "G"))
    for k in range(10):
        cv.put(2 + k // 4 - 1, 4 + k, "f")
    put("decor/wall_attic_frame", render(cv))
    cv = Canvas(16, 16)                      # dried lavender hanging head down
    cv.put(8, 0, "H")
    rect(cv, 7, 1, 3, 2, "D")
    for k, x in enumerate((5, 7, 9, 11, 6, 10)):
        top = 3 + (k % 2)
        vline(cv, x, top, top + 5, "6")
        oval(cv, x + 0.5, top + 8.0, 1.2, 2.6, "n" if k % 3 else "v")
    put("decor/wall_attic_lavender", render(cv))
    cv = Canvas(32, 16)                      # a shelf of keepsakes: a doll, a hat box, jars
    rect(cv, 1, 12, 30, 2, "4")
    hline(cv, 1, 30, 12, "5")
    for x in (3, 28):
        rect(cv, x, 14, 2, 2, "u")
    oval(cv, 6.5, 6.5, 2.2, 2.2, "w")        # the doll's head
    cv.put(5, 6, "1")
    cv.put(7, 6, "1")
    rect(cv, 4, 2, 5, 3, "D")                # hair
    rect(cv, 4, 9, 6, 3, "q")
    rect(cv, 4, 9, 1, 3, "P")
    rect(cv, 12, 5, 9, 7, "B")               # hat box
    rect(cv, 11, 4, 11, 2, "b")
    hline(cv, 11, 21, 4, "h")
    rect(cv, 15, 4, 2, 8, "q")
    for (x, h) in ((24, 6), (27, 4)):
        rect(cv, x, 12 - h, 3, h, "S")
        rect(cv, x, 11 - h, 3, 1, "H")
        cv.put(x, 12 - h + 1, "h")
    put("decor/wall_attic_shelf", render(cv))
    cv = Canvas(8, 16)                       # side: a coil of rope on a peg
    rect(cv, 0, 2, 3, 1, "D")
    ring_lit(cv, 3.5, 8.5, 1.5, 3.6, "D", "d", "F")
    cv.put(3, 12, "D")
    vline(cv, 4, 12, 15, "D")
    put("decor/side_attic", render(cv))


# =========================================================================== floor and wall-foot decals
def build_floor_decals():
    # Kitchen
    cv = Canvas(14, 8)                       # spilt flour (no outline: it is dust)
    for (x, y, w) in ((4, 1, 5), (2, 2, 9), (1, 3, 12), (2, 4, 10), (3, 5, 7), (6, 6, 3)):
        hline(cv, x, x + w - 1, y, "A")
    for (x, y) in ((5, 2), (8, 3), (4, 4), (10, 3), (12, 1), (0, 6)):
        cv.put(x, y, "w")
    put("areas/kitchen/floor_flour", to_img(cv))
    cv = Canvas(12, 8)                       # spilt peas
    for (x, y) in ((1, 2), (4, 1), (6, 4), (9, 2), (3, 5), (8, 6)):
        rect(cv, x, y, 2, 1, "g")
        cv.put(x, y + 1, "G")
        cv.put(x + 1, y + 1, "G")
    put("areas/kitchen/floor_peas", to_img(cv))
    cv = Canvas(13, 6)                       # a dropped wooden spoon
    hline(cv, 1, 7, 3, "D")
    hline(cv, 1, 7, 2, "d")
    oval(cv, 9.5, 2.5, 2.4, 1.8, "d")
    cv.put(9, 3, "D")
    put("areas/kitchen/floor_spoon", render(cv))
    cv = Canvas(13, 8)                       # shards of a blue-and-white plate
    for pts in (((1, 1), (5, 1), (3, 4)), ((6, 3), (10, 2), (9, 6)), ((2, 5), (5, 6), (3, 7))):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            for x in range(min(xs), max(xs) + 1):
                if _poly_inside(pts, x + 0.5, y + 0.5) or (x, y) in pts:
                    cv.put(x, y, "w")
        cv.put(pts[0][0], pts[0][1], "b")
        cv.put(pts[1][0], pts[1][1], "B")
    put("areas/kitchen/floor_shards", render(cv))
    cv = Canvas(12, 6)                       # dishwater
    for (x, y, w) in ((3, 1, 6), (1, 2, 10), (2, 3, 9), (4, 4, 5)):
        hline(cv, x, x + w - 1, y, "B")
    hline(cv, 3, 6, 2, "b")
    cv.put(4, 1, "h")
    put("areas/kitchen/floor_puddle", to_img(cv))
    cv = Canvas(14, 14)                      # foot: a flour sack slumped on the wall
    oval(cv, 7, 9.5, 5.5, 4.5, "A")
    rect(cv, 5, 2, 4, 4, "A")
    rect(cv, 5, 4, 4, 1, "F")
    rect(cv, 6, 1, 2, 1, "a")
    shade_edges(cv, "A", "w", "a", "a")
    rect(cv, 4, 9, 6, 1, "a")
    put("areas/kitchen/foot_sack", render(cv))
    cv = Canvas(14, 11)                      # foot: a basket of potatoes
    rect(cv, 1, 4, 12, 6, "D")
    for x in range(1, 13):
        for y in range(4, 10):
            if (x + y) % 3 == 0:
                cv.put(x, y, "F")
    hline(cv, 1, 12, 4, "d")
    for (x, y) in ((3, 2), (6, 1), (9, 2), (5, 3), (8, 3)):
        oval(cv, x + 0.5, y + 0.5, 1.6, 1.3, "d")
        cv.put(x, y, "x")
    put("areas/kitchen/foot_basket", render(cv))
    # Library
    cv = Canvas(15, 9)                       # an open book, pages up
    rect(cv, 1, 1, 13, 7, "p")
    rect(cv, 2, 1, 5, 6, "w")
    rect(cv, 8, 1, 5, 6, "A")
    vline(cv, 7, 1, 6, "a")
    for y in (2, 4):
        hline(cv, 3, 5, y, "a")
        hline(cv, 9, 11, y, "a")
    put("areas/library/floor_book", render(cv))
    cv = Canvas(15, 10)                      # loose pages
    for (x, y, w, h) in ((1, 1, 5, 6), (6, 3, 6, 5), (3, 6, 4, 3)):
        rect(cv, x, y, w, h, "w")
        hline(cv, x + 1, x + w - 2, y + 1, "a")
        hline(cv, x + 1, x + w - 3, y + 3, "a")
        vline(cv, x + w - 1, y, y + h - 1, "A")
    put("areas/library/floor_pages", render(cv))
    cv = Canvas(13, 11)                      # a stack of three books
    for k, (fill, sh) in enumerate((("B", "s"), ("p", "m"), ("G", "V"))):
        y = 7 - 3 * k
        rect(cv, 1 + k, y, 10, 3, fill)
        hline(cv, 1 + k, 10 + k, y + 2, sh)
        vline(cv, 10 + k, y, y + 2, "A")
        cv.put(2 + k, y, "y")
    put("areas/library/floor_stack", render(cv))
    cv = Canvas(12, 7)                       # spilt ink
    for (x, y, w) in ((2, 1, 5), (1, 2, 9), (2, 3, 10), (4, 4, 6), (7, 5, 3)):
        hline(cv, x, x + w - 1, y, "@")
    hline(cv, 3, 5, 2, "s")
    put("areas/library/floor_ink", to_img(cv))
    cv = Canvas(12, 6)                       # a dropped quill
    line(cv, 1, 4, 10, 1, "w")
    line(cv, 2, 4, 9, 2, "A")
    cv.put(1, 5, "1")
    cv.put(0, 5, "1")
    put("areas/library/floor_quill", render(cv))
    rng = random.Random(41)
    cv = Canvas(12, 14)                      # foot: a tall stack of books
    for k in range(5):
        fill, sh = SPINES[(k * 3) % len(SPINES)]
        x = 1 + (1 if k % 2 else 0)
        rect(cv, x, 11 - 2 * k - 1, 9, 2, fill)
        hline(cv, x, x + 8, 11 - 2 * k, sh)
        cv.put(x + 8, 11 - 2 * k - 1, "A")
    rect(cv, 2, 12, 9, 1, "j")
    put("areas/library/foot_books", render(cv))
    cv = Canvas(12, 14)                      # foot: a desk globe
    disc(cv, 6, 5.5, 4.6, "B")
    for (x, y) in ((4, 3), (5, 3), (4, 4), (7, 6), (8, 6), (7, 7), (5, 7)):
        cv.put(x, y, "G")
    cv.put(4, 2, "b")
    ring_lit(cv, 6, 5.5, 4.6, 5.6, "c", "o", "R")
    vline(cv, 6, 11, 12, "F")
    rect(cv, 3, 12, 7, 1, "F")
    put("areas/library/foot_globe", render(cv))
    # Attic
    cv = Canvas(12, 7)                       # buttons and a cotton reel
    for (x, y, ch) in ((1, 1, "y"), (4, 3, "r"), (2, 5, "b"), (6, 5, "w")):
        rect(cv, x, y, 2, 1, ch)
        cv.put(x, y + 1 if y < 6 else y, ch)
    rect(cv, 8, 1, 3, 5, "D")
    rect(cv, 8, 2, 3, 3, "q")
    put("areas/attic/floor_buttons", render(cv))
    cv = Canvas(15, 8)                       # fabric scraps
    for pts, ch in ((((1, 1), (6, 1), (5, 5), (1, 4)), "q"), (((6, 3), (12, 2), (13, 6), (7, 6)), "b"), (((3, 5), (6, 6), (4, 7)), "G")):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            for x in range(min(xs), max(xs) + 1):
                if _poly_inside(pts, x + 0.5, y + 0.5):
                    cv.put(x, y, ch)
    put("areas/attic/floor_scraps", render(cv))
    cv = Canvas(6, 11)                       # a tin soldier
    rect(cv, 2, 0, 2, 3, "1")
    rect(cv, 2, 3, 2, 1, "x")
    rect(cv, 1, 4, 4, 3, "r")
    hline(cv, 1, 4, 5, "w")
    rect(cv, 2, 7, 1, 3, "s")
    rect(cv, 3, 7, 1, 3, "s")
    put("areas/attic/floor_soldier", render(cv))
    cv = Canvas(10, 8)                       # a pincushion bristling with pins
    oval(cv, 5, 5, 3.8, 2.6, "r")
    oval(cv, 4.5, 4.5, 2.4, 1.4, "e")
    for (x, y, ch) in ((3, 1, "y"), (6, 0, "b"), (8, 2, "w"), (2, 3, "b")):
        cv.put(x, y, ch)
        cv.put(x, y + 1, "S")
    put("areas/attic/floor_pins", render(cv))
    cv = Canvas(16, 8)                       # a drift of grey dust
    for (x, y, w) in ((5, 2, 5), (2, 3, 11), (1, 4, 13), (3, 5, 9), (6, 6, 3)):
        hline(cv, x, x + w - 1, y, "a")
    for (x, y) in ((4, 4), (9, 3), (12, 5), (7, 5)):
        cv.put(x, y, "A")
    put("areas/attic/floor_dust", to_img(cv))
    cv = Canvas(14, 12)                      # foot: a hat box
    rect(cv, 2, 4, 10, 7, "B")
    rect(cv, 1, 2, 12, 3, "b")
    hline(cv, 1, 12, 2, "h")
    vline(cv, 2, 5, 10, "b")
    rect(cv, 6, 2, 2, 9, "q")
    put("areas/attic/foot_hatbox", render(cv))
    cv = Canvas(14, 16)                      # foot: picture frames leaning on the wall
    rect(cv, 1, 2, 9, 13, "F")
    rect(cv, 3, 4, 5, 9, "s")
    rect(cv, 6, 6, 7, 9, "c")
    rect(cv, 8, 8, 3, 5, "G")
    hline(cv, 6, 12, 6, "o")
    vline(cv, 1, 2, 14, "f")
    put("areas/attic/foot_frames", render(cv))


# =========================================================================== furniture (template B, C, U)
def table_piece(kind):
    cv = Canvas(16, 16)
    rect(cv, 0, 5, 16, 4, "d")           # the scrubbed top, seen from above
    hline(cv, 0, 15, 5, "x")
    rect(cv, 0, 9, 16, 2, "D")           # its front edge
    hline(cv, 0, 15, 10, "F")
    for k in range(0, 16, 5):
        cv.put((k + 3) % 16, 7, "X")
    if kind == "l":
        rect(cv, 1, 11, 2, 5, "F")
        rect(cv, 0, 5, 1, 6, "D")
        oval(cv, 9, 6, 3.2, 1.6, "B")        # a mixing bowl
        oval(cv, 9, 5.5, 2.2, 0.9, "A")
    elif kind == "r":
        rect(cv, 13, 11, 2, 5, "F")
        rect(cv, 15, 5, 1, 6, "R")
        rect(cv, 5, 2, 4, 5, "c")            # a copper jug
        vline(cv, 5, 2, 6, "o")
        cv.put(9, 3, "c")
        cv.put(9, 4, "c")
    else:
        oval(cv, 7, 5.5, 3.6, 2.0, "D")      # a loaf on a board
        hline(cv, 5, 9, 4, "d")
        hline(cv, 11, 15, 7, "S")            # a bread knife
    return render(cv)


def build_furniture():
    # ------------------------------------------------ Kitchen
    for k in ("l", "m", "r"):
        put("decor/prop_kitchen_table_%s" % k, on_shadow(table_piece(k)))
    cv = Canvas(16, 20)                       # the black iron range with its oven door
    rect(cv, 1, 6, 14, 14, "I")
    rect(cv, 1, 4, 14, 2, "H")
    hline(cv, 1, 14, 4, "L")
    vline(cv, 1, 6, 19, "L")
    vline(cv, 14, 6, 19, "3")
    rect(cv, 3, 4, 4, 1, "3")
    rect(cv, 9, 4, 4, 1, "3")
    rect(cv, 11, 0, 3, 4, "I")               # flue
    vline(cv, 11, 0, 3, "L")
    hline(cv, 1, 14, 8, "c")                 # brass rail
    hline(cv, 1, 14, 9, "R")
    rect(cv, 3, 11, 10, 7, "3")              # oven door
    rect(cv, 4, 12, 8, 5, "I")
    hline(cv, 4, 11, 12, "L")
    hline(cv, 5, 10, 15, "!")                # the warm slit
    rect(cv, 6, 13, 4, 1, "S")               # handle
    put("decor/prop_kitchen_range", on_shadow(render(cv)))
    cv = Canvas(16, 16)                       # a butcher's block with a cleaver in it
    rect(cv, 2, 6, 12, 4, "D")
    hline(cv, 2, 13, 6, "d")
    for (x, y) in ((5, 8), (9, 7), (11, 8)):
        cv.put(x, y, "F")
    rect(cv, 2, 10, 12, 3, "F")
    rect(cv, 3, 13, 2, 3, "R")
    rect(cv, 11, 13, 2, 3, "R")
    rect(cv, 7, 2, 5, 5, "S")
    vline(cv, 7, 2, 6, "h")
    hline(cv, 7, 11, 6, "i")
    rect(cv, 9, 0, 2, 2, "J")
    put("decor/prop_kitchen_block", on_shadow(render(cv)))
    cv = Canvas(16, 16)                       # (C) two flour sacks
    for (cx, top, w) in ((5, 5, 5), (11, 4, 5)):
        oval(cv, cx, 11, w, 4.5, "A")
        rect(cv, cx - 2, top, 4, 4, "A")
        rect(cv, cx - 2, top + 3, 4, 1, "F")
    shade_edges(cv, "A", "w", "a", "a")
    put("decor/prop_kitchen_sacks", on_shadow(render(cv)))
    # ------------------------------------------------ Library
    for k in ("l", "m", "r", "slide"):
        rng = random.Random({"l": 3, "m": 5, "r": 9, "slide": 13}[k])
        H = 26
        cv = Canvas(16, H)
        rect(cv, 0, 0, 16, H, "J")
        hline(cv, 0, 15, 0, "j")
        bx0 = 1 if k in ("l", "slide") else 0
        bx1 = 14 if k in ("r", "slide") else 15
        for (y0, y1) in ((2, 6), (8, 12), (14, 18), (20, 23)):
            rect(cv, bx0, y0, bx1 - bx0 + 1, y1 - y0 + 1, "1")
            books_row(cv, bx0, bx1, y0, y1, rng)
        for y in (7, 13, 19, 24):
            hline(cv, 0, 15, y, "j")
        if k in ("l", "slide"):
            vline(cv, 0, 0, H - 1, "j")
        if k in ("r", "slide"):
            vline(cv, 15, 0, H - 1, "u")
        if k == "slide":                      # a rolling base on two iron wheels
            rect(cv, 0, 23, 16, 2, "I")
            hline(cv, 0, 15, 23, "L")
            for wx in (3, 12):
                rect(cv, wx - 1, 24, 3, 2, "3")
                cv.put(wx, 24, "H")
        name = "decor/prop_library_%s" % ("shelf_" + k if k != "slide" else "slide")
        put(name, on_shadow(render(cv)))
    cv = Canvas(16, 18)                       # a reading desk with a green-shaded lamp (unlit) and a book
    rect(cv, 0, 8, 16, 3, "F")
    hline(cv, 0, 15, 8, "f")
    rect(cv, 2, 9, 12, 1, "G")
    rect(cv, 0, 11, 16, 2, "R")
    rect(cv, 1, 13, 2, 5, "R")
    rect(cv, 13, 13, 2, 5, "R")
    rect(cv, 3, 6, 6, 3, "w")
    vline(cv, 6, 6, 8, "a")
    vline(cv, 12, 3, 8, "c")
    rect(cv, 10, 1, 5, 3, "G")
    hline(cv, 10, 14, 1, "6")
    hline(cv, 10, 14, 3, "V")
    put("decor/prop_library_desk", on_shadow(render(cv)))
    cv = Canvas(16, 20)                       # a globe on its stand
    disc(cv, 8, 7.5, 6.2, "B")
    for (x, y) in ((5, 4), (6, 4), (5, 5), (6, 6), (7, 6), (10, 8), (11, 8), (10, 9), (9, 10), (6, 10)):
        cv.put(x, y, "G")
    for (x, y) in ((4, 3), (5, 2), (4, 4)):
        cv.put(x, y, "b")
    ring_lit(cv, 8, 7.5, 6.2, 7.3, "c", "o", "R")
    vline(cv, 8, 15, 17, "F")
    line(cv, 8, 17, 4, 19, "F")
    line(cv, 8, 17, 12, 19, "F")
    put("decor/prop_library_globe", on_shadow(render(cv)))
    rng = random.Random(77)
    cv = Canvas(16, 16)                       # (C) a pile of big books
    for k in range(5):
        fill, sh = SPINES[(k * 4 + 1) % len(SPINES)]
        x = 1 + (k * 3) % 3
        y = 13 - 3 * k
        rect(cv, x, y, 13, 3, fill)
        hline(cv, x, x + 12, y + 2, sh)
        vline(cv, x + 12, y, y + 2, "A")
        cv.put(x + 1, y, "y")
    put("decor/prop_library_stack", on_shadow(render(cv)))
    # ------------------------------------------------ Attic: dust-sheeted shapes and what is under them
    def sheet(h, top_w, body, seed):
        rng = random.Random(seed)
        cv = Canvas(16, h)
        for y in range(h - 1):
            t = y / float(h - 2)
            half = body(t)
            for x in range(int(8 - half), int(math.ceil(8 + half))):
                cv.put(x, y, "A")
        for x in range(1, 15):                # ragged hem resting on the floor
            if cv.get(x, h - 2) == "A" and rng.random() < 0.6:
                cv.put(x, h - 1, "A")
        for k in range(3):                    # folds hanging straight down
            fx = 4 + 4 * k + rng.randrange(-1, 2)
            for y in range(int(h * 0.35) + rng.randrange(0, 4), h - 1):
                if cv.get(fx, y) == "A":
                    cv.put(fx, y, "a")
        shade_edges(cv, "A", "w", "5", "a")
        return render(cv)
    put("decor/prop_attic_sheet_a", on_shadow(sheet(28, 6, lambda t: 5.0 + 2.6 * min(1.0, t * 3.0), 3)))
    put("decor/prop_attic_sheet_b", on_shadow(sheet(20, 6, lambda t: 3.2 + 0.8 * t if t < 0.4 else 6.0 + 1.2 * min(1.0, (t - 0.4) * 4.0), 5)))
    put("decor/prop_attic_sheet_c", on_shadow(sheet(26, 4, lambda t: 3.0 + 3.0 * math.sin(min(1.0, t * 1.6) * math.pi / 2) + (1.2 if t > 0.8 else 0), 7)))
    cv = Canvas(16, 28)                       # under sheet a: a wardrobe
    rect(cv, 1, 2, 14, 25, "F")
    rect(cv, 0, 0, 16, 3, "R")
    hline(cv, 0, 15, 0, "f")
    vline(cv, 8, 3, 26, "R")
    rect(cv, 3, 5, 4, 19, "R")
    rect(cv, 9, 5, 4, 19, "R")
    vline(cv, 3, 5, 23, "f")
    vline(cv, 9, 5, 23, "f")
    cv.put(7, 14, "y")
    cv.put(9, 14, "y")
    put("decor/prop_attic_wardrobe", on_shadow(render(cv)))
    cv = Canvas(16, 20)                       # under sheet b: a faded armchair
    rect(cv, 3, 2, 10, 9, "p")
    rect(cv, 1, 8, 14, 6, "p")
    rect(cv, 4, 10, 8, 3, "q")
    vline(cv, 3, 2, 9, "q")
    rect(cv, 1, 14, 14, 2, "m")
    rect(cv, 2, 16, 2, 3, "R")
    rect(cv, 12, 16, 2, 3, "R")
    put("decor/prop_attic_chair", on_shadow(render(cv)))
    cv = Canvas(16, 26)                       # under sheet c: a cheval mirror with a crack
    oval(cv, 8, 10, 5.6, 9.6, "F")
    oval(cv, 8, 10, 4.2, 8.2, "S")
    oval(cv, 7.2, 9.0, 2.0, 5.5, "h")
    line(cv, 9, 4, 10, 8, "i")
    line(cv, 10, 8, 8, 12, "i")
    vline(cv, 8, 20, 23, "F")
    hline(cv, 4, 12, 24, "F")
    put("decor/prop_attic_mirror", on_shadow(render(cv)))
    put("decor/prop_attic_trunk", on_shadow(trunk_frame()))


def trunk_frame(lid=0, teeth=False, eyes=False, dy=0):
    """A steamer trunk (16x16): leather, two straps, brass corners. `lid` opens it (the Snapping Trunk)."""
    cv = Canvas(16, 16)
    post = Canvas(16, 16)
    by = 7 + dy
    rect(cv, 1, by, 14, 16 - by - 1 + (0 if dy <= 0 else 0), "F")
    hline(cv, 1, 14, by, "f")
    for sx in (4, 11):
        vline(cv, sx, by, 14, "R")
    for (x, y) in ((1, by), (14, by), (1, 14), (14, 14)):
        cv.put(x, y, "y")
    if lid == 0:
        rect(cv, 1, by - 3, 14, 3, "F")
        hline(cv, 1, 14, by - 3, "f")
        hline(cv, 1, 14, by - 1, "R")
        cv.put(7, by, "y")
        cv.put(8, by, "c")
    else:
        top = by - 3 - lid
        rect(cv, 1, top, 14, 3, "F")
        hline(cv, 1, 14, top, "f")
        rect(cv, 2, top + 3, 12, by - top - 3, "m")       # the mouth
        if teeth:
            for x in range(2, 14, 2):
                cv.put(x, top + 3, "w")
                cv.put(x + 1, by - 1, "w")
        rect(cv, 5, by - 2, 6, 1, "q")                    # tongue
    if eyes:
        post.put(5, by - 4 - lid if lid else by - 2, "y")
        post.put(10, by - 4 - lid if lid else by - 2, "y")
    return render(cv, post)


# =========================================================================== creatures
def save_anim(th, kind, anim, frames):
    for i, im in enumerate(frames):
        put("areas/%s/%s_%s_f%d" % (th, kind, anim, i), im)
    CREATURES.setdefault(th, [])
    if kind not in CREATURES[th]:
        CREATURES[th].append(kind)


# ---------------------------------------------------------------- Kitchen: the Pot-Lid Crab (16x16)
# A red kitchen crab holding a copper pot lid in front of it (the sprite faces right; the game flips it).
LEG_OFF = [(0, 0, 0), (1, -1, 1), (0, 0, 0), (-1, 1, -1)]


def crab_frame(legs=0, dy=0, lid=0, blink=False, snap=False):
    cv = Canvas(16, 16)
    post = Canvas(16, 16)
    oval(cv, 7.0, 10.5 + dy, 4.8, 3.1, "r")
    shade_edges(cv, "r", "e", "R", "R")
    for i, (sx, fx) in enumerate(((3, 1), (5, 4), (7, 6))):          # back legs
        o = LEG_OFF[legs][i]
        line(cv, sx, 12 + dy, fx + o, 15, "R")
    for i, (sx, fx) in enumerate(((8, 9), (9, 11), (10, 13))):       # front legs
        o = LEG_OFF[legs][2 - i]
        line(cv, sx, 12 + dy, fx + o, 15, "R")
    rect(cv, 1, 7 + dy, 2, 2, "r")                                   # back claw
    cv.put(1, 6 + dy, "e")
    for ex in (5, 9):                                                # eye stalks
        vline(cv, ex, 6 + dy, 7 + dy, "R")
        rect(cv, ex - 1, 4 + dy, 2, 2, "w")
        if not blink:
            post.put(ex, 5 + dy, "1")
    # the lid: a copper disc seen edge-on, held up like a shield, knob outward
    lx = 13 + lid
    oval(cv, lx, 9.0 + dy - (1 if snap else 0), 2.1, 5.2, "c")
    for y in range(16):
        if cv.get(lx - 1, y) == "c":
            cv.put(lx - 1, y, "o")
        if cv.get(lx + 1, y) == "c":
            cv.put(lx + 1, y, "R")
    rect(cv, lx + 1, 8 + dy - (1 if snap else 0), 2, 2, "H")
    cv.put(11, 10 + dy, "r")                                         # the claw that holds it
    cv.put(10, 9 + dy, "r")
    return render(cv, post)


def build_crab():
    save_anim("kitchen", "lid_crab", "idle", [crab_frame(0, 0), crab_frame(0, 0), crab_frame(0, 1), crab_frame(0, 1, blink=True)])
    save_anim("kitchen", "lid_crab", "run", [crab_frame(k, (0, 1, 0, 1)[k]) for k in range(4)])
    save_anim("kitchen", "lid_crab", "atk", [crab_frame(0, 0, 1), crab_frame(1, 0, 2, snap=True), crab_frame(2, 0, 2, snap=True), crab_frame(3, 0, 1)])


# ---------------------------------------------------------------- Kitchen: the Flour Ghost (16x18, flies)
def flour_frame(dy=0, k=0, puff=0.0, mouth="o"):
    """A flour sack that got up as a ghost: a gathered, tied top, a printed blue band, a ragged ghost hem."""
    cv = Canvas(16, 18)
    post = Canvas(16, 18)
    half = {2: 2.5, 3: 1.5, 4: 1.5, 5: 2.0, 6: 3.5, 7: 4.8, 8: 5.6, 9: 6.0, 10: 6.0, 11: 6.0, 12: 6.0, 13: 5.8, 14: 5.6}
    for y, hw in half.items():
        hw += puff if y >= 7 else 0.0
        for x in range(int(math.floor(8 - hw)), int(math.ceil(8 + hw))):
            cv.put(x, y + dy, "A")
    sh = k % 2
    for (x0, x1) in ((3, 5), (7, 9), (11, 13)):                      # three ragged tails
        hline(cv, x0 + sh - (1 if x0 == 3 else 0), x1 + sh - (1 if x0 == 3 else 0), 15 + dy, "A")
        cv.put(x0 + 1 + sh - (1 if x0 == 3 else 0), 16 + dy, "A")
    shade_edges(cv, "A", "w", "a", "a")
    hline(cv, 6, 9, 5 + dy, "D")                                     # the twine round its neck
    cv.put(10, 6 + dy, "D")
    hline(cv, 3 - int(puff), 12 + int(puff), 12 + dy, "B")          # the printed band
    hline(cv, 3 - int(puff), 12 + int(puff), 13 + dy, "b")
    for ex in (5, 9):
        rect(cv, ex, 8 + dy, 2, 2, "1")
        post.put(ex, 8 + dy, "4")
    if mouth == "o":
        rect(cv, 7, 10 + dy, 2, 1, "4")
    else:
        rect(cv, 7, 10 + dy, 2, 2, "m")                              # cheeks full of flour
    for j in range(3):                                               # flour sifting out of the seams
        x = 4 + 4 * j + sh
        y = 17
        post.put(x, y, "A" if (k + j) % 2 else "w")
    return render(cv, post)


def build_flour():
    save_anim("kitchen", "flour_ghost", "idle", [flour_frame((0, 0, 1, 1)[k], k) for k in range(4)])
    save_anim("kitchen", "flour_ghost", "run", [flour_frame((0, 1, 1, 0)[k], k + 1) for k in range(4)])
    save_anim("kitchen", "flour_ghost", "atk", [flour_frame(0, 0, 0.6, "m"), flour_frame(0, 1, 1.2, "m"), flour_frame(-1, 2, 1.6, "m"), flour_frame(0, 3, 0.4, "o")])


# ---------------------------------------------------------------- Library: the Bookworm (16x16)
def worm_frame(k=0, rear=0, mouth=False, blink=False):
    cv = Canvas(16, 16)
    post = Canvas(16, 16)
    arch = [0, 1, 2, 1][k]
    segs = [(2.5, 0.0), (5.0, 0.8), (7.5, 1.0), (10.0, 0.6)]
    for i, (x, w) in enumerate(segs):
        y = 13.0 - arch * w - (rear * 0.3 if i == 3 else 0)
        disc(cv, x + (k % 2) * 0.0, y, 2.2, "q")
    hx, hy = 12.5, 11.0 - rear - arch * 0.4
    disc(cv, hx, hy, 2.8, "q")
    shade_edges(cv, "q", "w", "P", "p")
    for i in range(3):                                               # rings between the segments
        x = int(3.8 + 2.5 * i)
        for y in range(16):
            if cv.get(x, y) in ("q", "w", "P"):
                cv.put(x, y, "P")
                break
    # round spectacles: two pale lenses on a dark bridge, eyes peering through
    gy = int(hy) - 2
    for gx in (10, 13):
        rect(cv, gx, gy, 2, 2, "h")
        if not blink:
            post.put(gx + 1, gy + 1, "1")
    cv.put(12, gy, "1")
    if mouth:
        rect(cv, 13, int(hy) + 1, 2, 1, "m")
    else:
        cv.put(14, int(hy) + 1, "p")
    rect(cv, 6, int(12 - arch) - 2, 3, 2, "w")                       # a scrap of page on its back
    cv.put(8, int(12 - arch) - 1, "A")
    return render(cv, post)


def build_worm():
    save_anim("library", "bookworm", "idle", [worm_frame(0), worm_frame(0), worm_frame(1), worm_frame(0, blink=True)])
    save_anim("library", "bookworm", "run", [worm_frame(k) for k in range(4)])
    save_anim("library", "bookworm", "atk", [worm_frame(0, 1), worm_frame(0, 3, True), worm_frame(0, 3, True), worm_frame(0, 1)])


# ---------------------------------------------------------------- Library: the Inkblot (16x16) and its drops
def ink_frame(w=11, h=8, lift=0, look=0, mouth=False, nib=0, small=False):
    cv = Canvas(16, 16)
    post = Canvas(16, 16)
    bottom = 15 - lift
    AM.ellipse(cv, 8, bottom, w, h, "s")
    if lift == 0:                                                    # splats round its base
        for x in (8 - w // 2 - 1, 8 + w // 2):
            cv.put(x, 15, "s")
    shade_edges(cv, "s", "B", "2", "2")
    top = bottom - h + 1
    cv.put(5 if not small else 6, top + 1, "b")
    cv.put(6 if not small else 7, top + 1, "b")
    post.put(5 if not small else 6, top + 1, "h")
    ey = top + (3 if not small else 2)
    for ex in ((5, 9) if not small else (6, 9)):
        rect(cv, ex, ey, 2, 2, "w")
        post.put(ex + (1 if look >= 0 else 0), ey + 1, "1")
    if mouth:
        rect(cv, 7, ey + 3, 3, 1, "m") if not small else None
    if not small:                                                    # a quill nib stuck in its head
        nx = 10 + nib
        line(cv, nx, top - 1, nx + 3, top - 5, "w")
        line(cv, nx + 1, top - 1, nx + 3, top - 4, "A")
        cv.put(nx, top, "1")
    return render(cv, post)


def build_ink():
    save_anim("library", "inkblot", "idle", [ink_frame(11, 8), ink_frame(12, 7), ink_frame(11, 8), ink_frame(10, 9)])
    save_anim("library", "inkblot", "run", [ink_frame(12, 7), ink_frame(9, 10, 2, nib=-1), ink_frame(10, 9, 3, nib=-1), ink_frame(12, 7)])
    save_anim("library", "inkblot", "atk", [ink_frame(12, 7, mouth=True), ink_frame(13, 6, mouth=True), ink_frame(10, 9, 1, mouth=True), ink_frame(11, 8)])
    save_anim("library", "ink_drop", "idle", [ink_frame(6, 4, small=True), ink_frame(7, 4, small=True), ink_frame(6, 4, small=True), ink_frame(5, 5, small=True)])
    save_anim("library", "ink_drop", "run", [ink_frame(7, 4, small=True), ink_frame(5, 5, 1, small=True), ink_frame(5, 5, 2, small=True), ink_frame(7, 4, small=True)])


# ---------------------------------------------------------------- Attic: the Lantern-Shy Mannequin (16x22)
def mannequin_frame(step=0, dy=0, arms=0, lunge=False, eyes=False):
    """A jointed wooden artist's mannequin with no face. `step` swings the legs, `arms` the arms."""
    cv = Canvas(16, 22)
    post = Canvas(16, 22)
    hx = 8 + (2 if lunge else 0)
    oval(cv, hx, 3.5 + dy, 2.3, 2.8, "d")                            # head
    vline(cv, hx, 6 + dy, 7 + dy, "D")
    oval(cv, 8 + (1 if lunge else 0), 10.0 + dy, 3.0, 2.6, "d")      # chest
    cv.put(8, 12 + dy, "D")
    oval(cv, 8, 14.0 + dy, 2.5, 1.7, "d")                            # hips
    sh = [(5 + (1 if lunge else 0), 8 + dy), (11 + (1 if lunge else 0), 8 + dy)]
    if lunge:
        elbows, hands = [(9, 9 + dy), (13, 8 + dy)], [(13, 9 + dy), (15, 8 + dy)]
    else:
        sw = (0, 1, 0, -1)[arms]
        elbows = [(4 - sw, 11 + dy), (12 + sw, 11 + dy)]
        hands = [(4 - sw, 14 + dy), (12 + sw, 14 + dy)]
    for s, e, h in zip(sh, elbows, hands):
        line(cv, s[0], s[1], e[0], e[1], "d")
        line(cv, e[0], e[1], h[0], h[1], "d")
        cv.put(s[0], s[1], "D")
        cv.put(e[0], e[1], "D")
        cv.put(h[0], h[1], "x")
    kx = [(-1, 1), (0, 0), (1, -1), (0, 0)][step]
    if lunge:
        legs = [((7, 16), (4, 18), (3, 21)), ((9, 16), (10, 18), (11, 21))]
    else:
        legs = [((7, 16), (6 + kx[0], 18), (6 + kx[0], 21)), ((9, 16), (10 + kx[1], 18), (10 + kx[1], 21))]
    for hip, knee, foot in legs:
        line(cv, hip[0], hip[1] + dy, knee[0], knee[1] + (dy if knee[1] + dy < 21 else 0), "d")
        line(cv, knee[0], knee[1] + (dy if knee[1] + dy < 21 else 0), foot[0], 21, "d")
        cv.put(knee[0], knee[1] + (dy if knee[1] + dy < 21 else 0), "D")
        cv.put(foot[0] + 1, 21, "D")
    shade_edges(cv, "d", "x", "D", None)
    if eyes:                                                         # only in the dark: two ember pin-pricks
        post.put(hx - 1, 3 + dy, "r")
        post.put(hx + 1, 3 + dy, "r")
    return render(cv, post)


def build_mannequin():
    save_anim("attic", "mannequin", "idle", [mannequin_frame(1, 0, 1), mannequin_frame(1, 0, 1), mannequin_frame(1, 0, 1), mannequin_frame(1, 0, 1)])
    save_anim("attic", "mannequin", "run", [mannequin_frame(k, (0, 1, 0, 1)[k], k, eyes=True) for k in range(4)])
    save_anim("attic", "mannequin", "atk", [mannequin_frame(1, 0, 0, True, True), mannequin_frame(1, 1, 0, True, True),
                                            mannequin_frame(1, 0, 0, True, True), mannequin_frame(1, 1, 0, True, True)])


# ---------------------------------------------------------------- Attic: the Snapping Trunk (16x16)
def build_trunk():
    save_anim("attic", "trunk", "idle", [trunk_frame(), trunk_frame(), trunk_frame(), trunk_frame(eyes=True)])
    save_anim("attic", "trunk", "run", [trunk_frame(1, eyes=True), trunk_frame(2, True, True), trunk_frame(1, eyes=True), trunk_frame(0, eyes=True)])
    save_anim("attic", "trunk", "atk", [trunk_frame(2, True, True), trunk_frame(4, True, True), trunk_frame(4, True, True), trunk_frame(3, True, True)])


# =========================================================================== guardians
# ---------------------------------------------------------------- THE STOCKPOT (44x40)
def stockpot_frame(k=0, bob=0, ladles="down", lid=0, eyes="y", boil=0):
    W, H = 44, 40
    cv = Canvas(W, H)
    post = Canvas(W, H)
    cx = 22
    for lx in (10, 21, 32):                                          # three iron feet (they never move)
        rect(cv, lx, 36, 3, 4, "I")
        vline(cv, lx, 36, 39, "L")
    oval(cv, cx, 25.5 + bob, 16.2, 11.0, "I")                        # the belly
    shade_edges(cv, "I", "L", "3", "3")
    for y in range(H):                                               # a lit band on the upper left of the belly
        for x in range(W):
            if cv.get(x, y) == "I":
                u, v = (x + 0.5 - cx) / 16.2, (y + 0.5 - 25.5 - bob) / 11.0
                if -0.78 < u < -0.42 and -0.75 < v < 0.1:
                    cv.put(x, y, "L")
                elif u > 0.55 and v > -0.2:
                    cv.put(x, y, "3")
    for x in range(W):                                               # a riveted iron band round the belly
        for y in (24 + bob, 25 + bob):
            if cv.get(x, y) in ("I", "L", "3"):
                cv.put(x, y, "H" if y == 24 + bob else "3")
                if y == 24 + bob and x % 5 == 2:
                    cv.put(x, y, "S")
    for (x, y0) in ((12, 16), (13, 17), (30, 17)):                   # broth that has run down the side
        for y in range(y0 + bob, y0 + bob + (5 if x != 13 else 3)):
            if cv.get(x, y) in ("I", "L", "3"):
                cv.put(x, y, "c")
    # the rim and the broth inside it
    for y in range(H):
        for x in range(W):
            u, v = (x + 0.5 - cx) / 16.8, (y + 0.5 - 14.5 - bob) / 3.6
            d = u * u + v * v
            if d <= 1.0:
                ui, vi = (x + 0.5 - cx) / 13.6, (y + 0.5 - 14.5 - bob) / 2.3
                if ui * ui + vi * vi <= 1.0:
                    cv.put(x, y, "c" if (x + y + boil) % 7 else "o")
                else:
                    cv.put(x, y, "S" if (u < -0.3 and v < 0.3) else ("i" if v < 0.4 else "H"))
    for (bx, by, ph) in ((14, 14, 0), (20, 15, 1), (26, 14, 2), (31, 15, 3)):   # bubbles that come and go
        if (boil + ph) % 4 in (0, 1):
            cv.put(bx, by + bob, "y")
            if (boil + ph) % 4 == 1:
                cv.put(bx + 1, by + bob - 1, "Y")
    # the lid, ajar on the right of the rim: under its raised edge two eyes watch
    ly = 10 + bob - lid
    for r, (x0, x1) in enumerate(((22, 33), (19, 35), (18, 36), (19, 35))):
        for x in range(x0, x1 + 1):
            cv.put(x, ly + r + (x - 18) // 9, "S" if r == 0 or x == x0 else ("i" if r < 3 else "H"))
    rect(cv, 26, ly - 2, 3, 2, "H")
    cv.put(26, ly - 2, "S")
    rect(cv, 13, 11 + bob - lid, 9, 3 + lid, "1")                    # the dark gap under the lid
    if eyes:
        for ex in (14, 19):                                          # two eyes glaring out of the gap
            post.put(ex, 11 + bob - lid, eyes)
            post.put(ex + 1, 11 + bob - lid, eyes)
            post.put(ex, 12 + bob - lid, "o" if eyes == "y" else "y")
            post.put(ex + 1, 12 + bob - lid, "1")
        if lid >= 2:
            for x in range(13, 22, 2):
                post.put(x, 13 + bob, "w")                           # teeth when the lid lifts
    # the ladle arms: copper handles, pewter bowls
    for side in (-1, 1):
        sx = cx + side * 15
        if ladles == "down":
            ex, ey = sx + side * 5, 31 + bob
        elif ladles == "up":
            ex, ey = sx + side * 4, 6 + bob
        else:  # "pour": one scooping in front
            ex, ey = (sx + side * 6, 18 + bob) if side < 0 else (sx + side * 2, 4 + bob)
        line(cv, sx, 22 + bob, ex, ey, "c")
        line(cv, sx - side, 22 + bob, ex - side, ey, "o")
        disc(cv, ex + 0.5, ey + (1.5 if ladles != "up" else -1.0) + 0.5, 2.6, "S")
        disc(cv, ex + 0.5 - 0.6, ey + (1.5 if ladles != "up" else -1.0), 1.4, "h")
    for j in range(3):                                               # steam (drawn after the outline: no edge)
        sx = 14 + 8 * j + ((k + j) % 2)
        for t in range(3):
            y = 6 - t * 2 + bob - ((k + j) % 2)
            if 0 <= y < H and cv.get(sx + (t % 2), y) == ".":
                post.put(sx + (t % 2), y, "h" if t else "S")
    return render(cv, post)


def build_stockpot():
    save_anim("kitchen", "stockpot", "idle", [stockpot_frame(k, (0, 0, 1, 1)[k], "down", 0, "y", k) for k in range(4)])
    save_anim("kitchen", "stockpot", "run", [stockpot_frame(k, (0, 1, 1, 0)[k], "down" if k % 2 else "pour", 0, "y", k + 1) for k in range(4)])
    save_anim("kitchen", "stockpot", "atk", [stockpot_frame(k, 0, "up", (1, 2, 3, 2)[k], "w" if k % 2 else "y", k) for k in range(4)])


# ---------------------------------------------------------------- THE HEAD LIBRARIAN (32x52)
def librarian_frame(k=0, bob=0, arm="hush", eyes="t", book="shut", hem=0):
    W, H = 32, 52
    cv = Canvas(W, H)
    post = Canvas(W, H)
    cx = 16
    for y in range(16 + bob, 47):                                    # the long dark gown
        t = (y - 16 - bob) / float(30 - bob)
        half = int(5 + 6.5 * t)
        for x in range(cx - half, cx + half):
            cv.put(x, y, "s")
        cv.put(cx - half, y, "B")
        cv.put(cx + half - 1, y, "2")
    for x in range(cx - 12, cx + 12):                                # a ragged hem trailing into wisps
        tip = 47 + ((x + hem) % 5 == 0) * 4 + ((x + hem) % 5 == 2) * 2
        for y in range(46, tip):
            if cv.get(x, 45) in ("s", "B", "2"):
                cv.put(x, y, "s" if y < 49 else "2")
    for fx in (12, 16, 20):                                          # folds
        for y in range(28, 46):
            if cv.get(fx + (y // 12) % 2, y) == "s":
                cv.put(fx + (y // 12) % 2, y, "2")
    for y in range(15 + bob, 22 + bob):                              # a grey shawl over the shoulders
        hw = 6 + (y - 15 - bob) // 2
        for x in range(cx - hw, cx + hw):
            cv.put(x, y, "i")
        cv.put(cx - hw, y, "S")
    for x in range(cx - 9, cx + 9, 3):                               # its fringe
        cv.put(x, 22 + bob, "i")
    rect(cv, cx - 3, 13 + bob, 6, 3, "1")                            # high collar
    rect(cv, cx - 1, 15 + bob, 2, 3, "A")                            # lace at the throat, a brooch
    cv.put(cx - 1, 18 + bob, "y")
    oval(cv, cx, 9.0 + bob, 3.3, 4.2, "S")                           # the face
    shade_edges(cv, "S", "h", "i", None)
    disc(cv, cx, 2.6 + bob, 2.3, "H")                                # a tight iron-grey bun
    hline(cv, cx - 3, cx + 2, 5 + bob, "H")                          # hair drawn back from a parting
    cv.put(cx - 3, 6 + bob, "H")
    cv.put(cx + 2, 6 + bob, "H")
    cv.put(cx - 1, 1 + bob, "i")
    cv.put(cx - 2, 2 + bob, "i")
    cv.put(cx, 5 + bob, "I")
    for (x0, x1) in ((cx - 3, cx - 2), (cx + 1, cx + 2)):            # half-moon spectacles
        hline(cv, x0, x1, 10 + bob, "y")
    cv.put(cx - 1, 10 + bob, "c")
    post.put(cx - 3, 9 + bob, eyes)                                  # eyes glaring over them
    post.put(cx + 2, 9 + bob, eyes)
    cv.put(cx, 11 + bob, "i")                                        # the nose
    rect(cv, cx - 1, 12 + bob, 2, 1, "5")                            # pursed lips
    # the book, held to the chest (or open, its pages lifting)
    if book == "shut":
        rect(cv, cx - 9, 21 + bob, 6, 8, "p")
        vline(cv, cx - 4, 21 + bob, 28 + bob, "A")
        hline(cv, cx - 9, cx - 4, 28 + bob, "m")
        cv.put(cx - 7, 24 + bob, "y")
    else:
        rect(cv, cx - 12, 22 + bob, 10, 5, "w")
        vline(cv, cx - 7, 22 + bob, 26 + bob, "a")
        hline(cv, cx - 12, cx - 3, 27 + bob, "p")
        for j in range(3):
            post.put(cx - 11 + 3 * j, 20 + bob - ((k + j) % 3), "w")
    # the hushing arm: a finger to the lips, or raised high for the hush
    if arm == "hush":
        line(cv, cx + 7, 21 + bob, cx + 3, 15 + bob, "s")
        line(cv, cx + 8, 21 + bob, cx + 4, 15 + bob, "s")
        rect(cv, cx + 1, 13 + bob, 3, 2, "S")                        # the hand at the chin...
        post.put(cx + 1, 12 + bob, "h")                              # ...one finger up across the lips
        post.put(cx + 1, 11 + bob, "h")
    else:
        line(cv, cx + 6, 18 + bob, cx + 9, 9 + bob, "s")
        rect(cv, cx + 8, 7 + bob, 2, 2, "S")
        vline(cv, cx + 9, 4 + bob, 6 + bob, "S")
    for x in range(cx + 2, cx + 6):                                  # keys on a chain at the waist
        cv.put(x, 30 + bob + (x % 2), "y")
    cv.put(cx + 5, 32 + bob, "c")
    return render(cv, post)


def build_librarian():
    save_anim("library", "librarian", "idle", [librarian_frame(k, (0, 0, 1, 1)[k], "hush", "t", "shut", k) for k in range(4)])
    save_anim("library", "librarian", "run", [librarian_frame(k, (0, 1, 1, 0)[k], "hush", "t", "shut", k + 2) for k in range(4)])
    save_anim("library", "librarian", "atk", [librarian_frame(k, 0, "up", "w" if k % 2 else "t", "open", k) for k in range(4)])


# ---------------------------------------------------------------- THE DRESSMAKER'S FORM (40x48)
PIN_HEADS = ["r", "b", "y", "w", "q", "g"]


def form_frame(k=0, bob=0, needle="through", pins=4, sway=0, caster=0):
    W, H = 40, 48
    cv = Canvas(W, H)
    post = Canvas(W, H)
    cx = 20
    # the stand: pole, three splayed legs and their casters (on the bottom row)
    vline(cv, cx, 33, 43, "F")
    vline(cv, cx - 1, 33, 43, "f")
    for (fx, c2) in ((cx - 10, 0), (cx, 1), (cx + 10, 2)):
        line(cv, cx, 42, fx, 46, "F")
        rect(cv, fx - 1 + (1 if (caster + c2) % 2 else 0), 46, 2, 2, "3")
    # the skirt cage: three hoops and the ribs between them (see-through)
    for (hy, rx) in ((29, 7.5), (33, 10.5), (37, 13.0)):
        for x in range(W):
            for y in (hy + bob,):
                pass
        for t in range(0, 64):
            a = t * math.pi * 2 / 64
            x = int(round(cx - 0.5 + math.cos(a) * rx + sway * (hy - 27) / 10.0))
            y = int(round(hy + bob + math.sin(a) * rx * 0.22))
            cv.put(x, y, "R" if math.sin(a) > 0 else "F")
    for rib in (-1, 0, 1):
        line(cv, cx + rib * 5, 27 + bob, cx + rib * 12 + sway, 37 + bob, "F")
    # the torso: a padded linen bust
    halves = [4.5, 6.5, 8.0, 8.8, 9.3, 9.5, 9.3, 8.8, 8.2, 7.6, 7.0, 6.5, 6.2, 6.0, 6.2, 6.6, 7.0, 7.4]
    for i, hw in enumerate(halves):                                  # sloping shoulders, a bust, a nipped waist
        y = 9 + bob + i
        for x in range(int(round(cx - hw)), int(round(cx + hw))):
            cv.put(x, y, "X")
    shade_edges(cv, "X", "x", "D", "d")
    for y in range(11 + bob, 26 + bob, 2):                           # the centre seam, stitched
        cv.put(cx, y, "d")
    for y in range(13 + bob, 25 + bob):                              # princess seams
        cv.put(cx - 5 + (y - 13 - bob) // 6, y, "d")
        cv.put(cx + 4 - (y - 13 - bob) // 6, y, "d")
    rect(cv, cx - 2, 5 + bob, 4, 4, "F")                             # the neck post and its brass cap
    hline(cv, cx - 2, cx + 1, 5 + bob, "f")
    disc(cv, cx, 3.5 + bob, 2.0, "o")
    cv.put(cx - 1, 2 + bob, "y")
    for side in (-1, 1):                                             # a tape measure round the neck
        x = cx + side * 5
        for y in range(9 + bob, 21 + bob):
            cv.put(x + (1 if side > 0 and y > 15 + bob else 0), y, "y")
            if y % 2 == 0:
                post.put(x + (1 if side > 0 and y > 15 + bob else 0), y, "1")
    # pins stuck in the shoulders and the bust
    spots = [(cx - 8, 11), (cx - 4, 10), (cx + 6, 12), (cx + 8, 16), (cx - 7, 18), (cx + 3, 20), (cx - 2, 15)]
    for j in range(min(pins, len(spots))):
        px_, py_ = spots[j]
        dx = -1 if px_ < cx else 1
        post.put(px_ + dx, py_ + bob - 1, "S")
        post.put(px_ + 2 * dx, py_ + bob - 2, PIN_HEADS[(j + k) % len(PIN_HEADS)])
    # the great sewing needle (a lance): through its side, or levelled for the dash
    if needle == "through":
        line(cv, cx - 15, 31 + bob, cx + 15, 10 + bob, "S")
        line(cv, cx - 14, 31 + bob, cx + 15, 11 + bob, "i")
        tip = (cx - 15, 31 + bob)
        eye = (cx + 15, 10 + bob)
    else:
        hline(cv, cx - 6, cx + 19, 19 + bob, "S")
        hline(cv, cx - 6, cx + 18, 20 + bob, "i")
        tip = (cx + 19, 19 + bob)
        eye = (cx - 6, 19 + bob)
    cv.put(eye[0], eye[1], "1")
    for j in range(5):                                               # a red thread trailing from the eye
        post.put(eye[0] + (j if needle == "through" else -j), eye[1] - 1 - (j % 2), "r")
    post.put(tip[0], tip[1], "w")
    return render(cv, post)


def build_form():
    save_anim("attic", "dress_form", "idle", [form_frame(k, (0, 0, 1, 1)[k], "through", 4, 0, 0) for k in range(4)])
    save_anim("attic", "dress_form", "run", [form_frame(k, (0, 1, 1, 0)[k], "through", 4, (-1, 0, 1, 0)[k], k) for k in range(4)])
    save_anim("attic", "dress_form", "atk", [form_frame(k, 0, "level", 7, 0, k) for k in range(4)])


# =========================================================================== gimmick props
def build_kitchen_props():
    # a stove top: a cast-iron hot plate set into the floor, two burner rings
    def plate():
        cv = Canvas(16, 16)
        rect(cv, 1, 2, 14, 13, "I")
        hline(cv, 1, 14, 2, "L")
        vline(cv, 1, 2, 14, "L")
        hline(cv, 1, 14, 14, "3")
        vline(cv, 14, 2, 14, "3")
        return cv
    rings = [(5.5, 8.5, 2.2, 3.8), (11.0, 7.0, 1.4, 2.6)]
    cv = plate()
    for (x, y, r0, r1) in rings:
        disc(cv, x, y, r0 - 0.4, "3")
        ring_lit(cv, x, y, r0, r1, "H", "S", "3")
        cv.put(int(x), int(y), "1")
    for x in range(3, 14, 3):
        cv.put(x, 12, "3")
    put("areas/kitchen/stove", render(cv))
    for f, (a, b, c) in enumerate((("!", "m", "!"), ("r", "e", "o"), ("e", "o", "y"))):
        g = Canvas(16, 16)
        for (x, y, r0, r1) in rings:
            ring_lit(g, x, y, r0, r1, a, b, c)
        if f > 0:
            for (x, y, r0, r1) in rings:
                disc(g, x, y, r0 - 0.6, "m" if f == 1 else "r")
        put("areas/kitchen/stove_glow_f%d" % f, to_img(g))
    # the boiling pot (template U in the kitchen): copper, lid ajar
    cv = Canvas(16, 16)
    oval(cv, 8, 10.5, 6.2, 4.6, "c")
    shade_edges(cv, "c", "o", "R", "R")
    rect(cv, 1, 8, 2, 2, "R")
    rect(cv, 13, 8, 2, 2, "R")
    oval(cv, 8, 6.5, 6.0, 1.8, "y")
    oval(cv, 8, 6.5, 4.8, 1.0, "c")
    for x in range(5, 13):
        cv.put(x, 4 + (x - 5) // 4, "S" if x < 9 else "i")
    rect(cv, 8, 3, 2, 1, "H")
    put("areas/kitchen/pot", render(cv))
    for f in range(4):                                               # steam curling off it (no edge)
        cv = Canvas(8, 10)
        for j in range(4):
            y = 9 - j * 2 - (f % 2)
            x = 3 + ((j + f) % 3) - 1
            if 0 <= y:
                cv.put(x, y, "h" if j < 2 else "S")
                if j == 1:
                    cv.put(x + 1, y, "S")
        put("areas/kitchen/pot_steam_f%d" % f, to_img(cv))
    cv = Canvas(16, 12)                                              # the pot on its side after it spills
    oval(cv, 7, 7, 5.0, 3.8, "c")
    shade_edges(cv, "c", "o", "R", "R")
    oval(cv, 12, 7, 1.6, 3.4, "1")
    rect(cv, 6, 2, 2, 2, "R")
    put("areas/kitchen/pot_spilt", render(cv))
    for f in range(3):                                               # scalding broth (drawn unlit: it is hot)
        cv = Canvas(32, 20)
        oval(cv, 16, 10, 15.0, 8.6, "m")
        oval(cv, 16, 10, 14.0, 7.8, "R")
        oval(cv, 16, 10, 12.4, 6.6, "c")
        for (x, y, w) in ((9, 6, 6), (17, 13, 7), (6, 11, 4), (21, 8, 5)):   # skin forming on the broth
            hline(cv, x + (f % 2), x + w + (f % 2), y, "R")
        for (x, y, ph) in ((8, 8, 0), (14, 12, 1), (20, 7, 2), (24, 12, 0), (11, 13, 2), (18, 9, 1)):
            if (f + ph) % 3 != 2:
                cv.put(x, y, "o" if (f + ph) % 3 == 0 else "y")
                if (f + ph) % 3 == 1:
                    cv.put(x + 1, y - 1, "Y")
        for x in range(4, 29, 5):
            cv.put(x, 10 + (x % 3) - 1, "e")
        put("areas/kitchen/scald_f%d" % f, to_img(cv))
    for f in range(4):                                               # a flour cloud (soft: no dark edge)
        cv = Canvas(24, 20)
        blobs = [(8, 11, 5.5), (15, 9, 6.0), (12, 14, 5.0), (18, 14, 4.2), (6, 15, 3.6)]
        for j, (x, y, r) in enumerate(blobs):
            rr = r + (0.6 if (f + j) % 2 else 0.0) - (0.4 if f == 3 else 0.0)
            disc(cv, x + ((f + j) % 3) * 0.5, y - (f % 2) * 0.5, rr, "A")
        for y in range(20):
            for x in range(24):
                if cv.get(x, y) == "A":
                    if cv.get(x, y + 1) == "." or cv.get(x + 1, y) == ".":
                        cv.c[y][x] = "a"
                    elif cv.get(x, y - 1) == "." or cv.get(x - 1, y) == ".":
                        cv.c[y][x] = "w"
        put("areas/kitchen/flour_f%d" % f, to_img(cv))


def build_library_props():
    for k in ("l", "m", "r"):                                        # the rails a sliding shelf runs on
        cv = Canvas(16, 16)
        for x in range(1, 16, 5):                                    # sleepers under the rails
            vline(cv, x, 9, 15, "j")
        for y in (11, 14):
            hline(cv, 0, 15, y, "i")
            hline(cv, 0, 15, y - 1, "S")
        if k in ("l", "r"):
            x0 = 0 if k == "l" else 13
            rect(cv, x0, 8, 3, 7, "3")
            hline(cv, x0, x0 + 2, 8, "H")
        put("areas/library/rail_%s" % k, to_img(cv))
    # the hidden shelf-door: a built-in bookcase with one book sticking out; then it swings open on its hinge
    rng = random.Random(61)
    base = Canvas(32, 30)
    rect(base, 0, 0, 32, 30, "J")
    hline(base, 0, 31, 0, "j")
    for (y0, y1) in ((2, 8), (11, 17), (20, 27)):
        rect(base, 1, y0, 30, y1 - y0 + 1, "1")
        books_row(base, 1, 30, y0, y1, rng)
        hline(base, 1, 30, y1 + 1, "j")
    vline(base, 0, 0, 29, "j")
    vline(base, 31, 0, 29, "u")
    odd = Canvas(32, 30)
    for f in range(4):
        cv = Canvas(32, 30)
        if f == 0:
            cv.c = [r[:] for r in base.c]
            rect(cv, 19, 12, 3, 6, "9")                              # the odd book, pulled half out
            vline(cv, 21, 12, 17, "0")
            hline(cv, 19, 21, 12, "y")
            put("areas/library/shelfdoor_f0", render(cv))
            continue
        rect(cv, 0, 0, 32, 30, "1")                                  # the dark passage behind
        rect(cv, 0, 0, 32, 2, "J")
        vline(cv, 0, 0, 29, "J")
        vline(cv, 31, 0, 29, "J")
        w = (24, 14, 6)[f - 1]                                       # the case swings on its left hinge
        for y in range(30):
            for x in range(w):
                sx = int(x * 32 / w)
                cv.put(x, y, base.c[y][sx] if base.c[y][sx] != "." else "J")
        vline(cv, w - 1, 0, 29, "j")
        put("areas/library/shelfdoor_f%d" % f, render(cv))


def build_attic_props():
    def lantern(lit):
        cv = Canvas(10, 15)
        post = Canvas(10, 15)
        rect(cv, 4, 0, 2, 2, "H")                                    # the hook ring
        rect(cv, 2, 2, 6, 2, "H")
        hline(cv, 2, 7, 2, "i")
        rect(cv, 1, 4, 8, 8, "H")
        rect(cv, 2, 5, 6, 6, "Y" if lit else "2")
        vline(cv, 4, 5, 10, "H")
        vline(cv, 5, 5, 10, "H")
        rect(cv, 1, 12, 8, 2, "H")
        hline(cv, 1, 8, 12, "i")
        if lit:
            rect(cv, 2, 5, 2, 6, "y")
            rect(cv, 6, 5, 2, 6, "y")
            post.put(2, 6, "w")
            post.put(6, 6, "w")
        else:
            cv.put(2, 5, "s")
            cv.put(6, 5, "s")
        return render(cv, post)
    put("areas/attic/lantern_off", lantern(False))
    put("areas/attic/lantern_on", lantern(True))
    cv = Canvas(10, 15)                                              # the lit glass alone (drawn unlit, it glows)
    rect(cv, 2, 5, 2, 6, "y")
    rect(cv, 6, 5, 2, 6, "y")
    cv.put(2, 6, "w")
    cv.put(6, 6, "w")
    put("areas/attic/lantern_glow", to_img(cv))
    # the round window high in the attic wall, its cross of glazing bars, and the moonlit glass
    cv = Canvas(22, 22)
    ring_lit(cv, 11, 11, 8.4, 10.6, "F", "f", "R")
    disc(cv, 11, 11, 8.4, "2")
    vline(cv, 10, 3, 18, "F")
    vline(cv, 11, 3, 18, "R")
    hline(cv, 3, 18, 10, "F")
    hline(cv, 3, 18, 11, "R")
    put("areas/attic/window_round", render(cv))
    g = Canvas(22, 22)
    for y in range(22):
        for x in range(22):
            if cv.get(x, y) == "2" and (x - 11) ** 2 + (y - 11) ** 2 < 70:
                g.put(x, y, "B" if x + y > 24 else ("b" if x + y > 16 else "h"))
    for (x, y) in ((6, 6), (14, 7), (7, 14)):
        if g.get(x, y) != ".":
            g.put(x, y, "w")
    put("areas/attic/window_round_glass", to_img(g))
    for f in range(4):                                               # a dust sheet whisked away
        cv = Canvas(20, 16)
        pts = [[(2, 12), (9, 4), (17, 6), (14, 13)], [(1, 9), (8, 2), (18, 4), (12, 12)],
               [(3, 6), (10, 1), (19, 5), (11, 10)], [(5, 5), (12, 2), (17, 6), (10, 8)]][f]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            for x in range(min(xs), max(xs) + 1):
                if _poly_inside(pts, x + 0.5, y + 0.5):
                    cv.put(x, y, "A")
        shade_edges(cv, "A", "w", "a", "a")
        for j in range(2):
            fx = pts[0][0] + 3 + 4 * j
            for y in range(16):
                if cv.get(fx, y) == "A":
                    cv.put(fx, y, "a")
        put("areas/attic/sheet_fly_f%d" % f, render(cv))
    # moonlight through the round window: a soft round pool crossed by the bars' shadow (smooth light texture)
    W, Hh = 72, 72
    ys, xs = np.mgrid[0:Hh, 0:W]
    u = (xs - W / 2.0) + (ys - Hh / 2.0) * 0.35
    v = (ys - Hh / 2.0)
    r = np.sqrt(u * u + v * v * 1.1)
    a = np.clip(1.0 - (r / (W * 0.46)) ** 2.2, 0.0, 1.0)
    bars = np.clip((np.minimum(np.abs(u - 1.5), np.abs(v + 0.5)) - 1.6) / 2.0, 0.0, 1.0)
    a = a * (0.45 + 0.55 * bars)
    im = np.zeros((Hh, W, 4), dtype=np.uint8)
    im[:, :, 0:3] = 255
    im[:, :, 3] = np.clip(a * 255.0, 0, 255).astype(np.uint8)
    MADE_LIGHT["areas/attic/light/moon_round"] = Image.fromarray(im, "RGBA")


def build_bolts():
    """The Dressmaker's pins: a diamond pin head (UX-02: dark rim all round, a white-hot core, the darkest tones
    of steel blue), turning between two frames."""
    shapes = [["...K...", "..KsK..", ".KBwBK.", "KsBwwsK", ".KBwBK.", "..KsK..", "...K..."],
              ["...K...", "..KBK..", ".KswsK.", "KBwwwBK", ".KswsK.", "..KBK..", "...K..."]]
    for f, rows in enumerate(shapes):
        cv = Canvas(7, 7)
        cv.blit(rows)
        put("fx/bolt_pin_f%d" % f, to_img(cv))


EXTRA_BUILDERS.extend([build_crab, build_flour, build_worm, build_ink, build_mannequin, build_trunk,
                       build_stockpot, build_librarian, build_form,
                       build_kitchen_props, build_library_props, build_attic_props, build_bolts])


# =========================================================================== main
SHEET_PAL = AR.sheet_palette()


def check(name, im):
    a = np.array(im)
    assert set(np.unique(a[:, :, 3])) <= {0, 255}, name + " has semi-transparent pixels"
    cols = {tuple(int(v) for v in p[:3]) for p in a.reshape(-1, 4) if p[3]}
    bad = cols - SHEET_PAL
    assert not bad, "%s uses colours outside the 0x72 palette: %s" % (name, ["#%02x%02x%02x" % c for c in bad])


def contact(names, path, scale=4, cols=8, bg=(36, 30, 36, 255)):
    ims = [(n, MADE[n]) for n in names if n in MADE]
    if not ims:
        return
    cw = max(i.width for _, i in ims) * scale + 6
    ch = max(i.height for _, i in ims) * scale + 6
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGBA", (cw * min(cols, len(ims)), ch * rows), bg)
    for k, (n, im) in enumerate(ims):
        out.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST),
                            ((k % cols) * cw + 3, (k // cols) * ch + 3 + (ch - 6 - im.height * scale)))
    out.save(path)


def preview_room(theme, variant, path):
    """A room background at x3 with some of its decor laid out the way RoomDecor would."""
    room = MADE["rooms/room_%s%s" % (theme, "" if variant == 0 else "_%d" % variant)].copy()
    walls = [n for n in MADE if n.startswith("decor/wall_%s" % theme)]
    x = 32
    for n in walls:
        im = MADE[n]
        if x + im.width > 240:
            break
        room.alpha_composite(im, (x, 16))
        x += im.width + 16
    room.alpha_composite(MADE["decor/sconce_%s_side" % theme], (15, 40))
    room.alpha_composite(flip(MADE["decor/sconce_%s_side" % theme]), (257 - 8, 40))
    props = [n for n in MADE if n.startswith("decor/prop_%s" % theme)]
    for k, n in enumerate(props):
        im = MADE[n]
        cx, cy = 16 + 16 * (2 + (k % 6) * 2), 32 + 16 * (2 + (k // 6) * 3) + 16
        room.alpha_composite(im, (cx, cy - im.height))
    decals = [n for n in MADE if n.startswith("areas/%s/floor_" % theme) or n.startswith("areas/%s/foot_" % theme)]
    for k, n in enumerate(decals):
        im = MADE[n]
        room.alpha_composite(im, (40 + 30 * (k % 7), 140 + 14 * (k // 7)))
    room.resize((272 * 3, 192 * 3), Image.NEAREST).save(path)


def main():
    review = None
    for a in sys.argv[1:]:
        if a.startswith("--review"):
            review = a.split("=", 1)[1] if "=" in a else "/tmp/claude-0/review_areas"
    build_rooms()
    build_sconces()
    build_wall_pieces()
    build_floor_decals()
    build_furniture()
    for fn in EXTRA_BUILDERS:
        fn()
    for name, im in MADE.items():
        check(name, im)
        p = os.path.join(ART, name + ".png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p, optimize=True)
    for name, im in MADE_LIGHT.items():
        p = os.path.join(ART, name + ".png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p, optimize=True)
    print("wrote %d files" % (len(MADE) + len(MADE_LIGHT)))
    if review:
        os.makedirs(review, exist_ok=True)
        for th in ("kitchen", "library", "attic"):
            for v in range(3):
                preview_room(th, v, os.path.join(review, "room_%s_%d_3x.png" % (th, v)))
            contact([n for n in MADE if n.startswith(("decor/wall_%s" % th, "decor/side_%s" % th, "decor/sconce_%s" % th))],
                    os.path.join(review, "walls_%s.png" % th), 5, 6)
            contact([n for n in MADE if n.startswith("decor/prop_%s" % th)], os.path.join(review, "props_%s.png" % th), 5, 8)
            contact([n for n in MADE if n.startswith(("areas/%s/floor" % th, "areas/%s/foot" % th))],
                    os.path.join(review, "decals_%s.png" % th), 6, 8)
            contact([n for n in MADE if n.startswith("areas/%s/" % th) and not n.split("/")[-1].startswith(("floor", "foot"))
                     and "_idle_" not in n and "_run_" not in n and "_atk_" not in n],
                    os.path.join(review, "gimmick_%s.png" % th), 5, 8)
            for kind in CREATURES.get(th, []):
                contact([n for n in MADE if n.startswith("areas/%s/%s_" % (th, kind))],
                        os.path.join(review, "creature_%s.png" % kind), 6 if MADE["areas/%s/%s_idle_f0" % (th, kind)].height <= 24 else 4, 12)
        contact([n for n in MADE if n.startswith("fx/")], os.path.join(review, "bolts.png"), 10, 4)


if __name__ == "__main__":
    main()
