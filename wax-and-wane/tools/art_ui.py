#!/usr/bin/env python3
"""Wax & Wane - UI art (HUD bar, icons, buttons, panels, sticks, title logo)
plus a mock HUD preview. The launcher / store icons are in art_icon.py.

Every sprite is hand-authored pixel art written as character grids (one
character = one pixel, see PAL). The title letters are hand-drawn
silhouettes + hand-placed drips; a fixed rule pass adds their shading, slab
depth and outline. The only computed shapes are the joystick rings (plain
midpoint pixel circles).
Nothing is random, so running this script always gives identical PNGs.

Colours: 0x72 DungeonTileset II palette only (see DESIGN.md). Outlines are
1 px #21141b (HUD) / #222222 (0x72-style objects). Light from the top-left.
No anti-aliasing, no gradients; alpha is only used on the joystick rings.

Usage:
    python3 tools/art_ui.py               # write every PNG into assets/art/ui/
    python3 tools/art_ui.py --review DIR  # also write 6x contact sheets to DIR
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
UI = os.path.join(ART, "ui")

# --------------------------------------------------------------------------
# Palette (every colour appears in the 0x72 sheet)
# --------------------------------------------------------------------------
PAL = {
    ".": None,
    "K": "#21141b", "k": "#222222", "1": "#111111",
    "6": "#38262d", "7": "#3b3332", "8": "#302c2b", "9": "#2b2929",
    "3": "#333333", "4": "#483b3a", "5": "#775c55", "2": "#2a2a3a",
    "a": "#aa8d7a", "A": "#d3bfa9",
    "w": "#fdf7ed", "X": "#e2b694", "d": "#d8a57d", "D": "#b58057",
    "f": "#c38d70", "F": "#8a503e", "x": "#fccba3",
    "y": "#facb3e", "o": "#ee8e2e", "e": "#e46e33", "r": "#da4e38",
    "c": "#c56025", "R": "#8f4029", "m": "#62232f",
    "p": "#9f294e", "v": "#5f2d56", "q": "#f78697",
    "j": "#3f3f3f", "J": "#494949", "U": "#545454",
    "s": "#314152", "S": "#b6cbcf", "i": "#7b8994", "h": "#cae6f5",
}


def rgba(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def rows_of(block):
    rows = [ln.strip() for ln in block.strip("\n").splitlines()]
    return [r for r in rows if r]


def grid(block, alpha=None):
    """Char grid -> RGBA image. `alpha` optionally maps a char to an alpha."""
    rows = rows_of(block) if isinstance(block, str) else list(block)
    W = max(len(r) for r in rows)
    for r in rows:
        assert len(r) == W, ("ragged row", len(r), W, r)
    im = Image.new("RGBA", (W, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            col = PAL[ch]
            if col:
                px[x, y] = rgba(col, (alpha or {}).get(ch, 255))
    return im


def column(chars):
    """A 1 px wide image from a top-to-bottom string of palette chars."""
    return grid("\n".join(chars))


OUT = []


def save(im, name):
    p = os.path.join(UI, name)
    os.makedirs(UI, exist_ok=True)
    im.save(p)
    OUT.append(p)
    return im


# ==========================================================================
# WAX BAR  (a candle lying on its side in a brass holder, burning from the
# right). All four pieces are BAR_H tall so they line up. The game draws:
# left cap at x=0, 128 columns of fill/empty, right cap; the hero flame sits
# on the burning end with its wick pixel on bar row 4.
#   rows 2..H-3 of the empty socket get a red "recent damage" strip,
#   rows H-3..H-2 of the wax get #d3bfa9 quarter-hour ticks.
# ==========================================================================
BAR_H = 14

# One column of the candle: dark top edge, cream top highlight, wax body
# (#e2b694, same as Tallow's body), lower shade, dark bottom edge.
#           0   1   2   3   4   5   6   7   8   9   10  11  12  13
BAR_FILL = "K" "w" "w" "X" "X" "X" "X" "X" "X" "d" "d" "d" "D" "K"
# Burnt-away part: a warm dark socket, shadowed under the top lip, with the
# lit lower lip catching light.
BAR_EMPTY = "K" "K" "6" "6" "6" "6" "6" "6" "6" "6" "6" "6" "5" "K"

# Brass socket holding the cold end of the candle: rounded dome on the left,
# a dark seam, then a banded collar (same bands as Tallow's brass dish).
BAR_LEFT = """
....KKKKKK
..KKyooooR
.KyyRyyyyR
.KywRwwwyR
KyyoRyyyyR
KyooRyyyyR
KoooRooooR
KoocRooooR
KcccRooooR
KcccRccccR
.KcRRccccR
.KRRRooooR
..KKRRRRRR
....KKKKKK
"""

# Brass end-stop closing the socket at the far (burning) end.
BAR_RIGHT = """
KKK.
RooK
RyoK
RwoK
RyoK
RyoK
RooK
RooK
RooK
RccK
RccK
RocK
RRK.
KK..
"""


def make_bar():
    assert len(BAR_FILL) == BAR_H and len(BAR_EMPTY) == BAR_H
    left, right = grid(BAR_LEFT), grid(BAR_RIGHT)
    assert left.height == BAR_H and right.height == BAR_H
    save(left, "bar_frame_left.png")
    save(right, "bar_frame_right.png")
    save(column(BAR_FILL), "bar_wax_fill.png")
    save(column(BAR_EMPTY), "bar_wax_empty.png")


# ==========================================================================
# SMALL ICONS (9x9, 0x72 style: #222222 outline, light from the top-left)
# ==========================================================================
# Gold coin: cream glint on the lit rim, orange on the shaded rim, and a
# vertical stamped bar (like the 0x72 coin's light stripe).
ICON_COIN = """
...kkk...
.kkwyykk.
.kwyyyyk.
kwyyoyyok
kyyyowyok
kyyyowyok
.kyyywok.
.kkoookk.
...kkk...
"""

# 0x72-style bomb: grey ball lit from the top-left, tan fuse, yellow spark.
ICON_BOMB = """
.......y.
.....aywy
..kkkk.y.
.kUSUJk..
kUSUJJJk.
kUJJJJjk.
kJJJJjjk.
.kjjj3k..
..kkkk...
"""


def make_icons():
    save(grid(ICON_COIN), "icon_coin.png")
    save(grid(ICON_BOMB), "icon_bomb.png")


# ==========================================================================
# BUTTONS
# ==========================================================================
# Pause: two cream bars (with a 1 px drop shadow) in a dark rounded square.
BTN_PAUSE = """
.KKKKKKKKKKK.
K45555555554K
K56666666666K
K56ww666ww66K
K56wwK66wwK6K
K56wwK66wwK6K
K56wwK66wwK6K
K56wwK66wwK6K
K56wwK66wwK6K
K56AAK66AAK6K
K566KK666KK6K
K46666666666K
.KKKKKKKKKKK.
"""

# Round dark stone button (22x22): lit rim top-left, shadowed bottom-right.
BTN_ROUND = """
.......KKKKKKKK.......
.....KK55555555KK.....
...KK556666666644KK...
..K5566666666666644K..
.K566666666666666664K.
.K566666666666666664K.
K56666666666666666664K
K56666666666666666664K
K5666666666666666666KK
K5666666666666666666KK
K5666666666666666666KK
K5666666666666666666KK
K5666666666666666666KK
K5666666666666666666KK
K5666666666666666666KK
K5666666666666666666KK
.K46666666666666666KK.
.K46666666666666666KK.
..K44666666666666KKK..
...KK4466666666KKKK...
.....KK44KKKKKKKK.....
.......KKKKKKKK.......
"""

# Bomb drawn on the round button (offset BOMB_AT), 0x72-style.
BOMB_BIG = """
..........y..
.........ywy.
........a.y..
....kkkF.....
..kkUUUkk....
.kUUSUJJJk...
.kUSUJJJJk...
kUUJJJJJJjk..
kUJJJJJJJjk..
kUJJJJJJjjk..
.kJJJJJj3k...
.kjJJJjj3k...
..kk333kk....
....kkk......
"""
BOMB_AT = (5, 3)


def make_buttons():
    save(grid(BTN_PAUSE), "btn_pause.png")
    base = grid(BTN_ROUND)
    base.alpha_composite(grid(BOMB_BIG), BOMB_AT)
    save(base, "btn_bomb.png")


# ==========================================================================
# NINE-PATCHES
# panel_9 (8 px margins): carved dark stone - lit outer bevel, stone rim with
# brass rivets, a dark groove, then a warm 1 px candle-lit edge on the
# top/left of the flat inner field. Everything between the margins is
# uniform along the stretch axis so Godot can scale it cleanly.
# button_9 (6 px margins): raised stone slab with a 2 px front lip;
# button_9_pressed: the face sits 1 px lower, darker, with a 1 px lip.
# ==========================================================================
PANEL_9 = """
..KKKKKKKKKKKKKKKKKKKK..
.K55555555555555555555K.
K5yo4444444444444444yo4K
K5oc4444444444444444oc4K
K544KKKKKKKKKKKKKKKK444K
K544KFFFFFFFFFFFFF6K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544KF6666666666666K444K
K544K66666666666666K444K
K544KKKKKKKKKKKKKKKK444K
K5yo4444444444444444yo4K
K5oc4444444444444444oc4K
.K44444444444444444444K.
..KKKKKKKKKKKKKKKKKKKK..
"""

# button_9 (24x16, 6 px margins): wax-sealed stone slab.  1 px #21141b outline, lit top
# row, #483b3a face, 2 px #2a2a3a front lip, and two #fdf7ed wax drips hanging from the top
# edge inside the corner margins (x 1..5 / 18..22, y < 6) so 9-patch stretching keeps them
# at the corners.  Pressed: the slab sits 1 px lower, the light catches its bottom edge.
BUTTON_9 = """
.KKKKKKKKKKKKKKKKKKKKKK.
Kwwwww5555555555555wwwwK
K4ww444444444444444444wK
K44w4444444444444444444K
K4wX4444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K2222222222222222222222K
K2222222222222222222222K
.KKKKKKKKKKKKKKKKKKKKKK.
"""

BUTTON_9_PRESSED = """
.KKKKKKKKKKKKKKKKKKKKKK.
KKKKKKKKKKKKKKKKKKKKKKKK
Kwwwww2222222222222wwwwK
K4ww444444444444444444wK
K44w4444444444444444444K
K4wX4444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K4444444444444444444444K
K5555555555555555555555K
.KKKKKKKKKKKKKKKKKKKKKK.
"""


def make_boxes():
    save(grid(PANEL_9), "panel_9.png")
    save(grid(BUTTON_9), "button_9.png")
    save(grid(BUTTON_9_PRESSED), "button_9_pressed.png")


# ==========================================================================
# VIRTUAL STICKS (alpha allowed here). Rings are plain midpoint pixel circles
# (the same shape a pixel editor's circle tool makes), 1 px wide each.
# ==========================================================================
def disc_insets(d):
    """Left inset per row of a filled pixel circle of diameter d."""
    r = d / 2.0
    out = []
    for y in range(d):
        dy = abs(y + 0.5 - r)
        half = (r * r - dy * dy) ** 0.5 if dy < r else 0.0
        out.append(int(round(r - half)))
    return out


def ring_image(d, rings, fill=None):
    """rings: list of (char, alpha) from the outside in; fill: (char, alpha)."""
    im = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    px = im.load()
    layers = list(rings) + ([fill] if fill else [])
    for i, (ch, a) in enumerate(layers):
        dd = d - 2 * i
        ins = disc_insets(dd)
        nxt = disc_insets(dd - 2) if (i < len(rings) and dd > 2) else None
        for y in range(dd):
            for x in range(ins[y], dd - ins[y]):
                inner = False
                if nxt is not None and 1 <= y < dd - 1:
                    yy = y - 1
                    inner = nxt[yy] <= x - 1 < (dd - 2) - nxt[yy]
                if i < len(rings) and inner:
                    continue
                px[x + i, y + i] = rgba(PAL[ch], a)
    return im


# Little chevrons on the base ring pointing N/E/S/W.
CHEVRON = ["..A..", ".A.A.", "A...A"]


def make_sticks():
    base = ring_image(40, [("K", 150), ("A", 120), ("A", 120), ("K", 110)], ("K", 60))
    px = base.load()
    c = rgba(PAL["A"], 120)
    for j, row in enumerate(CHEVRON):
        for i, ch in enumerate(row):
            if ch == "A":
                px[17 + i, 7 + j] = c            # north (points up)
                px[17 + i, 32 - j] = c           # south
                px[7 + j, 17 + i] = c            # west
                px[32 - j, 17 + i] = c           # east
    save(base, "stick_base.png")
    save(grid(STICK_KNOB, alpha=KNOB_ALPHA), "stick_knob.png")


# Thumb knob: a matte disc of wax (lit rim top-left, shade bottom-right),
# semi-transparent so the action under the thumb stays visible.
STICK_KNOB = """
......KKKKKK......
....KKwwwwwwKK....
...KwwwXXXXXwwK...
..KwwXXXXXXXXXXK..
.KwwXXXXXXXXXXXdK.
.KwXXXXXXXXXXXXdK.
KwwXXXXXXXXXXXXXdK
KwXXXXXXXXXXXXXXdK
KwXXXXXXXXXXXXXXdK
KwXXXXXXXXXXXXXXdK
KwXXXXXXXXXXXXXddK
KXXXXXXXXXXXXXXddK
.KXXXXXXXXXXXXddK.
.KXXXXXXXXXXXdddK.
..KXXXXXXXXXdddK..
...KXXddddddddK...
....KKddddddKK....
......KKKKKK......
"""
KNOB_ALPHA = {"K": 170, "w": 220, "X": 150, "d": 200}


# ==========================================================================
# TITLE LOGO  "WAX & WANE"
# Hand-lettered slab-serif capitals in Tallow's wax colours. Thick strokes
# go down-right, thin strokes up-right (like hand-cut wood type). Each glyph
# below is a silhouette ('#'). Every exposed top surface gets a cream rim,
# wax drips run down the strokes and hang off a few bottom slabs. The & is
# polished brass (Tallow's holder colours) with Tallow's own flame on top.
# Build: soften slab corners -> rim / drips / tan body, shaded with light
# from the top-left -> 2 px slab depth below every face -> hanging drips ->
# 1 px #21141b outline -> flame.
# ==========================================================================
GLYPH_W = """
##########....#########....#######
##########....#########....#######
.########......#######......#####.
..######........#####........###..
...######......#######......###...
...######......#######......###...
...######......#######......###...
...######......#######......###...
....######....###.#####....###....
....######....###.#####....###....
....######....###.#####....###....
....######....###.#####....###....
.....######..###...#####..###.....
.....######..###...#####..###.....
.....######..###...#####..###.....
.....######..###...#####..###.....
......#########.....########......
......#########.....########......
......#########.....########......
......#########.....########......
.......#######.......######.......
.......#######.......######.......
.......#######.......######.......
.......#######.......######.......
"""
GLYPH_A = """
.........######.........
.........######.........
.........######.........
........########........
........########........
........########........
.......##########.......
.......##########.......
.......##########.......
......####..######......
......####..######......
......####..######......
.....####....######.....
.....####....######.....
.....##############.....
....################....
....####......######....
....####......######....
...####........######...
...####........######...
...####........######...
.#######......#########.
#########....###########
#########....###########
"""
GLYPH_X = """
#########....#######.
#########....#######.
.########....######..
...######....####....
....######..####.....
....######..####.....
.....##########......
.....##########......
......########.......
......########.......
.......######........
.......######........
........######.......
........######.......
.......########......
.......########......
......##########.....
......##########.....
.....####..######....
.....####..######....
....####....######...
..######....########.
.########...#########
.########...#########
"""
GLYPH_N = """
##########......########
##########......########
.########........######.
..#######.........####..
..########........####..
..########........####..
..#########.......####..
..#########.......####..
..##########......####..
..##########......####..
..####.######.....####..
..####.######.....####..
..####..######....####..
..####..######....####..
..####...######...####..
..####...######...####..
..####....######..####..
..####....######..####..
..####.....######.####..
..####.....######.####..
..####......##########..
.######.....##########..
########.....#########..
########.....#########..
"""
GLYPH_E = """
##################.
##################.
##################.
##################.
..######.......###.
..######.......###.
..######.......###.
..######...........
..######...##......
..######...##......
..###########......
..###########......
..###########......
..######...##......
..######...##......
..######...........
..######...........
..######.......###.
..######.......###.
..######.......###.
##################.
##################.
##################.
##################.
"""

GLYPH_AMP = """
.....######......
....########.....
....###..###.....
....###..###.....
....###..###.....
....###..###.....
.....######......
.....#####.......
....#######...###
...###.####..###.
..###...####.###.
..###....######..
.###......####...
.###......####...
.###......#####..
.###.....###.###.
..###...###...###
...#######.....##
....#####........
"""

# Every exposed top surface gets a RIM_ROWS-deep cream rim (the top of the
# wax, like Tallow's own rim). Drips run down the faces and hang off the
# bottom slabs; they are the same tan wax as the letters, shaped by a lit
# left edge and the shadow they cast to the right and below.
RIM_ROWS = 2

DROP_LONG = """
.##.
.##.
.##.
.##.
.##.
.##.
####
####
.##.
"""
DROP_BIG = """
.##.
.##.
.##.
.##.
####
####
.##.
"""
DROP_MID = """
.##.
.##.
####
####
.##.
"""
# (letter index in LOGO_TEXT, x, y, sprite): y = the drop's first row.
FACE_DRIPS = [
    (0, 4, 1, DROP_LONG), (0, 17, 1, DROP_MID),
    (1, 12, 3, DROP_LONG),
    (2, 5, 1, DROP_BIG),
    (4, 4, 1, DROP_MID), (4, 17, 1, DROP_LONG),
    (5, 12, 3, DROP_BIG),
    (6, 2, 1, DROP_LONG), (6, 18, 1, DROP_MID),
    (7, 3, 1, DROP_LONG),
]

# Wax hanging below the bottom slabs; the sprite's first row is the
# letter's bottom row, so the drip grows out of the slab.
HANG_LONG = """
####
####
.##.
.##.
.##.
####
####
####
.##.
"""
HANG_SHORT = """
###
###
.#.
###
###
.#.
"""
# (letter index, x, sprite)
DRIPS = [(1, 3, HANG_LONG), (2, 15, HANG_SHORT), (4, 9, HANG_SHORT), (6, 3, HANG_LONG),
         (7, 11, HANG_SHORT)]

LOGO_TEXT = ["W", "A", "X", "&", "W", "A", "N", "E"]
LOGO_KERN = {("W", "A"): -5}
LOGO_GAP = 2
AMP_SPACE = 4          # extra space on each side of the &
CAP_TOP = 12           # canvas row of the cap line


def glyph_rows(name):
    if name == "&":
        return rows_of(GLYPH_AMP)
    return rows_of(globals()["GLYPH_" + name])


def build_logo():
    # 1) place the silhouettes on the baseline
    placed = []
    x = 1
    prev = None
    for ch in LOGO_TEXT:
        rows = glyph_rows(ch)
        if prev is not None:
            x += LOGO_GAP + LOGO_KERN.get((prev, ch), 0)
            if "&" in (prev, ch):
                x += AMP_SPACE
        placed.append((ch, x, CAP_TOP + 24 - len(rows), rows))
        x += len(rows[0])
        prev = ch
    W, Hh = x + 3, CAP_TOP + 24 + 14
    face = {}                                   # (x, y) -> letter index
    for i, (ch, gx, gy, rows) in enumerate(placed):
        h = len(rows)
        for r, row in enumerate(rows):
            for c, v in enumerate(row):
                if v != "#":
                    continue
                if r in (0, h - 1):             # soften the slab corners
                    if c == 0 or row[c - 1] != "#" or c == len(row) - 1 or row[c + 1] != "#":
                        continue
                face[(gx + c, gy + r)] = i
    wax = lambda i: placed[i][0] != "&"
    rim = set()
    for (fx, fy), i in face.items():
        if wax(i) and any((fx, fy - k) not in face for k in range(1, RIM_ROWS + 1)):
            rim.add((fx, fy))
    drip = set()
    for (gi, dx, dy, spr) in FACE_DRIPS:
        ch, gx, gy, rows = placed[gi]
        for r, row in enumerate(rows_of(spr)):
            for c, v in enumerate(row):
                p = (gx + dx + c, gy + dy + r)
                if v == "#" and face.get(p) == gi and p not in rim:
                    drip.add(p)
    # 2) shade the faces, light from the top-left
    pix = {}
    for (fx, fy), i in face.items():
        lf, rt = (fx - 1, fy), (fx + 1, fy)
        up, dn = (fx, fy - 1), (fx, fy + 1)
        if not wax(i):                            # polished brass &
            if up not in face or lf not in face:
                ch = "y"
            elif rt not in face or dn not in face:
                ch = "c"
            else:
                ch = "o"
        elif (fx, fy) in rim:                     # cream rim of the wax
            ch = "w" if rt in face else "X"
        elif (fx, fy) in drip:                    # raised drip: lit left edge
            ch = "w" if lf not in drip and lf not in rim else "X"
            if rt not in face:
                ch = "d"
        else:                                     # tan body, drips cast shadow
            shaded = rt not in face or lf in drip or up in drip or up in rim
            ch = "d" if shaded else "X"
        pix[(fx, fy)] = ch
    # 3) slab depth: two rows straight down below every face pixel
    for (fx, fy), i in face.items():
        for k in (1, 2):
            p = (fx, fy + k)
            if p in face:
                break
            want = ("D" if wax(i) else "R") if k == 1 else ("F" if wax(i) else "m")
            if p not in pix or (k == 1 and pix[p] in "Fm"):
                pix[p] = want
    # 4) wax hanging off the bottom slabs
    for (gi, dx, spr) in DRIPS:
        ch, gx, gy, rows = placed[gi]
        top = gy + len(rows) - 1
        for r, row in enumerate(rows_of(spr)):
            for c, v in enumerate(row):
                if v == ".":
                    continue
                lit = c == 0 or row[c - 1] == "."
                dark = c == len(row) - 1 or row[c + 1] == "."
                pix[(gx + dx + c, top + r)] = "w" if lit else ("d" if dark else "X")
    im = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    out = im.load()
    for (px_, py_), ch in pix.items():
        out[px_, py_] = rgba(PAL[ch])
    # 5) 1 px outline (4-neighbour, like the 0x72 sprites)
    ol = rgba(PAL["K"])
    for y in range(Hh):
        for xx in range(W):
            if (xx, y) not in pix and any((xx + dx, y + dy) in pix
                                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[xx, y] = ol
    # 6) Tallow's flame burns on the top loop of the &, wick on its outline
    amp = [p for p in placed if p[0] == "&"][0]
    flame = Image.open(os.path.join(ART, "hero", "flame_f0.png")).convert("RGBA")
    im.alpha_composite(flame, (amp[1] + 8 - 4, amp[2] - 1 - 12))
    return im.crop(im.getbbox())


def make_logo():
    im = build_logo()
    assert im.width <= 220 and im.height <= 60, im.size
    save(im, "title_logo.png")



# ==========================================================================
# LAUNCHER ICONS live in tools/art_icon.py (app_icon_192, the adaptive
# fg/bg 432 pair, icon.png and the store icons). This script no longer
# writes them.
# ==========================================================================
HERO = os.path.join(ART, "hero", "hero_preview.png")    # used by the HUD preview


def upscale(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


# ==========================================================================
# HUD PREVIEW  (mock composite of the in-game HUD over the cellar room)
# Mirrors hud.gd: bar at (6,5), clock label at (8,17), counters at (8,34),
# pause button at (w-25,3) in a 22x22 box, bomb button at (w-33, h*0.42) in a
# 30x30 box, Label shadow (1,1) #21141b.
# ==========================================================================
def make_preview():
    vw, vh = 384, 216
    im = Image.new("RGBA", (vw, vh), (9, 7, 9, 255))
    room = Image.open(os.path.join(ART, "rooms", "room_cellar.png")).convert("RGBA")
    im.alpha_composite(room, ((vw - room.width) // 2, (vh - room.height) // 2))
    hero = Image.open(HERO).convert("RGBA")
    im.alpha_composite(hero, (vw // 2 - 10, vh // 2 + 10))
    big = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "kenney_pixel.ttf"), 16)
    small = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "kenney_mini.ttf"), 8)

    def label(xy, text, col, font):
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        d.text((xy[0] + 1, xy[1] + 1), text, font=font, fill=rgba(PAL["K"]))
        d.text(xy, text, font=font, fill=rgba(col))
        return d.textlength(text, font=font)

    def centred(tex, box_xy, box):
        # TextureRect/TextureButton STRETCH_KEEP_CENTERED (offset floored here)
        im.alpha_composite(tex, (box_xy[0] + (box[0] - tex.width) // 2,
                                 box_xy[1] + (box[1] - tex.height) // 2))

    # wax bar: 12:47 AM -> 73 of 120 minutes of wax left, a recent hit in red
    bar = bar_mock(73 / 120, 80 / 120)
    full = Image.new("RGBA", (vw, vh), (0, 0, 0, 0))
    full.alpha_composite(bar, (6, 5 - 9))  # bar_mock leaves 9 rows for the flame
    im.alpha_composite(full)
    label((8, 17), "12:47 AM", "#fdf7ed", big)
    label((66, 22), "The Cellar  -  1/4", "#aa8d7a", small)
    ui = lambda n: Image.open(os.path.join(UI, n)).convert("RGBA")
    x = 8
    centred(ui("icon_coin.png"), (x, 34), (10, 12))
    x += 10 + 3
    x += int(label((x, 34 - 3), "23", "#facb3e", big)) + 3 + 6 + 3
    centred(ui("icon_bomb.png"), (x, 34), (10, 12))
    x += 10 + 3
    label((x, 34 - 3), "2", "#fdf7ed", big)
    centred(ui("btn_pause.png"), (vw - 25, 3), (22, 22))
    centred(ui("btn_bomb.png"), (vw - 33, int(vh * 0.42)), (30, 30))
    base = ui("stick_base.png")
    base.putalpha(base.getchannel("A").point(lambda v: int(v * 0.8)))
    im.alpha_composite(base, (64 - 20, 160 - 20))
    im.alpha_composite(ui("stick_knob.png"), (64 + 8 - 9, 160 - 5 - 9))
    save(im, "ui_preview.png")



def bar_mock(frac, ghost=0.0, inner=128, wax_max=120.0):
    """Assemble the bar exactly like hud.gd::_draw_bar does (for review)."""
    left = Image.open(os.path.join(UI, "bar_frame_left.png"))
    right = Image.open(os.path.join(UI, "bar_frame_right.png"))
    fill = Image.open(os.path.join(UI, "bar_wax_fill.png"))
    empty = Image.open(os.path.join(UI, "bar_wax_empty.png"))
    flame = Image.open(os.path.join(ART, "hero", "flame_f0.png"))
    h = fill.height
    x0 = left.width
    W = x0 + inner + right.width
    top = 9  # room above the bar for the flame
    im = Image.new("RGBA", (W, h + top), (0, 0, 0, 0))
    wpx = round(inner * frac)
    gpx = round(inner * ghost)
    for x in range(inner):
        im.alpha_composite(empty, (x0 + x, top))
    if gpx > wpx:
        red = Image.new("RGBA", (gpx - wpx, h - 4), rgba("#da4e38"))
        im.alpha_composite(red, (x0 + wpx, top + 2))
    for x in range(wpx):
        im.alpha_composite(fill, (x0 + x, top))
    k = 15.0
    while k < wax_max:
        nx = x0 + round(inner * k / wax_max)
        if nx < x0 + wpx - 1:
            im.alpha_composite(Image.new("RGBA", (1, 2), rgba("#d3bfa9")), (nx, top + h - 3))
        k += 15.0
    im.alpha_composite(left, (0, top))
    im.alpha_composite(right, (x0 + inner, top))
    if frac > 0:
        im.alpha_composite(flame, (x0 + wpx - 4, top - flame.height + 5))
    return im


def sheet(path, ims, scale=6, bg="#1a1418", pad=3, cols=None):
    cols = cols or len(ims)
    rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]
    W = max(sum(i.width for i in r) + pad * (len(r) + 1) for r in rows)
    H = sum(max(i.height for i in r) for r in rows) + pad * (len(rows) + 1)
    out = Image.new("RGBA", (W, H), rgba(bg))
    y = pad
    for r in rows:
        x = pad
        for i in r:
            out.alpha_composite(i, (x, y))
            x += i.width + pad
        y += max(i.height for i in r) + pad
    out.resize((W * scale, H * scale), Image.NEAREST).save(path)


def ninepatch(im, m, W, H):
    """Stretch a nine-patch the way Godot's StyleBoxTexture does (nearest)."""
    w, h = im.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    xs = [(0, m, 0, m), (m, w - m, m, W - m), (w - m, w, W - m, W)]
    ys = [(0, m, 0, m), (m, h - m, m, H - m), (h - m, h, H - m, H)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            part = im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.alpha_composite(part, (dx0, dy0))
    return out


def write_review(d):
    os.makedirs(d, exist_ok=True)
    ld = lambda n: Image.open(os.path.join(UI, n)).convert("RGBA")
    sheet(os.path.join(d, "bar.png"),
          [bar_mock(1.0), bar_mock(0.62, 0.75), bar_mock(0.2), bar_mock(0.02)], scale=5, cols=1)
    sheet(os.path.join(d, "all_small_6x.png"),
          [ld("bar_frame_left.png"), ld("bar_wax_fill.png"), ld("bar_wax_empty.png"),
           ld("bar_frame_right.png"), ld("icon_coin.png"), ld("icon_bomb.png"), ld("btn_pause.png"),
           ld("btn_bomb.png"), ld("stick_knob.png"), ld("stick_base.png"), ld("panel_9.png"),
           ld("button_9.png"), ld("button_9_pressed.png")], scale=6, cols=9)
    sheet(os.path.join(d, "bar_6x.png"), [bar_mock(1.0), bar_mock(0.62, 0.75), bar_mock(0.2), bar_mock(0.02)],
          scale=6, cols=2)
    sheet(os.path.join(d, "bar_parts.png"),
          [ld("bar_frame_left.png"), ld("bar_wax_fill.png"), ld("bar_wax_empty.png"),
           ld("bar_frame_right.png"), ld("icon_coin.png"), ld("icon_bomb.png"),
           ld("btn_pause.png"), ld("btn_bomb.png")], scale=10)
    sheet(os.path.join(d, "boxes.png"),
          [ld("panel_9.png"), ld("button_9.png"), ld("button_9_pressed.png"),
           ninepatch(ld("panel_9.png"), 8, 90, 40), ninepatch(ld("button_9.png"), 6, 60, 20),
           ninepatch(ld("button_9_pressed.png"), 6, 60, 20)], scale=6, cols=3)
    room = ld(os.path.join("..", "rooms", "room_cellar.png")).crop((80, 60, 180, 130))
    base, knob = ld("stick_base.png"), ld("stick_knob.png")
    fade = base.copy()
    fade.putalpha(fade.getchannel("A").point(lambda a: int(a * 0.8)))
    room.alpha_composite(fade, (8, 15))
    room.alpha_composite(knob, (8 + 20 - 9 + 6, 15 + 20 - 9 - 4))
    sheet(os.path.join(d, "sticks.png"), [base, knob, room], scale=6)
    logo = ld("title_logo.png")
    sheet(os.path.join(d, "logo6.png"), [logo], scale=6)
    sheet(os.path.join(d, "logo1.png"), [logo], scale=1, pad=12)
    sheet(os.path.join(d, "logo3.png"), [logo], scale=3, pad=8)
    sheet(os.path.join(d, "icons.png"), [ld("app_icon_192.png"),
          ld("app_icon_bg_432.png").resize((192, 192), Image.NEAREST),
          ld("app_icon_fg_432.png").resize((192, 192), Image.NEAREST)], scale=1, pad=8)
    # adaptive icon as a launcher would show it: bg + fg, circle mask (72 dp)
    comp = ld("app_icon_bg_432.png")
    comp.alpha_composite(ld("app_icon_fg_432.png"))
    mask = Image.new("L", comp.size, 0)
    ImageDraw.Draw(mask).ellipse((72, 72, 360, 360), fill=255)
    comp.putalpha(mask)
    sheet(os.path.join(d, "icon_adaptive.png"), [comp.crop((72, 72, 360, 360))], scale=1, pad=8)
    prev = ld("ui_preview.png")
    prev.save(os.path.join(d, "preview1.png"))
    prev.resize((prev.width * 4, prev.height * 4), Image.NEAREST).crop((0, 0, 900, 260)).save(
        os.path.join(d, "preview4_tl.png"))
    prev.resize((prev.width * 4, prev.height * 4), Image.NEAREST).crop((1536 - 700, 0, 1536, 520)).save(
        os.path.join(d, "preview4_tr.png"))


def main():
    review = None
    if "--review" in sys.argv:
        review = sys.argv[sys.argv.index("--review") + 1]
    make_bar()
    make_icons()
    make_buttons()
    make_boxes()
    make_sticks()
    make_logo()
    make_preview()
    # Kenney fonts licence (CC0) next to the other licences
    lic = "/opt/assets/packs/kenney-fonts/fonts/License.txt"
    if os.path.exists(lic):
        shutil.copyfile(lic, os.path.join(ROOT, "assets", "licenses", "Kenney_Fonts_CC0.txt"))
    for p in OUT:
        print(os.path.relpath(p, ROOT), Image.open(p).size)
    if review:
        write_review(review)


if __name__ == "__main__":
    main()
