#!/usr/bin/env python3
"""Wax & Wane - app, launcher, store and Steam icons.

The icon: Tallow, drawn large, in front of a pewter-rimmed clock dial with the
hands at ten to two (the flame goes out at 2 AM). The flame is the brightest
thing in the picture; the dial's warm light is two stepped rings with a 1 px
checker band at each edge (no smooth gradient). Old-house wallpaper fills the
corners.

Pixel art at a small base size, scaled up by whole numbers (nearest
neighbour) for every output, so every file is crisp:
  - flat icon: 64 x 64 base   -> legacy 192 (x3), store 512 (x8), Steam 256
    (x4), Steam community 184 (x3, 4 px trimmed off each edge), Godot's
    icon.png 512 (x8), and 64/128/256 in the Windows .ico
  - Android adaptive: 108 x 108 base (x4 = 432), the launcher shows the
    middle 72; Tallow (foreground) stays inside the 66 px safe circle, the
    dial and wall are the background layer
  - Windows .ico 16 / 32 / 48: their own art (hand-drawn 16; the in-game
    1x Tallow, drawn the way player.gd draws it, for 32 and 48) - the .ico
    itself is written by tools/art_platform.py from ico_images()

Big Tallow is hand-placed character grids (one char = one pixel). Only the
dish shading was started from an ellipse and then finished by hand; the dial,
light rings, wallpaper and clock hands are plain pixel rules. Nothing is
random, so running this script always gives identical PNGs.

Colours: the 0x72 DungeonTileset II palette (art_ui.PAL) plus Tallow's
in-game wax colour #f3e6cf (player.gd). 1 px dark outline, light from the
top-left, no anti-aliasing.

Usage:
    python3 tools/art_icon.py               # write all icons
    python3 tools/art_icon.py --review DIR  # also the concept + phone-size sheets
    python3 tools/art_icon.py --review DIR --old OLD_DIR
        # + compare.png: the new icons next to copies of the old ones in OLD_DIR
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_ui  # noqa: E402  (palette, UI paths)

ROOT = art_ui.ROOT
ART = art_ui.ART
UI = art_ui.UI
MARKETING = os.path.join(ROOT, "docs", "marketing", "icons")
OUT = []

PAL = dict(art_ui.PAL)
PAL.update({
    "W": "#f3e6cf",   # Tallow's wax (player.gd WAX)
    "b": "#5698cc", "B": "#417089",
})


def rgba(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def rows_of(block):
    rows = [ln.strip() for ln in block.strip("\n").splitlines()]
    return [r for r in rows if r]


def grid(block):
    """Char grid -> RGBA image (short rows are padded with transparent px)."""
    rows = rows_of(block)
    W = max(len(r) for r in rows)
    rows = [r.ljust(W, ".") for r in rows]
    im = Image.new("RGBA", (W, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if PAL[ch]:
                px[x, y] = rgba(PAL[ch])
    return im


def upscale(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    OUT.append(path)
    return im


# ==========================================================================
# BIG TALLOW (hand-placed). Layers: dish, body, face, the dish's front lip
# again (over the body's foot), ring handle, wick, flame.
# ==========================================================================
FLAME = """
.......r.......
......rr.......
......ro.......
.....rro.......
.....roor......
....rrooo......
....roooor.....
...rrooyoor....
...rooyyoor....
..rrooyyyoor...
..rooyyyyyor...
..rooyywyyoor..
.rooyywwwyyor..
.rooyywwwwyoor.
.rooyywwwwwyor.
.rooyywwwwwyor.
.roooywwwwwyor.
..rooywwwwyoor.
..rrooywwyoor..
...rrooyyoor...
....rroooorr...
......rRRr.....
"""
FLAME_CORE = (7, 14)        # the flame's centre inside FLAME (glow rings centre)

# Wax body, 23 x 23: melted pool on top, a lip, drips that bulge the outline
# on both sides (like the in-game drips) and two short raised front drips.
BODY_TOP = """
......KKKKKKKKKKK......
....KKwwwwwwwwwwwKK....
...KwwXXXXXXXXXXXwaK...
..KwwXXXXXXXXXXXXXwAK..
.KwwwdXXXXXXXXXXXdwAaK.
KwwwwwwwwwwwwwwwwwAAaaK
"""
BODY_H = 23
BODY_ROW = ".KwWWWWWWWWWWWWWWAAAaK."     # lit edge, wax, shade, deep shade
FRONT_DRIPS = ((4, 4), (5, 3), (12, 2), (13, 3))   # (x, length) below the lip


def body_grid():
    rows = [list(r) for r in rows_of(BODY_TOP)]
    while len(rows) < BODY_H - 1:
        rows.append(list(BODY_ROW))
    rows.append(list(".KKKKKKKKKKKKKKKKKKKKK."))
    for y in (6, 7):                       # left side drip
        rows[y][0], rows[y][1] = "K", "w"
    for y in (6, 7, 8):                    # right side drip
        rows[y][21], rows[y][22] = "a", "K"
    for x, n in FRONT_DRIPS:               # raised drips: lit, one shade px at the tip
        for k in range(n):
            rows[6 + k][x] = "w"
        if rows[5 + n][x + 1] == "W":
            rows[5 + n][x + 1] = "A"
    return "\n".join("".join(r) for r in rows)


FACE = """
...wK......wK...
...KK......KK...
...KK......KK...
................
.qq...K...K..qq.
.......KKK......
"""

# Brass chamberstick dish seen from a little above: back rim, the bowl Tallow
# stands in, the lit front lip (brightest on the left) and the underside.
DISH = """
..........KKKKKKKKKKKKKKKKK..........
......KKKKyyyyyyyyyyyyyyyyyKKKK......
...KKKyyyyyycccccccccccccyyyyooKKK...
..KyyyycccccccccccccccccccccccyoooK..
.KyyyRRRRRRRRRRRRRRRRRRRRRRRRRRRcccK.
KyyyyRRRRRRRRRRRRRRRRRRRRRRRRRRRccccK
KywwwwRRRRRRRRRRRRRRRRRRRRRRRRRoooocK
KoywwwwwwRRRRRRRRRRRRRRRRRRRyyyooocRK
KRoyyywwwwyyyyyyyyyyyyyyyyyyyyycccRRK
.KRoooyyyyyyyyyyyyyyyyyyyyyooooRRRRK.
..KRRRoooooooooooooooooooooccccRRRK..
...KKKRRRRcccccccccccccccccRRRRKKK...
......KKKKRRRRRRRRRRRRRRRRRKKKK......
..........KKKKKKKKKKKKKKKKK..........
"""
DISH_FRONT_ROW = 8          # dish rows from here are drawn again over the body

# Finger ring on the right of the dish, as on the in-game holder.png.
RING = """
..KKKKK..
.KyyyyoK.
KyoKKKocK
KyK...KcK
KoK...KRK
KoK...KRK
KocKKKcRK
.KccRRRK.
..KKKKK..
"""


def hero():
    """Big Tallow on a transparent 48 x 58 canvas.
    Returns (image, flame centre (x, y))."""
    flame, body, face = grid(FLAME), grid(body_grid()), grid(FACE)
    dish, ring = grid(DISH), grid(RING)
    W, H = 48, 58
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dx, dy = 1, H - dish.height - 1
    im.alpha_composite(dish, (dx, dy))
    bx = dx + 18 - 11                          # body centre on the dish centre
    by = dy + 7 - (BODY_H - 1)                 # body's foot on dish row 7
    im.alpha_composite(body, (bx, by))
    im.alpha_composite(face, (bx + 4, by + 10))
    front = dish.crop((0, DISH_FRONT_ROW, dish.width, dish.height))
    im.alpha_composite(front, (dx, dy + DISH_FRONT_ROW))
    im.alpha_composite(ring, (dx + dish.width - 3, dy + 2))
    wx = bx + 11
    for k, ch in enumerate("RKK"):             # glowing wick tip, wick
        im.putpixel((wx, by - 2 + k), rgba(PAL[ch]))
    fx, fy = wx - flame.width // 2, by - 2 - flame.height
    im.alpha_composite(flame, (fx, fy))
    return im, (fx + FLAME_CORE[0] + 0.5, fy + FLAME_CORE[1] + 0.5)


# ==========================================================================
# SMALL TALLOW (1x, for the 32 / 48 px .ico sizes): drawn exactly the way
# player.gd _draw() draws the standing candle, with the in-game holder,
# face and flame sprites.
# ==========================================================================
OUTLINE, WAX_HI, WAX, WAX_SH, WAX_DEEP, POOL = (
    "#21141b", "#fdf7ed", "#f3e6cf", "#d3bfa9", "#aa8d7a", "#e2b694")


def mini_tallow(h, bw=10):
    """Returns (image, flame centre). Image is 18 x (h + 19); the feet point
    (player position) is (9, bottom)."""
    H = h + 19
    im = Image.new("RGBA", (18, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ox, oy = 9, H

    def r(x, y, w, hh, col):
        d.rectangle((ox + x, oy + y, ox + x + w - 1, oy + y + hh - 1), fill=rgba(col))

    base = -5
    top = base - h
    L = -bw // 2
    R = L + bw
    r(L, top, bw, h, OUTLINE)
    r(L + 1, top + 1, bw - 2, h - 1, WAX)
    r(L + 1, top + 1, 1, h - 1, WAX_HI)
    if bw >= 10:
        r(R - 4, top + 1, 2, h - 1, WAX_SH)
    else:
        r(R - 3, top + 1, 1, h - 1, WAX_SH)
    r(R - 2, top + 1, 1, h - 1, WAX_DEEP)
    r(L + 1, top + 1, bw - 2, 1, WAX_HI)
    r(L + 2, top + 1, bw - 4, 1, POOL)
    if bw >= 8:
        r(L + 3, top + 2, bw - 6, 1, WAX_SH)
    if h >= 6:
        r(L, top + 1, 1, 3, OUTLINE)
        r(L - 1, top + 2, 1, 3, OUTLINE)
        r(L, top + 2, 1, 2, WAX_HI)
        r(L - 1, top + 5, 2, 1, OUTLINE)
        r(R - 1, top + 1, 1, 4, OUTLINE)
        r(R, top + 3, 1, 3, OUTLINE)
        r(R - 1, top + 3, 1, 2, WAX_SH)
    if h >= 11 and bw >= 10:
        r(0, top + 2, 1, h // 2, WAX_SH)
        r(-1, top + 2 + h // 2, 3, 1, WAX_SH)
    r(0, top - 2, 1, 3, OUTLINE)                                   # wick
    hero_dir = os.path.join(ART, "hero")
    ld = lambda n: Image.open(os.path.join(hero_dir, n + ".png")).convert("RGBA")
    im.alpha_composite(ld("holder"), (ox - 9, oy - 7))
    im.alpha_composite(ld("face_open"), (ox - 5, oy + top + min(5, max(2, 2 + h // 5))))
    im.alpha_composite(ld("flame_f0"), (ox - 4, oy + top - 14))
    return im, (ox + 0.5, oy + top - 7.5)


# Windows 16 px: dial, white candle, flame breaking the rim, brass dish.
ICON_16 = """
.....KKrKKK.....
...KKSSroiiKK...
..KSS6roor6isK..
.KS26moyyom62sK.
.KS26mowyom62sK.
KS226mmyomm622sK
Ki22KKKKKKKK22sK
Ki22KwXXXXaK22sK
Kia2KwWWWWAKa2sK
Ks22KwKWWKAK22sK
.Ks2KwqWWqAK2sK.
.KyyKwWWWWAKyoK.
KywwyyyyyyyyyyoK
.KoooooooooocRK.
..KccccccccRRK..
....KKKKKKKK....
"""


# ==========================================================================
# Backdrops: plain pixel rules - rectangles, pixel discs, stepped light rings
# with a 1 px checker band at each ring edge.
# ==========================================================================
class Canvas:
    def __init__(self, n, ch="K"):
        self.n = n
        self.c = [[ch] * n for _ in range(n)]

    def put(self, x, y, ch):
        if 0 <= x < self.n and 0 <= y < self.n:
            self.c[y][x] = ch

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(max(0, y0), min(self.n, y1 + 1)):
            for x in range(max(0, x0), min(self.n, x1 + 1)):
                self.c[y][x] = ch

    def disc(self, cx, cy, r, ch, only=None):
        for y in range(self.n):
            for x in range(self.n):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r - 0.3:
                    if not only or self.c[y][x] in only:
                        self.c[y][x] = ch

    def light(self, cx, cy, radii, ramps, tall=1.0):
        """Stepped light: radii largest first = level 1, 2, ...; each material
        char in `ramps` maps to ramps[ch][level]. A 1 px checker band sits
        just outside each ring edge (dither, never a smooth ramp)."""
        for y in range(self.n):
            for x in range(self.n):
                ch = self.c[y][x]
                if ch not in ramps:
                    continue
                d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) / tall)
                lv = 0
                for i, r in enumerate(radii):
                    if d <= r - 0.3 or (d <= r + 0.7 and (x + y) % 2 == 0):
                        lv = i + 1
                ramp = ramps[ch]
                self.c[y][x] = ramp[min(lv, len(ramp) - 1)]

    def image(self):
        im = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        px = im.load()
        for y in range(self.n):
            for x in range(self.n):
                if PAL[self.c[y][x]]:
                    px[x, y] = rgba(PAL[self.c[y][x]])
        return im


def line(cv, x0, y0, x1, y1, ch):
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


# ==========================================================================
# THE ICON (concept B, polished)
# ==========================================================================
DIAL_R = 27.5             # dial radius per 64 visible px
GLOW = (19.0, 12.5)       # warm light rings on the dial face, per 64 px
LIGHT = (-0.7071, -0.7071)
DOT_STEPS = (0.8, 0.4, -0.3, -0.75)     # bezel facing the light -> away
BEZEL = ("hSiis", "Siiss", "iisss")     # pewter, outer band to inner band
HANDS = ((300, 7), (55, 12))             # (clock degrees, length short of R): 1:50


def dial(cv, dcx, dcy, R, bands=BEZEL, hands=HANDS, marks=True):
    """Pewter-rimmed clock dial: K outline, bevelled bezel lit from the
    top-left, K inner line, dark slate face '2', hour marks, hands."""
    n = cv.n
    for y in range(n):
        for x in range(n):
            ddx, ddy = x + 0.5 - dcx, y + 0.5 - dcy
            d = math.hypot(ddx, ddy)
            if d > R + 1:
                continue
            if d > R - 0.3:
                cv.c[y][x] = "K"
                continue
            dot = (ddx * LIGHT[0] + ddy * LIGHT[1]) / max(d, 0.01)
            lv = sum(1 for t in DOT_STEPS if dot <= t)
            band = int((R - 0.3 - d) // 1)
            if band < len(bands):
                cv.c[y][x] = bands[band][lv]
            elif band == len(bands):
                cv.c[y][x] = "K"
            else:
                cv.c[y][x] = "2"
    if marks:          # hour marks: quarters 2 px long, the rest 1 px
        for hr in range(12):
            a = hr * math.pi / 6
            for k in ((0, 1) if hr % 3 == 0 else (0,)):
                rr = R - len(bands) - 2.5 - k
                cv.put(int(dcx + math.sin(a) * rr), int(dcy - math.cos(a) * rr), "a")
    for deg, short in hands:
        a = math.radians(deg)
        ln = R - short
        line(cv, int(dcx), int(dcy), int(round(dcx + math.sin(a) * ln - 0.5)),
             int(round(dcy - math.cos(a) * ln - 0.5)), "A")


def wallpaper(cv, keep_out):
    """Old-house wallpaper on the bare wall: thin plum stripes, a small
    diamond between them. keep_out(x, y) -> True leaves a pixel alone."""
    n = cv.n
    for y in range(n):
        for x in range(n):
            if cv.c[y][x] != "K" or keep_out(x, y):
                continue
            u = (x - n // 2) % 8
            if u == 0 or (u == 4 and (y % 8) in (3, 5)) or (u in (3, 5) and y % 8 == 4):
                cv.c[y][x] = "6"


def dial_scene(v, n=None):
    """v = visible square (64 for the flat icons, 72 for the adaptive one),
    n = canvas size (108 for adaptive). Returns (background, foreground)."""
    n = n or v
    s = v / 64
    o = (n - v) // 2
    h, (fx, fy) = hero()
    bb = h.getbbox()
    hx = n // 2 - int(fx)
    hy = o + (v - (bb[3] - bb[1])) // 2 - bb[1]
    cx, cy = fx + hx, fy + hy
    cv = Canvas(n, "K")
    dcx = dcy = n / 2
    R = DIAL_R * s
    dial(cv, dcx, dcy, R)
    cv.light(cx, cy, [GLOW[0] * s, GLOW[1] * s], {"2": "26m"}, tall=1.12)
    wallpaper(cv, lambda x, y: math.hypot(x + 0.5 - dcx, y + 0.5 - dcy) <= R + 1.5)
    fg = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    fg.alpha_composite(h, (hx, hy))
    return cv.image(), fg


def flat_icon():
    bg, fg = dial_scene(64)
    bg.alpha_composite(fg)
    return bg


def mini_icon(n, h, R, glow):
    """32 / 48 px icon with the 1x in-game Tallow (pixel-exact, no scaling)."""
    t, (fx, fy) = mini_tallow(h)
    bb = t.getbbox()
    tx = n // 2 - int(fx)
    ty = (n - (bb[3] - bb[1])) // 2 - bb[1]
    cv = Canvas(n, "K")
    big = n >= 48            # at 32 px the hands and marks only add noise
    dial(cv, n / 2, n / 2, R, bands=BEZEL[:2], hands=((300, 5), (55, 8)) if big else (), marks=big)
    cv.light(fx + tx, fy + ty, glow, {"2": "26m"}, tall=1.12)
    im = cv.image()
    im.alpha_composite(t, (tx, ty))
    return im


def rounded(im, insets):
    """Cut stepped pixel corners (insets per row from the edge)."""
    out = im.copy()
    px = out.load()
    n = im.width
    for i, ins in enumerate(insets):
        for x in range(ins):
            for y in (i, n - 1 - i):
                px[x, y] = (0, 0, 0, 0)
                px[n - 1 - x, y] = (0, 0, 0, 0)
    return out


def ico_images():
    """Pixel-exact images for app_icon.ico: 16, 32, 48, 64, 128, 256."""
    flat = rounded(flat_icon(), [4, 2, 1, 1])
    return [grid(ICON_16), mini_icon(32, 11, 14.5, (10, 6.5)), mini_icon(48, 15, 21.5, (14.5, 9.5)),
            flat, upscale(flat, 2), upscale(flat, 4)]


def safe_zone_check(fg, n=108, safe=33.0):
    """Adaptive foreground must stay inside the 66 px (of 108) safe circle."""
    a = fg.getchannel("A").load()
    worst = 0.0
    for y in range(n):
        for x in range(n):
            if a[x, y]:
                d = max(math.hypot(x + dx - n / 2, y + dy - n / 2) for dx in (0, 1) for dy in (0, 1))
                worst = max(worst, d)
    assert worst <= safe, ("Tallow leaves the adaptive safe circle", worst, safe)
    return worst


def build():
    flat = flat_icon()
    save(upscale(rounded(flat, [5, 3, 2, 1, 1]), 3), os.path.join(UI, "app_icon_192.png"))
    bg, fg = dial_scene(72, 108)
    safe_zone_check(fg)
    save(upscale(fg, 4), os.path.join(UI, "app_icon_fg_432.png"))
    save(upscale(bg, 4), os.path.join(UI, "app_icon_bg_432.png"))
    save(upscale(flat, 8), os.path.join(ROOT, "icon.png"))
    # stores (docs/ is not exported with the game; .gdignore keeps Godot out)
    save(upscale(flat, 8), os.path.join(MARKETING, "google_play_512.png"))
    save(upscale(flat, 4), os.path.join(MARKETING, "steam_client_256.png"))
    save(upscale(flat, 3).crop((4, 4, 188, 188)), os.path.join(MARKETING, "steam_community_184.png"))
    gi = os.path.join(MARKETING, ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()


# ==========================================================================
# Review sheets: the three first concepts, phone-size previews (downscaled
# with a smooth filter the way a launcher does, inside circle and squircle
# masks, on dark and light wallpapers) and old-vs-new.
# ==========================================================================
def place_hero(n):
    h, (fx, fy) = hero()
    bb = h.getbbox()
    ox = n // 2 - int(fx)
    oy = (n - (bb[3] - bb[1])) // 2 - bb[1]
    return h, ox, oy, (fx + ox, fy + oy), bb[3] + oy


def concept_a(n=64):
    """A - halo: warm rings round the flame, arched window with a crescent
    moon, floorboards."""
    h, ox, oy, (cx, cy), floor = place_hero(n)
    cv = Canvas(n, "K")
    wx0, wy0, ww, wh = 4, 6, 14, 24
    r = ww / 2
    for y in range(wy0, wy0 + wh):
        for x in range(wx0, wx0 + ww):
            arch = y >= wy0 + r or math.hypot(x + 0.5 - (wx0 + r), y + 0.5 - (wy0 + r)) <= r
            if arch:
                cv.put(x, y, "4")
            inner = y >= wy0 + r or math.hypot(x + 0.5 - (wx0 + r), y + 0.5 - (wy0 + r)) <= r - 1.5
            if inner and wx0 + 2 <= x < wx0 + ww - 2 and wy0 + 2 <= y < wy0 + wh - 2:
                cv.put(x, y, "s")
    cv.rect(wx0 + ww // 2, wy0 + 1, wx0 + ww // 2, wy0 + wh - 3, "4")
    cv.rect(wx0 + 2, wy0 + wh // 2, wx0 + ww - 3, wy0 + wh // 2, "4")
    cv.disc(wx0 + 4.5, wy0 + 6.5, 2.6, "S", only="s")
    cv.disc(wx0 + 5.6, wy0 + 5.8, 2.3, "s", only="S")
    cv.rect(0, floor - 3, n - 1, n - 1, "7")
    cv.rect(0, floor - 3, n - 1, floor - 3, "8")
    for k in range(3, n, 12):
        cv.rect(k, floor - 2, k, n - 1, "8")
    cv.light(cx, cy, [28, 20, 13], {"K": "K6mR", "4": "445F", "7": "7755", "8": "8844"}, tall=1.15)
    im = cv.image()
    im.alpha_composite(h, (ox, oy))
    return im


def concept_b(n=64):
    """B - midnight clock (first pass: brass rim, dial below the flame)."""
    h, ox, oy, (cx, cy), floor = place_hero(n)
    cv = Canvas(n, "K")
    dial(cv, n / 2, cy + 7, 27.5, bands=("yyocR", "yocRR"))
    cv.light(cx, cy, [19, 12.5], {"2": "26m"}, tall=1.12)
    im = cv.image()
    im.alpha_composite(h, (ox, oy))
    return im


def concept_c(n=64):
    """C - moonlit window: cool blue panes behind, a small warm glow."""
    h, ox, oy, (cx, cy), floor = place_hero(n)
    cv = Canvas(n, "K")
    x0, y0, x1, y1 = 7, 3, n - 8, 46
    cv.rect(x0, y0, x1, y1, "4")
    cv.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "s")
    mcx, mcy = x0 + 11, y0 + 10
    cv.light(mcx, mcy, [14], {"s": "sB"})
    cv.disc(mcx, mcy, 5.5, "S", only="sB")
    cv.disc(mcx - 1.5, mcy - 1.5, 2.5, "h", only="S")
    cv.rect((x0 + x1) // 2, y0 + 2, (x0 + x1) // 2, y1 - 2, "4")
    cv.rect(x0 + 2, (y0 + y1) // 2, x1 - 2, (y0 + y1) // 2, "4")
    cv.rect(0, y1 + 1, n - 1, n - 1, "7")
    cv.light(cx, cy, [12, 8], {"K": "K6m", "s": "s6m", "B": "B6m", "4": "4F5", "7": "75"}, tall=1.15)
    im = cv.image()
    im.alpha_composite(h, (ox, oy))
    return im


def mask(size, kind, ss=4):
    N = size * ss
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    if kind == "circle":
        d.ellipse((0, 0, N - 1, N - 1), fill=255)
    else:                                   # squircle |x|^4 + |y|^4 <= 1
        for y in range(N):
            v = abs((y + 0.5) / N * 2 - 1)
            w = (1 - v ** 4) ** 0.25
            d.line((int(N / 2 - w * N / 2), y, int(N / 2 + w * N / 2), y), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def on_phone(icon, size, kind):
    im = icon.convert("RGBA").resize((size, size), Image.LANCZOS)
    im.putalpha(Image.composite(im.getchannel("A"), Image.new("L", im.size, 0), mask(size, kind)))
    return im


def adaptive_visible(fg_path, bg_path):
    """What the launcher shows of an adaptive icon: bg + fg, middle 72/108."""
    bg = Image.open(bg_path).convert("RGBA")
    bg.alpha_composite(Image.open(fg_path).convert("RGBA"))
    k = bg.width / 108
    return bg.crop((int(18 * k), int(18 * k), int(90 * k), int(90 * k)))


def phone_sheet(icons, path, title=None):
    walls = [rgba("#1d2230"), rgba("#d9dde6")]
    cell = 110
    top = 40 + (24 if title else 0)
    W = 170 + cell * 8
    sh = Image.new("RGBA", (W, top + len(icons) * (cell + 10)), rgba("#101014"))
    d = ImageDraw.Draw(sh)
    if title:
        d.text((8, 8), title, fill=(255, 255, 255, 255))
    cols = [(sz, k, wl) for wl in (0, 1) for k in ("circle", "squircle") for sz in (48, 96)]
    for i, (sz, k, wl) in enumerate(cols):
        d.text((170 + i * cell + 4, top - 26), "%d %s %s" % (sz, k, "dark" if wl == 0 else "light"),
               fill=(220, 220, 220, 255))
    for r, (label, ic) in enumerate(icons):
        y = top + r * (cell + 10)
        d.text((8, y + 46), label, fill=(240, 240, 240, 255))
        for i, (sz, k, wl) in enumerate(cols):
            x = 170 + i * cell
            sh.paste(Image.new("RGBA", (cell, cell), walls[wl]), (x, y))
            sh.alpha_composite(on_phone(ic, sz, k), (x + (cell - sz) // 2, y + (cell - sz) // 2))
    sh.save(path)


def compare_sheet(old, path):
    """Old icons (top) next to the new ones (bottom), at real size and zoomed."""
    bgc = rgba("#14101a")
    L = lambda *p: Image.open(os.path.join(*p)).convert("RGBA")
    new_ad = adaptive_visible(os.path.join(UI, "app_icon_fg_432.png"), os.path.join(UI, "app_icon_bg_432.png"))
    old_ad = adaptive_visible(os.path.join(old, "app_icon_fg_432.png"), os.path.join(old, "app_icon_bg_432.png"))
    ico_new = ico_images()

    def ico_sizes(p):
        ims = []
        with Image.open(p) as ic:
            for sz in sorted(ic.info.get("sizes", [])):
                if sz[0] <= 48:
                    ic.size = sz
                    ims.append(ic.convert("RGBA").copy())
        return ims

    sh = Image.new("RGBA", (1500, 900), bgc)
    d = ImageDraw.Draw(sh)
    white = (240, 240, 240, 255)
    for row, (label, legacy, adaptive, proj, icos, stick) in enumerate((
            ("OLD", L(old, "app_icon_192.png"), old_ad, L(old, "icon.png"), ico_sizes(os.path.join(old, "app_icon.ico")),
             L(old, "iron_stick.png")),
            ("NEW", L(UI, "app_icon_192.png"), new_ad, L(ROOT, "icon.png"), ico_new[:3],
             L(ART, "items", "iron_stick.png")))):
        y = 30 + row * 440
        d.text((10, y - 22), label, fill=(255, 220, 120, 255))
        d.text((10, y + 198), "legacy 192", fill=white)
        sh.alpha_composite(legacy.resize((192, 192), Image.NEAREST), (10, y))
        d.text((214, y + 198), "adaptive (circle, 192)", fill=white)
        sh.alpha_composite(on_phone(adaptive, 192, "circle"), (214, y))
        d.text((418, y + 198), "adaptive (squircle, 192)", fill=white)
        sh.alpha_composite(on_phone(adaptive, 192, "squircle"), (418, y))
        d.text((622, y + 198), "icon.png (Godot)", fill=white)
        sh.alpha_composite(proj.resize((192, 192), Image.LANCZOS), (622, y))
        # real phone size on a dark and a light home screen
        hs = Image.new("RGBA", (300, 192), rgba("#3a4256"))
        hs.paste(Image.new("RGBA", (150, 192), rgba("#d9dde6")), (150, 0))
        for i, kind in enumerate(("circle", "squircle")):
            for j, sz in enumerate((48, 64, 48, 64)):
                hs.alpha_composite(on_phone(adaptive, sz, kind),
                                   (8 + j * 72 + (j // 2) * 6 + (64 - sz) // 2, 20 + i * 90 + (64 - sz) // 2))
        d.text((826, y + 198), "phone size 48 / 64, circle + squircle", fill=white)
        sh.alpha_composite(hs, (826, y))
        x = 1140
        d.text((x, y + 198), ".ico 16/32/48 (1x and 3x)", fill=white)
        for im in icos:
            sh.alpha_composite(im, (x, y))
            x += im.width + 8
        x = 1140
        yy = y + 60
        for im in icos:
            sh.alpha_composite(upscale(im, 3), (x, yy))
            x += im.width * 3 + 8
        # relic icon on its own, 1x and 8x, next to its neighbours
        yy = y + 240
        d.text((10, yy), "Iron Candlestick relic (1x and 8x), with candelabra / fire tongs / pale taper",
               fill=white)
        sh.alpha_composite(stick, (10, yy + 20))
        sh.alpha_composite(upscale(stick, 8), (40, yy + 20))
        x = 190
        for nb in ("candelabra", "fire_tongs", "pale_taper", "tin_sconce"):
            sh.alpha_composite(upscale(L(ART, "items", nb + ".png"), 8), (x, yy + 20))
            x += 136
        # 1x strip on a dark game-like background
        strip = Image.new("RGBA", (16 * 6 + 5 * 4, 16), rgba("#1a1418"))
        for i, nb in enumerate(("iron_stick", "candelabra", "fire_tongs", "pale_taper", "tin_sconce", "wick_trimmer")):
            im = stick if nb == "iron_stick" else L(ART, "items", nb + ".png")
            strip.alpha_composite(im, (i * 20, 0))
        sh.alpha_composite(upscale(strip, 3), (x + 10, yy + 20))
        d.text((x + 10, yy + 74), "at 3x with neighbours", fill=white)
        sh.alpha_composite(strip, (x + 10, yy + 100))
    sh.save(path)


def review(d, old=None):
    os.makedirs(d, exist_ok=True)
    concepts = [("A halo + window", concept_a()), ("B clock (1st pass)", concept_b()),
                ("C moonlit window", concept_c())]
    big = Image.new("RGBA", (3 * 64 * 6 + 40, 64 * 6 + 20), rgba("#101014"))
    for i, (k, im) in enumerate(concepts):
        big.alpha_composite(upscale(im, 6), (10 + i * (64 * 6 + 10), 10))
    big.save(os.path.join(d, "concepts_6x.png"))
    oldrow = []
    if old:
        oldrow = [("old (legacy 192)", Image.open(os.path.join(old, "app_icon_192.png"))),
                  ("old (adaptive)", adaptive_visible(os.path.join(old, "app_icon_fg_432.png"),
                                                      os.path.join(old, "app_icon_bg_432.png")))]
    phone_sheet(oldrow + concepts, os.path.join(d, "concepts_phone.png"),
                "Three concepts at real phone size (launcher-style downscale)")
    final = [("final flat (store)", Image.open(os.path.join(MARKETING, "google_play_512.png"))),
             ("final adaptive", adaptive_visible(os.path.join(UI, "app_icon_fg_432.png"),
                                                 os.path.join(UI, "app_icon_bg_432.png")))]
    phone_sheet(oldrow + final, os.path.join(d, "final_phone.png"), "Final icon at real phone size")
    upscale(flat_icon(), 8).save(os.path.join(d, "final_8x.png"))
    ico = ico_images()
    strip = Image.new("RGBA", (16 + 32 + 48 + 64 + 40, 64), rgba("#101014"))
    x = 8
    for im in ico[:4]:
        strip.alpha_composite(im, (x, 64 - im.height))
        x += im.width + 8
    upscale(strip, 4).save(os.path.join(d, "ico_small_4x.png"))
    if old:
        compare_sheet(old, os.path.join(d, "compare.png"))


def main():
    build()
    for p in OUT:
        print(os.path.relpath(p, ROOT), Image.open(p).size)
    if "--review" in sys.argv:
        old = sys.argv[sys.argv.index("--old") + 1] if "--old" in sys.argv else None
        review(sys.argv[sys.argv.index("--review") + 1], old)


if __name__ == "__main__":
    main()
