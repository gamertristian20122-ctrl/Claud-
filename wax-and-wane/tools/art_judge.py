#!/usr/bin/env python3
"""Measure the fix/art judge shots (scripts/game/art_judge.gd): how well each creature stands out
from the floor right round it, in Tallow's shadow (UX-03) and, for the guardians, out in the dark (C6).

    python3 tools/art_judge.py DIR [BEFORE_DIR]

For every creature in every shot pair (A = as played, B = the creatures' sprites hidden):
  * its pixels = where A and B differ inside its sprite rect (+1 px for the rim),
  * floor = the median colour of B in a ring 3..8 px round those pixels,
  * top10 = WCAG contrast of the mean of its brightest 10 % of pixels against the floor
    (the UX review's measure, tools contrast.py: "ink" vs background),
  * body = WCAG contrast of the median of all its pixels against the floor.
Prints a table per condition and the worst cases; writes DIR/judge_table.json. Pass mark: top10 >= 3.0
for every creature in shadow at full and at 25 % wax.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def lum(rgb):
    c = np.asarray(rgb, dtype=float) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def ratio(la, lb):
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def measure(d):
    meta = json.load(open(os.path.join(d, "judge.json")))
    rows = []
    for pair in meta["pairs"]:
        a = np.array(Image.open(os.path.join(d, pair["a"])).convert("RGB")).astype(int)
        b = np.array(Image.open(os.path.join(d, pair["b"])).convert("RGB")).astype(int)
        H, W = a.shape[:2]
        sx = W / pair["viewport"][0]
        sy = H / pair["viewport"][1]
        diff = np.abs(a - b).sum(2) > 0
        for r in pair["rects"]:
            x0 = max(0, int(np.floor(r["x0"] * sx)) - 1)
            y0 = max(0, int(np.floor(r["y0"] * sy)) - 1)
            x1 = min(W, int(np.ceil(r["x1"] * sx)) + 1)
            y1 = min(H, int(np.ceil(r["y1"] * sy)) + 1)
            m = np.zeros_like(diff)
            m[y0:y1, x0:x1] = diff[y0:y1, x0:x1]
            if m.sum() < 6:
                rows.append({"tag": pair["tag"], "kind": r["kind"], "wax": pair["wax"], "missing": True})
                continue
            ring = ndimage.binary_dilation(m, iterations=8) & ~ndimage.binary_dilation(m, iterations=3)
            floor = np.median(b[ring], axis=0)
            px = a[m]
            L = lum(px)
            order = np.argsort(L)
            top = px[order[int(len(L) * 0.9):]].mean(0)
            lf = float(lum(floor))
            rows.append({
                "tag": pair["tag"], "kind": r["kind"], "boss": r.get("boss", False), "wax": pair["wax"],
                "pixels": int(m.sum()), "floor": [int(v) for v in floor], "floor_lum": round(lf, 4),
                "top10": round(ratio(float(lum(top)), lf), 2),
                "body": round(ratio(float(np.median(L)), lf), 2),
            })
    return rows


def cond(row):
    t = row["tag"]
    if "_boss_" in t:
        return "boss_dark_%d" % int(row["wax"] * 100)
    kind = "shadow" if "_shadow_" in t else "lit"
    return "%s_%d" % (kind, int(row["wax"] * 100))


def summary(rows, label):
    out = {}
    for r in rows:
        if r.get("missing"):
            continue
        out.setdefault(cond(r), []).append(r)
    print("== %s" % label)
    for k in sorted(out):
        v = out[k]
        t = np.array([r["top10"] for r in v])
        bdy = np.array([r["body"] for r in v])
        worst = sorted(v, key=lambda r: r["top10"])[:3]
        print("  %-14s n=%3d  top10 min %.2f median %.2f | body min %.2f median %.2f | below 3: %d | worst: %s" % (
            k, len(v), t.min(), np.median(t), bdy.min(), np.median(bdy), int((t < 3.0).sum()),
            ", ".join("%s %s %.2f" % (r["tag"].split("_")[0], r["kind"], r["top10"]) for r in worst)))
    miss = [r for r in rows if r.get("missing")]
    if miss:
        print("  missing (no pixels found):", ", ".join("%s/%s" % (r["tag"], r["kind"]) for r in miss))
    return out


def main():
    d = sys.argv[1]
    rows = measure(d)
    json.dump(rows, open(os.path.join(d, "judge_table.json"), "w"), indent=1)
    after = summary(rows, d)
    if len(sys.argv) > 2:
        before_rows = measure(sys.argv[2])
        before = summary(before_rows, sys.argv[2] + " (before)")
        print("== per creature, before -> after (top10)")
        idx = {(r["tag"], r["kind"]): r for r in before_rows if not r.get("missing")}
        for k in sorted(after):
            if not k.startswith(("shadow", "boss")):
                continue
            line = []
            for r in sorted(after[k], key=lambda r: r["top10"]):
                b = idx.get((r["tag"], r["kind"]))
                line.append("%s %s->%s" % (r["kind"], b["top10"] if b else "?", r["top10"]))
            print("  %s: %s" % (k, "; ".join(line)))
    bad = [r for r in rows if not r.get("missing") and cond(r).startswith("shadow") and r["top10"] < 3.0]
    print("PASS" if not bad else "FAIL: %d creatures in shadow below 3:1" % len(bad))


if __name__ == "__main__":
    main()
