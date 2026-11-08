#!/usr/bin/env python3
"""Wax & Wane: edits the trailer, the vertical shorts and the store loop from the footage that
scripts/trailer.gd staged and Godot's movie writer recorded. tools/make_trailer.sh runs both steps.

  python3 tools/trailer_edit.py --raw build/trailer_raw --out build/videos [--only trailer,short_a]
  python3 tools/trailer_edit.py ... --stills DIR     only save a few stills of each output (fast check)

Picture: gameplay frames are the game's own 384x216 picture. In the landscape trailer the text cards are
drawn onto that picture with the game's Kenney Pixel font (16 / 32 px, the game's palette) before it is
scaled x5 with nearest-neighbour, so text sits on the same pixel grid as the game. The end card scales
the logo x6. The vertical shorts put the room x4, the wax bar and clock x5 and big pixel text around them.
Sound: the game's own sound effects (recorded with each scene, the in-game music muted) over the game's
own CC0 music, ducked under the effects; loudness -16 LUFS (trailer) and -14 LUFS (shorts).
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets/fonts/kenney_pixel.ttf")
LOGO = os.path.join(ROOT, "assets/art/ui/title_logo.png")
MUSIC = os.path.join(ROOT, "assets/audio/music")
SFX = os.path.join(ROOT, "assets/audio/sfx")
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


# ---------------------------------------------------------------- footage

class Footage:
    """One recorded scene: PNG frames, the game's sound and the staged moments (marks.json)."""

    def __init__(self, raw, name):
        self.name = name
        self.dir = os.path.join(raw, name)
        with open(os.path.join(self.dir, "marks.json")) as f:
            self.marks = json.load(f)["marks"]
        self.n = len([f for f in os.listdir(self.dir) if f.startswith("f") and f.endswith(".png")])
        self._audio = None
        self._cache = {}

    def at(self, mark, sec=0.0):
        return int(self.marks[mark]) + int(round(sec * FPS))

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
    return 10.0 ** (x / 20.0)


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
    """Wrapped, centred pixel text scaled by a whole number (for the shorts and the end card)."""
    if isinstance(color, tuple) and isinstance(color[0], tuple):
        colors = color
    else:
        colors = None
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
    """n output frames: footage (optionally sped up or held), or a card drawn at full size."""

    def __init__(self, n, src=None, a=0, speed=1.0, hold=False, gain=1.0, full=None, fade_in=0, fade_out=0):
        self.n, self.src, self.a, self.speed, self.hold = n, src, a, speed, hold
        self.gain, self.full = gain, full
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
    def __init__(self):
        self.segs = []
        self.music = []      # (t0, t1, track, offset, gain_db, fade_in, fade_out)
        self.accents = []    # (t, sfx name, gain_db)

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

    def hold(self, src, a, secs):
        s = Seg(int(round(secs * FPS)), src, a, hold=True)
        self.segs.append(s)
        return s

    def card(self, secs, full, **kw):
        s = Seg(int(round(secs * FPS)), full=full, **kw)
        self.segs.append(s)
        return s


def sec(x):
    return int(round(x * FPS))


# ---------------------------------------------------------------- landscape overlays (drawn at 384x216)

def band(text, size=32, color=CREAM, y=None, sub=None, sub_color=GOLD):
    """One line on a dark band across the picture; the band opens and closes over 4 frames."""
    im = ptext(text, size, color)
    sim = ptext(sub, 16, sub_color) if sub else None
    h = im.height + 8 + (sim.height + 3 if sim else 0)
    yc = y if y is not None else 170 if size <= 16 else 166

    def draw(img, i, n):
        k = min(1.0, (i + 1) / 4.0, (n - i) / 4.0)
        hh = max(2, int(round(h * k)))
        top = yc - hh // 2
        ov = Image.new("RGBA", (GW, GH), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle([0, top, GW, top + hh - 1], fill=NIGHT + (218,))
        if k >= 1.0:
            ov.alpha_composite(im, ((GW - im.width) // 2, top + 4))
            if sim:
                ov.alpha_composite(sim, ((GW - sim.width) // 2, top + 4 + im.height + 3))
        img.paste(Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB"))
    return draw


def add_native(seg, t0, t1, fn):
    i0, i1 = sec(t0), min(seg.n, sec(t1))
    seg.native.append((i0, i1, lambda img, i, _f=fn, _a=i0, _b=i1: _f(img, i - _a, _b - _a)))


def flash(color=CREAM, frames=6):
    def draw(img, i, n):
        k = 1.0 - i / float(frames)
        if k > 0:
            img.paste(Image.blend(img, Image.new("RGB", img.size, color), 0.55 * k))
    return draw


# ---------------------------------------------------------------- shorts layout (1080x1920)

VW, VH = 1080, 1920
ROOM = (57, 22, 327, 214)     # the room (and the guardian's bar under it) in the game picture
ROOM_Y = 588                  # x4 -> 1080x768
BAR = (6, 2, 150, 23)         # the wax bar with its flame marker
CLOCK = (7, 23, 52, 33)       # the clock under it
HUD_Y = 456
HOOK_Y = 176                  # below the apps' top bar
CAP_Y = 1392                  # above the apps' bottom 300 px


def vertical(game):
    c = Image.new("RGB", (VW, VH), NIGHT)
    if game is None:
        return c
    room = game.crop(ROOM).resize(((ROOM[2] - ROOM[0]) * 4, (ROOM[3] - ROOM[1]) * 4), Image.NEAREST)
    c.paste(room, (0, ROOM_Y))
    bar = game.crop(BAR)
    bar = bar.resize((bar.width * 5, bar.height * 5), Image.NEAREST)
    clk = game.crop(CLOCK)
    clk = clk.resize((clk.width * 5, clk.height * 5), Image.NEAREST)
    x0 = (VW - (bar.width + 40 + clk.width)) // 2
    c.paste(bar, (x0, HUD_Y))
    c.paste(clk, (x0 + bar.width + 40, HUD_Y + 34))
    return c


def v_text(text, y, size=16, color=CREAM, scale=6, width=160, cx=VW // 2, pop=True):
    blk = text_block(text, size, color, width, scale)

    def draw(c, i, n):
        if pop and i < 3:   # a quick pop: the block lands one pixel-step low, then settles
            yy = y + (3 - i) * scale
        else:
            yy = y
        c.paste(blk, (cx - blk.width // 2, yy), blk)
    return draw


def add_canvas(seg, t0, t1, fn):
    i0, i1 = sec(t0), min(seg.n, sec(t1))
    seg.canvas.append((i0, i1, lambda c, i, _f=fn, _a=i0, _b=i1: _f(c, i - _a, _b - _a)))


# ---------------------------------------------------------------- end cards

def logo(scale):
    im = Image.open(LOGO).convert("RGBA")
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def end_card_landscape(bg_game):
    """Logo x6 over a dimmed, lit room (the game's own title room), the call to action under it."""
    base = bg_game.resize((GW * 5, GH * 5), Image.NEAREST)
    base = Image.blend(base, Image.new("RGB", base.size, NIGHT), 0.62).convert("RGBA")
    lg = logo(6)
    base.alpha_composite(lg, ((base.width - lg.width) // 2, 250))
    t1 = text_block("WISHLIST ON STEAM", 16, GOLD, 300, 6)
    base.alpha_composite(t1, ((base.width - t1.width) // 2, 600))
    t2 = text_block("Steam  -  itch.io  -  Google Play", 16, CREAM, 380, 4)
    base.alpha_composite(t2, ((base.width - t2.width) // 2, 730))
    t3 = text_block("Coming soon", 16, DIM, 380, 4)
    base.alpha_composite(t3, ((base.width - t3.width) // 2, 820))
    return base.convert("RGB")


def end_card_vertical(bg_game, line):
    c = vertical(bg_game)
    c = Image.blend(c, Image.new("RGB", c.size, NIGHT), 0.55).convert("RGBA")
    lg = logo(4)
    c.alpha_composite(lg, ((VW - lg.width) // 2, 760))
    t = text_block(line, 16, GOLD, 150, 6)
    c.alpha_composite(t, ((VW - t.width) // 2, 1000))
    return c.convert("RGB")


# ---------------------------------------------------------------- render

def render_video(tl, out, layout, crf, preset="medium"):
    """Frames -> H.264 (video only) through a pipe."""
    if layout == "landscape":
        size = (GW * 5, GH * 5)
    else:
        size = (VW, VH)
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % size,
           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", preset, "-crf", str(crf),
           "-pix_fmt", "yuv420p", "-profile:v", "high", "-g", "120", "-movflags", "+faststart", out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for s in tl.segs:
        for i in range(s.n):
            p.stdin.write(frame_of(s, i, layout).tobytes())
    p.stdin.close()
    if p.wait() != 0:
        sys.exit("ffmpeg failed on " + out)


def frame_of(s, i, layout):
    if s.full is not None:
        img = s.full(i) if callable(s.full) else s.full
    else:
        g = s.game(i).copy()
        if layout == "landscape":
            for i0, i1, fn in s.native:
                if i0 <= i < i1:
                    fn(g, i)
            img = g.resize((GW * 5, GH * 5), Image.NEAREST)
        else:
            img = vertical(g)
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


_music = {}


def music_track(name):
    if name not in _music:
        _music[name] = decode(os.path.join(MUSIC, name + ".ogg"))
    return _music[name]


def render_audio(tl, out_wav, lufs, duck_max=9.0, music_db=-5.0):
    n = tl.frames * SPF
    fx = np.concatenate([s.audio() for s in tl.segs]) if tl.segs else np.zeros((n, 2), np.float32)
    fx = fit(fx, n)
    mus = np.zeros((n, 2), np.float32)
    for t0, t1, name, off, gain, fin, fout in tl.music:
        tr = music_track(name)
        i0, i1 = int(t0 * SR), min(n, int(t1 * SR))
        o = int(off * SR)
        piece = tr[o:o + (i1 - i0)]
        while len(piece) < i1 - i0:   # the tracks loop in the game, so they can here too
            piece = np.concatenate([piece, tr[:i1 - i0 - len(piece)]])
        piece = piece.copy() * db(gain + music_db)
        if fin > 0:
            k = min(len(piece), int(fin * SR))
            piece[:k] *= np.linspace(0, 1, k, dtype=np.float32)[:, None]
        if fout > 0:
            k = min(len(piece), int(fout * SR))
            piece[-k:] *= np.linspace(1, 0, k, dtype=np.float32)[:, None]
        mus[i0:i1] += piece
    # duck the music under the game's sound effects (10 ms blocks, fast attack, slow release)
    blk = SR // 100
    nb = n // blk + 1
    m = np.pad(fx.mean(1), (0, nb * blk - n)).reshape(nb, blk)
    env = 20 * np.log10(np.sqrt((m ** 2).mean(1)) + 1e-9)
    want = np.clip((env + 34.0) * 0.55, 0.0, duck_max)
    g = np.zeros(nb)
    cur = 0.0
    for k in range(nb):
        cur = cur + (want[k] - cur) * (0.6 if want[k] > cur else 0.03)
        g[k] = cur
    gain = db(-np.repeat(g, blk)[:n]).astype(np.float32)[:, None]
    mix = fx + mus * gain
    for t, name, gdb in tl.accents:
        a = decode(os.path.join(SFX, name + ".ogg")) * db(gdb)
        i0 = int(t * SR)
        k = min(len(a), n - i0)
        if k > 0:
            mix[i0:i0 + k] += a[:k]
    with tempfile.TemporaryDirectory() as td:
        raw = os.path.join(td, "mix.f32")
        mix.astype(np.float32).tofile(raw)
        inp = ["-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", raw]
        ln = "loudnorm=I=%d:TP=-1.5:LRA=11" % lufs
        r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats"] + inp + ["-af", ln + ":print_format=json",
                           "-f", "null", "-"], capture_output=True, text=True)
        js = json.loads(r.stderr[r.stderr.rindex("{"):r.stderr.rindex("}") + 1])
        ln2 = ln + (":measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true"
                    % (js["input_i"], js["input_tp"], js["input_lra"], js["input_thresh"], js["target_offset"]))
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + inp + ["-af", ln2, "-ar", str(SR), "-c:a", "pcm_s16le",
                       out_wav], check=True)


def mux(video, wav, out, abr="192k"):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, "-i", wav, "-c:v", "copy", "-c:a", "aac",
                    "-b:a", abr, "-shortest", "-movflags", "+faststart", out], check=True)


def build(tl, out, layout, lufs, crf, stills=None):
    if stills is not None:
        save_stills(tl, out, layout, stills)
        return
    with tempfile.TemporaryDirectory() as td:
        v = os.path.join(td, "v.mp4")
        a = os.path.join(td, "a.wav")
        render_audio(tl, a, lufs)
        render_video(tl, v, layout, crf)
        mux(v, a, out)
    report(out)


def save_stills(tl, out, layout, d):
    """A contact sheet: one still every ~1.5 s, with its time, for checking the cut without a player."""
    os.makedirs(d, exist_ok=True)
    picks = []
    t = 0
    for s in tl.segs:
        for i in range(0, s.n, 90):
            picks.append((t + i, s, i))
        t += s.n
    ims = []
    for tt, s, i in picks:
        im = frame_of(s, i, layout)
        im = im.resize((im.width // 4, im.height // 4), Image.NEAREST)
        ImageDraw.Draw(im).text((4, 4), "%.1f" % (tt / FPS), fill=(255, 255, 0))
        ims.append(im)
    cols = 6 if layout == "landscape" else 8
    w, h = ims[0].size
    sheet = Image.new("RGB", (w * cols, h * ((len(ims) + cols - 1) // cols)))
    for k, im in enumerate(ims):
        sheet.paste(im, ((k % cols) * w, (k // cols) * h))
    path = os.path.join(d, os.path.splitext(os.path.basename(out))[0] + "_sheet.png")
    sheet.save(path)
    print("[edit] stills", path, "%.1fs" % (tl.frames / FPS))


def report(path):
    pr = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration,size", "-of", "json", path],
                        capture_output=True, text=True)
    f = json.loads(pr.stdout)["format"]
    print("[edit] %s  %.2f s  %.1f MB" % (path, float(f["duration"]), int(f["size"]) / 1048576.0))


# ---------------------------------------------------------------- the cuts

def trailer(F):
    """The 58-second trailer (docs/marketing/trailer_plan.md section 1)."""
    tl = Timeline()
    hook, title, cellar, floors = F("hook"), F("title"), F("cellar"), F("floors")
    bld, chapel, seance, cards = F("build"), F("chapel"), F("seance"), F("cards")
    boss, clutch, ladder, keeper, dawn = F("boss"), F("clutch"), F("ladder"), F("keeper"), F("dawn")
    # 0:00 the hook: 1:57 AM, a tiny light, the heartbeat; the first quick kills
    s = tl.shot(hook, hook.at("in", 0.2), 2.5)
    add_native(s, 0.1, 2.5, band("YOUR WAX IS YOUR CLOCK"))
    tl.accents.append((0.0, "bell_toll", -3.0))
    # 0:02.5 the match lights the wick and the logo flickers on
    s = tl.shot(title, 14, 3.0)
    # 0:05.5 a Cellar fight at midnight: a hit melts minutes off, Tallow grabs the spilled wax back
    s = tl.shot(cellar, cellar.at("hit1", -1.3), 4.6)
    add_native(s, 1.1, 4.6, band("EVERY HIT MELTS YOU"))
    # 0:10.1 kills buy time back: the Kindling streak, the room clears and its candles catch
    s = tl.shot(hook, hook.at("cleared", -2.0), 3.4)
    add_native(s, 0.2, 3.4, band("EVERY KILL BUYS TIME BACK"))
    # 0:13.5 four floors, one room each
    t0 = tl.t
    for k, n in enumerate([1, 2, 3, 4]):
        s = tl.shot(floors, floors.at("f%d" % n, 0.35), 1.3)
    seg_text_span(tl, t0, tl.t, band("BURN THROUGH THE HOUSE BEFORE 2 AM"))
    # 0:18.7 relics: three pickups held aloft, then the build melts a full room
    t0 = tl.t
    for r in ["r1", "r5", "r7"]:
        if r in bld.marks:
            tl.shot(bld, bld.at(r, -0.05), 0.95)
    seg_text_span(tl, t0, tl.t, band("64 RELICS THAT STACK", y=176))
    s = tl.shot(bld, bld.at("wave", 0.6), 3.4)
    add_native(s, 0.4, 3.4, band("BUILDS THAT SHOULDN'T WORK"))
    # 0:25.9 the Chapel's stained glass, a Seance wave
    tl.shot(chapel, chapel.at("in", 1.6), 2.4)
    s = tl.shot(seance, seance.at("in", 0.9), 2.8)
    add_native(s, 0.3, 2.8, band("33 LODGERS. SECRETS IN THE WALLS.", size=16))
    # 0:31.1 the guardians: three versus cards slam in, then the Hour Fiend's clock hands
    t_boss = tl.t
    for n in [1, 2, 3]:
        tl.shot(cards, cards.at("card%d" % n, 0.05), 1.05)
    s = tl.shot(boss, boss.at("card", 0.05), 1.9)
    s = tl.shot(boss, boss.at("hands", -0.2), 3.6)
    add_native(s, 0.3, 3.6, band("9 GUARDIANS"))
    # 0:40.7 the clutch: 1:58 AM, the guardian on a sliver; the music drops out until the last flame lands
    t_clutch = tl.t
    s = tl.shot(clutch, clutch.at("kill", -4.2), 4.2)
    add_native(s, 0.2, 2.4, band("ONE MINUTE LEFT", size=16, color=RED))
    t_kill = tl.t
    s = tl.shot(clutch, clutch.at("kill"), 2.2)
    add_native(s, 0, 6, flash())
    # 0:47.1 the Belfry falls before one: a ladder of light, the Clock Tower and the Keeper's stopped time
    s = tl.shot(ladder, ladder.at("ladder", 0.2), 2.4)
    add_native(s, 0.2, 2.4, band("FALL THE BELFRY BEFORE ONE...", size=16))
    s = tl.shot(keeper, keeper.at("stop", 0.6), 2.6)
    add_native(s, 0.2, 2.6, band("...AND THE CLOCK TOWER OPENS", size=16))
    # 0:52.1 the end card: logo over the lit title room
    t_end = tl.t
    tl.card(5.9, end_card_landscape(title.frame(title.at("out", -0.1))), fade_in=12)
    tl.accents.append((t_end, "bell_toll", -2.0))
    tl.accents.append((tl.t - 1.2, "tick", -4.0))
    # music: the Belfry theme under the house, the guardian theme for the bosses, silence for the clutch,
    # the Keeper's theme from the killing blow to the end
    tl.music.append((2.5, t_boss + 0.15, "floor_4", 0.0, 0.0, 0.05, 0.3))
    tl.music.append((t_boss, t_clutch, "boss", 0.0, 0.0, 0.1, 0.25))
    tl.music.append((t_kill, tl.t, "final_boss", 0.0, 0.0, 0.02, 2.4))
    return tl


def seg_text_span(tl, t0, t1, fn):
    """Puts one overlay across several cuts (each cut draws its own part of it)."""
    t = 0.0
    for s in tl.segs:
        st, en = t, t + s.n / FPS
        a, b = max(st, t0), min(en, t1)
        if b > a:
            i0, i1 = sec(a - st), sec(b - st)
            g0, g1 = sec(a - t0), sec(t1 - t0)
            s.native.append((i0, i1, lambda img, i, _f=fn, _i0=i0, _g0=g0, _g1=g1: _f(img, _g0 + i - _i0, _g1)))
        t = en


def short_a(F):
    """'The candle is the timer' (trailer_plan.md 2, Short A)."""
    tl = Timeline()
    cellar, hook = F("cellar"), F("hook")
    s = tl.shot(cellar, cellar.at("in"), 2.0)
    add_canvas(s, 0, 2.0, v_text("12:00 AM. A FULL CANDLE.", CAP_Y, color=GOLD, scale=5, width=170))
    span = (cellar.at("out") - cellar.at("in", 2.0)) / FPS
    s = tl.shot(cellar, cellar.at("in", 2.0), span / 2.0, speed=2.0)
    add_canvas(s, 0, span / 2.0, v_text("EVERY HIT MELTS MINUTES OFF  (x2 SPEED)", CAP_Y, color=CREAM, scale=5, width=170))
    s = tl.shot(hook, hook.at("in", 0.0), (hook.at("cleared", 1.6) - hook.at("in")) / FPS)
    add_canvas(s, 0, 1.6, v_text("1:57 AM", CAP_Y, color=RED, scale=6))
    add_canvas(s, 1.6, 99, v_text("KILL FAST AND THE KINDLING POURS TIME BACK", CAP_Y, color=GOLD, scale=5, width=170))
    s = tl.card(2.0, end_card_vertical(hook.frame(hook.at("cleared", 1.6)), "WAX & WANE.\nLINK IN BIO."))
    add_hook(tl, "MY HEALTH BAR IS ALSO THE CLOCK", 0, tl.t - 2.0)
    tl.music.append((0.0, tl.t, "floor_2", 0.0, -2.0, 0.05, 0.6))
    return tl


def short_b(F):
    """'Every fire relic on one candle' (Short B): a counter that climbs, then the room melts."""
    tl = Timeline()
    b = F("build")
    s = tl.shot(b, b.at("in", 0.4), 2.4)
    add_canvas(s, 0, 2.4, v_text("RELIC 0", CAP_Y, color=DIM, scale=6))
    names = {"twin_wick": "TWIN WICK", "ember_heart": "EMBER HEART", "blue_flame": "BLUE FLAME", "bellows": "BELLOWS",
             "will_o_wisp": "WILL-O'-WISP", "hot_drip": "HOT DRIP", "tinderbox": "TINDERBOX"}
    order = ["twin_wick", "ember_heart", "blue_flame", "bellows", "will_o_wisp", "hot_drip", "tinderbox"]
    k = 1
    while "r%d" % k in b.marks:
        nxt = b.at("r%d" % (k + 1)) if "r%d" % (k + 1) in b.marks else b.at("wave")
        secs = min(1.4, (nxt - b.at("r%d" % k)) / FPS)
        s = tl.shot(b, b.at("r%d" % k, -0.05), secs)
        add_canvas(s, 0, secs, v_text("%d: %s" % (k, names.get(order[k - 1], "?")), CAP_Y, color=GOLD, scale=6))
        k += 1
    end = min(b.at("cleared", 0.8), b.at("wave", 7.5))
    s = tl.shot(b, b.at("wave", 0.2), (end - b.at("wave", 0.2)) / FPS)
    add_canvas(s, 0, 99, v_text("ALL %d AT ONCE" % (k - 1), CAP_Y, color=EMBER, scale=6))
    tl.card(2.4, end_card_vertical(b.frame(b.at("cleared", 0.8)), "WHICH RELIC SHOULD I ADD NEXT?"))
    add_hook(tl, "I STACKED EVERY FIRE RELIC ON ONE CANDLE", 0, tl.t - 2.4)
    tl.music.append((0.0, tl.t, "floor_4", 0.0, -2.0, 0.05, 0.6))
    return tl


def short_c(F):
    """'One minute left' (Short C): the clutch in real time, no music, a freeze before the result."""
    tl = Timeline()
    c = F("clutch")
    kill = c.at("kill")
    start = max(c.at("in", 0.2), kill - sec(10.0))
    s = tl.shot(c, start, (kill - sec(0.15) - start) / FPS, gain=1.25)
    add_canvas(s, 0, 3.0, v_text("1:58 AM", CAP_Y, color=RED, scale=6))
    tl.hold(c, kill - sec(0.15), 1.6)
    add_canvas(tl.segs[-1], 0, 1.6, v_text("...", CAP_Y, color=CREAM, scale=6))
    s = tl.shot(c, kill - sec(0.15), 2.8, gain=1.25)
    add_canvas(s, 0.4, 2.8, v_text("SNUFFED AT 1:58", CAP_Y, color=GOLD, scale=6))
    tl.card(2.2, end_card_vertical(c.frame(kill + sec(2.6)), "WOULD YOU HAVE MADE IT?"))
    add_hook(tl, "1:58 AM. THE HOUR FIEND IS STILL STANDING.", 0, tl.t - 2.2)
    return tl


def add_hook(tl, text, t0, t1):
    fn = v_text(text, HOOK_Y, color=CREAM, scale=6, width=160, pop=False)
    t = 0.0
    for s in tl.segs:
        st, en = t, t + s.n / FPS
        a, b = max(st, t0), min(en, t1)
        if b > a:
            i0, i1 = sec(a - st), sec(b - st)
            s.canvas.append((i0, i1, lambda c, i, _f=fn: _f(c, 99, 99)))
        t = en


def loop_clip(F):
    """6-8 s for the store pages: the Hour Fiend's card slams in, then the fight."""
    tl = Timeline()
    b = F("boss")
    tl.shot(b, b.at("card", -0.1), 7.0)
    return tl


def render_loop(tl, out_dir, stills=None):
    frames = [frame_of(s, i, "native") if False else s.game(i) for s in tl.segs for i in range(s.n)]
    if stills is not None:
        return
    with tempfile.TemporaryDirectory() as td:
        for k, im in enumerate(frames[::2]):   # 30 fps
            im.save(os.path.join(td, "%05d.png" % k))
        src = ["-framerate", "30", "-i", os.path.join(td, "%05d.png")]
        webm = os.path.join(out_dir, "loop_boss.webm")
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + src + ["-vf", "scale=768:432:flags=neighbor",
                       "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "36", "-row-mt", "1", "-an", webm], check=True)
        report(webm)
        gif = os.path.join(out_dir, "loop_boss.gif")
        pal = os.path.join(td, "pal.png")
        g = ["-framerate", "30", "-i", os.path.join(td, "%05d.png")]
        vf = "fps=15,scale=384:216:flags=neighbor"
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + g + ["-vf", vf + ",palettegen=max_colors=128:stats_mode=diff", pal],
                       check=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + g + ["-i", pal, "-lavfi",
                       vf + "[x];[x][1:v]paletteuse=dither=none:diff_mode=rectangle", "-loop", "0", gif], check=True)
        report(gif)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(ROOT, "build/trailer_raw"))
    ap.add_argument("--out", default=os.path.join(ROOT, "build/videos"))
    ap.add_argument("--only", default="trailer,short_a,short_b,short_c,loop")
    ap.add_argument("--stills", default=None)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    F = lambda name: footage(args.raw, name)
    only = args.only.split(",")
    if "trailer" in only:
        build(trailer(F), os.path.join(args.out, "trailer_60s.mp4"), "landscape", -16, 18, args.stills)
    if "short_a" in only:
        build(short_a(F), os.path.join(args.out, "short_a_candle_is_the_timer.mp4"), "vertical", -14, 20, args.stills)
    if "short_b" in only:
        build(short_b(F), os.path.join(args.out, "short_b_every_fire_relic.mp4"), "vertical", -14, 20, args.stills)
    if "short_c" in only:
        build(short_c(F), os.path.join(args.out, "short_c_one_minute_left.mp4"), "vertical", -14, 20, args.stills)
    if "loop" in only:
        render_loop(loop_clip(F), args.out, args.stills)


if __name__ == "__main__":
    main()
