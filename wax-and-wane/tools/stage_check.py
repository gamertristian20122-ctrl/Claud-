#!/usr/bin/env python3
"""Pixel-exactness judge for Screen: Big (scripts/stage.gd, docs/streams/v28_screen.md).

A tour run with --layers saves, for every shot, the composed screen (NN_name.png, at the screen's own size) and the
two low-resolution buffers behind it: NN_name.world.png (the room, one pixel per art pixel) and NN_name.ui.png (menus
and HUD, with alpha). This script rebuilds the screen from the buffers the only way a pixel-perfect picture can be
built: the world enlarged by a whole number kw (nearest neighbour), the UI enlarged by a whole number ku and laid
over it (its colours are stored premultiplied), and compares that with what the game put on the glass.

    python3 tools/stage_check.py <shots dir>

PASS: where the UI is absent or opaque every pixel is identical; where it is translucent no channel is off by more
than 1 of 255 (the UI buffer holds 8 bits per channel). Exit code 1 on a FAIL."""
import os
import sys

import numpy as np
from PIL import Image

WALLS = (250, 180)   # the room, wall to wall and top of the top wall to the foot of the bottom wall (art pixels)


def up(a, k, w, h):
    return np.repeat(np.repeat(a, k, axis=0), k, axis=1)[:h, :w]


def main(d):
    shots = sorted(f[:-10] for f in os.listdir(d) if f.endswith(".world.png"))
    if not shots:
        print("[stage_check] no *.world.png in %s (run a tour with --layers in Screen: Big)" % d)
        return 1
    bad = 0
    line = ""
    for s in shots:
        comp = np.asarray(Image.open(os.path.join(d, s + ".png")).convert("RGB")).astype(np.int32)
        world = np.asarray(Image.open(os.path.join(d, s + ".world.png")).convert("RGB")).astype(np.int32)
        ui = np.asarray(Image.open(os.path.join(d, s + ".ui.png")).convert("RGBA")).astype(np.int32)
        h, w = comp.shape[:2]
        kw = -(-w // world.shape[1])   # the buffers are ceil(screen / scale) wide
        ku = -(-w // ui.shape[1])
        if world.shape[0] * kw < h or ui.shape[0] * ku < h or world.shape[1] * kw < w or ui.shape[1] * ku < w:
            print("[stage_check] %s FAIL: buffers %s x%d / %s x%d do not cover the %dx%d screen" % (
                s, world.shape[1::-1], kw, ui.shape[1::-1], ku, w, h))
            bad += 1
            continue
        big_world = up(world, kw, w, h)
        big_ui = up(ui, ku, w, h)
        alpha = big_ui[..., 3:4]
        want = big_ui[..., :3] + (big_world * (255 - alpha) + 127) // 255
        diff = np.abs(np.clip(want, 0, 255) - comp).max(axis=2)
        clear = alpha[..., 0] == 0
        solid = alpha[..., 0] == 255
        mixed = ~(clear | solid)
        n_clear_bad = int((diff[clear] != 0).sum())
        n_solid_bad = int((diff[solid] != 0).sum())
        n_mixed_bad = int((diff[mixed] > 1).sum())
        ok = n_clear_bad == 0 and n_solid_bad == 0 and n_mixed_bad == 0
        bad += 0 if ok else 1
        line = "screen %dx%d: world %dx%d x%d, ui %dx%d x%d" % (w, h, world.shape[1], world.shape[0], kw,
                                                              ui.shape[1], ui.shape[0], ku)
        print("[stage_check] %-28s %s  world-only px %d (off %d)  opaque-ui px %d (off %d)  translucent px %d "
              "(max diff %d, off by >1: %d)" % (s, "ok  " if ok else "FAIL", int(clear.sum()), n_clear_bad,
                                                int(solid.sum()), n_solid_bad, int(mixed.sum()),
                                                int(diff[mixed].max()) if mixed.any() else 0, n_mixed_bad))
    if line:
        w, h = [int(v) for v in line.split(":")[0].split()[1].split("x")]
        kw = int(line.split(" x")[1].split(",")[0])
        rw, rh = min(WALLS[0] * kw, w), min(WALLS[1] * kw, h)
        print("[stage_check] %s; the room's walls cover %d x %d screen pixels: %.1f%% of the width, %.1f%% of the "
              "height, %.1f%% of the screen" % (line, rw, rh, 100.0 * rw / w, 100.0 * rh / h, 100.0 * rw * rh / (w * h)))
    print("[stage_check] %d shots, %d failed -> %s" % (len(shots), bad, "PASS" if bad == 0 else "FAIL"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
