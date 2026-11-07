#!/usr/bin/env python3
"""Wax & Wane - THE CLOCK TOWER (endgame stream): the secret fifth floor, its lodgers, the Keeper of
Hours, the ladder of light, Moonwick's silver dish and the ending scenes.

    python3 tools/art_tower.py                 writes the files listed below
    python3 tools/art_tower.py --review=<dir>  also writes x4 contact sheets and room previews

Same rules as every other art tool here (tools/art_rooms.py, art_decor.py, art_monsters.py): the
0x72 DungeonTileset II palette only (asserted for every file), a 1 px #222222 outline round every
shape, light from the top-left, flat fills with one shade, no anti-aliasing and no semi-transparent
pixels. The only smooth image is the moonlight texture in tower/light/ (a PointLight2D texture).
Round things (gears, dials, discs) are rasterised from fixed integer maths, so every run writes the
same PNGs.

Output
  rooms/room_tower.png, room_tower_1.png, room_tower_2.png   floor 5 backgrounds (RoomDecor picks one)
  decor/sconce_tower_top|side, wall_tower_*, side_tower,
        prop_tower_case, prop_tower_crate                    pieces RoomDecor / Room load by name
  tower/room_keeper.png        the Keeper's room: a brass clock dial inlaid in the boards
  tower/gear_f0..5             a big wall gear turning (6 frames, one tooth = 6 frames)
  tower/window_slats(+_glow)   a slatted belfry window; the glow layer is drawn unshaded
  tower/floor_*                floor decals            tower/ladder_f0..3   the ladder of light
  tower/holder_silver          Moonwick's dish         tower/end_*          the ending scenes
  tower/light/moon_slats.png   moonlight through slats (smooth light texture)
  monsters/cog_sentry_*, minute_wraith_*, keeper_*       (idle / run / atk, 4 frames each)
  fx/bolt_cog_f0..1            the Keeper's and the sentries' brass cog bolts
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_rooms as AR      # noqa: E402  room builder, palette check
import art_monsters as AM   # noqa: E402  Canvas, render (outline pass), palette letters

ROOT = AR.ROOT
ART = os.path.join(ROOT, "assets", "art")

# extra palette letters (all 0x72 colours) on top of art_monsters' PAL
AM.PAL.update({
    "j": "#3b3332", "J": "#38262d", "u": "#302c2b", "z": "#2b2929", "Y": "#ffcc68", "Z": "#ffad3b",
    "N": "#1f1833", "M": "#414859", "O": "#323e4f", "Q": "#243f4c", "W": "#38607c", "H": "#545454",
    "I": "#3f3f3f", "L": "#4d4d4d", "E": "#494949", "U": "#140c11", "C": "#23151d", "V": "#3e5442",
})
PAL = AM.PAL
Canvas = AM.Canvas
render = AM.render

MADE = {}    # relative path (under assets/art, no .png) -> image


def put(name, im):
    MADE[name] = im


def rgb(ch):
    return AM.rgba(PAL[ch])


# --------------------------------------------------------------------------- canvas helpers
def rect(cv, x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            cv.put(xx, yy, ch)


def line(cv, x0, y0, x1, y1, ch):
    """Bresenham, inclusive."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        cv.put(x0, y0, ch)
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def disc(cv, cx, cy, r, ch):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                cv.put(x, y, ch)


def ring_lit(cv, cx, cy, r0, r1, base, hi, sh, top=None):
    """A flat ring lit from the top-left: the outer edge facing the light gets `hi` (and `top` on the
    very top-left), the edge facing away gets `sh`."""
    for y in range(int(cy - r1 - 1), int(cy + r1 + 2)):
        for x in range(int(cx - r1 - 1), int(cx + r1 + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if r0 <= d <= r1:
                k = (-dx - dy) / (d * 1.4142 + 1e-6)
                ch = base
                if k > 0.45:
                    ch = hi
                    if top and k > 0.85 and d > r1 - 1.2:
                        ch = top
                elif k < -0.45:
                    ch = sh
                cv.put(x, y, ch)


def to_img(cv):
    """Canvas -> image without an outline pass."""
    im = Image.new("RGBA", (cv.w, cv.h), (0, 0, 0, 0))
    px = im.load()
    for y in range(cv.h):
        for x in range(cv.w):
            ch = cv.c[y][x]
            if ch != ".":
                px[x, y] = rgb(ch)
    return im


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def remap(im, mapping):
    return AR.remap(im, mapping)


# =========================================================================== rooms
# Floor 5 is wood and brass: dark umber boards, wainscot panels with a brass rail on the top wall,
# the walls' stone caps in a dark umber ramp. Night comes from the floor's CanvasModulate and the
# moonlit windows (RoomDecor + Tower.dress), so the art itself stays neutral.
O, S1, S2, S3, S4 = AR.O, AR.S1, AR.S2, AR.S3, AR.S4
WOOD = {"gap": "#21141b", "fill": "#3b3332", "hi": "#483b3a", "grain": "#302c2b", "nail": "#545454",
        "alt": "#302c2b", "alt_hi": "#3b3332"}
AR.THEMES["tower"] = dict(
    wall={O: "#21141b", S1: "#2b2929", S2: "#3b3332", S3: "#775c55", S4: "#aa8d7a"},
    floor={},
    ring={"#3b3332": "#302c2b", "#483b3a": "#3b3332", "#302c2b": "#2b2929"},
    shadow={"#3b3332": "#2b2929", "#483b3a": "#302c2b", "#302c2b": "#21141b", "#2b2929": "#21141b"},
    seed=1205,
)
FX0, FY0, FX1, FY1 = AR.FX0, AR.FY0, AR.FX1, AR.FY1


def _hex(c):
    return AR.rgb(c) + (255,)


def _board_v(px, x0, y0, x1, y1, fill, hi, rng):
    """One board running north-south: lit left edge and top end, a gap on the right and bottom."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = fill
            if x == x1 - 1 or y == y1 - 1:
                c = WOOD["gap"]
            elif x == x0 or y == y0:
                c = hi
            px[x, y] = _hex(c)
    for _ in range((y1 - y0) // 12):
        gx = rng.randrange(x0 + 2, max(x0 + 3, x1 - 2))
        gy = rng.randrange(y0 + 2, max(y0 + 3, y1 - 5))
        for k in range(rng.randrange(2, 5)):
            if gy + k < y1 - 1:
                px[gx, gy + k] = _hex(WOOD["grain"])
    if y1 - y0 >= 12:
        for ny in (y0 + 2, y1 - 3):
            px[x0 + 2, ny] = _hex(WOOD["nail"])
            px[x1 - 3, ny] = _hex(WOOD["nail"])


def paint_boards(floor, rng):
    """Long boards running from the door at the top to the door at the bottom, joints staggered."""
    px = floor.load()
    for bx in range(FX0, FX1, 8):
        y = FY0 - rng.randrange(0, 48)
        while y < FY1:
            ln = rng.randrange(40, 96)
            a, b = max(y, FY0), min(y + ln, FY1)
            if b - a >= 3:
                _board_v(px, bx, a, bx + 8, b, WOOD["fill"], WOOD["hi"], rng)
            y += ln
    return {}, {}


def paint_parquet(floor, rng):
    """Basket-weave parquet: each tile is two boards, turned a quarter from its neighbours."""
    px = floor.load()
    for ty in range(9):
        for tx in range(15):
            x0, y0 = FX0 + 16 * tx, FY0 + 16 * ty
            if (tx + ty) % 2 == 0:
                for k in (0, 8):   # two boards lying east-west
                    for y in range(y0 + k, y0 + k + 8):
                        for x in range(x0, x0 + 16):
                            c = WOOD["alt"]
                            if y == y0 + k + 7 or x == x0 + 15:
                                c = WOOD["gap"]
                            elif y == y0 + k or x == x0:
                                c = WOOD["alt_hi"]
                            px[x, y] = _hex(c)
            else:
                for k in (0, 8):   # two boards standing north-south
                    _board_v(px, x0 + k, y0, x0 + k + 8, y0 + 16, WOOD["fill"], WOOD["hi"], rng)
    return {}, {}


GRATE_C = (136, 104)


def paint_grate(floor, rng):
    """Boards, and in the middle a round brass grate over the clockwork turning below the floor."""
    paint_boards(floor, rng)
    cv = Canvas(48, 48)
    disc(cv, 24, 24, 20, "1")
    gear_into(cv, 30.5, 30.5, 15, 10, 0.21, "I", "L", "z", "z", clip=(24, 24, 19.5))   # wheels under the floor
    gear_into(cv, 11.5, 13.5, 9, 7, 0.05, "I", "L", "z", "z", clip=(24, 24, 19.5))
    for i in range(-19, 20, 5):                                     # the bars
        for y in range(48):
            for x in (24 + i, 25 + i):
                if (x + 0.5 - 24) ** 2 + (y + 0.5 - 24) ** 2 <= 19.5 ** 2:
                    cv.put(x, y, "k")
    ring_lit(cv, 24, 24, 19.5, 22.5, "c", "o", "R", "y")
    im = render(cv)
    floor.alpha_composite(im, (GRATE_C[0] - 24, GRATE_C[1] - 24))
    return {}, {}


def wainscot(room):
    """Wood panels and a brass rail on the top wall face (y 16..31)."""
    px = room.load()
    for x in range(16, 256):
        i = (x - 16) % 16
        col = {16: "#21141b", 17: "#ee8e2e", 18: "#c56025", 19: "#21141b", 30: "#302c2b", 31: "#21141b"}
        for y in range(16, 32):
            if y in col:
                c = col[y]
                if y == 17 and i in (3, 12):
                    c = "#facb3e"                     # rivets on the rail
            elif i == 0:
                c = "#21141b"
            elif i == 1:
                c = "#483b3a"
            elif 3 <= i <= 13 and 21 <= y <= 28:
                if i == 3 or y == 21:
                    c = "#302c2b"                     # the panel's sunk edge (in shadow, top-left)
                elif i == 13 or y == 28:
                    c = "#483b3a"                     # its lit lower-right lip
                else:
                    c = "#3b3332"
            else:
                c = "#38262d"
            px[x, y] = _hex(c)


def build_rooms():
    variants = [("room_tower", paint_boards), ("room_tower_1", paint_parquet), ("room_tower_2", paint_grate)]
    for name, painter in variants:
        AR.FLOOR_VARIANTS["tower"] = [painter]
        room = AR.build_room("tower", variant=1)
        wainscot(room)
        put("rooms/" + name, room)
    AR.FLOOR_VARIANTS["tower"] = [paint_dial]
    room = AR.build_room("tower", variant=1)
    wainscot(room)
    put("tower/room_keeper", room)


DIAL_C = (136, 104)    # room centre: the Keeper stands on it and its hands sweep from it


def paint_dial(floor, rng):
    """The Keeper's room: boards, and a great brass dial inlaid in the floor (12 marks, a ring)."""
    paint_boards(floor, rng)
    cv = Canvas(136, 136)
    c = 68
    disc(cv, c, c, 62, "u")                          # darker inlay inside the ring
    for y in range(136):                             # its boards run east-west, against the floor
        for x in range(136):
            if cv.c[y][x] == "u" and y % 8 == 7:
                cv.c[y][x] = "K"
    ring_lit(cv, c, c, 58.5, 61.5, "c", "o", "R", "y")
    ring_lit(cv, c, c, 40.5, 41.5, "R", "c", "m")
    for h in range(12):
        a = h * math.pi / 6
        big = h % 3 == 0
        for r in range(46, 56 if big else 52):
            x, y = c + math.sin(a) * r, c - math.cos(a) * r
            cv.put(int(math.floor(x)), int(math.floor(y)), "o" if not big else "y")
            if big:
                cv.put(int(math.floor(x + math.cos(a))), int(math.floor(y + math.sin(a))), "c")
    for m in range(60):
        if m % 5:
            a = m * math.pi / 30
            cv.put(int(math.floor(c + math.sin(a) * 56)), int(math.floor(c - math.cos(a) * 56)), "R")
    disc(cv, c, c, 5.5, "R")
    disc(cv, c, c, 4, "c")
    disc(cv, c, c, 1.5, "K")
    im = to_img(cv)
    floor.alpha_composite(im, (DIAL_C[0] - c, DIAL_C[1] - c))
    return {}, {}


# =========================================================================== gears
def gear_into(cv, cx, cy, R, teeth, phase, base, hi, sh, hole=".", solid=False, clip=None):
    """A spoked gear (rim, teeth, 5 spokes, hub). `phase` turns it (radians). `solid` fills the
    wheel (small gears); `clip` = (cx, cy, r) keeps only the part inside that circle."""
    rb = R - 2.0
    step = 2 * math.pi / teeth
    for y in range(int(cy - R - 2), int(cy + R + 3)):
        for x in range(int(cx - R - 2), int(cx + R + 3)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > R + 0.01:
                continue
            if clip and (x + 0.5 - clip[0]) ** 2 + (y + 0.5 - clip[1]) ** 2 > clip[2] ** 2:
                continue
            th = math.atan2(dy, dx) - phase
            tooth = (th % step) < step * 0.48
            if d > rb and not tooth:
                continue
            inner = d < rb - 2.6 and not solid
            if solid and d < 1.3 and hole != ".":
                cv.put(x, y, hole)
                continue
            if inner:
                sp = False
                for k in range(5):
                    a = phase + k * 2 * math.pi / 5
                    # distance from the spoke's centre line
                    px_ = dx * math.cos(a) + dy * math.sin(a)
                    py_ = -dx * math.sin(a) + dy * math.cos(a)
                    if px_ > 0 and abs(py_) < 1.45:
                        sp = True
                if d < 3.6:
                    sp = d > 1.3 or hole != "."
                    if d <= 1.3 and hole != ".":
                        cv.put(x, y, hole)
                        continue
                if not sp:
                    continue
            k = (-dx - dy) / (d * 1.4142 + 1e-6)
            ch = base
            if (d > rb - 1.0 or d < 3.6) and k > 0.4:
                ch = hi
            elif (d > rb - 1.0) and k < -0.4:
                ch = sh
            elif inner and d >= 3.6 and k < -0.5:
                ch = sh
            cv.put(x, y, ch)


def tiny_cog(cv, cx, cy, r, teeth, base, hi, sh, hole="k", tooth=None):
    """A small cog that stays clean at 5-9 px: a round body, single-pixel teeth at `teeth`
    (offsets from the centre cell), a hole, lit from the top-left."""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= r * r + r * 0.6:
                ch = base
                if dx + dy <= -r + 0.5 and (dx < 0 or dy < 0):
                    ch = hi
                elif dx + dy >= r - 0.5:
                    ch = sh
                cv.put(x, y, ch)
    for tx, ty in teeth:
        cv.put(cx + tx, cy + ty, tooth or (hi if tx + ty < 0 else (sh if tx + ty > 0 else base)))
    if hole:
        cv.put(cx, cy, hole)


def build_gears():
    for f in range(6):
        cv = Canvas(34, 34)
        gear_into(cv, 17, 17, 15.5, 10, f * (2 * math.pi / 10) / 6, "c", "o", "R")
        put("tower/gear_f%d" % f, render(cv))


# =========================================================================== decor pieces
def build_sconces():
    m = {"#545454": "#8f4029", "#3f3f3f": "#62232f", "#333333": "#38262d", "#b6cbcf": "#facb3e"}
    put("decor/sconce_tower_top", remap(Image.open(os.path.join(ART, "decor/sconce_belfry_top.png")).convert("RGBA"), m))
    put("decor/sconce_tower_side", remap(Image.open(os.path.join(ART, "decor/sconce_belfry_side.png")).convert("RGBA"), m))


def dial_into(cv, cx, cy, r, hour, minute, face="w", shade="A", hand="k"):
    """A small clock face: cream dial, four marks, hands showing hour:minute."""
    disc(cv, cx, cy, r, face)
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.c[y][x] == face:
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if math.hypot(dx, dy) > r - 1.6 and dx + dy > 1.0:
                    cv.c[y][x] = shade
    ic, jc = int(math.floor(cx)), int(math.floor(cy))
    for a in range(4):
        ang = a * math.pi / 2
        cv.put(int(math.floor(cx + math.sin(ang) * (r - 1.2))), int(math.floor(cy - math.cos(ang) * (r - 1.2))), "a")
    am = minute * math.pi / 30
    ah = (hour % 12 + minute / 60) * math.pi / 6
    line(cv, ic, jc, int(round(cx - 0.5 + math.sin(am) * (r - 1.6))), int(round(cy - 0.5 - math.cos(am) * (r - 1.6))), hand)
    line(cv, ic, jc, int(round(cx - 0.5 + math.sin(ah) * (r - 3.2))), int(round(cy - 0.5 - math.cos(ah) * (r - 3.2))), hand)


def build_wall_pieces():
    # a bracket clock on the wainscot: every clock in the tower says one o'clock
    cv = Canvas(30, 22)
    rect(cv, 3, 4, 24, 17, "J")
    rect(cv, 4, 5, 22, 1, "j")
    rect(cv, 3, 4, 1, 17, "j")
    rect(cv, 6, 1, 18, 3, "c")
    rect(cv, 7, 1, 16, 1, "o")
    rect(cv, 12, 0, 6, 1, "y")
    ring_lit(cv, 15, 12, 6.5, 8.2, "c", "o", "R", "y")
    dial_into(cv, 15, 12, 6.5, 1, 0)
    rect(cv, 2, 20, 26, 2, "R")
    rect(cv, 3, 20, 24, 1, "c")
    put("decor/wall_tower_clock", render(cv))
    # a half wheel set into the panels
    cv = Canvas(16, 16)
    gear_into(cv, 8, 9, 7.5, 8, 0.2, "c", "o", "R", hole="K", solid=True)
    ring_lit(cv, 8, 9, 3.2, 4.2, "R", "c", "m")
    rect(cv, 0, 15, 16, 1, ".")
    put("decor/wall_tower_gear", render(cv))
    # chains and two clock weights
    cv = Canvas(16, 16)
    for x0, top, ln in ((4, 0, 6), (11, 0, 9)):
        for y in range(top, top + ln):
            cv.put(x0, y, "H" if y % 2 else "I")
        rect(cv, x0 - 2, top + ln, 5, 6, "o")
        rect(cv, x0 - 2, top + ln, 1, 6, "y")
        rect(cv, x0 + 2, top + ln, 1, 6, "c")
        rect(cv, x0 - 2, top + ln + 5, 5, 1, "R")
        cv.put(x0, top + ln - 1, "y")
    put("decor/wall_tower_weights", render(cv))
    # a shelf: oil can, a jar of screws, springs
    cv = Canvas(32, 16)
    rect(cv, 1, 11, 30, 2, "F")
    rect(cv, 1, 11, 30, 1, "f")
    rect(cv, 3, 13, 2, 3, "J")
    rect(cv, 27, 13, 2, 3, "J")
    rect(cv, 4, 4, 7, 7, "c")       # oil can
    rect(cv, 4, 4, 2, 7, "o")
    rect(cv, 10, 4, 1, 7, "R")
    rect(cv, 6, 2, 3, 2, "R")
    line(cv, 11, 6, 14, 3, "R")
    rect(cv, 16, 5, 6, 6, "S")     # jar
    rect(cv, 16, 5, 1, 6, "h")
    rect(cv, 16, 4, 6, 1, "c")
    for (x, y) in ((18, 8), (20, 7), (19, 9), (17, 6)):
        cv.put(x, y, "i")
    for k in range(3):              # a spring lying down
        rect(cv, 24 + 2 * k, 7, 1, 4, "H" if k % 2 else "S")
    put("decor/wall_tower_shelf", render(cv))
    # side wall: a chain running to a weight
    cv = Canvas(8, 16)
    for y in range(0, 9):
        cv.put(3, y, "H" if y % 2 else "I")
    rect(cv, 1, 9, 5, 6, "o")
    rect(cv, 1, 9, 1, 6, "y")
    rect(cv, 5, 9, 1, 6, "c")
    rect(cv, 1, 14, 5, 1, "R")
    put("decor/side_tower", render(cv))
    # slatted window (louvres) in the wainscot, with the night sky between the slats
    cv = Canvas(16, 16)
    rect(cv, 2, 1, 12, 14, "J")
    rect(cv, 3, 2, 10, 12, "W")
    for y in (3, 6, 9, 12):
        rect(cv, 3, y, 10, 2, "j")
        rect(cv, 3, y, 10, 1, "4")
    rect(cv, 2, 1, 12, 1, "c")
    rect(cv, 2, 14, 12, 1, "R")
    im = render(cv)
    put("tower/window_slats", im)
    glow = Canvas(16, 16)
    for y in (2, 5, 8, 11):
        rect(glow, 3, y, 10, 1, "h")
        rect(glow, 9, y, 4, 1, "S")
    put("tower/window_slats_glow", to_img(glow))


def build_props():
    # a long-case clock (template B): 16 x 30, anchored bottom-centre
    cv = Canvas(16, 30)
    rect(cv, 2, 1, 12, 11, "J")            # hood
    rect(cv, 1, 0, 14, 2, "j")
    rect(cv, 2, 0, 12, 1, "4")
    rect(cv, 6, -1, 4, 1, "c")
    ring_lit(cv, 8, 6.5, 4.0, 5.2, "c", "o", "R", "y")
    dial_into(cv, 8, 6.5, 4.0, 1, 0)
    rect(cv, 3, 12, 10, 14, "J")           # trunk
    rect(cv, 3, 12, 1, 14, "j")
    rect(cv, 5, 14, 6, 9, "1")             # its glass and the pendulum
    rect(cv, 8, 14, 1, 6, "R")
    disc(cv, 8.5, 20.5, 1.6, "o")
    cv.put(7, 19, "y")
    rect(cv, 5, 14, 6, 1, "U")
    rect(cv, 2, 26, 12, 3, "j")            # plinth
    rect(cv, 2, 26, 12, 1, "4")
    rect(cv, 2, 29, 12, 1, "x")
    for x in range(2, 14):
        cv.put(x, 29, ".")
    im = render(cv)
    shadow = Image.new("RGBA", (16, 30), (0, 0, 0, 0))
    sp = shadow.load()
    for x in range(1, 15):
        sp[x, 29] = AM.rgba("#21141b")
    shadow.alpha_composite(im)
    put("decor/prop_tower_case", shadow)
    # a crate of spare wheels
    cv = Canvas(16, 16)
    rect(cv, 1, 6, 14, 9, "F")
    rect(cv, 1, 6, 14, 1, "f")
    rect(cv, 1, 6, 1, 9, "f")
    rect(cv, 1, 10, 14, 1, "R")
    tiny_cog(cv, 5, 5, 3, [(0, -4), (4, 0), (-4, 0), (3, -3), (-3, -3)], "o", "y", "c")
    tiny_cog(cv, 11, 5, 2, [(0, -3), (3, 0), (-2, -2), (2, -2)], "S", "w", "i")
    im = render(cv)
    sh = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    spx = sh.load()
    for x in range(1, 16):
        spx[x, 15] = AM.rgba("#21141b")
    sh.alpha_composite(im)
    put("decor/prop_tower_crate", sh)


def build_floor_decals():
    cv = Canvas(13, 9)
    tiny_cog(cv, 4, 4, 2, [(0, -3), (3, 0), (0, 3), (-3, 0), (2, -2), (-2, 2)], "c", "o", "R")
    tiny_cog(cv, 9, 5, 1, [(0, -2), (2, 0), (0, 2), (-2, 0)], "S", "w", "i")
    put("tower/floor_cogs", render(cv))
    cv = Canvas(10, 6)
    for k in range(4):
        rect(cv, 1 + 2 * k, 1, 1, 4, "S" if k % 2 == 0 else "i")
        cv.put(2 + 2 * k, 1 if k % 2 == 0 else 4, "H")
    put("tower/floor_spring", render(cv))
    cv = Canvas(11, 6)
    for (x, y) in ((1, 1), (4, 3), (7, 1), (9, 4)):
        cv.put(x, y, "S")
        cv.put(x + 1, y, "i")
    put("tower/floor_screws", render(cv))
    cv = Canvas(10, 6)
    rect(cv, 1, 1, 3, 4, "o")
    rect(cv, 2, 2, 1, 2, "k")
    rect(cv, 4, 2, 5, 2, "c")
    cv.put(4, 2, "y")
    cv.put(8, 1, "c")
    put("tower/floor_key", render(cv))
    cv = Canvas(12, 6)
    rect(cv, 2, 1, 8, 4, "C")
    rect(cv, 1, 2, 10, 2, "C")
    rect(cv, 4, 2, 3, 1, "J")
    put("tower/floor_oil", to_img(cv))
    cv = Canvas(12, 9)          # a fallen clock weight at the wall foot
    rect(cv, 1, 3, 10, 5, "o")
    rect(cv, 1, 3, 10, 1, "y")
    rect(cv, 1, 7, 10, 1, "c")
    rect(cv, 10, 3, 1, 5, "R")
    rect(cv, 0, 4, 1, 3, "H")
    put("tower/floor_weight", render(cv))


# =========================================================================== the ladder of light
def build_ladder():
    H = 72
    for f in range(4):
        cv = Canvas(18, H)
        post = Canvas(18, H)
        for y in range(H):
            fade = y < 22
            if fade and (y * 7 + f * 3) % (3 + (22 - y) // 5) != 0:
                continue
            for x in (3, 14):
                cv.put(x, y, "Y" if not fade else "w")
            cv.put(4, y, "y" if not fade else ".")
            cv.put(13, y, "o" if not fade else ".")
        for y in range(H - 5, 18, -8):
            band = ((H - y) // 8 + f) % 4 == 0
            for x in range(4, 14):
                cv.put(x, y, "w" if band else "Y")
                cv.put(x, y + 1, "y" if band else "o")
        for k in range(10):     # motes rising round it
            yy = (H - 1 - (k * 13 + f * 5) % (H - 4))
            xx = (k * 7 + 3) % 18
            if cv.get(xx, yy) == ".":
                post.put(xx, yy, "w" if k % 3 else "Y")
        im = to_img(cv)
        p2 = to_img(post)
        im.alpha_composite(p2)
        put("tower/ladder_f%d" % f, im)


# =========================================================================== Moonwick's dish
def build_holder():
    im = Image.open(os.path.join(ART, "hero/holder.png")).convert("RGBA")
    put("tower/holder_silver", remap(im, {"#facb3e": "#fdf7ed", "#ee8e2e": "#b6cbcf", "#c56025": "#7b8994",
                                          "#8f4029": "#545454"}))


# =========================================================================== bolts
def build_bolts():
    teeth = [[(1, -3), (3, 1), (-1, 3), (-3, -1)], [(-1, -3), (3, -1), (1, 3), (-3, 1)]]
    for f in range(2):
        cv = Canvas(7, 7)
        tiny_cog(cv, 3, 3, 2, teeth[f], "o", "y", "c", "R", tooth="Y")
        put("fx/bolt_cog_f%d" % f, to_img(cv))


# =========================================================================== creatures
def sentry_frame(legs=0, dy=0, eye="t", spin=0.0, key=0):
    cv = Canvas(16, 16)
    y0 = 4 + dy
    # winding key on top
    if key == 0:
        rect(cv, 6, y0 - 3, 5, 2, "y")
        rect(cv, 6, y0 - 3, 5, 1, "Y")
    else:
        rect(cv, 7, y0 - 3, 3, 2, "y")
        cv.put(8, y0 - 3, "Y")
    cv.put(8, y0 - 1, "c")
    # the drum: a brass wheel lying on its edge, teeth round the rim
    gear_into(cv, 8, y0 + 4.5, 6.4, 9, spin, "o", "y", "c")
    disc(cv, 8, y0 + 4.5, 3.6, "R")
    disc(cv, 8, y0 + 4.5, 2.8, "B" if eye == "t" else "m")
    disc(cv, 8, y0 + 4.5, 1.9, eye)
    cv.put(7, y0 + 3, "h" if eye == "t" else "y")
    # three iron legs
    lx = [(4, 12), (8, 12), (12, 12)]
    off = [(0, 0, 0), (1, 0, -1), (0, 0, 0), (-1, 0, 1)][legs]
    for (x, y), o in zip(lx, off):
        for yy in range(y0 + 9, 16):
            cv.put(x + (o if yy == 15 else 0), yy, "H")
        cv.put(x + o, 15, "I")
    return render(cv)


def build_sentry():
    idle = [sentry_frame(0, dy, "t", 0.0, k) for dy, k in ((0, 0), (0, 0), (1, 1), (0, 1))]
    run = [sentry_frame(l, (0, 1, 0, 1)[l], "t", l * 0.17, l % 2) for l in range(4)]
    atk = [sentry_frame(0, 0, "r", k * 0.17 * 2, k % 2) for k in range(4)]
    for anim, frames in (("idle", idle), ("run", run), ("atk", atk)):
        for i, im in enumerate(frames):
            put("monsters/cog_sentry_%s_f%d" % (anim, i), im)


def wraith_frame(k, dy=0, eyes="t", pull=0):
    cv = Canvas(16, 22)
    y = 2 + dy
    # hood and shroud
    rect(cv, 5, y, 6, 2, "S")
    rect(cv, 4, y + 1, 8, 4, "S")
    rect(cv, 3, y + 4, 10, 6, "S")
    rect(cv, 4, y + 2, 1, 7, "i")          # the shade down the back (left)
    rect(cv, 3, y + 6, 1, 4, "i")
    rect(cv, 6, y + 1, 3, 1, "h")
    # the face is a hole under the hood
    rect(cv, 6, y + 3, 4, 3, "K")
    rect(cv, 6, y + 2, 4, 1, "i")
    cv.put(6 + (1 if eyes != "w" else 1), y + 4, eyes)
    cv.put(9, y + 4, eyes)
    # the long tail, waving
    wave = [0, 1, 0, -1][k]
    for i, w in enumerate([10, 8, 7, 6, 5, 4, 3, 2]):
        yy = y + 10 + i
        sh = (wave if i >= 3 else 0) + (wave if i >= 6 else 0)
        x0 = 3 + (10 - w) // 2 + sh
        rect(cv, x0, yy, w, 1, "S")
        cv.put(x0, yy, "i")
        if w >= 4:
            cv.put(x0 + w - 1, yy, "h" if i < 2 else "S")
    for i in range(3):     # a ragged hem between the folds
        cv.put(4 + 3 * i + (k % 2), y + 10, "i")
    # the minute hand: a long brass blade held across the body, point up-right
    hx = -pull
    pts = [(2 + hx, 17 + dy), (13 + hx, 4 + dy)]
    line(cv, pts[0][0], pts[0][1], pts[1][0], pts[1][1], "y")
    line(cv, pts[0][0] + 1, pts[0][1], pts[1][0] + 1, pts[1][1], "c")
    tip = pts[1]
    rect(cv, tip[0] - 1, tip[1] - 1, 3, 2, "Y")
    cv.put(tip[0] + 1, tip[1] - 2, "Y")
    cv.put(tip[0] + 2, tip[1] - 2, "y")
    # a hand round the shaft
    cv.put(9 + hx, 9 + dy, "h")
    cv.put(10 + hx, 9 + dy, "h")
    return render(cv)


def build_wraith():
    idle = [wraith_frame(k, (0, 0, 1, 1)[k]) for k in range(4)]
    run = [wraith_frame(k, (0, 1, 1, 0)[k]) for k in range(4)]
    atk = [wraith_frame(k, (0, 0, 1, 1)[k], "w" if k % 2 else "r", 2 if k < 2 else 0) for k in range(4)]
    for anim, frames in (("idle", idle), ("run", run), ("atk", atk)):
        for i, im in enumerate(frames):
            put("monsters/minute_wraith_%s_f%d" % (anim, i), im)


# ---- THE KEEPER OF HOURS (48 x 56): a cloaked long-case clock with a dial for a face.
# Its two dial hands are drawn by the game (keeper.gd) on the dial centre KEEPER_DIAL.
KW, KH = 48, 56
KEEPER_DIAL = (24, 15)


def keeper_frame(swing=0, bob=0, arms="down", eyes="t", hem=0, glow=False):
    cv = Canvas(KW, KH)
    post = Canvas(KW, KH)
    cx = 24
    b = bob
    dx, dy = KEEPER_DIAL
    dy += b
    # plinth (never moves: the feet stay on the bottom row)
    rect(cv, 12, 51, 24, 5, "J")
    rect(cv, 12, 51, 24, 1, "j")
    rect(cv, 12, 51, 1, 5, "j")
    rect(cv, 13, 55, 3, 1, "c")
    rect(cv, 32, 55, 3, 1, "c")
    # the cloak: plum, falling from the hood to a ragged hem, open over the clock's trunk
    for y in range(24 + b, 51):
        t = (y - 24 - b) / max(1, 27 - b)
        half = int(11 + 7 * t)
        for x in range(cx - half, cx + half):
            cv.put(x, y, "v")
        cv.put(cx - half, y, "p")               # lit edge (light from the top-left)
        cv.put(cx + half - 1, y, "N")
        cv.put(cx + half - 2, y, "N")
    for x in range(cx - 18, cx + 18):           # folds and hem
        if (x - cx + 40) % 6 == 2:
            for y in range(36 + b, 50):
                if cv.get(x, y) == "v":
                    cv.put(x, y, "N")
        if (x + hem) % 3 == 0:
            cv.c[50][x] = "." if 0 <= x < KW else "."
    # trunk: dark wood, brass trim, a window with the pendulum
    rect(cv, 17, 29 + b, 14, 22 - b, "J")
    rect(cv, 17, 29 + b, 1, 22 - b, "j")
    rect(cv, 19, 32 + b, 10, 16 - b, "c")
    rect(cv, 19, 32 + b, 10, 1, "o")
    rect(cv, 28, 32 + b, 1, 16 - b, "R")
    rect(cv, 20, 33 + b, 8, 14 - b, "1")
    px_ = 24 + swing
    line(cv, 24, 33 + b, px_, 42, "c")
    disc(cv, px_ + 0.5, 43.5, 2.3, "o")
    cv.put(px_ - 1, 42, "y")
    # arms: segmented brass, a gear at the elbow, iron clamps for hands
    for side in (-1, 1):
        sx = cx + side * 14
        if arms == "down":
            line(cv, sx, 28 + b, sx + side * 3, 37 + b, "o")
            line(cv, sx - side, 28 + b, sx + side * 2, 37 + b, "c")
            disc(cv, sx + side * 3 + 0.5, 38.5 + b, 1.6, "y")
            line(cv, sx + side * 3, 39 + b, sx + side * 2, 45 + b, "o")
            rect(cv, sx + side * 2 - 1, 45 + b, 3, 2, "S")
            cv.put(sx + side * 2 - 1, 47 + b, "i")
            cv.put(sx + side * 2 + 1, 47 + b, "i")
        else:
            line(cv, sx, 28 + b, sx + side * 6, 22 + b, "o")
            line(cv, sx, 29 + b, sx + side * 6, 23 + b, "c")
            disc(cv, sx + side * 6 + 0.5, 21.5 + b, 1.6, "y")
            line(cv, sx + side * 6, 20 + b, sx + side * 7, 11 + b, "o")
            rect(cv, sx + side * 7 - 1, 8 + b, 3, 3, "S")
            cv.put(sx + side * 7 - 1, 7 + b, "i")
            cv.put(sx + side * 7 + 1, 7 + b, "i")
    # the hood: a pointed cowl round the dial
    for y in range(dy - 18, dy + 12):
        k = y - (dy - 18)
        half = min(16, 1 + k)
        if y > dy + 6:
            half = 16 - (y - dy - 6) // 2
        for x in range(dx - half, dx + half):
            if cv.get(x, y) in (".", "v", "p", "N"):
                cv.put(x, y, "v")
        cv.put(dx - half, y, "p")
        cv.put(dx + half - 1, y, "N")
    disc(cv, dx, dy, 13.6, "U")                 # the dark inside of the hood
    rect(cv, dx - 1, dy - 18, 2, 2, "c")         # a brass tip
    cv.put(dx - 1, dy - 18, "y")
    # the face: a dial in a brass bezel
    ring_lit(cv, dx, dy, 10.6, 12.6, "o", "y", "c", "Y")
    disc(cv, dx, dy, 10.6, "w")
    for y in range(KH):
        for x in range(KW):
            if cv.c[y][x] == "w":
                ddx, ddy = x + 0.5 - dx, y + 0.5 - dy
                if math.hypot(ddx, ddy) > 8.8 and ddx + ddy > 2.0:
                    cv.c[y][x] = "A"
    for h in range(12):
        a = h * math.pi / 6
        x = int(math.floor(dx + math.sin(a) * 9.2))
        y = int(math.floor(dy - math.cos(a) * 9.2))
        cv.put(x, y, "k" if h % 3 == 0 else "a")
    # the winding holes are its eyes
    for ex in (dx - 5, dx + 3):
        ey = dy + 3
        rect(cv, ex, ey, 2, 2, "k")
        if eyes:
            post.put(ex + (1 if ex > dx else 0), ey, eyes)
            if glow:
                post.put(ex + (0 if ex > dx else 1), ey + 1, "r" if eyes == "y" else "B")
    return render(cv, post)


def build_keeper():
    sw = [-2, 0, 2, 0]
    idle = [keeper_frame(sw[k], (0, 0, 1, 1)[k], "down", "t", k % 2) for k in range(4)]
    run = [keeper_frame(sw[k], (0, 1, 1, 0)[k], "down", "t", k) for k in range(4)]
    atk = [keeper_frame(sw[k] // 2, 0, "up", "y" if k % 2 == 0 else "w", k % 2, True) for k in range(4)]
    for anim, frames in (("idle", idle), ("run", run), ("atk", atk)):
        for i, im in enumerate(frames):
            put("monsters/keeper_%s_f%d" % (anim, i), im)


# =========================================================================== ending scenes
SW, SH = 192, 96


def sky_bands(cv, rows, cols):
    y = 0
    for n, c in zip(rows, cols):
        rect(cv, 0, y, cv.w, n, c)
        y += n


def build_end_house():
    cv = Canvas(SW, SH)
    sky_bands(cv, [30, 26, 22, 18], ["N", "2", "O", "M"])
    disc(cv, 34, 24, 10, "w")                   # the moon
    for (x, y) in ((30, 19), (31, 19), (37, 26), (29, 27), (38, 20)):
        cv.put(x, y, "h")
    for y in range(SH):
        for x in range(SW):
            if cv.c[y][x] == "w" and (x + 0.5 - 34) + (y + 0.5 - 24) > 8:
                cv.c[y][x] = "S"
    # the hill
    for x in range(SW):
        top = 78 + int(4 * math.sin(x / 23.0)) + int(2 * math.sin(x / 7.0))
        rect(cv, x, top, 1, SH - top, "U")
    # the house: two wings, a roof, the clock tower in the middle with its belfry
    rect(cv, 52, 52, 40, 30, "C")
    rect(cv, 112, 56, 46, 26, "C")
    for i in range(14):                          # roofs
        rect(cv, 52 + i, 52 - i // 2, 40 - 2 * i, 1, "C")
        rect(cv, 112 + i, 56 - i // 2, 46 - 2 * i, 1, "C")
    rect(cv, 88, 26, 28, 56, "z")                # the tower
    rect(cv, 86, 24, 32, 3, "C")
    for i in range(12):
        rect(cv, 88 + i, 24 - i, 28 - 2 * i, 1, "C")
    rect(cv, 101, 9, 2, 4, "C")
    for x in range(88, 116):                     # moonlight on the tower's left edges
        pass
    rect(cv, 88, 27, 1, 55, "M")
    for i in range(12):
        cv.put(88 + i, 24 - i, "M")
    for i in range(14):
        cv.put(52 + i, 52 - i // 2, "M")
        cv.put(112 + i, 56 - i // 2, "M")
    # the tower clock (its hands are drawn by the ending scene)
    ring_lit(cv, 102, 40, 7.0, 8.4, "R", "c", "m")
    disc(cv, 102, 40, 7.0, "S")
    for (x, y) in ((101, 33), (101, 46), (95, 39), (108, 39)):
        cv.put(x, y, "i")
    rect(cv, 97, 53, 10, 8, "1")                 # belfry arch
    rect(cv, 98, 52, 8, 1, "1")
    # windows: all dark but one
    for (x, y) in ((58, 60), (70, 60), (82, 60), (118, 63), (130, 63), (142, 63), (58, 70), (130, 72), (142, 72), (98, 66)):
        rect(cv, x, y, 4, 5, "1")
        rect(cv, x, y, 4, 1, "U")
    rect(cv, 70, 70, 4, 5, "y")
    rect(cv, 70, 70, 4, 1, "o")
    cv.put(72, 72, "w")
    rect(cv, 118, 72, 4, 5, "1")
    # a chimney
    rect(cv, 134, 40, 5, 10, "C")
    rect(cv, 133, 39, 7, 2, "z")
    put("tower/end_house", to_img(cv))


def build_end_dial():
    cv = Canvas(SW, SH)
    for y in range(SH):                          # the tower's stone face
        for x in range(SW):
            row = y // 6
            off = 8 if row % 2 else 0
            edge = (y % 6 == 5) or ((x + off) % 16 == 15)
            cv.put(x, y, "U" if edge else ("z" if (x // 16 + row) % 3 else "u"))
    c = (96, 48)
    disc(cv, c[0], c[1], 44, "C")
    ring_lit(cv, c[0], c[1], 37.5, 42.5, "c", "o", "R", "y")
    disc(cv, c[0], c[1], 37.5, "A")
    disc(cv, c[0], c[1], 34.5, "w")
    for h in range(12):
        a = h * math.pi / 6
        big = h % 3 == 0
        for r in range(27 if big else 30, 34):
            for w in ((-0.5, 0.5) if big else (0,)):
                x = c[0] + math.sin(a) * r + math.cos(a) * w
                y = c[1] - math.cos(a) * r + math.sin(a) * w
                cv.put(int(math.floor(x)), int(math.floor(y)), "k")
    for m in range(60):
        if m % 5:
            a = m * math.pi / 30
            cv.put(int(math.floor(c[0] + math.sin(a) * 33)), int(math.floor(c[1] - math.cos(a) * 33)), "a")
    put("tower/end_dial", to_img(cv))


def build_end_window():
    """A window seen from inside (panes left transparent: the scene draws the sky), a sill, curtains."""
    cv = Canvas(SW, SH)
    for y in range(SH):
        for x in range(SW):
            i = x % 16
            cv.put(x, y, "U" if i == 0 else ("j" if 3 <= i <= 13 else "J"))
    # window: x 56..135, y 6..69 ; panes (transparent) inside the frame
    rect(cv, 54, 4, 84, 70, "J")
    rect(cv, 54, 4, 84, 1, "4")
    rect(cv, 54, 4, 1, 70, "4")
    for (x, y, w, h) in ((58, 8, 37, 29), (97, 8, 37, 29), (58, 39, 37, 29), (97, 39, 37, 29)):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                cv.c[yy][xx] = "."
    # the sill
    rect(cv, 46, 70, 100, 6, "f")
    rect(cv, 46, 70, 100, 1, "X")
    rect(cv, 46, 75, 100, 1, "F")
    rect(cv, 50, 76, 92, 3, "J")
    # curtains: straight folds, tied back with a brass cord
    for side in (0, 1):
        for y in range(0, 84):
            tie = abs(y - 50)
            w = 18 if y < 30 else (11 + min(7, tie // 3) if y < 70 else 18 + (y - 70) // 3)
            for k in range(w):
                x = (38 - w + k) if side == 0 else (153 + w - 1 - k)
                fold = k % 5
                ch = "m" if fold == 0 else ("p" if fold < 3 else "v")
                if k == w - 1:
                    ch = "m"
                cv.put(x, y, ch)
            if 49 <= y <= 51:
                for k in range(w + 1):
                    x = (38 - w + k) if side == 0 else (153 + w - 1 - k)
                    cv.put(x, y, "o" if y == 49 else ("c" if y == 50 else "R"))
    put("tower/end_window", to_img(cv))


# =========================================================================== moonlight texture
def build_moon_light():
    """Moonlight through louvres: four soft bars leaning right, falling off at the ends (smooth)."""
    W, H = 96, 128
    a = np.zeros((H, W), dtype=np.float64)
    ys, xs = np.mgrid[0:H, 0:W]
    u = (xs - W / 2.0) - (ys - H / 2.0) * 0.32           # leans with the moon high on the left
    v = (ys - H / 2.0)
    bars = np.cos((v / H) * math.pi * 9.0) * 0.5 + 0.5
    bars = np.clip((bars - 0.25) / 0.6, 0.0, 1.0)
    fall = np.exp(-((u / (W * 0.30)) ** 2) - ((v / (H * 0.42)) ** 4))
    a = bars * fall
    im = np.zeros((H, W, 4), dtype=np.uint8)
    im[:, :, 0:3] = 255
    im[:, :, 3] = np.clip(a * 255.0, 0, 255).astype(np.uint8)
    MADE_LIGHT["tower/light/moon_slats"] = Image.fromarray(im, "RGBA")


MADE_LIGHT = {}


# =========================================================================== main
def check(name, im):
    a = np.array(im)
    assert set(np.unique(a[:, :, 3])) <= {0, 255}, name + " has semi-transparent pixels"
    cols = {tuple(int(v) for v in p[:3]) for p in a.reshape(-1, 4) if p[3]}
    bad = cols - SHEET_PAL
    assert not bad, "%s uses colours outside the 0x72 palette: %s" % (name, ["#%02x%02x%02x" % c for c in bad])


SHEET_PAL = AR.sheet_palette()


def contact(names, path, scale=4, cols=8, bg=(36, 30, 36, 255)):
    ims = [(n, MADE[n]) for n in names]
    cw = max(i.width for _, i in ims) * scale + 6
    ch = max(i.height for _, i in ims) * scale + 6
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGBA", (cw * min(cols, len(ims)), ch * rows), bg)
    for k, (n, im) in enumerate(ims):
        out.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST),
                            ((k % cols) * cw + 3, (k // cols) * ch + 3))
    out.save(path)


def main():
    review = None
    for a in sys.argv[1:]:
        if a.startswith("--review"):
            review = a.split("=", 1)[1] if "=" in a else "/tmp/claude-0/review_tower"
    build_rooms()
    build_gears()
    build_sconces()
    build_wall_pieces()
    build_props()
    build_floor_decals()
    build_ladder()
    build_holder()
    build_bolts()
    build_sentry()
    build_wraith()
    build_keeper()
    build_end_house()
    build_end_dial()
    build_end_window()
    build_moon_light()
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
        for n in ["rooms/room_tower", "rooms/room_tower_1", "rooms/room_tower_2", "tower/room_keeper"]:
            MADE[n].resize((272 * 3, 192 * 3), Image.NEAREST).save(os.path.join(review, n.split("/")[1] + "_3x.png"))
        contact([n for n in MADE if n.startswith("monsters/")], os.path.join(review, "monsters.png"), 6, 12)
        contact([n for n in MADE if n.startswith(("decor/", "tower/gear", "tower/window", "tower/floor", "tower/holder", "fx/"))],
                os.path.join(review, "decor.png"), 6, 8)
        contact([n for n in MADE if n.startswith("tower/ladder")], os.path.join(review, "ladder.png"), 4, 4)
        contact([n for n in MADE if n.startswith("tower/end_")], os.path.join(review, "ending.png"), 3, 1)


if __name__ == "__main__":
    main()
