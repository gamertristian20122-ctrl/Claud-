#!/usr/bin/env python3
"""Wax & Wane - v2.7 the controls primer's pictures (scripts/ui/primer.gd, primer_glyphs.gd, wax_dummy.gd).

  primer/thumb.png          11x18  a thumb seen from above, nail first (the touch sticks and buttons)
  primer/key.png            16x16  an ivory keycap with a front edge (nine-patch 5/5/5/6; words drawn in code)
  primer/key_down.png       16x16  the same key pressed: 1 px lower, the face lit gold
  primer/pad.png            48x30  a gamepad from above (bumpers, triggers, d-pad, face buttons, two stick wells)
  primer/pad_cap(_on).png    7x7   a stick's cap, ivory or lit gold (tilted in its well in code)
  primer/pad_lb|rb|lt|rt.png 48x30 overlays lighting one bumper / trigger gold
  primer/mouse.png          11x16  a mouse
  primer/mouse_left.png     11x16  its left button lit (an overlay)
  primer/dummy_f0..f2.png   18x26  the wax dummy: upright, leaning right, leaning left (a wobble)
  primer/dummy_hit.png      18x26  the dummy's hit flash (cream, ink outline)

Rules (DESIGN.md): the 0x72 DungeonTileset II palette only (every pixel is checked against the sheet), a 1 px
#21141b outline, light from the top-left, flat fills, no anti-aliasing, fully opaque pixels. Identical output
each run. Uses the UI kit's helpers (tools/art_ui2.py).

Usage:
    python3 tools/art_primer.py               # write the PNGs into assets/art/primer/
    python3 tools/art_primer.py --review DIR  # also a 6x contact sheet and the keys / dummy mock-ups in DIR
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_ui2  # noqa: E402
from art_ui2 import Canvas, grid_img, ninepatch, sheet  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, "assets", "art", "primer")
OUT = []


def save(c, name):
    im = c.im if isinstance(c, Canvas) else c
    os.makedirs(OUTDIR, exist_ok=True)
    p = os.path.join(OUTDIR, name)
    im.save(p)
    OUT.append(p)
    return im


# ---------------------------------------------------------------- the thumb
# Nail first (the player's own thumb, seen from above as it rests on the glass): a cream nail with its cuticle,
# warm skin lit from the left, a crease at the knuckle, the base cut square (it runs on off the glyph).
THUMB = """
....KKK....
..KKwwwKK..
.KwwwwwwAK.
.KwwwwwwAK.
KXwwwwwAAXK
KXAwwwAAXdK
KXXAAAAXXdK
KXXXXXXXXdK
KXXXXXXXddK
KXXXXXXXddK
KXdXXXXdddK
KXXddddXddK
KXXXXXXXddK
KXXXXXXddDK
KdXXXXXddDK
KdXXXXddDDK
KdddddddDDK
KKKKKKKKKKK
"""


# ---------------------------------------------------------------- keys
def key(down=False):
    """16x16 nine-patch [5 left, 5 right, 5 top, 6 bottom]: ivory face, a front edge, an ink rim.
    Pressed: the face sits 1 px lower on a 1 px edge and glows gold (the key being pressed right now)."""
    c = Canvas(16, 16)
    top = 1 if down else 0
    face, lit, shade, edge, edge2 = ("y", "z", "o", "c", "R") if down else ("X", "w", "f", "F", "R")
    bottom = 15
    # ink rim (rounded corners)
    for x in range(1, 15):
        c.p(x, top, "K")
        c.p(x, bottom, "K")
    for y in range(top + 1, bottom):
        c.p(0, y, "K")
        c.p(15, y, "K")
    c.rect(1, top + 1, 14, bottom - top - 1, face)
    # light from the top-left, a shaded right side
    for x in range(2, 14):
        c.p(x, top + 1, lit)
    for y in range(top + 2, bottom - 3):
        c.p(1, y, lit)
        c.p(14, y, shade)
    c.p(1, top + 1, face)
    # the front edge: 3 rows up, 2 pressed (the key went down)
    rows = [edge2] if down else [edge, edge2]
    for i, ch in enumerate(reversed(rows)):
        y = bottom - 1 - i
        for x in range(1, 15):
            c.p(x, y, ch)
    y = bottom - 1 - len(rows)
    for x in range(1, 15):
        c.p(x, y, shade)
    return c


# ---------------------------------------------------------------- the gamepad stick
def disc(c, cx, cy, r, ch):
    for y in range(c.h):
        for x in range(c.w):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r * 0.6:
                c.p(x, y, ch)


PAD_W, PAD_H = 48, 30
PAD_STICKS = [(15, 18), (32, 18)]          # the wells' middles (the caps are drawn there in code, tilted)
PAD_BUMPERS = {"lb": (5, 3, 12), "rb": (31, 3, 12)}    # x, y, width of each bumper's top face
PAD_TRIGGERS = {"lt": (7, 0, 7), "rt": (34, 0, 7)}


def _pad_shape():
    """Which pixels the pad's body covers: a rounded bar with a grip under each end."""
    inside = set()
    for y in range(PAD_H):
        for x in range(PAD_W):
            bar = 4 <= x <= 43 and 6 <= y <= 19 and not ((x in (4, 43)) and y in (6, 19))
            grip = any((x - gx) ** 2 + (y - 20) ** 2 <= 60 for gx in (11, 36))
            if bar or grip:
                inside.add((x, y))
    return inside


def pad_body():
    """48x30: a gamepad from above, lit from the top-left: bumpers and triggers on its back edge, a d-pad and four
    face buttons, two stick wells (the caps are separate: they tilt). Muted wood-brown like the HUD's dark parts."""
    c = Canvas(PAD_W, PAD_H)
    for name, (x, y, w) in PAD_TRIGGERS.items():
        c.rect(x, y + 1, w, 3, "4")
        c.rect(x + 1, y + 1, w - 2, 1, "5")
    for name, (x, y, w) in PAD_BUMPERS.items():
        c.rect(x, y + 1, w, 3, "5")
        c.rect(x + 1, y + 1, w - 2, 1, "a")
    for (x, y) in _pad_shape():
        c.p(x, y, "5")
    for (x, y) in _pad_shape():
        if (x, y - 1) not in _pad_shape() or (x - 1, y) not in _pad_shape():
            c.p(x, y, "a")         # the lit top / left edge
        elif (x, y + 1) not in _pad_shape() or (x + 1, y) not in _pad_shape():
            c.p(x, y, "4")         # the shaded bottom / right edge
    # d-pad (left) and face buttons (right)
    for (x, y) in [(10, 9), (10, 10), (10, 11), (10, 12), (10, 13), (8, 11), (9, 11), (11, 11), (12, 11)]:
        c.p(x, y, "K")
    for (x, y, ch) in [(37, 9, "y"), (35, 11, "B"), (39, 11, "r"), (37, 13, "g")]:
        c.p(x, y, ch)
        c.p(x + 1, y, "K")
    c.rect(21, 11, 2, 1, "4")
    c.rect(25, 11, 2, 1, "4")
    for (sx, sy) in PAD_STICKS:
        disc(c, sx, sy, 4, "K")
        disc(c, sx, sy, 3, "8")
    c.outline("K", diag=False)
    return c


def pad_part(kind, on=True):
    """An overlay the size of the pad lighting one bumper or trigger gold (the button the step asks for)."""
    c = Canvas(PAD_W, PAD_H)
    x, y, w = (PAD_BUMPERS.get(kind) or PAD_TRIGGERS.get(kind))
    c.rect(x, y + 1, w, 3, "y")
    c.rect(x + 1, y + 1, w - 2, 1, "z")
    c.rect(x, y + 3, w, 1, "o")
    return c


def pad_cap(on=False):
    """7x7: a stick's cap (ivory, or lit gold on the stick the step asks for)."""
    c = Canvas(7, 7)
    disc(c, 3, 3, 3, "K")
    disc(c, 3, 3, 2, "y" if on else "A")
    c.p(2, 2, "z" if on else "w")
    c.p(3, 2, "z" if on else "w")
    c.p(4, 4, "o" if on else "a")
    return c


# ---------------------------------------------------------------- the mouse
MOUSE = """
...KKKKK...
..KwwKXXK..
.KwwwKXXfK.
.KwwwKXXfK.
.KwwwKXXfK.
.KKKKKKKKK.
.KXXXXXXfK.
.KXXXXXXfK.
.KXXXXXXfK.
.KXXXXXXfK.
.KXXXXXffK.
.KfXXXXffK.
..KfXXffK..
..KKffffK..
...KKKKK...
...........
"""
MOUSE_LEFT = """
...KKKKK...
..KzzK.....
.KzyyK.....
.KyyyK.....
.KyyoK.....
.KKKKK.....
...........
...........
...........
...........
...........
...........
...........
...........
...........
...........
"""


# ---------------------------------------------------------------- the wax dummy
# An old wax figure on a wooden post, a target painted on its chest. Built from parts so it can lean: rows above
# the post shift by up to `lean` px (more at the head), then everything gets the ink outline.
DUMMY_WAX = """
.......XXXX.......
......wwwXXX......
.....wwwwXXXf.....
.....wwwwXXff.....
.....XwwXXXff.....
......XXXXff......
.......XXff.......
....wwwXXXXXff....
...wwwwwXXXXXff...
...wwrrrrrXXXff...
...wrwwwwwrXXff...
...wrwrrrwrXXff...
...wrwrwrwrXfff...
...wrwrrrwrXfff...
...XrwwwwwrXfff...
...XXrrrrrXXfff...
...wXXXXXXXffff...
....XXwXXXXfff....
....XwfXXXXff.....
.....f.XXff.f.....
"""
DUMMY_POST = """
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
..................
........FR........
........FR........
....FFFFFRRRRR....
..................
"""


def dummy(lean=0, hit=False):
    W, H = 18, 26
    wax_rows = art_ui2.rows_of(DUMMY_WAX)
    post_rows = art_ui2.rows_of(DUMMY_POST)
    c = Canvas(W, H)
    for y, row in enumerate(post_rows):
        for x, ch in enumerate(row):
            if ch != ".":
                c.p(x, y + 1, ch)
    n = len(wax_rows)
    for y, row in enumerate(wax_rows):
        # a wobble on its post: the head and neck sway, the body with the painted target stays put
        k = lean if y < 7 else 0
        for x, ch in enumerate(row):
            if ch != ".":
                c.p(x + k, y + 1, ch)
    if hit:
        for y in range(H):
            for x in range(W):
                if c.get(x, y):
                    c.p(x, y, "w")
    c.outline("K", diag=False)
    return c


def make_all():
    save(grid_img(THUMB), "thumb.png")
    save(key(False), "key.png")
    save(key(True), "key_down.png")
    save(pad_body(), "pad.png")
    save(pad_cap(False), "pad_cap.png")
    save(pad_cap(True), "pad_cap_on.png")
    for part in ["lb", "rb", "lt", "rt"]:
        save(pad_part(part), "pad_%s.png" % part)
    save(grid_img(MOUSE), "mouse.png")
    save(grid_img(MOUSE_LEFT), "mouse_left.png")
    save(dummy(0), "dummy_f0.png")
    save(dummy(1), "dummy_f1.png")
    save(dummy(-1), "dummy_f2.png")
    save(dummy(0, True), "dummy_hit.png")


def palette_check():
    import art_rooms
    allowed = art_rooms.sheet_palette()
    bad = 0
    for p in OUT:
        im = Image.open(p).convert("RGBA")
        data = im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()
        for (r, g, b, a) in set(data):
            if a == 0:
                continue
            if a != 255 or (r, g, b) not in allowed:
                print("OFF-PALETTE", os.path.relpath(p, ROOT), (r, g, b, a))
                bad += 1
    print("[art_primer] palette check: %d files, %s" % (len(OUT), "PASS" if bad == 0 else "%d FAIL" % bad))
    return bad


def write_review(d):
    os.makedirs(d, exist_ok=True)
    ld = lambda n: Image.open(os.path.join(OUTDIR, n)).convert("RGBA")
    sheet(os.path.join(d, "primer_all_6x.png"), [Image.open(p).convert("RGBA") for p in OUT], scale=6, cols=12)
    # keys as the game stretches them: W A S D, SHIFT, a pressed D
    mock = Image.new("RGBA", (176, 44), art_ui2.rgba("#38262d"))
    for i, (x, y, w, down) in enumerate([(14, 2, 13, False), (1, 16, 13, False), (14, 16, 13, False), (27, 16, 13, True),
                                         (46, 16, 28, False), (78, 16, 20, True)]):
        mock.alpha_composite(ninepatch(ld("key_down.png" if down else "key.png"), 5, 5, 5, 6, w, 14), (x, y))
    mock.alpha_composite(ld("pad.png"), (102, 2))
    mock.alpha_composite(ld("pad_lt.png"), (102, 2))
    mock.alpha_composite(ld("pad_cap_on.png"), (102 + 15 - 3 + 1, 2 + 18 - 3))
    mock.alpha_composite(ld("pad_cap.png"), (102 + 32 - 3, 2 + 18 - 3))
    mock.alpha_composite(ld("thumb.png"), (158, 20))
    sheet(os.path.join(d, "primer_keys_8x.png"), [mock], scale=8)


def main():
    review = sys.argv[sys.argv.index("--review") + 1] if "--review" in sys.argv else None
    make_all()
    bad = palette_check()
    if review:
        write_review(review)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
