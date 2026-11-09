#!/usr/bin/env python3
"""v2.1 shots judge: how big and how readable every enemy shot (and telegraph) is on the screen.

    python3 tools/shot_judge.py DIR [BEFORE_DIR] [--md] [--sheet OUT.png]

DIR holds the images and judge.json of
    xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
        -- --autotest --tour --shotjudge --shots=DIR
(scripts/game/shot_judge.gd: every enemy shot held still on floors 1-4 and the Clock Tower, at 100 % and 20 % wax,
across the lit floor and in a shadowed corner; 1 image px = 1 game px). Every layout is shot as A0 / A1 (the two
pulse frames), T (shots hidden) and B (shots and telegraphs hidden).

Per shot (window of 21 x 21 game px round its centre; its own pixels = where A differs from T):
  * size: width / height of its own pixels, in game pixels (the drawn sprite);
  * contrast: WCAG ratio of its ink against the local floor (T's median luminance in a 3 px band round the
    shot): the better of its brightest 10 % (on a dark floor) and its darkest 10 % (on a light floor). Target
    >= 4.5 everywhere. The worse of the two pulse frames counts;
  * seen: its pixels that stand out >= 3:1 from that floor (the part the eye picks up at a glance), as a count and
    as the side of their bounding box ("visible size").
Telegraph marks (T vs B): the same contrast rule for each mark, and the share of mark pixels >= 3:1.
With BEFORE_DIR it prints both runs side by side; --sheet writes a before/after picture at phone scale.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

WIN = 10          # half window round a shot centre
TARGET = 4.5


def lum(rgb):
    c = np.asarray(rgb, dtype=float) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def ratio(a, b):
    hi, lo = np.maximum(a, b), np.minimum(a, b)
    return (hi + 0.05) / (lo + 0.05)


def load(d, name):
    return np.asarray(Image.open(os.path.join(d, name)).convert("RGB")).astype(int)


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def measure(a, t, x, y):
    """One shot: its own pixels in A (vs T) round (x, y)."""
    h, w = a.shape[:2]
    x0, y0, x1, y1 = max(0, x - WIN), max(0, y - WIN), min(w, x + WIN + 1), min(h, y + WIN + 1)
    A = a[y0:y1, x0:x1]
    T = t[y0:y1, x0:x1]
    m = np.abs(A - T).sum(-1) > 0
    if not m.any():
        return None
    # only the blob(s) at the centre: Tallow's flame and its heat haze move on their own near the lit row
    from scipy import ndimage
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    cy, cx = y - y0, x - x0
    keep = set(np.unique(lab[max(0, cy - 2):cy + 3, max(0, cx - 2):cx + 3])) - {0}
    m = np.isin(lab, list(keep))
    if not m.any():
        return None
    ys, xs = np.nonzero(m)
    band = dilate(m, 3) & ~dilate(m, 1)
    bg = float(np.median(lum(T[band]))) if band.any() else float(np.median(lum(T)))
    L = lum(A[m])
    hi = float(np.percentile(L, 90))
    lo = float(np.percentile(L, 10))
    c = max(float(ratio(hi, bg)), float(ratio(lo, bg)))
    seen = ratio(L, bg) >= 3.0
    sy, sx = ys[seen], xs[seen]
    side = int(max(sx.max() - sx.min() + 1, sy.max() - sy.min() + 1)) if seen.any() else 0
    return {"w": int(xs.max() - xs.min() + 1), "h": int(ys.max() - ys.min() + 1), "px": int(m.sum()),
            "contrast": c, "seen": int(seen.sum()), "seen_side": side, "bg": bg}


def tele_marks(t, b):
    """Telegraph dots (T vs B). A dot is a coloured mark pixel: it differs from B by >= 32 in some channel (the
    flicker of Tallow's flame and the wall candles between the two captures moves the floor by a few levels
    only) and is not the dark outline (luminance >= 0.05). It reads by the better of its own contrast with the
    floor (in the dark) and that of the darkest mark pixel next to it (its dark outline, on a light floor). Floor =
    B's median in a 9 x 9 window round the dot, mark pixels (any change >= 8) left out.
    Returns the min / median dot contrast and the share of dots >= 3:1."""
    diff = np.abs(t - b).max(-1)
    m = diff >= 8
    if not m.any():
        return None
    Lt, Lb = lum(t), lum(b)
    h, w = m.shape
    cs = []
    for y, x in zip(*np.nonzero((diff >= 32) & (Lt >= 0.05))):
        y0, y1, x0, x1 = max(0, y - 4), min(h, y + 5), max(0, x - 4), min(w, x + 5)
        floor = ~m[y0:y1, x0:x1]
        if not floor.any():
            continue
        bg = float(np.median(Lb[y0:y1, x0:x1][floor]))
        c = float(ratio(Lt[y, x], bg))
        near = m[max(0, y - 1):y + 2, max(0, x - 1):x + 2]
        dark = Lt[max(0, y - 1):y + 2, max(0, x - 1):x + 2][near].min()
        if dark < bg:
            c = max(c, float(ratio(dark, bg)))
        cs.append(c)
    cs = np.array(cs)
    return {"marks": len(cs), "px": int(m.sum()), "min": float(cs.min()), "median": float(np.median(cs)),
            "share3": float((cs >= 3.0).mean())}


def judge(d):
    j = json.load(open(os.path.join(d, "judge.json")))
    rows = []
    for L in j["layouts"]:
        f = L["files"]
        t = load(d, f["t"])
        b = load(d, f["b"])
        per = []
        for s in L["shots"]:
            worst = None
            for k in ("a0", "a1"):
                r = measure(load(d, f[k]), t, int(round(s["x"])), int(round(s["y"])))
                if r and (worst is None or r["contrast"] < worst["contrast"]):
                    worst = r
            if worst:
                worst.update({"kind": s["kind"], "place": s["place"]})
                per.append(worst)
        rows.append({"floor": L["floor"], "wax": L["wax"], "size": L["size"], "shots": per, "tele": tele_marks(t, b),
                     "files": f})
    return rows


def summary(rows):
    out = {}
    for r in rows:
        for place in ("lit", "corner"):
            ss = [s for s in r["shots"] if s["place"] == place]
            key = (r["size"], r["floor"], int(r["wax"] * 100), place)
            out[key] = {
                "min": min(s["contrast"] for s in ss), "median": float(np.median([s["contrast"] for s in ss])),
                "size": float(np.mean([max(s["w"], s["h"]) for s in ss])),
                "seen": float(np.mean([s["seen"] for s in ss])), "seen_side": float(np.mean([s["seen_side"] for s in ss])),
                "worst": min(ss, key=lambda s: s["contrast"])["kind"]}
        out[(r["size"], r["floor"], int(r["wax"] * 100), "tele")] = r["tele"]
    return out


def per_kind(rows):
    k = {}
    for r in rows:
        for s in r["shots"]:
            e = k.setdefault((r["size"], s["kind"]), {"c": [], "size": [], "seen": [], "side": []})
            e["c"].append(s["contrast"])
            e["size"].append(max(s["w"], s["h"]))
            e["seen"].append(s["seen"])
            e["side"].append(s["seen_side"])
    return k


def report(rows, title):
    sm = summary(rows)
    sizes = sorted({k[0] for k in sm})
    print("## %s" % title)
    for size in sizes:
        print("\n### shots, size %s: min / median contrast (worst kind), drawn size, pixels >= 3:1 (visible side)" % size)
        print("| floor | wax | lit floor | shadowed corner | telegraph marks: min / median, share >= 3:1 |")
        print("|---|---|---|---|---|")
        for (sz, fl, wax, place), v in sorted(sm.items()):
            if sz != size or place != "lit":
                continue
            c = sm[(sz, fl, wax, "corner")]
            t = sm[(sz, fl, wax, "tele")]
            cell = lambda v: "%.2f / %.2f (%s), %.1f px, %.0f px (%.1f)" % (v["min"], v["median"], v["worst"].split("_")[1],
                                                                             v["size"], v["seen"], v["seen_side"])
            tc = "%.2f / %.2f, %.0f%%" % (t["min"], t["median"], 100 * t["share3"]) if t else "-"
            print("| F%d | %d%% | %s | %s | %s |" % (fl, wax, cell(v), cell(c), tc))
        allc = [s["contrast"] for r in rows if r["size"] == size for s in r["shots"]]
        below = sum(1 for c in allc if c < TARGET)
        print("\nworst shot contrast %.2f, below %.1f: %d of %d" % (min(allc), TARGET, below, len(allc)))
    pk = per_kind(rows)
    print("\n### per kind (all floors, wax levels and places): min contrast, drawn size, mean pixels >= 3:1, visible side")
    print("| kind | " + " | ".join(sizes) + " |")
    print("|---|" + "---|" * len(sizes))
    for kind in sorted({k[1] for k in pk}):
        cells = []
        for size in sizes:
            e = pk.get((size, kind))
            cells.append("%.2f, %d px, %.0f px, %.1f" % (min(e["c"]), max(e["size"]), np.mean(e["seen"]), np.mean(e["side"])) if e else "-")
        print("| %s | %s |" % (kind, " | ".join(cells)))
    return sm


def sheet(after_dir, before_dir, path, scale=2, zoom=4):
    """Before / after: columns 2.0 / 2.1 Normal / 2.1 Large, rows floor 1 at full wax and floors 2, 3 and the tower
    at 20 % wax. Each cell is the whole screen at `scale` (x2 is about the size it has on a 6.5 inch phone held at
    arm's length on a desktop monitor) with the lit row and the shadowed corner below it at `zoom`."""
    ja = json.load(open(os.path.join(after_dir, "judge.json")))
    jb = json.load(open(os.path.join(before_dir, "judge.json")))
    picks = [(1, 1.0), (2, 0.2), (3, 0.2), (5, 0.2)]
    cols = [("2.0", jb, before_dir, jb["sizes"][0])] + [("2.1 " + s, ja, after_dir, s) for s in ja["sizes"]]
    cw, ch = 480 * scale, 216 * scale
    lit, corner = (160, 86, 320, 106), (276, 49, 348, 85)   # screen rects of the lit row and the corner block
    zh = (corner[3] - corner[1]) * zoom
    out = Image.new("RGB", (cw * len(cols) + 8 * (len(cols) - 1), (ch + zh + 30) * len(picks)), (12, 10, 12))
    d = ImageDraw.Draw(out)
    for ri, (fl, wax) in enumerate(picks):
        for ci, (lab, j, dd, size) in enumerate(cols):
            L = next(l for l in j["layouts"] if l["floor"] == fl and abs(l["wax"] - wax) < 1e-6 and l["size"] == size)
            im = Image.open(os.path.join(dd, L["files"]["a0"])).convert("RGB")
            x = ci * (cw + 8)
            y = ri * (ch + zh + 30)
            d.text((x + 4, y + 2), "%s - floor %d, %d%% wax" % (lab, fl, int(wax * 100)), fill=(240, 230, 210))
            out.paste(im.resize((cw, ch), Image.NEAREST), (x, y + 14))
            zl = im.crop(lit)
            zc = im.crop(corner)
            out.paste(zl.resize((zl.width * zoom, zl.height * zoom), Image.NEAREST), (x, y + 14 + ch + 8))
            out.paste(zc.resize((zc.width * zoom, zc.height * zoom), Image.NEAREST), (x + cw - zc.width * zoom, y + 14 + ch + 8))
    out.save(path)
    return path


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    after = judge(args[0])
    sm_a = report(after, "this build: " + args[0])
    if len(args) > 1:
        before = judge(args[1])
        print()
        sm_b = report(before, "before: " + args[1])
        print("\n## before -> after, per floor and wax (min contrast lit / corner, visible side lit)")
        sizes = sorted({k[0] for k in sm_a})
        bsize = sorted({k[0] for k in sm_b})[0]
        for size in sizes:
            print("\n%s -> %s" % (bsize, size))
            print("| floor | wax | min contrast lit | min contrast corner | visible side (lit) | px >= 3:1 (lit) | telegraph >= 3:1 |")
            print("|---|---|---|---|---|---|---|")
            for (sz, fl, wax, place), v in sorted(sm_a.items()):
                if sz != size or place != "lit":
                    continue
                b = sm_b[(bsize, fl, wax, "lit")]
                bc = sm_b[(bsize, fl, wax, "corner")]
                c = sm_a[(sz, fl, wax, "corner")]
                tb, ta = sm_b[(bsize, fl, wax, "tele")], sm_a[(sz, fl, wax, "tele")]
                print("| F%d | %d%% | %.2f -> %.2f | %.2f -> %.2f | %.1f -> %.1f | %.0f -> %.0f | %.0f%% -> %.0f%% |" % (
                    fl, wax, b["min"], v["min"], bc["min"], c["min"], b["seen_side"], v["seen_side"], b["seen"], v["seen"],
                    100 * tb["share3"], 100 * ta["share3"]))
        if "--sheet" in sys.argv:
            print("sheet ->", sheet(args[0], args[1], sys.argv[sys.argv.index("--sheet") + 1]))


if __name__ == "__main__":
    main()
