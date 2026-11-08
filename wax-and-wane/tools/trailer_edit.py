#!/usr/bin/env python3
"""Wax & Wane: edits the trailer, the three vertical shorts and the store loop from the footage that
scripts/trailer.gd staged and Godot's movie writer recorded. tools/make_trailer.sh runs every step.

  python3 tools/trailer_edit.py --raw build/trailer_raw --out build/videos --voice docs/marketing/voice/ai_narrator
          [--only trailer,short_a,short_b,short_c,loop] [--stills DIR]
  python3 tools/trailer_edit.py --check --out build/videos      lengths, sizes, loudness, frames of the finals

Picture: the game's own 384x216 frames, scaled x5 with nearest-neighbour (1920x1080, every pixel sharp); the
close-up crops a 192x108 window around Tallow and scales it x10. Text cards are drawn in the game's Kenney
Pixel font on the game's own pixel grid, in the game's palette. The vertical shorts put the room x4, the wax
bar and clock x5 and big pixel text inside the TikTok / Shorts / Reels safe zones.
Sound: the narrator (one file per line, see docs/marketing/voice/) over the game's own sound effects (recorded
with each scene) and the game's own CC0 music. The music ducks under the voice and under big hits; the
effects duck a little under the voice. Loudness -16 LUFS (trailer) / -14 LUFS (shorts), peaks under -1.5 dB.
Every video also gets <name>.json: where each narrator line sits, for the check that hears it back.
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.signal import sosfiltfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets/fonts/kenney_pixel.ttf")
MUSIC = os.path.join(ROOT, "assets/audio/music")
SFX = os.path.join(ROOT, "assets/audio/sfx")
SCRIPT = os.path.join(ROOT, "docs/marketing/voice/script.json")
EXTS = (".wav", ".flac", ".m4a", ".mp3", ".ogg", ".opus", ".aac", ".mp4")
FPS = 60
SR = 48000
SPF = SR // FPS               # audio samples per video frame
GW, GH = 384, 216             # the game's own picture
# the game's palette (scripts/ui/ui.gd)
CREAM = (253, 247, 237)
WAX = (226, 182, 148)
GOLD = (250, 203, 62)
EMBER = (238, 142, 46)
RED = (218, 78, 56)
DIM = (170, 141, 122)
INK = (33, 20, 27)
NIGHT = (20, 12, 17)          # the ending cards' background (#140c11)
# mix levels (LUFS of each layer before the final loudness pass)
FX_LUFS = -21.0               # the game's sound effects
MUSIC_LUFS = -19.0            # the music bed where nobody speaks
VO_DUCK_MUSIC = 14.0          # dB the music drops under the narrator
VO_DUCK_FX = 12.0             # dB the effects drop under the narrator
VO_POCKET = 8.0               # dB more, in the speech band only, under the narrator
FINALS = {"trailer": "trailer_60s.mp4", "short_a": "short_a_candle_is_the_timer.mp4",
          "short_b": "short_b_every_fire_relic.mp4", "short_c": "short_c_one_minute_left.mp4"}
LOOP = "loop_fight"


with open(SCRIPT) as _f:
    V_TEXT = [ln["text"] for ln in json.load(_f)["lines"]]


# ---------------------------------------------------------------- footage

class Footage:
    """One recorded scene: PNG frames, the game's sound and the staged moments (marks.json)."""

    def __init__(self, raw, name):
        self.name = name
        self.dir = os.path.join(raw, name)
        if not os.path.exists(os.path.join(self.dir, "marks.json")):
            sys.exit("[edit] no footage for '%s' in %s: run ./tools/make_trailer.sh record %s" % (name, raw, name))
        with open(os.path.join(self.dir, "marks.json")) as f:
            self.marks = json.load(f)["marks"]
        self.n = len([f for f in os.listdir(self.dir) if f.startswith("f") and f.endswith(".png")])
        self._audio = None
        self._cache = {}

    def at(self, mark, sec=0.0):
        return int(self.marks[mark]) + int(round(sec * FPS))

    def spot(self, name):
        return tuple(int(v) for v in self.marks[name])

    def frame(self, i):
        i = max(0, min(self.n - 1, int(i)))
        im = self._cache.get(i)
        if im is None:
            im = Image.open(os.path.join(self.dir, "f%08d.png" % i)).convert("RGB")
            if len(self._cache) > 8:
                self._cache.clear()
            self._cache[i] = im
        return im

    @property
    def audio(self):
        if self._audio is None:
            self._audio = decode(os.path.join(self.dir, "f.wav"))
        return self._audio


_footage = {}


def footage(raw, name):
    if name not in _footage:
        _footage[name] = Footage(raw, name)
    return _footage[name]


# ---------------------------------------------------------------- sound helpers

def decode(path, rate=SR):
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(rate), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).reshape(-1, 2).copy()


def atempo(a, speed):
    filt = []
    s = speed
    while s > 2.0:
        filt.append("atempo=2.0")
        s /= 2.0
    filt.append("atempo=%.4f" % s)
    out = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                          "-af", ",".join(filt), "-f", "f32le", "-"], input=a.astype(np.float32).tobytes(),
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).reshape(-1, 2).copy()


def fit(a, n):
    if len(a) >= n:
        return a[:n].copy()
    return np.concatenate([a, np.zeros((n - len(a), 2), np.float32)])


def edge_fades(a, ms=6):
    k = min(len(a) // 2, int(SR * ms / 1000))
    if k > 0:
        ramp = np.linspace(0.0, 1.0, k, dtype=np.float32)[:, None]
        a[:k] *= ramp
        a[-k:] *= ramp[::-1]
    return a


def db(x):
    return 10.0 ** (np.asarray(x) / 20.0)


def loudness(a):
    """(integrated LUFS, true peak dBTP) by ffmpeg's EBU R128 meter."""
    if len(a) < SR // 2:
        a = fit(a, SR // 2)
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                        "-af", "ebur128=peak=true:framelog=quiet", "-f", "null", "-"],
                       input=a.astype(np.float32).tobytes(), capture_output=True)
    err = r.stderr.decode("utf-8", "replace")
    i = re.findall(r"I:\s+(-?[\d.]+|-inf) LUFS", err)
    p = re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", err)
    lu = float(i[-1]) if i and i[-1] != "-inf" else -70.0
    tp = float(p[-1]) if p and p[-1] != "-inf" else -70.0
    return lu, tp


def level(a, target):
    lu, _ = loudness(a)
    return a * float(db(target - lu)) if lu > -69 else a


def blocks_db(mono, blk):
    nb = len(mono) // blk + 1
    m = np.pad(mono, (0, nb * blk - len(mono))).reshape(nb, blk)
    return 20 * np.log10(np.sqrt((m ** 2).mean(1)) + 1e-9)


def envelope(x, attack, release):
    """One-pole smoothing, separate attack and release coefficients (per block)."""
    g = np.zeros(len(x))
    cur = 0.0
    for k in range(len(x)):
        cur = cur + (x[k] - cur) * (attack if x[k] > cur else release)
        g[k] = cur
    return g


def limit(a, ceiling_db=-1.8):
    """ffmpeg's look-ahead limiter: keeps the peaks of the final mix under the ceiling."""
    lim = 10 ** (ceiling_db / 20.0)
    out = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-af",
                          "alimiter=limit=%.4f:attack=4:release=60:level=false:asc=true" % lim, "-f", "f32le", "-"],
                         input=a.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).reshape(-1, 2).copy()


# ---------------------------------------------------------------- the narrator

class Voice:
    """The narrator's lines (docs/marketing/voice/script.json), one file per line in a folder: the AI voice
    (ai_narrator/) or anyone's own recordings with the same file names (any audio type)."""

    def __init__(self, d):
        self.dir = d
        with open(SCRIPT) as f:
            self.lines = json.load(f)["lines"]
        self._cache = {}

    def text(self, i):
        return self.lines[i]["text"]

    def path(self, i):
        stem = os.path.splitext(self.lines[i]["file"])[0]
        for e in EXTS:
            p = os.path.join(self.dir, stem + e)
            if os.path.exists(p):
                return p
        sys.exit("[edit] narrator line %s is missing in %s" % (stem, self.dir))

    def line(self, i):
        """The line at 48 kHz stereo, silence trimmed, at -16 LUFS (the same level for any voice)."""
        if i not in self._cache:
            a = decode(self.path(i))
            a = trim(a)
            self._cache[i] = level(a, -16.0).astype(np.float32)
        return self._cache[i]

    def parts(self, i):
        """The line cut in two at its longest pause, with the matching halves of its text:
        [(audio, "Four floors."), (audio, "One secret.")]."""
        a1, a2 = split_pause(self.line(i))
        words = re.split(r"(?<=[.!?])\s+", self.text(i))
        k = max(1, len(words) // 2)
        return [(a1, " ".join(words[:k])), (a2, " ".join(words[k:]))]


def trim(a, floor_db=-45.0, head=0.04, tail=0.12):
    blk = SR // 100
    e = blocks_db(a.mean(1), blk)
    on = np.where(e > max(e.max() + floor_db, -70.0))[0]
    if len(on) == 0:
        return a
    s0 = max(0, on[0] * blk - int(head * SR))
    s1 = min(len(a), (on[-1] + 1) * blk + int(tail * SR))
    return edge_fades(a[s0:s1].copy(), 8)


def split_pause(a):
    """Cuts a line at its longest pause *between* words (never in the trailing breath): the pause is looked
    for only between the first and the last loud stretch of speech."""
    blk = SR // 100
    e = blocks_db(a.mean(1), blk)
    loud = np.where(e > e.max() - 20.0)[0]
    lo, hi = int(loud[0]), int(loud[-1])
    quiet = e < e.max() - 30.0
    best, k = None, lo
    while k <= hi:
        if quiet[k]:
            j = k
            while j <= hi and quiet[j]:
                j += 1
            if best is None or j - k > best[1] - best[0]:
                best = (k, j)
            k = j
        else:
            k += 1
    if best is None or best[1] - best[0] < 3:   # no clear pause: the quietest moment of the middle half
        q0, q1 = lo + (hi - lo) // 4, hi - (hi - lo) // 4
        m = q0 + int(np.argmin(e[q0:q1 + 1]))
        best = (m, m + 1)
    c1 = min(best[0] * blk + int(0.08 * SR), best[1] * blk)
    c2 = max(best[1] * blk - int(0.04 * SR), best[0] * blk)
    return edge_fades(a[:c1].copy(), 8), edge_fades(a[c2:].copy(), 8)


# ---------------------------------------------------------------- pixel text

_fonts = {}
_texts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size)
    return _fonts[size]


def ptext(text, size=16, color=CREAM, shadow=INK):
    """Crisp (no anti-aliasing) Kenney Pixel text with a 1 px shadow, cropped to its ink; RGBA."""
    key = (text, size, color, shadow)
    if key in _texts:
        return _texts[key]
    f = font(size)
    l, t, r, b = f.getbbox(text)
    im = Image.new("RGBA", (r - l + 2, b - t + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    if shadow:
        d.text((-l + 1, -t + 1), text, font=f, fill=shadow + (255,))
    d.text((-l, -t), text, font=f, fill=color + (255,))
    _texts[key] = im
    return im


def wrap(text, size, width):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if cur and font(size).getlength(t) > width:
            lines.append(cur)
            cur = wd
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def text_block(text, size, color, width, scale, gap=3):
    """Wrapped, centred pixel text scaled by a whole number (the shorts and the end cards)."""
    colors = color if isinstance(color, tuple) and isinstance(color[0], tuple) else None
    lines = []
    for k, part in enumerate(text.split("\n")):
        for ln in wrap(part, size, width):
            lines.append((ln, colors[k] if colors else color))
    ims = [ptext(ln, size, c) for ln, c in lines]
    lh = max(im.height for im in ims) + gap
    w = max(im.width for im in ims)
    out = Image.new("RGBA", (w, lh * len(ims)), (0, 0, 0, 0))
    for k, im in enumerate(ims):
        out.alpha_composite(im, ((w - im.width) // 2, k * lh))
    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)


# ---------------------------------------------------------------- timeline

class Seg:
    """n output frames: footage (optionally sped up, held, or a pixel-perfect close-up) or a full card."""

    def __init__(self, n, src=None, a=0, speed=1.0, hold=False, gain=1.0, full=None, fade_in=0, fade_out=0,
                 zoom=None, hud=True):
        self.n, self.src, self.a, self.speed, self.hold = n, src, a, speed, hold
        self.gain, self.full, self.zoom, self.hud = gain, full, zoom, hud
        self.fade_in, self.fade_out = fade_in, fade_out
        self.native = []     # (i0, i1, fn(img, i)) drawn on the 384x216 picture (landscape)
        self.canvas = []     # (i0, i1, fn(canvas, i)) drawn on the finished frame (shorts)

    def game(self, i):
        if self.src is None:
            return None
        return self.src.frame(self.a if self.hold else self.a + int(i * self.speed))

    def audio(self):
        n = self.n * SPF
        if self.src is None or self.hold:
            return np.zeros((n, 2), np.float32)
        a0 = self.a * SPF
        a1 = a0 + int(round(self.n * self.speed)) * SPF
        a = self.src.audio[a0:a1]
        if self.speed != 1.0 and len(a) > 0:
            a = atempo(a, self.speed)
        return edge_fades(fit(a, n)) * self.gain


class Timeline:
    def __init__(self, name):
        self.name = name
        self.segs = []
        self.music = []      # (t0, t1, track, offset, gain_db, fade_in, fade_out)
        self.accents = []    # (t, sfx name, gain_db)
        self.vo = []         # (t, audio, text)

    @property
    def frames(self):
        return sum(s.n for s in self.segs)

    @property
    def t(self):
        return self.frames / FPS

    def shot(self, src, a, secs, speed=1.0, gain=1.0, **kw):
        s = Seg(int(round(secs * FPS)), src, a, speed=speed, gain=gain, **kw)
        self.segs.append(s)
        return s

    def hold(self, src, a, secs, **kw):
        s = Seg(int(round(secs * FPS)), src, a, hold=True, **kw)
        self.segs.append(s)
        return s

    def card(self, secs, full, **kw):
        s = Seg(int(round(secs * FPS)), full=full, **kw)
        self.segs.append(s)
        return s

    def say(self, t, audio, text, line):
        """The narrator at time t (`line`: its number in the script, 0-based); returns its length in seconds."""
        self.vo.append((t, audio, text, line))
        return len(audio) / SR


def sec(x):
    return int(round(x * FPS))


def secs(a):
    return len(a) / SR


# ---------------------------------------------------------------- landscape overlays (drawn at 384x216)

def band(text, size=16, color=CREAM, y=None, sub=None, sub_color=GOLD, alpha=218):
    """One line on a dark band across the picture; the band opens and closes over 4 frames."""
    im = ptext(text, size, color)
    sim = ptext(sub, 16, sub_color) if sub else None
    h = im.height + 8 + (sim.height + 3 if sim else 0)
    yc = y if y is not None else 186

    def draw(img, i, n):
        k = min(1.0, (i + 1) / 4.0, (n - i) / 4.0)
        hh = max(2, int(round(h * k)))
        top = yc - hh // 2
        ov = Image.new("RGBA", (GW, GH), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle([0, top, GW, top + hh - 1], fill=NIGHT + (alpha,))
        if k >= 1.0:
            ov.alpha_composite(im, ((GW - im.width) // 2, top + 4))
            if sim:
                ov.alpha_composite(sim, ((GW - sim.width) // 2, top + 4 + im.height + 3))
        img.paste(Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB"))
    return draw


def add_native(seg, t0, t1, fn):
    i0, i1 = sec(t0), min(seg.n, sec(t1))
    seg.native.append((i0, i1, lambda img, i, _f=fn, _a=i0, _b=i1: _f(img, i - _a, _b - _a)))


def span(tl, t0, t1, fn, where="native"):
    """One overlay across several cuts (each cut draws its part of it)."""
    t = 0.0
    for s in tl.segs:
        st, en = t, t + s.n / FPS
        a, b = max(st, t0), min(en, t1)
        if b > a:
            i0, i1 = sec(a - st), sec(b - st)
            g0, g1 = sec(a - t0), sec(t1 - t0)
            getattr(s, where).append((i0, i1, lambda img, i, _f=fn, _i0=i0, _g0=g0, _g1=g1: _f(img, _g0 + i - _i0, _g1)))
        t = en


def flash(color=CREAM, frames=6, strength=0.55):
    def draw(img, i, n):
        k = 1.0 - i / float(frames)
        if k > 0:
            img.paste(Image.blend(img, Image.new("RGB", img.size, color), strength * k))
    return draw


def zoom_crop(g, z):
    """A window 1/f of the picture around (cx, cy), kept inside the picture (scaled x5f later)."""
    cx, cy, f = z
    w, h = GW // f, GH // f
    x0 = min(max(0, cx - w // 2), GW - w)
    y0 = min(max(0, cy - h // 2), GH - h)
    return g.crop((x0, y0, x0 + w, y0 + h))


# ---------------------------------------------------------------- shorts layout (1080x1920)

VW, VH = 1080, 1920
ROOM = (65, 14, 319, 214)     # the room, the banner band over its top and the guardian's bar under it
NOTCH = (65, 14, 148, 21)     # where the wax bar's right end reaches into that crop (painted out)
ROOM_Y = 572                  # x4 -> 1016x800
BAR = (6, 2, 150, 21)         # the wax bar with its flame marker
CLOCK = (7, 23, 52, 33)       # the clock under it
HUD_Y = 446
HOOK_Y = 190                  # below the apps' top bar (TikTok / Shorts / Reels keep the top ~150 px clear)
CAP_Y = 1400                  # above the apps' bottom ~420 px (caption, buttons)


def vertical(game, zoom=None, hud=True):
    c = Image.new("RGB", (VW, VH), NIGHT)
    if game is None:
        return c
    rw, rh = ROOM[2] - ROOM[0], ROOM[3] - ROOM[1]
    if zoom:
        cx, cy, f = zoom
        w, h = rw // f, rh // f
        x0 = min(max(0, cx - w // 2), GW - w)
        y0 = min(max(0, cy - h // 2), GH - h)
        room = game.crop((x0, y0, x0 + w, y0 + h)).resize((w * 4 * f, h * 4 * f), Image.NEAREST)
    else:
        src = game.crop(ROOM)
        if hud:   # the wax bar is shown on its own above the room, so its tip is painted out of this crop
            ImageDraw.Draw(src).rectangle([0, 0, NOTCH[2] - ROOM[0] - 1, NOTCH[3] - ROOM[1] - 1],
                                          fill=game.getpixel((1, 120)))
        room = src.resize((rw * 4, rh * 4), Image.NEAREST)
    c.paste(room, ((VW - room.width) // 2, ROOM_Y))
    if not hud:
        return c
    bar = game.crop(BAR)
    bar = bar.resize((bar.width * 5, bar.height * 5), Image.NEAREST)
    clk = game.crop(CLOCK)
    clk = clk.resize((clk.width * 5, clk.height * 5), Image.NEAREST)
    x0 = (VW - (bar.width + 40 + clk.width)) // 2
    c.paste(bar, (x0, HUD_Y))
    c.paste(clk, (x0 + bar.width + 40, HUD_Y + 34))
    return c


def v_text(text, y, size=16, color=CREAM, scale=6, width=160, cx=VW // 2, pop=True, plate=True):
    blk = text_block(text, size, color, width, scale)
    pad = scale * 3
    pl = None
    if plate:   # a dark plate behind the words, so they read over any picture
        pl = Image.new("RGBA", (blk.width + pad * 2, blk.height + pad * 2 - scale * 2), NIGHT + (200,))

    def draw(c, i, n):
        yy = y + ((3 - i) * scale if pop and i < 3 else 0)   # a quick pop: lands one pixel-step low, settles
        if pl is not None:
            c.paste(pl, (cx - pl.width // 2, yy - pad), pl)
        c.paste(blk, (cx - blk.width // 2, yy), blk)
    return draw


def add_canvas(seg, t0, t1, fn):
    i0, i1 = sec(t0), min(seg.n, sec(t1))
    seg.canvas.append((i0, i1, lambda c, i, _f=fn, _a=i0, _b=i1: _f(c, i - _a, _b - _a)))


def add_hook(tl, text, t0, t1, color=CREAM):
    """The hook line at the top of a short, steady from t0 to t1."""
    fn = v_text(text, HOOK_Y, color=color, scale=6, width=160, pop=False)
    span(tl, t0, t1, lambda c, i, n: fn(c, 99, 99), where="canvas")


# ---------------------------------------------------------------- end cards

def cta(img_native):
    """The call to action band on the game's own title picture (logo, tagline, lit Tallow): drawn at
    384x216, so it is on the same pixel grid as the game."""
    im = img_native.copy()
    band("WISHLIST ON STEAM", 32, GOLD, y=191, sub="Steam  -  Google Play  -  itch.io", sub_color=WAX,
         alpha=235)(im, 99, 999)
    return im


def end_card_vertical(bg_game, line, sub="WISHLIST ON STEAM"):
    c = vertical(bg_game)
    c = Image.blend(c, Image.new("RGB", c.size, NIGHT), 0.72).convert("RGBA")
    lg = Image.open(os.path.join(ROOT, "assets/art/ui/title_logo.png")).convert("RGBA")
    lg = lg.resize((lg.width * 4, lg.height * 4), Image.NEAREST)
    c.alpha_composite(lg, ((VW - lg.width) // 2, 700))
    t = text_block(line, 16, CREAM, 150, 6)
    c.alpha_composite(t, ((VW - t.width) // 2, 960))
    if sub:
        t2 = text_block(sub, 16, GOLD, 170, 5)
        c.alpha_composite(t2, ((VW - t2.width) // 2, 960 + t.height + 50))
    return c.convert("RGB")


# ---------------------------------------------------------------- render

def frame_of(s, i, layout):
    if s.full is not None:
        img = s.full(i) if callable(s.full) else s.full
        if layout == "landscape" and img.size == (GW, GH):
            img = img.resize((GW * 5, GH * 5), Image.NEAREST)
    else:
        g = s.game(i).copy()
        if layout == "landscape":
            for i0, i1, fn in s.native:
                if i0 <= i < i1:
                    fn(g, i)
            if s.zoom:
                g = zoom_crop(g, s.zoom)
                img = g.resize((g.width * 5 * s.zoom[2], g.height * 5 * s.zoom[2]), Image.NEAREST)
            else:
                img = g.resize((GW * 5, GH * 5), Image.NEAREST)
        else:
            img = vertical(g, s.zoom, s.hud)
    if layout != "landscape" and s.canvas:
        img = img.copy()
        for i0, i1, fn in s.canvas:
            if i0 <= i < i1:
                fn(img, i)
    k = 1.0
    if s.fade_in and i < s.fade_in:
        k = i / float(s.fade_in)
    if s.fade_out and i >= s.n - s.fade_out:
        k = min(k, (s.n - 1 - i) / float(s.fade_out))
    if k < 1.0:
        img = Image.blend(Image.new("RGB", img.size, (0, 0, 0)), img, max(0.0, k))
    return img


def render_video(tl, out, layout, crf, preset="medium"):
    """Frames -> H.264 (video only) through a pipe."""
    size = (GW * 5, GH * 5) if layout == "landscape" else (VW, VH)
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % size,
           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", preset, "-crf", str(crf), "-tune", "animation",
           "-pix_fmt", "yuv420p", "-profile:v", "high", "-g", "120", "-threads", "3", "-movflags", "+faststart", out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for s in tl.segs:
        for i in range(s.n):
            im = frame_of(s, i, layout)
            if im.size != size:
                sys.exit("[edit] a frame of %s is %s, not %s" % (tl.name, im.size, size))
            p.stdin.write(im.tobytes())
    p.stdin.close()
    if p.wait() != 0:
        sys.exit("ffmpeg failed on " + out)


_music = {}


def music_track(name):
    if name not in _music:
        _music[name] = decode(os.path.join(MUSIC, name + ".ogg"))
    return _music[name]


def tempo(name):
    """(beat period in s, the first beat's offset): a spectral-flux onset curve, autocorrelated (70-180 BPM)."""
    a = music_track(name).mean(1)
    hop = 480
    n = len(a) // hop
    fr = np.lib.stride_tricks.sliding_window_view(a[:n * hop + 1024], 1024)[::hop][:n] * np.hanning(1024)
    mag = np.abs(np.fft.rfft(fr, axis=1))
    flux = np.maximum(0.0, np.diff(np.log1p(mag * 10), axis=0)).sum(1)
    flux = flux - flux.mean()
    ac = np.correlate(flux, flux, "full")[len(flux) - 1:]
    lo, hi = int(60.0 / 180 * SR / hop), int(60.0 / 70 * SR / hop)
    lag = lo + int(np.argmax(ac[lo:hi]))
    period = lag * hop / SR
    ph = [flux[k::lag].sum() for k in range(lag)]
    return period, int(np.argmax(ph)) * hop / SR


def _speech_band():
    from scipy.signal import butter
    return butter(4, [250.0, 4500.0], btype="band", fs=SR, output="sos")


def render_audio(tl, out_wav, target):
    n = tl.frames * SPF
    fx = fit(np.concatenate([s.audio() for s in tl.segs]) if tl.segs else np.zeros((n, 2), np.float32), n)
    fx = level(fx, FX_LUFS)
    # the narrator, and where it speaks (a 0..1 curve: in a little early, out slowly)
    vo = np.zeros((n, 2), np.float32)
    for t, a, _, _ in tl.vo:
        i0 = int(t * SR)
        k = min(len(a), n - i0)
        if k > 0:
            vo[i0:i0 + k] += a[:k]
    blk = SR // 100
    nb = n // blk + 1
    speak = (blocks_db(vo.mean(1), blk) > -50.0).astype(float)
    speak = np.maximum(speak, np.concatenate([speak[10:], np.zeros(10)]))   # duck 100 ms before the voice
    speak = envelope(speak, 0.35, 0.025)
    # the music bed: each piece levelled, faded, ducked under the voice and under big hits
    mus = np.zeros((n, 2), np.float32)
    for t0, t1, name, off, gain, fin, fout in tl.music:
        tr = music_track(name)
        i0, i1 = int(t0 * SR), min(n, int(t1 * SR))
        o = int(off * SR) % len(tr)
        piece = tr[o:o + (i1 - i0)]
        while len(piece) < i1 - i0:   # the tracks loop in the game, so they can here too
            piece = np.concatenate([piece, tr[:i1 - i0 - len(piece)]])
        piece = level(piece.copy(), MUSIC_LUFS + gain)
        if fin > 0:
            k = min(len(piece), int(fin * SR))
            piece[:k] *= np.linspace(0, 1, k, dtype=np.float32)[:, None]
        if fout > 0:
            k = min(len(piece), int(fout * SR))
            piece[-k:] *= np.linspace(1, 0, k, dtype=np.float32)[:, None]
        mus[i0:i1] += piece
    hit = np.clip((blocks_db(fx.mean(1), blk) + 30.0) * 0.5, 0.0, 6.0)
    hit = envelope(hit, 0.6, 0.03)
    duck_m = np.repeat(-(VO_DUCK_MUSIC * speak + hit), blk)[:n]
    duck_f = np.repeat(-VO_DUCK_FX * speak, blk)[:n]
    bed = fx * db(duck_f).astype(np.float32)[:, None] + mus * db(duck_m).astype(np.float32)[:, None]
    # and a pocket for the words: while the narrator speaks, the bed's speech band (250 Hz - 4.5 kHz) drops
    # a further VO_POCKET dB (a dynamic EQ keyed by the voice), so a hit or a chime never covers a word
    carve = np.repeat(-VO_POCKET * speak, blk)[:n]
    band = sosfiltfilt(_speech_band(), bed, axis=0).astype(np.float32)
    bed = bed - band + band * db(carve).astype(np.float32)[:, None]
    # how far the voice stands over everything else while it speaks (dialogue wants 10 dB or more)
    ratios = []
    for t, a, _, _ in tl.vo:
        i0, i1 = int(t * SR), min(n, int(t * SR) + len(a))
        v = float(np.mean(vo[i0:i1] ** 2))
        b = float(np.mean(bed[i0:i1] ** 2)) + 1e-12
        ratios.append(10 * math.log10(v / b + 1e-12))
    if ratios:
        print("[edit] %s: voice over the bed per line (dB): %s" % (tl.name, " ".join("%.0f" % r for r in ratios)))
    mix = bed + vo
    for t, name, gdb in tl.accents:
        a = level(decode(os.path.join(SFX, name + ".ogg")), FX_LUFS + 2.0) * float(db(gdb))
        i0 = int(t * SR)
        k = min(len(a), n - i0)
        if k > 0:
            mix[i0:i0 + k] += a[:k]
    # loudness: gain to the target, the limiter catches the peaks, then a last trim (3 passes converge)
    for _ in range(3):
        mix = level(mix, target)
        mix = limit(mix)
    lu, tp = loudness(mix)
    mix = mix * float(db(target - lu))
    lu, tp = loudness(mix)
    print("[edit] %s: mix %.1f LUFS, true peak %.1f dB" % (tl.name, lu, tp))
    with tempfile.TemporaryDirectory() as td:
        raw = os.path.join(td, "mix.f32")
        mix.astype(np.float32).tofile(raw)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", raw,
                        "-c:a", "pcm_s16le", out_wav], check=True)


def mux(video, wav, out, abr="192k"):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, "-i", wav, "-c:v", "copy", "-c:a", "aac",
                    "-b:a", abr, "-ar", str(SR), "-shortest", "-movflags", "+faststart", out], check=True)


def build(tl, out, layout, target, crf, stills=None, audio_only=False):
    print("[edit] %s: %.2f s, %d cuts, %d narrator lines" % (tl.name, tl.t, len(tl.segs), len(tl.vo)), flush=True)
    if stills is not None:
        save_stills(tl, out, layout, stills)
        return
    side = {"video": os.path.basename(out), "seconds": round(tl.t, 3),
            "lines": [{"t0": round(t, 3), "t1": round(t + secs(a), 3), "text": txt, "line": k, "script": V_TEXT[k]}
                      for t, a, txt, k in tl.vo]}
    if audio_only:   # the sound alone, fast (for checking the mix): <name>.wav + <name>.json
        wav = os.path.splitext(out)[0] + ".wav"
        render_audio(tl, wav, target)
        with open(os.path.splitext(out)[0] + ".json", "w") as f:
            json.dump(dict(side, video=os.path.basename(wav)), f, indent=2)
        return
    with tempfile.TemporaryDirectory() as td:
        v = os.path.join(td, "v.mp4")
        a = os.path.join(td, "a.wav")
        render_audio(tl, a, target)
        render_video(tl, v, layout, crf)
        mux(v, a, out)
    with open(os.path.splitext(out)[0] + ".json", "w") as f:
        json.dump(side, f, indent=2)
    if tl.vo:
        write_srt(tl, os.path.splitext(out)[0] + ".srt")
    report(out)


def write_srt(tl, path):
    """The narration as subtitles (upload with the video on YouTube: viewers who watch muted can read it)."""
    def ts(x):
        ms = int(round(x * 1000))
        return "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)
    cues = sorted((t, t + secs(a), txt) for t, a, txt, _ in tl.vo if txt)
    with open(path, "w") as f:
        for k, (t0, t1, txt) in enumerate(cues, 1):
            end = min(t1 + 0.25, cues[k][0] - 0.05) if k < len(cues) else t1 + 0.25
            f.write("%d\n%s --> %s\n%s\n\n" % (k, ts(t0), ts(end), txt.replace("...", "\u2026")))


def save_stills(tl, out, layout, d):
    """A contact sheet: one still every ~1 s and one at every cut, with its time, to check the cut fast."""
    os.makedirs(d, exist_ok=True)
    picks, t = [], 0
    for s in tl.segs:
        for i in sorted(set([min(4, s.n - 1)] + list(range(30, s.n, 60)))):
            picks.append((t + i, s, i))
        t += s.n
    ims = []
    for tt, s, i in picks:
        im = frame_of(s, i, layout)
        im = im.resize((im.width // 5, im.height // 5) if layout == "landscape" else (im.width // 6, im.height // 6),
                       Image.NEAREST)
        dr = ImageDraw.Draw(im)
        dr.rectangle([0, 0, 34, 11], fill=(0, 0, 0))
        dr.text((2, 1), "%.1f" % (tt / FPS), fill=(255, 255, 0))
        ims.append(im)
    cols = 6 if layout == "landscape" else 10
    w, h = ims[0].size
    sheet = Image.new("RGB", (w * cols, h * ((len(ims) + cols - 1) // cols)))
    for k, im in enumerate(ims):
        sheet.paste(im, ((k % cols) * w, (k // cols) * h))
    path = os.path.join(d, os.path.splitext(os.path.basename(out))[0] + "_sheet.png")
    sheet.save(path)
    print("[edit] stills", path, "%.1fs" % (tl.frames / FPS))


def probe(path):
    pr = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                         "format=duration,size:stream=codec_name,width,height,r_frame_rate,pix_fmt,sample_rate,bit_rate",
                         "-of", "json", path], capture_output=True, text=True)
    return json.loads(pr.stdout)


def report(path):
    f = probe(path)["format"]
    print("[edit] %s  %.2f s  %.2f MB" % (path, float(f["duration"]), int(f["size"]) / 1048576.0), flush=True)


# ---------------------------------------------------------------- the trailer

class Grid:
    """A music track's beats on the timeline: the track starts so that a beat lands on t0."""

    def __init__(self, t0, period):
        self.t0, self.period = t0, period

    def snap(self, t):
        return self.t0 + round((t - self.t0) / self.period) * self.period


def on_beat(tl, g, src, a, nominal, **kw):
    """A shot about `nominal` seconds long whose cut lands on the nearest beat (never under 0.4 s)."""
    end = g.snap(tl.t + nominal)
    while end - tl.t < 0.4:
        end += g.period
    return tl.shot(src, a, end - tl.t, **kw)


def title_dark(title):
    """The first title frame after the boot's burn-in (the dark room, just before the match strikes)."""
    seen_burn = False
    for f in range(0, min(title.n, 120), 2):
        a = np.asarray(title.frame(f).convert("L"))
        bright = float((a > 180).mean())
        if bright > 0.005:
            seen_burn = True
        elif seen_burn and bright < 0.003:
            return f + 2
    return 22


def trailer(F, V):
    """About 55 s for Steam, YouTube, itch and the Play store (docs/marketing/trailer_plan.md, section 1),
    built around the narrator: each shot under a line stretches to fit the line."""
    tl = Timeline("trailer")
    intro, cellar, hook, floors, bld = F("intro"), F("cellar"), F("hook"), F("floors"), F("build")
    chapel, seance, spec, cards = F("chapel"), F("seance"), F("specials"), F("cards")
    boss, clutch, ladder, keeper, title = F("boss"), F("clutch"), F("ladder"), F("keeper"), F("title")
    tx, ty = title.spot("tallow")

    # 0:00 THE HOOK. Darkness; a match comes to a little candle with a face and the wick catches: the
    # game's own title, as a pixel-perfect close-up (x10).
    v1 = V.line(0)                                      # "This is Tallow. Tallow is a candle."
    d0 = title_dark(title)
    tl.say(1.05, v1, V.text(0), 0)                          # after the strike: the match is the first sound
    tl.shot(title, d0, max(3.0, 1.05 + secs(v1) + 0.25), zoom=(tx + 6, ty - 10, 2))
    # wide, in the game: the clock reads 12:00 AM, then the house wakes up around him
    v2 = V.line(1)                                      # "At midnight, the house wakes up."
    t = tl.t
    lead = max(1.0, secs(v2) - 0.75)                     # "...wakes up" lands as the doors slam
    tl.say(t + 0.1, v2, V.text(1), 1)
    tl.shot(intro, intro.at("wake", -lead), lead + 1.7)
    t_house = tl.t
    # 0:07 THE RULE. A hit melts minutes off the candle (and the clock jumps)
    v3 = V.line(2)                                      # "His wax is his health. His wax is also his clock."
    t = tl.t
    tl.say(t + 0.25, v3, V.text(2), 2)
    s = tl.shot(cellar, cellar.at("hit1", -1.05), max(3.6, secs(v3) + 0.55))
    add_native(s, secs(v3) * 0.55, s.n / FPS, band("YOUR WAX IS YOUR CLOCK"))
    # "Every hit melts him faster." (the second hit, the spill) | "Every win buys him time." (Kindling, lights)
    (v4a, x4a), (v4b, x4b) = V.parts(3)
    t = tl.t
    tl.say(t + 0.1, v4a, x4a, 3)
    tl.shot(cellar, cellar.at("hit2", -0.45), max(2.1, secs(v4a) + 0.4))
    t = tl.t
    tl.say(t + 0.15, v4b, x4b, 3)
    s = tl.shot(hook, hook.at("cleared", -1.55), max(3.0, secs(v4b) + 1.4))
    add_native(s, 0.0, s.n / FPS - 0.1, band("KILL FAST: KINDLING POURS TIME BACK", color=GOLD))
    t_rules_end = tl.t

    # 0:20 THE HOUSE (cut on the Belfry theme's beats). Relics held aloft, a build that melts a full room,
    # the special rooms, a Seance.
    beat4, first4 = tempo("floor_4")
    g = Grid(t_house, beat4)                            # the theme comes in on a beat at t_house
    t0 = tl.t
    for r in ["r1", "r3", "r6"]:
        on_beat(tl, g, bld, bld.at(r, -0.05), 0.86)
    span(tl, t0, tl.t, band("64 RELICS THAT STACK"))
    on_beat(tl, g, bld, bld.at("wave", 0.7), 2.6)
    for t_ in ["mirror", "font", "musicbox"]:
        on_beat(tl, g, spec, spec.at(t_, 0.25), 1.2)
    s = on_beat(tl, g, seance, seance.at("in", 0.8), 1.9)
    add_native(s, 0.1, s.n / FPS, band("SPECIAL ROOMS. SECRETS IN THE WALLS."))
    # "Four floors." over one room of each floor
    (v5a, x5a), (v5b, x5b) = V.parts(4)
    t = tl.t
    tl.say(t + 0.1, v5a, x5a, 4)
    for n in [1, 2, 3, 4]:
        on_beat(tl, g, floors, floors.at("f%d" % n, 0.6), 0.86)
    on_beat(tl, g, chapel, chapel.at("in", 1.4), 1.3)
    # 0:36 THE GUARDIANS (the Hour Fiend's theme, on its beats). Versus cards slam in, then the clock hands.
    t_boss = tl.t
    beatb, firstb = tempo("final_boss")
    g = Grid(t_boss, beatb)
    for n in [1, 2, 3]:
        on_beat(tl, g, cards, cards.at("card%d" % n, 0.05), 0.86)
    on_beat(tl, g, boss, boss.at("card", 0.05), 1.0)
    s = on_beat(tl, g, boss, boss.at("hands", -0.1), 2.4)
    add_native(s, 0.1, s.n / FPS, band("9 GUARDIANS"))
    # "One secret." The Belfry falls before one: a ladder of light, the Clock Tower, the Keeper stops time.
    t = tl.t
    tl.say(t + 0.25, v5b, x5b, 4)
    tl.shot(ladder, ladder.at("ladder", 0.1), max(1.6, secs(v5b) + 0.45))
    tl.shot(ladder, ladder.at("tower", 0.75), 1.5)
    s = tl.shot(keeper, keeper.at("stop", 0.5), 1.8)
    add_native(s, 0.1, 1.8, band("THE CLOCK TOWER", color=WAX))
    # 0:45 THE CLUTCH. 1:58 AM, the guardian on a sliver; the music drops out until the last flame lands.
    v6 = V.line(5)                                      # "Be done by two... or burn out trying."
    t_clutch = tl.t
    pre = max(3.4, secs(v6) + 0.5)
    tl.say(t_clutch + pre - secs(v6) - 0.15, v6, V.text(5), 5)   # "...trying" ends just before the kill
    s = tl.shot(clutch, clutch.at("kill", -pre), pre)
    t_kill = tl.t
    s = tl.shot(clutch, clutch.at("kill"), 1.6)
    add_native(s, 0, 0.1, flash())
    # 0:50 THE END. The game's own title: the match strikes, the wick catches, the logo flickers on.
    v7 = V.line(6)                                      # "Wax and Wane. Light the wick."
    t_end = tl.t
    lit = title_dark(title) + sec(0.75)                 # the room is lit; the logo flickers on next
    logo_in = max(0.0, (title.at("menu") - lit) / FPS - 0.9)
    tl.say(t_end + logo_in + 0.25, v7, V.text(6), 6)       # "Wax and Wane." as the logo comes on
    tl.shot(title, lit, (title.at("out", -0.05) - lit) / FPS)
    s = tl.card(max(3.0, t_end + logo_in + 0.25 + secs(v7) + 2.0 - tl.t), cta(title.frame(title.at("out", -0.05))))
    s.fade_out = 18

    # music: the title theme's quiet opening under the cold open; the Belfry's driven theme from the rule
    # to the guardians; the Hour Fiend's theme for the guardians and the secret; silence for the clutch;
    # the credits theme from the killing blow to the end card.
    tl.music.append((0.0, t_house + 0.3, "title", 0.0, -3.0, 1.2, 0.4))
    tl.music.append((t_house, t_boss + 0.2, "floor_4", first4, 0.0, 0.02, 0.25))
    tl.music.append((t_boss, t_clutch + 0.25, "final_boss", firstb, 1.0, 0.02, 0.3))
    tl.music.append((t_kill, tl.t, "ending", 0.0, -1.0, 0.02, 1.6))
    tl.accents.append((t_boss, "bell_toll", -2.0))
    tl.accents.append((t_end + 0.3, "bell_toll", -4.0))
    return tl


# ---------------------------------------------------------------- the shorts

def short_a(F, V):
    """'The candle is the timer' (trailer_plan.md 2, Short A), narrated: the close-up, two hits, a Kindling."""
    tl = Timeline("short_a")
    title, cellar, hook = F("title"), F("cellar"), F("hook")
    tx, ty = title.spot("tallow")
    v1 = V.line(0)
    tl.say(0.6, v1, V.text(0), 0)
    s = tl.shot(title, title_dark(title), max(2.8, 0.6 + secs(v1) + 0.3), zoom=(tx + 6, ty - 10, 2), hud=False)
    add_canvas(s, 0.9, 9, v_text("THIS IS TALLOW.", CAP_Y, color=GOLD, scale=6, width=170))
    v3 = V.line(2)
    t = tl.t
    tl.say(t + 0.15, v3, V.text(2), 2)
    s = tl.shot(cellar, cellar.at("hit1", -1.0), max(3.4, secs(v3) + 0.4))
    add_canvas(s, 0.9, 9, v_text("A HIT MELTS MINUTES OFF THE CLOCK", CAP_Y, color=CREAM, scale=5, width=170))
    (v4a, x4a), (v4b, x4b) = V.parts(3)
    t = tl.t
    tl.say(t + 0.1, v4a, x4a, 3)
    s = tl.shot(cellar, cellar.at("hit2", -0.45), max(2.2, secs(v4a) + 0.4))
    add_canvas(s, 0, 9, v_text("GRAB THE SPILLED WAX BACK", CAP_Y, color=WAX, scale=5, width=170))
    t = tl.t
    tl.say(t + 0.1, v4b, x4b, 3)
    s = tl.shot(hook, hook.at("in", 0.2), (hook.at("cleared", 1.4) - hook.at("in", 0.2)) / FPS)
    add_canvas(s, 0, 1.6, v_text("1:56 AM", CAP_Y, color=RED, scale=7))
    add_canvas(s, 1.6, 99, v_text("KILL FAST: KINDLING POURS TIME BACK", CAP_Y, color=GOLD, scale=5, width=170))
    t_end = tl.t
    tl.card(2.4, end_card_vertical(hook.frame(hook.at("cleared", 1.4)), "YOUR HEALTH BAR IS A CANDLE."))
    add_hook(tl, "MY HEALTH BAR\nIS ALSO THE CLOCK", 0, t_end)
    tl.music.append((0.0, tl.t, "floor_2", 0.0, 0.0, 0.3, 0.6))
    return tl


def short_b(F, V):
    """'Every fire relic on one candle' (Short B): a counter that climbs, then the room melts. Music only."""
    tl = Timeline("short_b")
    b = F("build")
    beat, first = tempo("floor_4")
    g = Grid(0.0, beat)                                  # cut on the Belfry theme's beats
    s = on_beat(tl, g, b, b.at("in", 0.4), 2.2)
    add_canvas(s, 0, s.n / FPS, v_text("RELIC 0", CAP_Y, color=DIM, scale=7))
    names = {"twin_wick": "TWIN WICK", "ember_heart": "EMBER HEART", "blue_flame": "BLUE FLAME", "bellows": "BELLOWS",
             "will_o_wisp": "WILL-O'-WISP", "hot_drip": "HOT DRIP", "tinderbox": "TINDERBOX"}
    order = ["twin_wick", "ember_heart", "blue_flame", "bellows", "will_o_wisp", "hot_drip", "tinderbox"]
    k = 1
    while "r%d" % k in b.marks:
        nxt = b.at("r%d" % (k + 1)) if "r%d" % (k + 1) in b.marks else b.at("wave")
        dur = min(1.29, (nxt - b.at("r%d" % k)) / FPS)
        s = on_beat(tl, g, b, b.at("r%d" % k, -0.05), dur)
        add_canvas(s, 0, s.n / FPS, v_text("%d: %s" % (k, names.get(order[k - 1], "?")), CAP_Y, color=GOLD, scale=6))
        k += 1
    end = min(b.at("cleared", 0.6), b.at("wave", 6.5))
    s = tl.shot(b, b.at("wave", 0.2), (end - b.at("wave", 0.2)) / FPS)
    add_canvas(s, 0, 99, v_text("ALL %d AT ONCE" % (k - 1), CAP_Y, color=EMBER, scale=7))
    t_end = tl.t
    tl.card(2.6, end_card_vertical(b.frame(b.at("cleared", 0.6)), "WHICH RELIC SHOULD I ADD NEXT?"))
    add_hook(tl, "I STACKED EVERY FIRE\nRELIC ON ONE CANDLE", 0, t_end)
    tl.music.append((0.0, tl.t, "floor_4", first, 1.0, 0.02, 0.6))
    return tl


def short_c(F, V):
    """'One minute left' (Short C): the clutch in real time, narrated, a freeze before the result."""
    tl = Timeline("short_c")
    c = F("clutch")
    kill = c.at("kill")
    start = max(c.at("in", 0.2), kill - sec(9.0))
    s = tl.shot(c, start, (kill - sec(0.12) - start) / FPS, gain=1.2)
    add_canvas(s, 0, 2.6, v_text("1:58 AM", CAP_Y, color=RED, scale=7))
    add_canvas(s, 2.6, 99, v_text("NO MUSIC. JUST THE HEARTBEAT.", CAP_Y, color=DIM, scale=5, width=170))
    v6 = V.line(5)
    tl.say(max(0.2, tl.t - secs(v6) - 0.1), v6, V.text(5), 5)
    # the fight is live, so the guardian falls a little sooner or later each recording: the freeze and
    # the victory stretch so the short always runs about 16 s
    pre = tl.t
    hold, post = 1.3, 2.6
    post_max = (c.at("out") - kill) / FPS - 0.15
    short = 16.0 - (pre + hold + post + 2.4)
    if short > 0:
        add = min(short, max(0.0, post_max - post))
        post += add
        hold += min(short - add, 0.8)
    tl.hold(c, kill - sec(0.12), hold)
    add_canvas(tl.segs[-1], 0, hold, v_text("...", CAP_Y, color=CREAM, scale=7))
    t_kill = tl.t
    s = tl.shot(c, kill - sec(0.1), post, gain=1.2)
    add_canvas(s, 0.35, post, v_text("SNUFFED IT AT 1:58 AM.", CAP_Y, color=GOLD, scale=6, width=170))
    t_end = tl.t
    tl.card(max(2.4, 15.6 - tl.t), end_card_vertical(c.frame(kill + sec(2.4)), "WOULD YOU HAVE MADE IT?"))
    add_hook(tl, "1:58 AM. THE HOUR FIEND\nIS STILL STANDING.", 0, t_end)
    tl.music.append((t_kill, tl.t, "ending", 0.0, -2.0, 0.02, 1.0))
    return tl


# ---------------------------------------------------------------- the store loop (6-8 s, under 3 MB)

def loop_frames(F):
    """7 s of the fire build melting a full room; the last 0.5 s dissolves into the first, so it loops."""
    b = F("build")
    a, n, x = b.at("wave", 0.6), sec(7.0), sec(0.5)
    frames = [b.frame(a + i) for i in range(n)]
    out = []
    for i in range(n - x):
        if i < x:   # the tail laid over the head
            out.append(Image.blend(frames[n - x + i], frames[i], (i + 1) / float(x + 1)))
        else:
            out.append(frames[i])
    return out


def render_loop(F, out_dir, stills=None):
    frames = loop_frames(F)
    if stills is not None:
        return
    with tempfile.TemporaryDirectory() as td:
        for k, im in enumerate(frames[::2]):   # 30 fps
            im.save(os.path.join(td, "%05d.png" % k))
        src = ["-framerate", "30", "-i", os.path.join(td, "%05d.png")]
        webm = os.path.join(out_dir, LOOP + ".webm")
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + src + ["-vf", "scale=768:432:flags=neighbor",
                       "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "34", "-row-mt", "1", "-pix_fmt", "yuv420p",
                        "-an", webm], check=True)
        report(webm)
        gif = os.path.join(out_dir, LOOP + ".gif")
        pal = os.path.join(td, "pal.png")
        vf = "fps=15,scale=384:216:flags=neighbor"
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + src + ["-vf", vf + ",palettegen=max_colors=96:stats_mode=diff",
                       pal], check=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + src + ["-i", pal, "-lavfi",
                       vf + "[x];[x][1:v]paletteuse=dither=none:diff_mode=rectangle", "-loop", "0", gif], check=True)
        report(gif)


# ---------------------------------------------------------------- the check

def check(out_dir):
    """Every final: length, size, picture, sound, loudness, and a sheet of frames to look at."""
    d = os.path.join(out_dir, "check")
    os.makedirs(d, exist_ok=True)
    rows = []
    want = {"trailer": (45, 60, (1920, 1080), -16), "short_a": (15, 25, (1080, 1920), -14),
            "short_b": (15, 25, (1080, 1920), -14), "short_c": (15, 25, (1080, 1920), -14)}
    for key, name in list(FINALS.items()) + [("loop", LOOP + ".webm"), ("loop", LOOP + ".gif")]:
        p = os.path.join(out_dir, name)
        if not os.path.exists(p):
            rows.append({"file": name, "ok": False, "problems": ["missing"]})
            continue
        pr = probe(p)
        f = pr["format"]
        v = next(s for s in pr["streams"] if s.get("width"))
        au = [s for s in pr["streams"] if s.get("sample_rate")]
        dur, size = float(f["duration"]), int(f["size"])
        row = {"file": name, "seconds": round(dur, 2), "mb": round(size / 1048576.0, 2),
               "picture": "%dx%d %s %s" % (v["width"], v["height"], v["codec_name"], v.get("r_frame_rate", "")),
               "pix_fmt": v.get("pix_fmt", ""), "problems": []}
        if au:
            a = decode(p)
            row["lufs"], row["true_peak"] = loudness(a)
            row["audio"] = "%s %s Hz" % (au[0]["codec_name"], au[0]["sample_rate"])
        if key in want:
            lo, hi, wh, lu = want[key]
            if not lo <= dur <= hi:
                row["problems"].append("length %.1f s (want %d-%d)" % (dur, lo, hi))
            if (v["width"], v["height"]) != wh:
                row["problems"].append("size %dx%d" % (v["width"], v["height"]))
            if abs(row.get("lufs", -99) - lu) > 1.0:
                row["problems"].append("loudness %.1f LUFS (want %d)" % (row.get("lufs", -99), lu))
            if row.get("true_peak", 0) > -1.0:
                row["problems"].append("true peak %.1f dB" % row["true_peak"])
            if v.get("pix_fmt") != "yuv420p" or v["codec_name"] != "h264":
                row["problems"].append("not H.264 yuv420p")
            if "60/1" not in v.get("r_frame_rate", ""):
                row["problems"].append("not 60 fps")
        else:
            if not 6.0 <= dur <= 8.0:
                row["problems"].append("length %.1f s (want 6-8)" % dur)
            if size > 3 * 1024 * 1024:
                row["problems"].append("%.1f MB (want under 3)" % (size / 1048576.0))
        sheet = os.path.join(d, os.path.splitext(name)[0] + "_" + name.rsplit(".", 1)[1] + ".png")
        n = 12 if key != "loop" else 6
        step = max(dur / n, 0.1)
        w = 320 if v["width"] >= v["height"] else 180
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", p, "-vf",
                        "fps=1/%.3f,scale=%d:-1:flags=neighbor,tile=%dx%d" % (step, w, 6, (n + 5) // 6),
                        "-frames:v", "1", sheet], check=True)
        row["sheet"] = sheet
        row["ok"] = not row["problems"]
        rows.append(row)
    with open(os.path.join(d, "report.json"), "w") as f:
        json.dump(rows, f, indent=2)
    print("| File | Length | Size | Picture | Loudness | Peak | OK |")
    print("|---|---:|---:|---|---:|---:|---|")
    for r in rows:
        print("| %s | %s s | %s MB | %s | %s | %s | %s |" % (
            r["file"], r.get("seconds", "-"), r.get("mb", "-"), r.get("picture", "-"),
            ("%.1f LUFS" % r["lufs"]) if "lufs" in r else "-", ("%.1f dB" % r["true_peak"]) if "true_peak" in r else "-",
            "yes" if r["ok"] else "NO: " + "; ".join(r["problems"])))
    return all(r["ok"] for r in rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(ROOT, "build/trailer_raw"))
    ap.add_argument("--out", default=os.path.join(ROOT, "build/videos"))
    ap.add_argument("--voice", default=os.path.join(ROOT, "docs/marketing/voice/ai_narrator"))
    ap.add_argument("--only", default="trailer,short_a,short_b,short_c,loop")
    ap.add_argument("--stills", default=None)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--audio-only", action="store_true", help="only the sound mix (+ its .json), for a quick check")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    if args.check:
        sys.exit(0 if check(args.out) else 1)
    F = lambda name: footage(args.raw, name)
    V = Voice(args.voice)
    only = args.only.split(",")
    if "trailer" in only:
        build(trailer(F, V), os.path.join(args.out, FINALS["trailer"]), "landscape", -16, 18, args.stills,
              args.audio_only)
    for k, fn in [("short_a", short_a), ("short_b", short_b), ("short_c", short_c)]:
        if k in only:
            tl = fn(F, V)
            if tl.t < 15.5:   # live fights vary a little between recordings: the end card holds longer
                tl.segs[-1].n += sec(15.5 - tl.t)
            build(tl, os.path.join(args.out, FINALS[k]), "vertical", -14, 19, args.stills, args.audio_only)
    if "loop" in only:
        render_loop(F, args.out, args.stills)


if __name__ == "__main__":
    main()
