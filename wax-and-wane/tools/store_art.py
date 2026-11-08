#!/usr/bin/env python3
"""Wax & Wane - store art: screenshots, key art and capsules for Steam, itch.io and Google Play.

The game stages and renders every picture itself (scripts/store_shots.gd, run through
scripts/autotest.gd) at its own pixel size (384 x 216 on a 16:9 screen). This script runs those
renders, then builds every store image from them with whole-number nearest-neighbour scaling only:
no blur, no smoothing, no anti-aliasing on the pixel art. The darkness around the art is stepped and
dithered on the game's own pixel grid (like the light rings in tools/art_icon.py), never a smooth
gradient.

Re-run it on the final build with one command (about 1.5 minutes; needs godot + xvfb-run):
    python3 tools/store_art.py
Options:
    --import        run `godot --headless --import` first (after new or changed assets)
    --no-render     rebuild the images from the last renders in build/store_raw/ (a few seconds)
    --raw DIR       where the raw renders go (default build/store_raw, git-ignored)
    --review DIR    also write review sheets: every capsule at the size Steam really shows it

Output: docs/marketing/store_assets/ (README.md there lists each file and where it is uploaded).
"""
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "marketing", "store_assets")
LOGO = os.path.join(ROOT, "assets", "art", "ui", "title_logo.png")
FONT = os.path.join(ROOT, "assets", "fonts", "kenney_pixel.ttf")

CLEAR = (9, 7, 9)            # the game's clear colour (project.godot default_clear_color)
SHADOW = (12, 8, 12)         # the logo's drop shadow
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32)
# light left in each darkness step (1 = untouched); neighbouring steps are mixed with a 4x4 Bayer dither
STEPS = np.array([1.0, 0.7, 0.46, 0.27, 0.13, 0.04, 0.0], dtype=np.float32)

# store screenshots, in upload order (the names scripts/store_shots.gd saves)
STEAM_SHOTS = ["cellar_fight", "boss_fight", "chapel_light", "seance", "boss_card", "low_wax", "treasure",
               "relic_aloft", "shop", "title"]
PHONE_SHOTS = ["cellar_fight", "boss_fight", "relic_aloft"]
RENDERS = [  # (raw folder, window, autotest arguments): run one after another (they share one save file)
    ("keyart", "1920x1080", ["--keyart"]),                          # the cast laid out wide
    ("keyart_tall", "1920x1080", ["--keyart", "--keylayout=tall"]),  # ...and stacked, for portrait capsules
    ("shots", "1920x1080", ["--shots-store"]),
    ("phone", "2160x1080", ["--shots-store", "--phone"]),   # 18:9 phone, the widest Google Play accepts (2:1)
]


# ---------------------------------------------------------------- rendering

def render(raw):
    for name, res, extra in RENDERS:
        d = os.path.join(raw, name)
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
        w, h = res.split("x")
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 %sx%sx24" % (w, h), "godot", "--path", ROOT,
               "--rendering-driver", "opengl3", "--resolution", res, "--",
               "--autotest"] + extra + ["--shots=" + d]
        print("[store_art] rendering %s at %s ..." % (name, res), flush=True)
        with open(os.path.join(raw, name + ".log"), "w") as log:
            r = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        made = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        print("[store_art]   exit %d, %d images" % (r.returncode, len(made)))
        with open(os.path.join(raw, name + ".log")) as log:
            errs = [ln.strip() for ln in log if "SCRIPT ERROR" in ln]
        if errs:
            print("[store_art]   script errors:", *errs[:5], sep="\n    ")


# ---------------------------------------------------------------- pixel helpers

def up(img, k):
    """Whole-number nearest-neighbour scale."""
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def no_alpha(img):
    bg = Image.new("RGB", img.size, CLEAR)
    bg.paste(img.convert("RGB"))
    return bg


def window(src, cx, cy, w, h):
    """A w x h piece of src centred on (cx, cy); outside src is the game's clear colour."""
    c = Image.new("RGB", (w, h), CLEAR)
    c.paste(src.convert("RGB"), (int(round(w / 2 - cx)), int(round(h / 2 - cy))))
    return c


def darken(img, t):
    """Steps a native-size image towards the clear colour. t: darkness 0..1 per pixel (numpy h x w)."""
    a = np.asarray(img.convert("RGB"), dtype=np.float32)
    h, w = t.shape
    pos = np.clip(t, 0.0, 1.0) * (len(STEPS) - 1)
    base = np.floor(pos)
    thr = (np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] + 0.5) / 16.0
    idx = np.clip(base + ((pos - base) > thr), 0, len(STEPS) - 1).astype(int)
    f = STEPS[idx][..., None]
    bg = np.array(CLEAR, dtype=np.float32)
    out = bg + (a - bg) * f
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGB")


def ramp(d, r0, r1):
    return np.clip((d - r0) / max(1e-3, r1 - r0), 0.0, 1.0)


def light_pool(w, h, fx, fy, rx, ry, r0=0.55, r1=1.25):
    """0 inside an ellipse around (fx, fy), rising to 1 outside."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx + 0.5 - fx) / rx) ** 2 + ((yy + 0.5 - fy) / ry) ** 2)
    return ramp(d, r0, r1)


def edges(w, h, margin_x, margin_y, sides="lrtb"):
    """Darkness that rises towards the chosen borders."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.zeros((h, w), np.float32)
    if margin_x > 0:
        if "l" in sides:
            t = np.maximum(t, ramp(margin_x - xx, 0, margin_x))
        if "r" in sides:
            t = np.maximum(t, ramp(xx - (w - 1 - margin_x), 0, margin_x))
    if margin_y > 0:
        if "t" in sides:
            t = np.maximum(t, ramp(margin_y - yy, 0, margin_y))
        if "b" in sides:
            t = np.maximum(t, ramp(yy - (h - 1 - margin_y), 0, margin_y))
    return t


def plate(w, h, x0, y0, x1, y1, strength, soft):
    """A dark backing under the logo (native pixels): `strength` inside the box, fading over `soft` px."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = np.maximum(np.maximum(x0 - xx, xx - x1), 0)
    dy = np.maximum(np.maximum(y0 - yy, yy - y1), 0)
    d = np.sqrt(dx * dx + dy * dy)
    return strength * (1.0 - ramp(d, 0, soft))


_logo_cache = {}


def logo(k, shadow=True):
    """The title logo scaled k times, with a hard one-pixel drop shadow (in logo pixels)."""
    key = (k, shadow)
    if key not in _logo_cache:
        src = Image.open(LOGO).convert("RGBA")
        pad = 1 if shadow else 0
        base = Image.new("RGBA", (src.width + pad, src.height + pad), (0, 0, 0, 0))
        if shadow:
            a = src.getchannel("A")
            sh = Image.new("RGBA", src.size, SHADOW + (255,))
            sh.putalpha(a.point(lambda v: 255 if v > 0 else 0))
            base.alpha_composite(sh, (1, 1))
            base.alpha_composite(sh, (0, 1))
        base.alpha_composite(src, (0, 0))
        _logo_cache[key] = up(base, k)
    return _logo_cache[key]


# ---------------------------------------------------------------- key art

class KeyArt:
    def __init__(self, raw, layout="keyart"):
        d = os.path.join(raw, layout)
        self.full = Image.open(os.path.join(d, "keyart_full.png")).convert("RGB")
        with open(os.path.join(d, "keyart.json")) as f:
            self.info = json.load(f)
        self.tallow = tuple(self.info["tallow"])
        pts = [self.info["tallow"]] + self.info.get("lodgers", [])
        if "guardian" in self.info:
            g = self.info["guardian"]
            pts += [g, [g[0], g[1] - 36]]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts] + [self.tallow[1] - 28]
        self.cast = ((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0)
        self.room = self.info["room"]

    def point(self, ref):
        """("tallow" | "cast" | "room", dx, dy) -> a point in keyart_full.png."""
        name, dx, dy = ref
        if name == "tallow":
            x, y = self.tallow
        elif name == "cast":
            x, y = self.cast
        else:
            x, y = self.room[0] + self.room[2] / 2.0, self.room[1] + self.room[3] / 2.0
        return x + dx, y + dy

    def compose(self, size, k, centre, logo_k=0, logo_at=(0.5, 0.2), pool=(0, -14, 90, 70), pool_r=(0.5, 1.3),
                edge=(0.0, 0.0), edge_sides="lrtb", plate_strength=0.75, plate_soft=16, dim=1.0,
                guard=(0, -18, 30, 32), fade_l=None):
        W, H = size
        nw, nh = -(-W // k), -(-H // k)
        cx, cy = self.point(centre)
        nat = window(self.full, cx, cy, nw, nh)
        ox, oy = (nw * k - W) // 2, (nh * k - H) // 2
        # darkness: a pool of light round Tallow, the borders, and a backing under the logo
        tx, ty = self.tallow[0] - cx + nw / 2.0, self.tallow[1] - cy + nh / 2.0
        t = light_pool(nw, nh, tx + pool[0], ty + pool[1], pool[2], pool[3], pool_r[0], pool_r[1])
        if guard and "guardian" in self.info:   # the guardian keeps its cold rim light
            gx, gy = self.info["guardian"][0] - cx + nw / 2.0, self.info["guardian"][1] - cy + nh / 2.0
            t = np.minimum(t, light_pool(nw, nh, gx + guard[0], gy + guard[1], guard[2], guard[3], 0.45, 1.15))
        if edge[0] or edge[1]:
            t = np.maximum(t, edges(nw, nh, edge[0], edge[1], edge_sides))
        if fade_l:   # a dark panel on the left (for a logo beside the art): black up to x0, clear from x1
            xx = np.arange(nw, dtype=np.float32)[None, :].repeat(nh, 0)
            t = np.maximum(t, 1.0 - ramp(xx, fade_l[0], fade_l[1]))
        lg = None
        if logo_k:
            lg = logo(logo_k)
            lx = int(round(W * logo_at[0] - lg.width / 2.0))
            ly = int(round(H * logo_at[1] - lg.height / 2.0))
            x0, y0 = (lx + ox) / k, (ly + oy) / k
            x1, y1 = (lx + ox + lg.width) / k, (ly + oy + lg.height) / k
            t = np.maximum(t, plate(nw, nh, x0, y0, x1, y1, plate_strength, plate_soft))
        if dim < 1.0:
            t = 1.0 - (1.0 - t) * dim
        img = up(darken(nat, t), k).crop((ox, oy, ox + W, oy + H))
        if lg is not None:
            img = img.convert("RGBA")
            img.alpha_composite(lg, (lx, ly))
            img = img.convert("RGB")
        return img


# Every capsule: output size, art scale k, crop centre, logo scale and centre (fractions of the size),
# the light pool round Tallow (dx, dy, rx, ry in game pixels) and dark borders.
CAPSULES = [
    # (file, kwargs)
    ("steam/header_capsule_920x430.png", dict(size=(920, 430), k=3, centre=("tallow", -36, -31), logo_k=2, logo_at=(0.27, 0.47),
                                              pool=(14, -14, 110, 66), edge=(16, 10), plate_soft=20, fade_l=(96, 138))),
    ("steam/small_capsule_462x174.png", dict(size=(462, 174), k=2, centre=("tallow", 0, -40), logo_k=2, logo_at=(0.5, 0.37),
                                             pool=(0, -14, 70, 40), edge=(22, 10), plate_strength=0.55, plate_soft=10,
                                             guard=None)),
    ("steam/main_capsule_1232x706.png", dict(size=(1232, 706), k=4, centre=("cast", 8, -6), logo_k=4, logo_at=(0.5, 0.16),
                                             pool=(14, -12, 130, 80), edge=(20, 12))),
    ("steam/vertical_capsule_748x896.png", dict(layout="tall", size=(748, 896), k=4, centre=("cast", 0, -14), logo_k=3, logo_at=(0.5, 0.12),
                                                pool=(18, -12, 90, 90), edge=(16, 20))),
    ("steam/library_capsule_600x900.png", dict(layout="tall", size=(600, 900), k=4, centre=("cast", 0, -10), logo_k=2, logo_at=(0.5, 0.1),
                                               pool=(18, -12, 80, 90), edge=(14, 20))),
    ("steam/library_hero_3840x1240.png", dict(size=(3840, 1240), k=9, centre=("tallow", 40, -22),
                                              pool=(16, -12, 120, 64), edge=(150, 12))),
    ("steam/page_background_1438x810.png", dict(size=(1438, 810), k=5, centre=("room", 0, 0),
                                                pool=(20, -10, 120, 80), pool_r=(0.4, 1.6), edge=(30, 20), dim=0.42)),
    ("google_play/feature_graphic_1024x500.png", dict(size=(1024, 500), k=3, centre=("tallow", 51, -46), logo_k=3, logo_at=(0.5, 0.165),
                                                       pool=(14, -12, 110, 64), edge=(18, 12))),
    ("itch/cover_630x500.png", dict(size=(630, 500), k=3, centre=("tallow", 22, -36), logo_k=2, logo_at=(0.5, 0.16),
                                    pool=(0, -14, 64, 56), edge=(14, 14))),
    ("press/keyart_1920x1080.png", dict(size=(1920, 1080), k=6, centre=("cast", 6, -6),
                                        pool=(14, -12, 120, 76), edge=(20, 12))),
    ("press/keyart_logo_1920x1080.png", dict(size=(1920, 1080), k=6, centre=("cast", 6, -14), logo_k=4, logo_at=(0.5, 0.15),
                                             pool=(14, -12, 120, 76), edge=(20, 12))),
    ("press/keyart_3840x2160.png", dict(size=(3840, 2160), k=12, centre=("cast", 6, -6),
                                        pool=(14, -12, 120, 76), edge=(20, 12))),
]


def logo_files():
    """Logo-only images on a transparent background."""
    out = {}
    lg = logo(6, shadow=False)                       # 1260 x 246: Steam wants 1280 wide and/or 720 tall
    c = Image.new("RGBA", (1280, lg.height), (0, 0, 0, 0))
    c.alpha_composite(lg, ((1280 - lg.width) // 2, 0))
    out["steam/library_logo_1280x246.png"] = c
    for w, h, k in [(1280, 720, 6), (640, 360, 3)]:  # the press kit's logo canvases
        lg = logo(k, shadow=False)
        c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        c.alpha_composite(lg, ((w - lg.width) // 2, (h - lg.height) // 2))
        out["press/logo_%dx%d.png" % (w, h)] = c
    return out


# ---------------------------------------------------------------- screenshots

def check_shot(img, path, want_h=216):
    """Problems a store shot must not have (the staging also snaps banners fully on or off)."""
    probs = []
    if img.height != want_h:
        probs.append("height %d, not %d" % (img.height, want_h))
    lum = np.asarray(img.convert("L"), dtype=np.float32)
    if lum.mean() < 12:
        probs.append("nearly black (mean %.1f)" % lum.mean())
    if probs:
        print("[store_art] CHECK %s: %s" % (os.path.basename(path), "; ".join(probs)))
    return not probs


def screenshots(raw):
    made = []
    for i, name in enumerate(STEAM_SHOTS):
        src = os.path.join(raw, "shots", name + ".png")
        if not os.path.exists(src):
            print("[store_art] missing shot", name)
            continue
        img = Image.open(src).convert("RGB")
        check_shot(img, src)
        k = 1080 // img.height
        out = up(img, k)
        p = "screenshots/%02d_%s_%dx%d.png" % (i + 1, name, out.width, out.height)
        save(out, p)
        made.append(p)
    for i, name in enumerate(PHONE_SHOTS):
        src = os.path.join(raw, "phone", name + ".png")
        if not os.path.exists(src):
            print("[store_art] missing phone shot", name)
            continue
        img = Image.open(src).convert("RGB")
        check_shot(img, src)
        out = up(img, 1080 // img.height)
        p = "google_play/phone_%02d_%s_%dx%d.png" % (i + 1, name, out.width, out.height)
        save(out, p)
        made.append(p)
    return made


# ---------------------------------------------------------------- output

def save(img, rel):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if img.mode == "RGBA" and not rel.startswith(("steam/library_logo", "press/logo")):
        img = no_alpha(img)
    img.save(p, optimize=True)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


# where Steam (and the others) really show each image, in pixels: for the review sheet and overview
DISPLAY = {
    "steam/small_capsule_462x174.png": [(184, 69), (231, 87)],
    "steam/header_capsule_920x430.png": [(460, 215)],
    "steam/main_capsule_1232x706.png": [(616, 353)],
    "steam/vertical_capsule_748x896.png": [(374, 448)],
    "steam/library_capsule_600x900.png": [(200, 300)],
    "steam/library_hero_3840x1240.png": [(960, 310)],
    "google_play/feature_graphic_1024x500.png": [(512, 250)],
    "itch/cover_630x500.png": [(315, 250)],
}


def shrink(img, w, h):
    """For previews only (the overview / review sheets), never for a store file."""
    return img.convert("RGBA").resize((w, h), Image.LANCZOS)


def overview(files, review_dir=None):
    """A contact sheet of every file at (about) the size it is shown at."""
    f16 = font(16)
    items = []
    for rel in files:
        img = Image.open(os.path.join(OUT, rel))
        if rel in DISPLAY:
            w, h = DISPLAY[rel][-1]
        elif rel.startswith("screenshots/") or rel.startswith("google_play/phone"):
            w, h = img.width // 5, img.height // 5
        elif "logo" in rel:
            w, h = img.width // 4, img.height // 4
        else:
            s = min(480 / img.width, 300 / img.height)
            w, h = int(img.width * s), int(img.height * s)
        items.append((rel, shrink(img, w, h)))
    pad, colw = 12, 1000
    x = y = pad
    rowh = 0
    places = []
    for rel, im in items:
        if x + im.width > colw * 2:
            x, y = pad, y + rowh + 30
            rowh = 0
        places.append((x, y, rel, im))
        x += im.width + pad
        rowh = max(rowh, im.height)
    sheet = Image.new("RGB", (colw * 2 + pad, y + rowh + 30 + pad), (24, 20, 24))
    d = ImageDraw.Draw(sheet)
    checker = Image.new("RGBA", (16, 16), (60, 56, 60, 255))
    ImageDraw.Draw(checker).rectangle((0, 0, 7, 7), fill=(80, 76, 80, 255))
    ImageDraw.Draw(checker).rectangle((8, 8, 15, 15), fill=(80, 76, 80, 255))
    for x, y, rel, im in places:
        if "logo" in rel:   # transparency shown on a checker board
            for cx in range(0, im.width, 16):
                for cy in range(0, im.height, 16):
                    sheet.paste(checker.crop((0, 0, min(16, im.width - cx), min(16, im.height - cy))), (x + cx, y + cy))
        sheet.paste(im, (x, y), im)
        d.text((x, y + im.height + 4), rel, font=f16, fill=(226, 182, 148))
    # a preview, not a store file: 256 colours keep it small
    sheet.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(os.path.join(OUT, "overview.png"), optimize=True)
    if review_dir:
        os.makedirs(review_dir, exist_ok=True)
        for rel, sizes in DISPLAY.items():
            img = Image.open(os.path.join(OUT, rel))
            ims = [shrink(img, w, h) for w, h in sizes] + [img.convert("RGBA")]
            W = sum(i.width for i in ims) + 10 * len(ims)
            H = max(i.height for i in ims)
            s = Image.new("RGB", (W, H), (27, 40, 56))   # Steam's dark blue page
            xx = 0
            for i in ims:
                s.paste(i, (xx, 0), i)
                xx += i.width + 10
            s.save(os.path.join(review_dir, "review_" + os.path.basename(rel)))


def main():
    args = sys.argv[1:]
    raw = os.path.join(ROOT, "build", "store_raw")
    review = None
    if "--raw" in args:
        raw = os.path.abspath(args[args.index("--raw") + 1])
    if "--review" in args:
        review = os.path.abspath(args[args.index("--review") + 1])
    os.makedirs(raw, exist_ok=True)
    if "--import" in args:
        print("[store_art] importing assets ...", flush=True)
        subprocess.run(["godot", "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=900)
    if "--no-render" not in args:
        render(raw)
    files = screenshots(raw)
    ka = {"wide": KeyArt(raw), "tall": KeyArt(raw, "keyart_tall")}
    for rel, kw in CAPSULES:
        kw = dict(kw)
        save(ka[kw.pop("layout", "wide")].compose(**kw), rel)
        files.append(rel)
    shutil.copyfile(os.path.join(OUT, "steam/header_capsule_920x430.png"), os.path.join(OUT, "steam/library_header_920x430.png"))
    files.append("steam/library_header_920x430.png")
    for rel, img in logo_files().items():
        save(img, rel)
        files.append(rel)
    with open(os.path.join(OUT, ".gdignore"), "w") as f:
        f.write("")
    groups = ["steam/", "google_play/feature", "itch/", "press/", "screenshots/", "google_play/phone"]
    order = sorted(files, key=lambda f: next((i for i, g in enumerate(groups) if f.startswith(g)), 99))
    overview(order, review)
    for rel in files:
        im = Image.open(os.path.join(OUT, rel))
        print("[store_art] %-52s %5d x %-5d %s" % (rel, im.width, im.height, im.mode))
    print("[store_art] done: %d files in %s" % (len(files), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
