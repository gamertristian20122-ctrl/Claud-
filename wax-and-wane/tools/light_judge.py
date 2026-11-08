#!/usr/bin/env python3
"""Outside judge for the light pass. Reads the images `-- --autotest --lightjudge --shots=DIR` writes.

  python3 tools/light_judge.py DIR [BEFORE_DIR]

1. Bands: distinct luminance levels along 16 rays out of Tallow's light on a flat 0x72 colour (panel.png)
   and the light factor (lit / albedo) along rays in the real start room (room_lit / room_albedo).
2. Palette: room_albedo must equal BEFORE_DIR/room_albedo (the raw palette colours are untouched), and
   every pixel no light reached before (BEFORE room_lit == BEFORE room_dark) must be unchanged now.
3. Waning: mean HSV saturation of wane_100 vs wane_20; and of the "hot" pixels (fire, flame, embers).
4. Haze / shockwave: every changed pixel must be a copy of a pixel at most 1 px (haze) / 2 px (ring)
   away in the reference frame (pixel-snapped displacement), and the changed area must stay small.
"""
import sys
import os
import math
import numpy as np
from PIL import Image


def load(d, n):
    p = os.path.join(d, n + ".png")
    return np.asarray(Image.open(p).convert("RGB")).astype(np.int32) if os.path.exists(p) else None


def lum(a):
    return (a[..., 0] * 299 + a[..., 1] * 587 + a[..., 2] * 114) // 1000


def ray_samples(h, w, cx, cy, rmax, n=16):
    pts = []
    for k in range(n):
        ang = 2 * math.pi * k / n
        for r in range(0, rmax):
            x = int(round(cx + math.cos(ang) * r))
            y = int(round(cy + math.sin(ang) * r))
            if 0 <= x < w and 0 <= y < h:
                pts.append((k, r, y, x))
    return pts


def levels(vals, tol):
    """Distinct values after merging values closer than `tol` (8-bit rounding noise)."""
    vals = sorted(set(vals))
    out = []
    for v in vals:
        if not out or v - out[-1] > tol:
            out.append(v)
    return out


def bands(d, info):
    res = {}
    p = load(d, "panel")
    if p is not None:
        cx, cy = info.get("panel_light", (p.shape[1] // 2, p.shape[0] // 2))
        L = lum(p)
        per_ray = {}
        for k, r, y, x in ray_samples(*L.shape, cx, cy, 120):
            per_ray.setdefault(k, []).append(int(L[y, x]))
        counts = [len(levels(v, 1)) for v in per_ray.values()]
        allv = levels([v for vs in per_ray.values() for v in vs], 1)
        res["panel_levels_per_ray_max"] = max(counts)
        res["panel_levels_per_ray_mean"] = round(sum(counts) / len(counts), 1)
        res["panel_levels_all_rays"] = len(allv)
        # steps: how often the luminance changes between neighbours along a ray (smooth ramp = many)
        steps = []
        for vs in per_ray.values():
            steps.append(sum(1 for a, b in zip(vs, vs[1:]) if abs(a - b) > 1))
        res["panel_steps_per_ray_mean"] = round(sum(steps) / len(steps), 1)
    lit, alb = load(d, "room_lit"), load(d, "room_albedo")
    if lit is not None and alb is not None:
        cx, cy = info.get("room_light", (lit.shape[1] // 2, lit.shape[0] // 2))
        la, ll = lum(alb), lum(lit)
        per_ray = {}
        for k, r, y, x in ray_samples(*la.shape, cx, cy, 70):
            if la[y, x] >= 60:   # dark albedo makes the ratio pure rounding noise
                per_ray.setdefault(k, []).append(round(ll[y, x] / la[y, x], 2))
        counts = [len(levels(v, 0.035)) for v in per_ray.values() if len(v) >= 10]
        if counts:
            res["room_factor_levels_per_ray_median"] = int(np.median(counts))
            res["room_factor_levels_per_ray_max"] = max(counts)
    return res


def palette(d, before):
    res = {}
    if not before:
        return res
    a0, a1 = load(before, "room_albedo"), load(d, "room_albedo")
    if a0 is not None and a1 is not None and a0.shape == a1.shape:
        same = np.all(a0 == a1, axis=2)
        res["albedo_identical_pct"] = round(100.0 * same.mean(), 2)
    l0, d0, l1 = load(before, "room_lit"), load(before, "room_dark"), load(d, "room_lit")
    if l0 is not None and d0 is not None and l1 is not None:
        unlit = np.all(l0 == d0, axis=2)
        same = np.all(l1 == l0, axis=2)
        res["unlit_pixels"] = int(unlit.sum())
        res["unlit_unchanged_pct"] = round(100.0 * same[unlit].mean(), 2) if unlit.any() else None
    return res


def palette_set():
    here = os.path.dirname(os.path.abspath(__file__))
    import re
    txt = open(os.path.join(here, "..", "DESIGN.md")).read()
    return {tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in re.findall(r"#([0-9a-fA-F]{6})", txt)}


def flame(d, info):
    """The flame is unshaded: in the albedo frame its pixels must all be 0x72 palette colours; and the
    sputter tint (self_modulate) must still reach it."""
    res = {}
    a = load(d, "room_albedo")
    if a is None or "flame" not in info:
        return res
    fx, fy = info["flame"]
    box = a[fy - 13:fy + 2, fx - 5:fx + 6].reshape(-1, 3)
    pal = palette_set()
    warm = [tuple(int(v) for v in c) for c in box if c[0] > 150 and c[0] > c[2] + 60]   # flame-coloured pixels
    if warm:
        res["flame_px"] = len(warm)
        res["flame_in_palette_pct"] = round(100.0 * sum(1 for c in warm if c in pal) / len(warm), 1)
        res["flame_off_palette"] = sorted({"#%02x%02x%02x" % c for c in warm if c not in pal})[:6]
    s = load(d, "flame_sputter")
    if s is not None:
        sb = s[fy - 13:fy + 2, fx - 5:fx + 6].reshape(-1, 3).astype(float)
        ab = box.astype(float)
        m = ab[:, 0] > 150
        if m.any():
            res["sputter_g_over_r"] = round(float(sb[m, 1].sum() / max(sb[m, 0].sum(), 1)), 3)
            res["normal_g_over_r"] = round(float(ab[m, 1].sum() / max(ab[m, 0].sum(), 1)), 3)
    return res


def foes(d, info):
    """A plain slug vs a 'chilled' champion slug (modulate 0.7, 0.95, 1.35): mean colour of each body."""
    res = {}
    a = load(d, "foes_albedo")
    if a is None or "foe0" not in info or "foe1" not in info:
        return res
    for k in ("foe0", "foe1"):
        x, y = info[k]
        box = a[y - 16:y, x - 9:x + 9].reshape(-1, 3).astype(float)
        m = box.max(axis=1) > 40
        if m.any():
            res[k + "_mean_rgb"] = [round(float(v), 1) for v in box[m].mean(axis=0)]
    if "foe0_mean_rgb" in res and "foe1_mean_rgb" in res:
        r0, r1 = res["foe0_mean_rgb"], res["foe1_mean_rgb"]
        res["champ_tint_visible"] = abs((r1[2] / max(r1[0], 1)) - (r0[2] / max(r0[0], 1))) > 0.1
    return res


def sat(a):
    f = a / 255.0
    mx, mn = f.max(axis=2), f.min(axis=2)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)


def hot_mask(a):
    """Fire colours: bright, saturated, red-orange-yellow (the flame, hearths, embers)."""
    f = a / 255.0
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    return (r > 0.75) & (r >= g) & (g >= b) & (sat(a) > 0.55)


def waning(d):
    res = {}
    a, b = load(d, "wane_100"), load(d, "wane_20")
    if a is None or b is None:
        return res
    res["sat_mean_100"] = round(float(sat(a).mean()), 4)
    res["sat_mean_20"] = round(float(sat(b).mean()), 4)
    res["sat_ratio_20_vs_100"] = round(res["sat_mean_20"] / max(res["sat_mean_100"], 1e-6), 3)
    # the room only (the 272x192 room image centred on screen; the void around it is the clear colour)
    h, w = a.shape[:2]
    y0, x0 = (h - 192) // 2, (w - 272) // 2
    ra, rb = sat(a[y0:y0 + 192, x0:x0 + 272]), sat(b[y0:y0 + 192, x0:x0 + 272])
    res["room_sat_100"] = round(float(ra.mean()), 4)
    res["room_sat_20"] = round(float(rb.mean()), 4)
    res["room_sat_ratio_20_vs_100"] = round(res["room_sat_20"] / max(res["room_sat_100"], 1e-6), 3)
    hm = hot_mask(b)
    res["hot_pixels_20"] = int(hm.sum())
    if hm.any():
        res["hot_sat_20"] = round(float(sat(b)[hm].mean()), 3)
    hm0 = hot_mask(a)
    if hm0.any():
        res["hot_sat_100"] = round(float(sat(a)[hm0].mean()), 3)
    res["lum_mean_100"] = round(float(lum(a).mean()), 1)
    res["lum_mean_20"] = round(float(lum(b).mean()), 1)
    return res


def displacement(d, on, off, maxd):
    a, b = load(d, on), load(d, off)
    if a is None or b is None:
        return {}
    diff = np.any(a != b, axis=2)
    ys, xs = np.nonzero(diff)
    res = {on + "_changed_px": int(diff.sum())}
    if not len(ys):
        return res
    res[on + "_bbox"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    h, w = diff.shape
    bad = 0
    used = {}
    for y, x in zip(ys, xs):
        found = None
        for r in range(1, maxd + 1):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and np.array_equal(b[yy, xx], a[y, x]):
                        found = r
                        break
                if found:
                    break
            if found:
                break
        if found is None:
            bad += 1
        else:
            used[found] = used.get(found, 0) + 1
    res[on + "_not_a_shifted_copy"] = bad
    res[on + "_shift_hist"] = used
    return res


def main():
    d = sys.argv[1]
    before = sys.argv[2] if len(sys.argv) > 2 else None
    info = {}
    log = os.path.join(d, "judge.log")
    if os.path.exists(log):
        for line in open(log):
            for key in ("panel_light", "room_light", "flame", "shock", "foe0", "foe1"):
                if line.startswith("[judge] %s=" % key):
                    x, y = line.split("=")[1].strip().split(",")
                    info[key] = (int(x), int(y))
    out = {}
    out.update(bands(d, info))
    out.update(palette(d, before))
    out.update(flame(d, info))
    if before:
        out.update({"before_" + k: v for k, v in flame(before, info).items() if "palette" in k})
    out.update(waning(d))
    out.update(foes(d, info))
    out.update(displacement(d, "haze_on", "haze_off", 1))
    out.update(displacement(d, "shock_on", "shock_off", 2))
    for k, v in out.items():
        print("%s: %s" % (k, v))


if __name__ == "__main__":
    main()
