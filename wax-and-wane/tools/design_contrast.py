#!/usr/bin/env python3
"""Fair deaths: how well every enemy bullet and telegraph colour stands out on each floor's lit floor.

    python3 tools/design_contrast.py <shots_dir> [--md]

<shots_dir> holds the floorbg_N.png screenshots from
    xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
        -- --autotest --designcheck --floorshots --shots=<shots_dir>
(the viewport image, 1 px = 1 game pixel; the room sits at (104,12) with Tallow at (240,126)).

Floor colour: the interior floor of the room (room-local x 16..256, y 32..176), only pixels within the
candle's light (<= 80 px from Tallow) and away from Tallow himself; "typical" is their median luminance,
"bright" the 90th percentile (the floor right under the flame, where bullets end up when they hit).

Bullet: its 1 px rim (opaque pixels touching transparency) and its body (the rest) are measured
separately; on a light floor the dark rim carries the shape, on a dark floor the bright body does, so a
bullet's contrast on a floor is the better of the two (WCAG ratio, (L1 + 0.05) / (L2 + 0.05)).
Telegraphs are drawn as a 1 px line in one colour with a 35 % darker pixel under it: the line colour.
Both frames of each bullet are measured; the worse frame counts. Prints a table and the minimum.
"""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BULLETS = ["bullet_purple", "bullet_green", "bullet_water", "bolt_bone", "bolt_cog", "bolt_page", "bolt_ring", "bolt_wax"]
TELEGRAPHS = {"tele_red": "#da4e38", "tele_pale": "#cae6f5", "tele_pink": "#f78697"}
_TG = open(os.path.join(ROOT, "scripts/game/enemies/telegraph.gd")).read()
HOT = {a: "#" + b for a, b in re.findall(r'"([0-9a-f]{6})": Color\("#([0-9a-f]{6})"\)', _TG)}
ROOM = (104, 12)
PLAYER = (240, 126)
TARGET = 3.0


def lum(rgb):
    c = np.asarray(rgb, dtype=float) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def ratio(a, b):
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def hex_rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def bullet_parts(path):
    im = np.asarray(Image.open(path).convert("RGBA"))
    a = im[..., 3] > 0
    h, w = a.shape
    rim = np.zeros_like(a)
    for y in range(h):
        for x in range(w):
            if not a[y, x]:
                continue
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if yy < 0 or xx < 0 or yy >= h or xx >= w or not a[yy, xx]:
                    rim[y, x] = True
                    break
    body = a & ~rim
    L = lum(im[..., :3])
    rim_l = float(np.mean(L[rim])) if rim.any() else 0.0
    # the body's brightest quarter: the core the eye locks on to
    body_l = float(np.percentile(L[body], 75)) if body.any() else rim_l
    return rim_l, body_l


def floor_levels(path):
    im = np.asarray(Image.open(path).convert("RGB"))
    x0, y0 = ROOM[0] + 16, ROOM[1] + 32
    x1, y1 = ROOM[0] + 256, ROOM[1] + 176
    ys, xs = np.mgrid[y0:y1, x0:x1]
    d = np.hypot(xs - PLAYER[0], ys - (PLAYER[1] - 6))
    keep = (d <= 80) & (d > 14)
    L = lum(im[y0:y1, x0:x1])[keep]
    return float(np.median(L)), float(np.percentile(L, 90))


def main():
    shots = sys.argv[1]
    floors = {}
    for n in range(1, 6):
        f = sorted(glob.glob(os.path.join(shots, "*_floorbg_%d.png" % n)))
        if f:
            floors[n] = floor_levels(f[0])
    rows = []
    worst = (99.0, "")
    for k in BULLETS + list(TELEGRAPHS):
        if k in TELEGRAPHS:
            # half the dots are the colour, half its hot partner (telegraph.gd HOT), if it has one
            base = TELEGRAPHS[k]
            l = float(lum(hex_rgb(base)))
            l2 = float(lum(hex_rgb(HOT.get(base.lstrip("#"), base))))
            parts = [(l, l2)]
        else:
            parts = [bullet_parts(os.path.join(ROOT, "assets/art/fx/%s_f%d.png" % (k, i))) for i in range(2)]
        cells = []
        for n, (typ, bright) in floors.items():
            c = 99.0
            for rim_l, body_l in parts:
                for fl in (typ, bright):
                    c = min(c, max(ratio(rim_l, fl), ratio(body_l, fl)))
            cells.append(c)
            if c < worst[0]:
                worst = (c, "%s on floor %d" % (k, n))
        rows.append((k, cells))
    hdr = "| sprite | " + " | ".join("F%d" % n for n in floors) + " | min |"
    print(hdr)
    print("|" + "---|" * (len(floors) + 2))
    low = 0
    for k, cells in rows:
        m = min(cells)
        low += 1 if m < TARGET else 0
        print("| %s | %s | %s%.2f |" % (k, " | ".join("%.2f" % c for c in cells), "**" if m < TARGET else "", m))
    print("floor luminance (typical, bright): " + ", ".join("F%d %.3f/%.3f" % (n, t, b) for n, (t, b) in floors.items()))
    print("below %.1f:1 on some floor: %d of %d; worst %.2f (%s)" % (TARGET, low, len(rows), worst[0], worst[1]))


if __name__ == "__main__":
    main()
