#!/usr/bin/env python3
"""Wax & Wane - UI art (HUD bar, icons, buttons, panels, sticks, title logo,
launcher icons) plus a mock HUD preview.

Every sprite is hand-authored pixel art written as character grids (one
character = one pixel, see PAL). The only computed shapes are the joystick
rings (plain midpoint pixel circles) and the flat glow bands behind the app
icon; nothing is random, so running this script always gives identical PNGs.

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
    "3": "#333333", "4": "#483b3a", "5": "#775c55",
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
# Gold coin with an engraved inner ring (dark on the lit side, light on the
# shaded side) and a cream glint.
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

BUTTON_9 = """
.KKKKKKKKKKKKKKKKKKKKKK.
K5555555555555555555557K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K5444444444444444444447K
K9999999999999999999999K
K9999999999999999999999K
.KKKKKKKKKKKKKKKKKKKKKK.
"""

BUTTON_9_PRESSED = """
.KKKKKKKKKKKKKKKKKKKKKK.
KKKKKKKKKKKKKKKKKKKKKKKK
K4444444444444444444449K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K4777777777777777777779K
K9999999999999999999999K
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


def main():
    review = None
    if "--review" in sys.argv:
        review = sys.argv[sys.argv.index("--review") + 1]
    make_bar()
    make_icons()
    make_buttons()
    make_boxes()
    make_sticks()
    for p in OUT:
        print(os.path.relpath(p, ROOT), Image.open(p).size)
    if review:
        write_review(review)


if __name__ == "__main__":
    main()
