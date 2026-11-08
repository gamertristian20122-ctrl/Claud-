#!/usr/bin/env python3
"""Readable decisions: does the wax bar show exactly the price that is about to be paid?

    python3 tools/design_ghost_check.py <shots_dir>

<shots_dir> comes from
    xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
        -- --autotest --designcheck --ghostshot --shots=<shots_dir>
which writes the screenshots and ghost.json: per shot the game's own numbers (wax, max, charred, the
price now and for good) and where the bar's 128 px of wax start. This script does not trust the HUD:
it works out the expected pixels from those numbers (the bar is 128 px for max + charred minutes) and
counts, on one row of the screenshot under the notches, the pixels in the price colours:
  wax cut now   #da4e38 / #8f4029 (marching red at the flame end)
  charred later #775c55 / #21141b (marching soot at the far end; row 11 of the empty bar is #38262d)
PASS when every count equals the expected pixels and lies within 1 px of the exact (unrounded) width.
"""
import glob
import json
import os
import sys

from PIL import Image

NOW = {(0xda, 0x4e, 0x38), (0x8f, 0x40, 0x29)}
LATER = {(0x77, 0x5c, 0x55), (0x21, 0x14, 0x1b)}


def main():
    d = sys.argv[1]
    rows = json.load(open(os.path.join(d, "ghost.json")))
    ok = True
    for r in rows:
        f = glob.glob(os.path.join(d, "*_%s.png" % r["name"]))[0]
        im = Image.open(f).convert("RGB")
        inner = int(r["inner"])
        total = float(r["wax_max"]) + float(r["charred"])
        wax = float(r["wax"])
        x0 = int(round(r["bar_x"]))
        y = int(round(r["bar_y"])) + int(r["h"]) - 3
        px = [im.getpixel((x0 + i, y)) for i in range(inner)]
        now_cols = [i for i, c in enumerate(px) if c in NOW]
        later_cols = [i for i, c in enumerate(px) if c in LATER]
        now_rng = (round(inner * max(0.0, wax - r["cost_now"]) / total), round(inner * wax / total))
        exp_now = now_rng[1] - now_rng[0]
        exact_now = inner * min(wax, r["cost_now"]) / total
        later_rng = (round(inner * max(0.0, total - r["charred"] - r["cost_max"]) / total), round(inner * (total - r["charred"]) / total))
        exp_later = later_rng[1] - later_rng[0]
        exact_later = inner * r["cost_max"] / total
        # where the wax cut now runs into the charred end (wax near full), the cut is drawn on top
        overlap = max(0, min(now_rng[1], later_rng[1]) - max(now_rng[0], later_rng[0])) if exp_now and exp_later else 0
        good = len(now_cols) == exp_now and abs(len(now_cols) - exact_now) <= 1.0 \
            and len(later_cols) + overlap == exp_later and abs(len(later_cols) + overlap - exact_later) <= 1.0
        if now_cols:
            good = good and now_cols[0] == now_rng[0] and now_cols[-1] - now_cols[0] + 1 == len(now_cols)   # one unbroken slice, in place
        ok = ok and good
        print("%-16s wax %.1f/%d  now: %.1f min -> expect %d px (exact %.2f) at %d.., measured %d %s | for good: %.0f min -> expect %d px (exact %.2f), measured %d%s  %s" % (
            r["name"], wax, total, r["cost_now"], exp_now, exact_now, now_rng[0], len(now_cols),
            ("at %d..%d" % (now_cols[0], now_cols[-1])) if now_cols else "", r["cost_max"], exp_later, exact_later,
            len(later_cols), (" + %d under the cut" % overlap) if overlap else "", "ok" if good else "BAD"))
    print("ghost %s" % ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main()
