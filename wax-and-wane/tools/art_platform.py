#!/usr/bin/env python3
"""Wax & Wane - platform art: mouse cursors, keyboard/gamepad focus frames, the
achievement medal and the Windows .ico app icon (art from art_icon.py).

Everything is hand-placed pixel art written as character grids (see PAL in
art_ui.py, the 0x72 DungeonTileset II palette). No anti-aliasing, no gradients.
The cursors are drawn at 1x; the game scales them by its integer pixel scale.

Usage:
    python3 tools/art_platform.py               # write the PNGs + app_icon.ico
    python3 tools/art_platform.py --review DIR  # also write 8x contact sheets to DIR
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_icon  # noqa: E402  (the app icon art for the .ico)
import art_ui  # noqa: E402  (palette, grid(), upscale())

from art_ui import PAL, grid, rgba, upscale  # noqa: E402

ROOT = art_ui.ROOT
UI = art_ui.UI
OUT = []


def save(im, name):
    p = os.path.join(UI, name)
    im.save(p)
    OUT.append(p)
    return im


# --------------------------------------------------------------------------
# Mouse cursors (hotspot noted next to each; the game reads them from code)
# --------------------------------------------------------------------------
# Menu pointer: a cream wax arrow with a dark outline, hotspot (0, 0).
CURSOR_ARROW = """
K.......
KK......
KwK.....
KwwK....
KwwwK...
KwwwAK..
KwwwAAK.
KwwAKKKK
KwAKwK..
KKK.KwK.
K....KK.
"""

# Aiming crosshair, hotspot (4, 4): four short gold arms, an ember centre dot.
CURSOR_CROSS = """
...KKK...
...KwK...
...KyK...
KKKK.KKKK
KwyKoKywK
KKKK.KKKK
...KyK...
...KwK...
...KKK...
"""

# --------------------------------------------------------------------------
# Focus frames (keyboard / gamepad selection)
# --------------------------------------------------------------------------
# focus_9: drawn 1 px outside a 24x16 button_9 (26x18, nine-patch margins 4).
# A gold ring that follows the button's notched corners, cream at the corners
# so the selection reads at a glance on the dark panels.
def focus_frame(w, h):
    rows = []
    for y in range(h):
        r = ""
        for x in range(w):
            edge_x = x in (0, w - 1)
            edge_y = y in (0, h - 1)
            ch = "."
            if edge_y and 2 <= x <= w - 3:
                ch = "y"
            elif edge_x and 2 <= y <= h - 3:
                ch = "y"
            elif (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
                ch = "y"
            # cream corner brackets
            near_l = x <= 3
            near_r = x >= w - 4
            near_t = y <= 3
            near_b = y >= h - 4
            if ch == "y" and ((near_l or near_r) and (near_t or near_b)):
                ch = "w"
            r += ch
        rows.append(r)
    return grid(rows)


# --------------------------------------------------------------------------
# Achievement medal (9x9): a brass medal with a little flame, light top-left.
# icon_medal_off is the same shape in soot greys (locked).
# --------------------------------------------------------------------------
MEDAL = """
..KKKKK..
.KyyyyoK.
KyyKrKocK
KyKrorKcK
KyKoyoKcK
KyoKwKccK
KoccKcccK
.KccccRK.
..KKKKK..
"""


def recolour(im, mapping):
    out = im.copy()
    px = out.load()
    lut = {rgba(PAL[a]): rgba(PAL[b]) for a, b in mapping.items()}
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y] in lut:
                px[x, y] = lut[px[x, y]]
    return out


# --------------------------------------------------------------------------
# Windows .ico: every size is pixel-exact (no resampling blur). The art comes
# from tools/art_icon.py (the app icon: Tallow in front of the clock dial):
#   16  hand-drawn small icon
#   32, 48  the in-game 1x Tallow on a small dial (96 = the 48 doubled)
#   64  the 64 px flat icon (128 / 192 / 256 = x2 / x3 / x4)
# --------------------------------------------------------------------------
def make_ico():
    i16, i32, i48, i64, i128, i256 = art_icon.ico_images()
    imgs = [i16, i32, i48, i64, upscale(i48, 2), i128, upscale(i64, 3), i256]
    path = os.path.join(UI, "app_icon.ico")
    imgs[-1].save(path, format="ICO", sizes=[(im.width, im.height) for im in imgs], append_images=imgs[:-1])
    OUT.append(path)
    # keep a png strip of the small sizes for review
    return imgs


def sheet(path, ims, scale=8, pad=4):
    w = sum(im.width * scale + pad for im in ims) + pad
    h = max(im.height * scale for im in ims) + 2 * pad
    s = Image.new("RGBA", (w, h), rgba("#2a2a3a"))
    x = pad
    for im in ims:
        s.alpha_composite(upscale(im, scale), (x, pad))
        x += im.width * scale + pad
    s.save(path)


def main():
    review = None
    if "--review" in sys.argv:
        review = sys.argv[sys.argv.index("--review") + 1]
        os.makedirs(review, exist_ok=True)
    arrow = save(grid(CURSOR_ARROW), "cursor_arrow.png")
    cross = save(grid(CURSOR_CROSS), "cursor_cross.png")
    f9 = save(focus_frame(26, 18), "focus_9.png")
    slot = save(focus_frame(20, 20), "focus_slot.png")
    medal = save(grid(MEDAL), "icon_medal.png")
    off = save(recolour(grid(MEDAL), {"y": "5", "o": "4", "c": "3", "R": "K", "r": "5", "w": "a"}), "icon_medal_off.png")
    ico = make_ico()
    for p in OUT:
        print(os.path.relpath(p, ROOT))
    if review:
        sheet(os.path.join(review, "platform_ui.png"), [arrow, cross, medal, off, f9, slot])
        sheet(os.path.join(review, "platform_icons.png"), ico[:3], scale=6)
        # the focus frame over a real button
        btn = Image.open(os.path.join(UI, "button_9.png")).convert("RGBA")
        comp = Image.new("RGBA", (26, 18), rgba("#38262d"))
        comp.alpha_composite(btn, (1, 1))
        comp.alpha_composite(f9)
        sheet(os.path.join(review, "platform_focus.png"), [comp], scale=10)


if __name__ == "__main__":
    main()
