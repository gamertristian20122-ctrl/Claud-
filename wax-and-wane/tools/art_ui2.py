#!/usr/bin/env python3
"""Wax & Wane - the 2.6 UI kit ("candlelit wood and brass").

One look for every menu and the HUD: dark mahogany frames with brass corner brackets and a pour of
wax on the top rail, dark-oak buttons with brass nails, a brass plate for the main action, red sealing
wax for the dangerous one, a gold focus ring with a little flame for keys and gamepads, tabs, a slider
with a flame knob, an ON/OFF switch, heading flourishes, a separator, icon sockets, the banner plate and
ribbon, the HUD's clock digits and counter chips, menu / stat icons, the title's book stack and a wax seal.
The Godot side (one Theme built from these files) is `UI.theme()` in scripts/ui/ui.gd.

Rules (DESIGN.md): 0x72 DungeonTileset II palette only (every pixel is checked against the sheet),
1 px #21141b outline, light from the top-left, flat fills, no anti-aliasing, no gradients, fully
opaque pixels. Nine-patches are built so the stretched middle rows / columns are uniform (or a plain
repeat) and every ornament sits in a fixed corner. Nothing is random: the output is identical each run.

Usage:
    python3 tools/art_ui2.py               # write every PNG into assets/art/ui/
    python3 tools/art_ui2.py --review DIR  # also write zoomed contact sheets + nine-patch mock-ups to DIR
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "art", "ui")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

PAL = {
    ".": None,
    "K": "#21141b", "k": "#222222",
    "6": "#38262d", "7": "#3b3332", "8": "#302c2b", "9": "#2b2929",
    "4": "#483b3a", "5": "#775c55", "3": "#333333", "j": "#3f3f3f", "J": "#494949", "U": "#545454",
    "a": "#aa8d7a", "A": "#d3bfa9",
    "w": "#fdf7ed", "X": "#e2b694", "d": "#d8a57d", "D": "#b58057", "f": "#c38d70",
    "F": "#8a503e", "R": "#8f4029", "m": "#62232f",
    "z": "#ffcc68", "y": "#facb3e", "Y": "#ffad3b", "o": "#ee8e2e", "e": "#e46e33", "c": "#c56025",
    "r": "#da4e38", "n": "#dc4a7b", "p": "#9f294e", "v": "#5f2d56", "q": "#f78697",
    "s": "#314152", "b": "#417089", "B": "#5698cc", "S": "#b6cbcf", "i": "#7b8994", "h": "#cae6f5",
    "G": "#3d734f", "g": "#4ba747", "t": "#49a790",
}


def rgba(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = rgba(PAL[ch]) if PAL[ch] else (0, 0, 0, 0)

    def rect(self, x, y, w, h, ch):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, ch)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y][3] > 0
        return False

    def grid(self, block, x=0, y=0):
        """Paste a char grid ('.' = leave as is)."""
        for j, row in enumerate(rows_of(block)):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.p(x + i, y + j, ch)

    def outline(self, ch="K", diag=True):
        """Ring every filled pixel with `ch` (8-neighbourhood by default)."""
        filled = [[self.get(x, y) for x in range(self.w)] for y in range(self.h)]
        nb = [(-1, 0), (1, 0), (0, -1), (0, 1)] + ([(-1, -1), (1, -1), (-1, 1), (1, 1)] if diag else [])
        for y in range(self.h):
            for x in range(self.w):
                if filled[y][x]:
                    continue
                for dx, dy in nb:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and filled[yy][xx]:
                        self.p(x, y, ch)
                        break


def rows_of(block):
    rows = [ln.strip() for ln in block.strip("\n").splitlines()]
    rows = [r for r in rows if r]
    W = max(len(r) for r in rows)
    for r in rows:
        assert len(r) == W, ("ragged row", len(r), W, r)
    return rows


def grid_img(block):
    rows = rows_of(block)
    c = Canvas(len(rows[0]), len(rows))
    c.grid(block)
    return c


OUT = []


def save(c, name):
    im = c.im if isinstance(c, Canvas) else c
    p = os.path.join(UI, name)
    os.makedirs(UI, exist_ok=True)
    im.save(p)
    OUT.append(p)
    return im


# ==========================================================================
# PANEL  (kit_panel.png 24x24, 8 px corners): a mahogany frame 3 px wide (light on the top / left edge of
# each rail), a shadow groove inside the top / left rails and a lit lip inside the bottom / right ones, a
# plum-brown field, and an L-shaped brass bracket with two nails in each corner (inside the 8x8 corner, so
# the stretched rails stay plain wood). The pour of wax on the top rail is a separate overlay (kit_drip).
# ==========================================================================
RAIL = ["F", "R", "m"]          # outer (lit) -> inner
ARM = ["y", "o", "c"]           # brass arm: lit row / body / shaded row


def frame_panel(W=24, H=24, arm=6, field="6"):
    c = Canvas(W, H)
    c.rect(1, 1, W - 2, H - 2, field)
    for x in range(1, W - 1):
        for i, ch in enumerate(RAIL):
            c.p(x, 1 + i, ch)                # top rail
            c.p(x, H - 4 + i, ch)            # bottom rail
    for y in range(1, H - 1):
        for i, ch in enumerate(RAIL):
            c.p(1 + i, y, ch)
            c.p(W - 4 + i, y, ch)
    # groove: shadow under the top / left rails, a lit lip over the bottom / right ones
    for x in range(4, W - 4):
        c.p(x, H - 5, "4")
    for y in range(4, H - 4):
        c.p(W - 5, y, "4")
    for x in range(4, W - 4):
        c.p(x, 4, "K")
    for y in range(4, H - 4):
        c.p(4, y, "K")
    # outline, the corner pixel cut
    for x in range(1, W - 1):
        c.p(x, 0, "K")
        c.p(x, H - 1, "K")
    for y in range(1, H - 1):
        c.p(0, y, "K")
        c.p(W - 1, y, "K")
    # brass brackets
    for left in (True, False):
        for top in (True, False):
            hy = 1 if top else H - 4                       # the horizontal arm's first row
            vx = 1 if left else W - 4                      # the vertical arm's first column
            xs = range(1, 1 + arm) if left else range(W - 1 - arm, W - 1)
            ys = range(1, 1 + arm) if top else range(H - 1 - arm, H - 1)
            for x in xs:
                for i in range(3):
                    c.p(x, hy + i, ARM[i])
            for y in ys:
                for i in range(3):
                    c.p(vx + i, y, ARM[i])
            # the corner square: lit on its top row and left column, shaded on the others
            for i in range(3):
                for j in range(3):
                    ch = "y" if (i == 0 or j == 0) else ("c" if (i == 2 or j == 2) else "o")
                    c.p(vx + j, hy + i, ch)
            # end caps (ink) where brass meets wood, inside the corner
            ex = 1 + arm if left else W - 2 - arm
            ey = 1 + arm if top else H - 2 - arm
            for i in range(3):
                c.p(ex, hy + i, "K")
                c.p(vx + i, ey, "K")
            # nails near the arm ends
            c.p(ex - 2 if left else ex + 2, hy + 1, "R")
            c.p(vx + 1, ey - 2 if top else ey + 2, "R")
    return c


# Wax poured along a panel's top rail (overlay, drawn 2 px above the panel's top edge): a low bulge over the
# outline and the rails, a few drips of different lengths running into the top of the field (never past the
# field's 3rd row, so the content below stays clear). Cream on top, wax shade below, the right side of each drip
# darker, 1 px ink outline.
def pour(W, bulge, drips):
    OFF = 2                                  # image row = panel row + OFF
    c = Canvas(W, 11)
    cols = {}
    for x in range(1, W - 1):
        top = -1 if bulge[0] <= x < bulge[1] else 0
        cols[x] = [top, 3]
    for (x0, w, n) in drips:
        for x in range(x0, x0 + w):
            cols[x][1] = 3 + n - (1 if (x == x0 + w - 1 and w > 2) else 0)
    for x, (top, bot) in cols.items():
        for r in range(top, bot + 1):
            if r - top < 2:
                ch = "w"
            else:
                ch = "X"
            right_of_drip = r > 3 and (x + 1 not in cols or cols[x + 1][1] < r)
            if (r >= 2 and x >= W - 4) or right_of_drip:
                ch = "d"
            c.p(x, r + OFF, ch)
    c.outline("K", diag=False)
    return c


def drip_big():
    return pour(30, (5, 20), [(4, 3, 4), (11, 2, 2), (17, 3, 3), (24, 2, 1)])


def drip_small():
    return pour(15, (3, 10), [(3, 2, 3), (9, 3, 2)])


# ==========================================================================
# CARD (kit_card.png 12x12, 4 px corners): a slim mahogany-edged card for tiles, slot cards, toasts and
# small news boxes inside a panel. INSET (kit_inset.png): a sunken dark well (lists, the Journal grid).
# ==========================================================================
def card():
    c = Canvas(12, 12)
    c.rect(1, 1, 10, 10, "8")
    for x in range(1, 11):
        c.p(x, 1, "R")
        c.p(x, 10, "m")
    for y in range(1, 11):
        c.p(1, y, "R")
        c.p(10, y, "m")
    for x in range(2, 10):
        c.p(x, 2, "4")
    for x in range(1, 11):
        c.p(x, 0, "K")
        c.p(x, 11, "K")
    for y in range(1, 11):
        c.p(0, y, "K")
        c.p(11, y, "K")
    # brass pin heads in the top corners
    c.p(2, 2, "y")
    c.p(9, 2, "o")
    return c


def inset():
    c = Canvas(10, 10)
    c.rect(1, 1, 8, 8, "9")
    for x in range(1, 9):
        c.p(x, 1, "K")
        c.p(x, 8, "4")
    for y in range(1, 9):
        c.p(1, y, "K")
        c.p(8, y, "4")
    c.p(8, 1, "9")
    c.p(1, 8, "9")
    for x in range(1, 9):
        c.p(x, 0, "8")
        c.p(x, 9, "8")
    for y in range(1, 9):
        c.p(0, y, "8")
        c.p(9, y, "8")
    return c


# ==========================================================================
# BUTTONS (24x24, corners 6 / 6 / 6 / 7): a face, a lit top row, a shaded row and a 2 px front lip (its
# thickness). Pressed: the face sits 1 px lower (the lip is 1 px), so it visibly goes down.
#   secondary: dark oak with two brass nails;  primary: a brass plate (ink text);  danger: red sealing wax.
# ==========================================================================
STYLES = {
    #            outline lit  face  shade lip   nail  shine
    "sec":       ("K", "5", "4", "7", "9", "o", None),
    "sec_hover": ("K", "o", "4", "7", "9", "y", None),
    "pri":       ("K", "y", "o", "c", "R", "R", "z"),
    "pri_hover": ("K", "z", "Y", "o", "c", "R", "w"),
    "dan":       ("K", "n", "p", "m", "v", "y", "q"),
    "dan_hover": ("K", "q", "p", "m", "v", "y", "w"),
    "off":       ("K", "4", "8", "9", "K", None, None),
}


def button(style, pressed=False, W=24, H=24):
    ol, lit, face, shade, lip, nail, shine = STYLES[style]
    c = Canvas(W, H)
    top = 1 if not pressed else 2           # the face's first row
    lip_h = 2 if not pressed else 1
    bottom = H - 1 - lip_h                   # first lip row
    c.rect(1, top, W - 2, bottom - top, face)
    for x in range(1, W - 1):
        c.p(x, top, lit)
        c.p(x, bottom - 1, shade)
        for i in range(lip_h):
            c.p(x, bottom + i, lip)
    for y in range(top, bottom - 1):
        c.p(1, y, lit)
        c.p(W - 2, y, shade)
    if shine:
        for x in range(2, 6):
            c.p(x, top + 1, shine)
        c.p(2, top + 2, shine)
    if pressed:
        for x in range(1, W - 1):
            c.p(x, 1, ol)
    if nail:
        for x in (3, W - 4):
            c.p(x, top + 2, nail)
            c.p(x, bottom - 3, nail)
    for x in range(1, W - 1):
        c.p(x, 0, ol)
        c.p(x, H - 1, ol)
    for y in range(1, H - 1):
        c.p(0, y, ol)
        c.p(W - 1, y, ol)
    return c


# Focus ring for keys / gamepads (kit_focus.png 12x12, corners 4, drawn 2 px outside the button): an ink and a
# gold ring with cream sparks on the corners; kit_focus_flame.png: the little flame UI.button lights next to the
# focused button's text.
def focus():
    W, H = 12, 12
    c = Canvas(W, H)
    for x in range(1, W - 1):
        c.p(x, 0, "K")
        c.p(x, H - 1, "K")
        c.p(x, 1, "y")
        c.p(x, H - 2, "y")
    for y in range(1, H - 1):
        c.p(0, y, "K")
        c.p(W - 1, y, "K")
        c.p(1, y, "y")
        c.p(W - 2, y, "y")
    for (x, y) in [(1, 1), (W - 2, 1), (1, H - 2), (W - 2, H - 2)]:
        c.p(x, y, "w")
    return c


FOCUS_FLAME = """
...K...
..KyK..
..KzK..
.KyzyK.
.KzwzK.
KyzwzyK
KozwzoK
KeoyoeK
.KeeeK.
..KKK..
"""


# ==========================================================================
# TABS (16x16, corners 5): rounded top corners. On: a lit plate with a gold top rule. Off: darker, lower.
# ==========================================================================
def tab(on):
    c = Canvas(16, 16)
    face, lit, rule = ("4", "5", "y") if on else ("9", "8", "4")
    c.rect(1, 1, 14, 14, face)
    for x in range(2, 14):
        c.p(x, 1, rule)
        c.p(x, 2, "o" if on else face)
    for y in range(2, 15):
        c.p(1, y, lit)
        c.p(14, y, "7" if on else "8")
    for x in range(2, 14):
        c.p(x, 0, "K")
        c.p(x, 15, "K")
    for y in range(2, 15):
        c.p(0, y, "K")
        c.p(15, y, "K")
    c.p(1, 1, "K")
    c.p(14, 1, "K")
    c.p(1, 15, "K")
    c.p(14, 15, "K")
    return c


# ==========================================================================
# SLIDER: a sunken track (kit_track.png 12x7, ends 4), its lit part (kit_track_fill.png), a flame knob.
# SWITCH: kit_switch_on / _off 20x11 (a pill with a cream knob; on = warm brass track).
# ==========================================================================
def track(fill):
    c = Canvas(12, 7)
    if not fill:
        c.rect(1, 1, 10, 5, "9")
        for x in range(1, 11):
            c.p(x, 1, "K")
            c.p(x, 5, "4")
    else:
        c.rect(1, 1, 10, 5, "o")
        for x in range(1, 11):
            c.p(x, 1, "z")
            c.p(x, 2, "y")
            c.p(x, 4, "c")
            c.p(x, 5, "R")
    for x in range(1, 11):
        c.p(x, 0, "K")
        c.p(x, 6, "K")
    for y in range(1, 6):
        c.p(0, y, "K")
        c.p(11, y, "K")
    return c


KNOB = """
...K...
..KwK..
..KzK..
.KzyyK.
.KyoyK.
KyoeoyK
KoeeeoK
KoeReoK
.KcRcK.
..KKK..
"""


def switch(on):
    W, H = 20, 11
    c = Canvas(W, H)
    # the track: a pill
    body = "c" if on else "9"
    lit = "o" if on else "8"
    for y in range(1, H - 1):
        inset = {1: 2, 2: 1, H - 3: 1, H - 2: 2}.get(y, 0)
        for x in range(1 + inset, W - 1 - inset):
            c.p(x, y, body)
    for x in range(3, W - 3):
        c.p(x, 1, lit)
    c.outline("K", diag=False)
    # the knob: a 9x9 round cream button, at the right when on
    kx = W - 11 if on else 1
    kb = "w" if on else "a"
    ks = "X" if on else "5"
    k = rows_of("""
    ..KKKKK..
    .KwwwwsK.
    KwwwwwwsK
    KwwwwwwsK
    KwwwwwwsK
    KwwwwwwsK
    KswwwwssK
    .KsssssK.
    ..KKKKK..
    """)
    for j, row in enumerate(k):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            c.p(kx + i, 1 + j, {"w": kb, "s": ks}.get(ch, ch))
    if on:   # a lit wick on the knob
        c.p(kx + 4, 3, "y")
        c.p(kx + 4, 4, "o")
    return c


# ==========================================================================
# HEADINGS / SEPARATOR / SOCKET
# ==========================================================================
def orn_l():
    """A heading flourish (left side): a small brass dot, a rule and a diamond next to the text."""
    W, H = 18, 7
    c = Canvas(W, H)
    for x in range(4, 13):
        c.p(x, 3, "y")
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if abs(dx) + abs(dy) <= 2:
                ch = "z" if (dx, dy) == (0, -1) else ("y" if dy < 0 else ("o" if dy == 0 else "c"))
                c.p(14 + dx, 3 + dy, ch)
    for (dx, dy) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]:
        c.p(1 + dx, 3 + dy, "y" if dy < 0 else ("o" if dy == 0 else "c"))
    c.outline("K")
    return c


def mirror(c):
    m = Canvas(c.w, c.h)
    for y in range(c.h):
        for x in range(c.w):
            m.px[c.w - 1 - x, y] = c.px[x, y]
    return m


SEP_GEM = """
...K...
..KyK..
.KyzcK.
KyoooRK
.KcoRK.
..KRK..
...K...
"""


def sep_tile():
    c = Canvas(4, 2)
    c.rect(0, 0, 4, 1, "K")
    c.rect(0, 1, 4, 1, "4")
    return c


def slot():
    c = Canvas(18, 18)
    c.rect(1, 1, 16, 16, "9")
    for x in range(0, 18):
        c.p(x, 0, "K")
        c.p(x, 17, "4")
    for y in range(0, 18):
        c.p(0, y, "K")
        c.p(17, y, "4")
    c.p(17, 0, "8")
    c.p(0, 17, "8")
    for (x, y) in [(1, 1), (16, 1), (1, 16), (16, 16)]:
        c.p(x, y, "8")
    return c


# ==========================================================================
# BANNERS: a brass plate for titles (kit_plate.png 16x16, corners 5, rivets in the corners; ink text,
# engraved) and a dark ribbon for the line under it (kit_strip.png 16x12, corners 4, brass end caps).
# ==========================================================================
def plate():
    W, H = 16, 16
    c = Canvas(W, H)
    c.rect(1, 1, W - 2, H - 2, "o")
    for x in range(1, W - 1):
        c.p(x, 1, "z")
        c.p(x, 2, "y")
        c.p(x, H - 4, "c")
        c.p(x, H - 3, "R")
        c.p(x, H - 2, "R")
    for y in range(2, H - 4):
        c.p(1, y, "y")
        c.p(W - 2, y, "c")
    for (x, y) in [(3, 4), (W - 4, 4), (3, H - 6), (W - 4, H - 6)]:
        c.p(x, y, "R")
        c.p(x - 1, y - 1, "z")
    for x in range(1, W - 1):
        c.p(x, 0, "K")
        c.p(x, H - 1, "K")
    for y in range(1, H - 1):
        c.p(0, y, "K")
        c.p(W - 1, y, "K")
    return c


def strip():
    W, H = 16, 12
    c = Canvas(W, H)
    c.rect(1, 1, W - 2, H - 2, "6")
    for x in range(1, W - 1):
        c.p(x, 1, "4")
        c.p(x, H - 2, "9")
    # brass end caps
    for y in range(1, H - 1):
        for i, ch in enumerate(["y", "o", "c"]):
            c.p(1 + i, y, ch)
            c.p(W - 4 + i, y, ch)
        c.p(4, y, "K")
        c.p(W - 5, y, "K")
    for x in range(1, W - 1):
        c.p(x, 0, "K")
        c.p(x, H - 1, "K")
    for y in range(1, H - 1):
        c.p(0, y, "K")
        c.p(W - 1, y, "K")
    c.p(2, 3, "R")
    c.p(W - 3, 3, "R")
    c.p(2, H - 4, "R")
    c.p(W - 3, H - 4, "R")
    return c


# ==========================================================================
# HUD: the clock's digits (hud_digits.png: 0-9 and ':' in 8x12 cells, 2 px strokes, cream lit from the left,
# 1 px ink outline; hud_digits_hot.png the same in red for low wax), the plate they sit on, counter chips,
# the coin and bomb icons (12x12), the boss bar's frame.
# ==========================================================================
DIGITS = {
    "0": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "1": ["..##..", ".###..", "####..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    "2": [".####.", "##..##", "....##", "....##", "...##.", "..##..", ".##...", "##....", "##....", "######"],
    "3": [".####.", "##..##", "....##", "....##", "..###.", "....##", "....##", "....##", "##..##", ".####."],
    "4": ["##..##", "##..##", "##..##", "##..##", "######", "....##", "....##", "....##", "....##", "....##"],
    "5": ["######", "##....", "##....", "#####.", "....##", "....##", "....##", "....##", "##..##", ".####."],
    "6": [".####.", "##..##", "##....", "##....", "#####.", "##..##", "##..##", "##..##", "##..##", ".####."],
    "7": ["######", "....##", "....##", "...##.", "...##.", "..##..", "..##..", "..##..", "..##..", "..##.."],
    "8": [".####.", "##..##", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", "##..##", ".####."],
    "9": [".####.", "##..##", "##..##", "##..##", ".#####", "....##", "....##", "....##", "##..##", ".####."],
    ":": ["......", "......", "..##..", "..##..", "......", "......", "..##..", "..##..", "......", "......"],
}
DIGIT_ORDER = "0123456789:"


def digits(lit, shade):
    cw, ch = 8, 12
    c = Canvas(cw * len(DIGIT_ORDER), ch)
    for n, d in enumerate(DIGIT_ORDER):
        cell = Canvas(cw, ch)
        rows = DIGITS[d]
        for y, row in enumerate(rows):
            for x, chh in enumerate(row):
                if chh == "#":
                    # a 2 px stroke: the right / lower pixel of each stroke is the shaded one
                    right_edge = x + 1 >= len(row) or row[x + 1] != "#"
                    below = y + 1 < len(rows) and rows[y + 1][x] == "#"
                    sh = right_edge and (x == 0 or row[x - 1] == "#")
                    cell.p(1 + x, 1 + y, shade if sh or (not below and y == len(rows) - 1 and x > 0) else lit)
        cell.outline("K")
        c.im.alpha_composite(cell.im, (n * cw, 0))
    c.px = c.im.load()
    return c


def clockplate():
    W, H = 12, 12
    c = Canvas(W, H)
    c.rect(1, 1, W - 2, H - 2, "6")
    for x in range(1, W - 1):
        c.p(x, 1, "y")
        c.p(x, H - 2, "c")
        c.p(x, 2, "K")
    for y in range(1, H - 1):
        c.p(1, y, "y")
        c.p(W - 2, y, "c")
        c.p(2, y, "K")
    c.p(2, 2, "K")
    c.p(W - 2, 1, "o")
    c.p(1, H - 2, "o")
    for x in range(1, W - 1):
        c.p(x, 0, "K")
        c.p(x, H - 1, "K")
    for y in range(1, H - 1):
        c.p(0, y, "K")
        c.p(W - 1, y, "K")
    return c


def chip():
    c = Canvas(10, 10)
    c.rect(1, 1, 8, 8, "6")
    for x in range(1, 9):
        c.p(x, 1, "4")
        c.p(x, 8, "9")
    for x in range(1, 9):
        c.p(x, 0, "K")
        c.p(x, 9, "K")
    for y in range(1, 9):
        c.p(0, y, "K")
        c.p(9, y, "K")
    return c


HUD_COIN = """
...KKKKKK...
..KzzyyyyoK.
.KzyyyyyyocK
KzyyyocyyyocK
"""
COIN = """
...KKKKKK...
.KKccccccKK.
.KczzyyyycK.
KczyyyocyycK
KczyyyocyycK
KcyyyyocyycK
KcyyyyocyycK
KcyyyyocyycK
KcyyyyyyyycK
.KcyyyyyycK.
.KKccccccKK.
...KKKKKK...
"""
BOMB = """
.........y..
........ywy.
......K..y..
.....KoK....
...KKKcKK...
..KUUjjjjK..
.KUSUjjjjjK.
.KUUjjjjj3K.
.KjjjjjjJ3K.
.KjjjjjJ33K.
..KjJJ333K..
...KKKKKK...
"""

BOSS_FRAME = None   # built in boss_frame()


def boss_frame():
    W, H = 16, 10
    c = Canvas(W, H)
    c.rect(1, 1, W - 2, H - 2, "9")
    for x in range(1, W - 1):
        c.p(x, 1, "K")
        c.p(x, H - 2, "4")
    for y in range(1, H - 1):
        for i, ch in enumerate(["y", "o", "c"]):
            c.p(1 + i, y, ch)
            c.p(W - 4 + i, y, ch)
        c.p(4, y, "K")
        c.p(W - 5, y, "K")
    for x in range(1, W - 1):
        c.p(x, 0, "K")
        c.p(x, H - 1, "K")
    for y in range(1, H - 1):
        c.p(0, y, "K")
        c.p(W - 1, y, "K")
    c.p(2, 2, "z")
    c.p(W - 3, 2, "z")
    return c


# ==========================================================================
# ICONS (11x11, ink outline): the title's small buttons, the results' stat tiles, the primary actions.
# ==========================================================================
ICONS = {
    "ico_journal": """
    .KKKKKKKK..
    KGGGGGGGgK.
    KGyyyyyGgAK
    KGGGGGGGgAK
    KGGyyyGGgAK
    KGGGGGGGgAK
    KGGGGGGGgAK
    KGGGGGGGgAK
    KGGGGGGGgAK
    KKKKKKKKKwK
    .KKKKKKKKK.
    """,
    "ico_seed": """
    KKKKKKKKKKK
    KwXKwXKwXKK
    KXXKXXKXXKK
    KKKKKKKKKKK
    KwXKwXKwXKK
    KXXKXXKXXKK
    KKKKKKKKKKK
    KwXKyoKwXKK
    KXXKocKXXKK
    KKKKKKKKKKK
    .KKKKKKKKK.
    """,
    "ico_settings": """
    ....KKK....
    ..K.KaK.K..
    .KaKKaKKaK.
    ..KaaaaaK..
    KKKaKKKaKKK
    KaaaK.KaaaK
    KKKaKKKaKKK
    ..KaaaaaK..
    .KaKK5KKaK.
    ..K.K5K.K..
    ....KKK....
    """,
    "ico_credits": """
    .KKKKKKKK..
    KwwwwwwwwK.
    KXwKKKKwXK.
    .KwwwwwwKy.
    .KwKKKKKyK.
    .KwwwwwyoK.
    .KwKKKyoK..
    .KwwwwoKwK.
    KXwwwwwwXK.
    KwwwwwwwwK.
    .KKKKKKKK..
    """,
    "ico_quit": """
    .KKKKKKKK..
    .KFFFFFFK..
    .KFRRRRFK..
    .KFRRRRFK..
    .KFRRRyFKK.
    .KFRRRRFKwK
    .KFRRRRFK.K
    .KFRRRRFK..
    .KFRRRRFK..
    KKKKKKKKKK.
    KaaaaaaaaaK
    """,
    "ico_flame": """
    .....K.....
    ....KyK....
    ....KyK....
    ...KyzyK...
    ..KyzwzyK..
    ..KozwzoK..
    .KoyzwzyoK.
    .KeoyzyoeK.
    .KeeoooeeK.
    ..KeeReeK..
    ...KKKKK...
    """,
    # the same flame cut into brass (on the primary button: dark on the plate, a bright core)
    "ico_flame_dark": """
    .....K.....
    ....KRK....
    ....KRK....
    ...KRcRK...
    ..KRcycRK..
    ..KRcycRK..
    .KRRcycRRK.
    .KmRRcRRmK.
    .KmmRRRmmK.
    ..KmmmmmK..
    ...KKKKK...
    """,
    "ico_moon": """
    ...KKKK....
    ..KhhSK....
    .KhhSK.....
    KhhSK......
    KhhSK...KK.
    KhhSSK.KhK.
    KhhhSSKShK.
    .KhhhSSSK..
    .KShhhSSK..
    ..KKSSSK...
    ....KKK....
    """,
    "ico_clock": """
    ...KKKKK...
    ..KwwwwwK..
    .KwwwKwwXK.
    KwwwwKwwwXK
    KwwwwKwwwXK
    KwwwwKKKwXK
    KwwwwwwwwXK
    KXwwwwwwXXK
    .KXXwwwXXK.
    ..KKXXXKK..
    ...KKKKK...
    """,
    "ico_stairs": """
    .......KKKK
    .......KaaK
    .......KAaK
    ....KKKKaaK
    ....KaaaaaK
    ....KAaaaaK
    .KKKKaaaaaK
    .KaaaaaaaaK
    .KAaaaaaaaK
    KKKKKKKKKKK
    K555555555K
    """,
    "ico_skull": """
    ..KKKKKKK..
    .KwwwwwwwK.
    KwwwwwwwwXK
    KwKKwwKKwXK
    KwKKwwKKwXK
    KwwwwKwwwXK
    .KXwwwwwXK.
    ..KwKwKwK..
    ..KXwXwXK..
    ...KKKKK...
    ...........
    """,
    "ico_page": """
    .KKKKKKK...
    .KwwwwwwKK.
    .KwKKKwwXwK
    .KwwwwwwXXK
    .KwKKKKwwXK
    .KwwwwwwwXK
    .KwKKKKKwXK
    .KwwwwwwwXK
    .KwKKKwwwXK
    .KXwwwwwwXK
    .KKKKKKKKKK
    """,
    "ico_relic": """
    ....KKK....
    ...KhSbK...
    ..KhhSbbK..
    .KhwhSbbBK.
    KhhhhSbbbBK
    KSSSSSbbbbK
    .KbbbbbbbK.
    ..KbbbbbK..
    ...KbbbK...
    ....KbK....
    .....K.....
    """,
    "ico_rooms": """
    ..KKKKKKK..
    .KFFFFFFFK.
    KFRRRRRRRFK
    KFRKKKKKRFK
    KFRK999KRFK
    KFRK999KRFK
    KFRK99yKRFK
    KFRK999KRFK
    KFRK999KRFK
    KKKKKKKKKKK
    K555555555K
    """,
    "ico_back": """
    ...........
    ....KK.....
    ...KyK.....
    ..KyyKKKKK.
    .KyyyyyyyyK
    KyyyyyyyyyK
    .KcyycccccK
    ..KcyKKKKK.
    ...KcK.....
    ....KK.....
    ...........
    """,
}

# Tallow's stand on the title: three old books (wine, green, night blue) with gold bands and page edges.
def books():
    W, H = 36, 16
    c = Canvas(W, H)
    specs = [  # x0, x1, y0, h, body, lit, dark
        (1, W - 1, 11, 5, "s", "b", "2"),
        (3, W - 4, 6, 5, "G", "g", "k"),
        (6, W - 8, 1, 5, "p", "n", "m"),
    ]
    PAL.setdefault("2", "#2a2a3a")
    for x0, x1, y0, h, body, lit, dark in specs:
        c.rect(x0, y0, x1 - x0, h, body)
        for x in range(x0, x1):
            c.p(x, y0, lit)
            c.p(x, y0 + h - 1, dark)
        # gold bands near each end, page edges on the right
        for bx in (x0 + 3, x1 - 7):
            for y in range(y0, y0 + h):
                c.p(bx, y, "y" if y < y0 + h - 1 else "c")
        for y in range(y0 + 1, y0 + h - 1):
            c.p(x1 - 3, y, "A")
            c.p(x1 - 2, y, "w")
            c.p(x1 - 1, y, "A")
        # a title stamp in the middle of the spine
        mid = (x0 + x1 - 3) // 2
        c.p(mid - 1, y0 + 2, "y")
        c.p(mid, y0 + 2, "y")
        c.p(mid + 1, y0 + 2, "y")
    c.outline("K", diag=False)
    return c


SEAL = """
...KKKKKK...
..KrrrnnrK..
.KrnnrrrrrK.
KrnrrppprrrK
KrnrpKKprrpK
KrrrpKrprrpK
KrrrrpKprrpK
KrrrppKKprpK
.KrrrrrrrppK
.KprrrrrppK.
..KKpppppK..
....KKKKK...
"""

MEDAL = """
....KKKKKKK....
..KKzzyyyyyKK..
.KzzyyyyyyyyoK.
.KzyoooooooyoK.
KzyocccccccoycK
KyyocccccccoycK
KyyocccccccoycK
KyyocccccccoycK
KyyocccccccoycK
KyyocccccccoycK
KyoocccccccoocK
.KoyoooooooocK.
.KoyyyyyyyyccK.
..KKccccccRKK..
....KKKKKKK....
"""


# ==========================================================================
def palette_check():
    import art_rooms
    allowed = art_rooms.sheet_palette()
    bad = 0
    for p in OUT:
        im = Image.open(p).convert("RGBA")
        for (r, g, b, a) in set(im.convert('RGBA').get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()):
            if a == 0:
                continue
            if a != 255 or (r, g, b) not in allowed:
                print("OFF-PALETTE", os.path.relpath(p, ROOT), (r, g, b, a))
                bad += 1
    print("[art_ui2] palette check: %d files, %s" % (len(OUT), "PASS" if bad == 0 else "%d FAIL" % bad))
    return bad


def make_all():
    save(frame_panel(), "kit_panel.png")
    save(drip_big(), "kit_drip.png")
    save(drip_small(), "kit_drip_small.png")
    save(card(), "kit_card.png")
    save(inset(), "kit_inset.png")
    for name, style in [("kit_btn", "sec"), ("kit_btn_hover", "sec_hover"), ("kit_btn_primary", "pri"),
                        ("kit_btn_primary_hover", "pri_hover"), ("kit_btn_danger", "dan"),
                        ("kit_btn_danger_hover", "dan_hover"), ("kit_btn_disabled", "off")]:
        save(button(style), name + ".png")
    save(button("sec", True), "kit_btn_pressed.png")
    save(button("pri", True), "kit_btn_primary_pressed.png")
    save(button("dan", True), "kit_btn_danger_pressed.png")
    save(focus(), "kit_focus.png")
    save(grid_img(FOCUS_FLAME), "kit_focus_flame.png")
    save(tab(True), "kit_tab_on.png")
    save(tab(False), "kit_tab.png")
    save(track(False), "kit_track.png")
    save(track(True), "kit_track_fill.png")
    save(grid_img(KNOB), "kit_knob.png")
    save(switch(True), "kit_switch_on.png")
    save(switch(False), "kit_switch_off.png")
    orn = orn_l()
    save(orn, "kit_orn_l.png")
    save(mirror(orn), "kit_orn_r.png")
    save(grid_img(SEP_GEM), "kit_sep_gem.png")
    save(sep_tile(), "kit_sep.png")
    save(slot(), "kit_slot.png")
    save(plate(), "kit_plate.png")
    save(strip(), "kit_strip.png")
    save(digits("w", "X"), "hud_digits.png")
    save(digits("r", "p"), "hud_digits_hot.png")
    save(clockplate(), "hud_clockplate.png")
    save(chip(), "hud_chip.png")
    save(grid_img(COIN), "hud_coin.png")
    save(grid_img(BOMB), "hud_bomb.png")
    save(boss_frame(), "boss_frame.png")
    for name, block in ICONS.items():
        save(grid_img(block), name + ".png")
    save(books(), "title_books.png")
    save(grid_img(SEAL), "kit_seal.png")
    save(grid_img(MEDAL), "kit_medal.png")


# ---------------------------------------------------------------- review sheets
def ninepatch(im, l, t, r, b, W, H):
    """Stretch a nine-patch the way Godot's StyleBoxTexture does (nearest)."""
    w, h = im.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    xs = [(0, l, 0, l), (l, w - r, l, W - r), (w - r, w, W - r, W)]
    ys = [(0, t, 0, t), (t, h - b, t, H - b), (h - b, h, H - b, H)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                part = im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
                out.alpha_composite(part, (dx0, dy0))
    return out


def sheet(path, ims, scale=6, bg="#140c11", pad=4, cols=None):
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


def mock(d):
    """A panel with a drip, a heading, buttons in every state and a focus ring, as the game composes them."""
    ld = lambda n: Image.open(os.path.join(UI, n)).convert("RGBA")
    W, H = 190, 120
    im = Image.new("RGBA", (W + 20, H + 20), rgba("#140c11"))
    im.alpha_composite(ninepatch(ld("kit_panel.png"), 8, 8, 8, 8, W, H), (10, 10))
    im.alpha_composite(ld("kit_drip.png"), (10 + 30, 10 - 2))
    im.alpha_composite(ld("kit_drip_small.png"), (10 + W - 50, 10 - 2))
    im.alpha_composite(ld("kit_orn_l.png"), (10 + 50, 22))
    im.alpha_composite(ld("kit_orn_r.png"), (10 + 127, 22))
    y = 34
    for row in [["kit_btn_primary", "kit_btn_primary_hover", "kit_btn_primary_pressed"],
                ["kit_btn", "kit_btn_hover", "kit_btn_pressed"],
                ["kit_btn_danger", "kit_btn_danger_hover", "kit_btn_disabled"]]:
        x = 22
        for n in row:
            im.alpha_composite(ninepatch(ld(n + ".png"), 6, 6, 6, 7, 52, 24), (x, y))
            x += 58
        y += 28
    f = ninepatch(ld("kit_focus.png"), 4, 4, 4, 4, 52 + 4, 24 + 4)
    im.alpha_composite(f, (22 - 2, 34 - 2))
    im.alpha_composite(ld("kit_focus_flame.png"), (22 + 6, 34 + 6))

    return im


def write_review(d):
    os.makedirs(d, exist_ok=True)
    ld = lambda n: Image.open(n).convert("RGBA")
    ims = [ld(p) for p in OUT]
    sheet(os.path.join(d, "kit_all_6x.png"), ims, scale=6, cols=12)
    sheet(os.path.join(d, "kit_mock_4x.png"), [mock(d)], scale=4)


def main():
    review = sys.argv[sys.argv.index("--review") + 1] if "--review" in sys.argv else None
    make_all()
    bad = palette_check()
    if review:
        write_review(review)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
