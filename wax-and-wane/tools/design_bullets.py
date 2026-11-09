#!/usr/bin/env python3
"""Rebuild only the enemy bullet sprites (assets/art/fx/bullet_*, bolt_*: the 9 px Normal set <kind>_f<i> and the
11 px Large set <kind>_lg_f<i>, v2.1) and judge them against the player's shots (fix/art, UX-02: friend or foe by
shape and lightness, not hue):

    python3 tools/design_bullets.py [--review DIR] [--judge DIR] [--floors SHOTS_DIR]

All eight are drawn by tools/art_fx2.py (ENEMY_SHOTS); art_hero_fx_items.py (orbs) and art_tower.py (cog)
hand their old versions over to it, so re-running any of the three keeps these.

--judge DIR writes DIR/bullets_cvd.png (player shots above both sets of enemy shots on each floor's colour, with normal
sight and simulated protanopia, deuteranopia and tritanopia; Machado, Oliveira & Fernandes 2009, severity 1) and prints,
for each set:
  * dE: CIELAB dE76 between the mean colours of each enemy shot and the player's ember / Blue Flame ember (outline
    pixels left out, as the UX review's bullet_de.py), per vision type. Target: >= 30 for normal, protan, deutan.
  * floor: tools/design_contrast.py's rule (the better of rim and body against each floor's typical and bright
    lit floor). Floor levels from --floors SHOTS_DIR (floorbg shots of `--designcheck --floorshots`), else the
    levels measured on this build (FLOORS below). Target: >= 3:1.
  * rim: share of the shot's edge pixels that are dark (luminance < 0.03): the shape cue. Player shots have none.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import art_fx2  # noqa: E402

ART = os.path.join(os.path.dirname(HERE), "assets", "art")
ENEMY = ["bullet_purple", "bullet_green", "bullet_water", "bolt_bone", "bolt_cog", "bolt_page", "bolt_ring", "bolt_wax"]
SETS = {"": "Normal (9 px)", "_lg": "Large (11 px)"}   # file suffix -> "Enemy shots" setting
PLAYER = {"ember": "fx/ember_f0", "blue ember": "fx/ember_blue_f0"}
SHEET_PLAYER = ["fx/ember_f0", "fx/ember_f2", "fx/ember_blue_f0", "fx/ember_big_f0", "items/fx/spark_f0",
                "items/fx/spark_blue_f0", "items/fx/ghost_f0", "items/fx/ring_f0"]
# lit floor luminance (typical, bright) per floor, tools/design_contrast.py on this build's floorbg shots
FLOORS = {1: (0.057, 0.113), 2: (0.033, 0.068), 3: (0.024, 0.087), 4: (0.020, 0.101), 5: (0.021, 0.060)}
FLOOR_RGB = [(52, 40, 38), (34, 38, 48), (40, 30, 52), (48, 32, 30), (44, 36, 30)]
CVD = {
    "normal": np.eye(3),
    "protanopia": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    "deuteranopia": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "tritanopia": np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}


def lin(c):
    c = np.asarray(c, dtype=float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055) * 255.0


def sim(rgb, kind):
    return np.round(srgb(lin(rgb) @ CVD[kind].T))


def lab(rgb):
    xyz = lin(rgb) @ np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]]).T
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def wcag_lum(rgb):
    c = np.asarray(rgb, dtype=float) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def load(name):
    return np.array(Image.open(os.path.join(ART, name + ".png")).convert("RGBA"))


def mean_lab(im, kind):
    rgb = im[..., :3][im[..., 3] > 0]
    rgb = rgb[rgb.sum(1) > 140]          # outline pixels (#21141b, #222222) left out, as bullet_de.py
    return lab(sim(rgb, kind)).mean(0)


def edges(im):
    a = im[..., 3] > 0
    h, w = a.shape
    rim = np.zeros_like(a)
    for y in range(h):
        for x in range(w):
            if a[y, x] and any(not (0 <= y + dy < h and 0 <= x + dx < w) or not a[y + dy, x + dx]
                               for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                rim[y, x] = True
    return a, rim


def floor_contrast(im, floors):
    a, rim = edges(im)
    L = wcag_lum(im[..., :3])
    body = a & ~rim
    rim_l = float(L[rim].mean())
    body_l = float(np.percentile(L[body], 75)) if body.any() else rim_l

    def r(p, q):
        return (max(p, q) + 0.05) / (min(p, q) + 0.05)
    return min(max(r(rim_l, f), r(body_l, f)) for t in floors.values() for f in t)


def dark_rim(im):
    a, rim = edges(im)
    return float((wcag_lum(im[..., :3])[rim] < 0.03).mean())


def sheet(path, scale=6):
    cell = 13
    names = [SHEET_PLAYER] + [["fx/%s%s_f0" % (n, sfx) for n in ENEMY] for sfx in SETS]
    W = (max(len(n) for n in names) + 1) * cell
    H = len(names) * cell * len(FLOOR_RGB)
    base = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(base)
    for fi, bg in enumerate(FLOOR_RGB):
        for row, ns in enumerate(names):
            y = (fi * len(names) + row) * cell
            d.rectangle([0, y, W, y + cell - 1], fill=bg)
            for i, n in enumerate(ns):
                if not os.path.exists(os.path.join(ART, n + ".png")):
                    continue
                im = Image.open(os.path.join(ART, n + ".png")).convert("RGBA")
                base.paste(im, (cell + i * cell + (cell - im.width) // 2, y + (cell - im.height) // 2), im)
    arr = np.array(base)
    w, h = W * scale, H * scale
    out = Image.new("RGB", (w * 2 + 8, (h + 14) * 2 + 8))
    d = ImageDraw.Draw(out)
    for i, kind in enumerate(CVD):
        a = arr if kind == "normal" else sim(arr.reshape(-1, 3), kind).reshape(arr.shape).astype(np.uint8)
        x, y = (i % 2) * (w + 8), (i // 2) * (h + 22)
        out.paste(Image.fromarray(a).resize((w, h), Image.NEAREST), (x, y + 12))
        d.text((x + 2, y), "%s - rows: player shots / enemy shots Normal / Large, on each floor's colour" % kind,
               fill=(255, 255, 255))
    out.save(path)
    return path


def judge(d, floors):
    os.makedirs(d, exist_ok=True)
    players = {k: load(v) for k, v in PLAYER.items()}
    worst = 999.0
    worst_c = 999.0
    for sfx, label in SETS.items():
        print("%s: dE76 to the player's shots (normal / protan / deutan / tritan), floor contrast, dark rim share" % label)
        for n in ENEMY:
            frames = [load("fx/%s%s_f%d" % (n, sfx, i)) for i in range(2)]
            cells = []
            for pk, pim in players.items():
                vals = []
                for kind in CVD:
                    v = min(np.linalg.norm(mean_lab(f, kind) - mean_lab(pim, kind)) for f in frames)
                    vals.append(v)
                    if kind != "tritanopia":
                        worst = min(worst, v)
                cells.append("%s %s" % (pk, "/".join("%.0f" % v for v in vals)))
            fc = min(floor_contrast(f, floors) for f in frames)
            worst_c = min(worst_c, fc)
            print("  %-14s %dpx %s | floor %.2f | rim %.0f%%" % (n, frames[0].shape[0], " | ".join(cells), fc,
                                                              100 * min(dark_rim(f) for f in frames)))
    for k, pim in players.items():
        print("  %-14s (player) dark rim %.0f%%" % (k, 100 * dark_rim(pim)))
    print("worst dE (normal/protan/deutan) %.1f (target 30), worst floor contrast %.2f (target 3)" % (worst, worst_c))
    print("sheet ->", sheet(os.path.join(d, "bullets_cvd.png")))
    return worst >= 30 and worst_c >= 3


def main():
    sys.path.insert(0, HERE)
    import art_rooms
    pal = art_rooms.sheet_palette()
    for name, im in art_fx2.enemy_shot_images().items():
        a = np.array(im).reshape(-1, 4)
        cols = {tuple(int(v) for v in px[:3]) for px in a if px[3] > 0}
        assert cols <= pal, (name, cols - pal)
        assert set(a[:, 3].tolist()) <= {0, 255}, name
    art_fx2.build_enemy_shots()
    floors = FLOORS
    if "--floors" in sys.argv:
        import design_contrast as dc
        import glob
        sd = sys.argv[sys.argv.index("--floors") + 1]
        floors = {n: dc.floor_levels(sorted(glob.glob(os.path.join(sd, "*_floorbg_%d.png" % n)))[0]) for n in range(1, 6)
                  if glob.glob(os.path.join(sd, "*_floorbg_%d.png" % n))}
    if "--review" in sys.argv:
        d = sys.argv[sys.argv.index("--review") + 1]
        os.makedirs(d, exist_ok=True)
        sh = Image.new("RGBA", (len(ENEMY) * 104, 4 * 104), (40, 30, 34, 255))
        for i, n in enumerate(ENEMY):
            for j, sfx in enumerate(SETS):
                for f in range(2):
                    im = Image.open(os.path.join(ART, "fx", "%s%s_f%d.png" % (n, sfx, f))).convert("RGBA")
                    sh.alpha_composite(im.resize((im.width * 8, im.height * 8), Image.NEAREST),
                                       (i * 104 + 8, (j * 2 + f) * 104 + 8))
        sh.save(os.path.join(d, "bullets_8x.png"))
    print("bullets rebuilt")
    if "--judge" in sys.argv:
        ok = judge(sys.argv[sys.argv.index("--judge") + 1], floors)
        print("PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
