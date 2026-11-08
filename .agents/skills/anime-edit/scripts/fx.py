"""Frame effects for anime_edit: a moving camera with motion blur, transitions (zoom, spin, whip, glitch,
flash), speed-ramp curves, glow, film grain and pop-in kinetic text.

Frames are RGB uint8 numpy arrays. OpenCV does the heavy lifting (warps, blurs, resizes).
"""
from __future__ import annotations

import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"
DISPLAY_FONT = FONT_DIR / "Anton-Regular.ttf"


# ----------------------------------------------------------------------------- easing

def clamp01(x: float) -> float:
    return 0.0 if x < 0 else 1.0 if x > 1 else x


def smooth(x: float) -> float:
    x = clamp01(x)
    return x * x * (3 - 2 * x)


def ease_out(x: float) -> float:
    return 1 - (1 - clamp01(x)) ** 3


def ease_in(x: float) -> float:
    return clamp01(x) ** 3


def ease_out_back(x: float, s: float = 2.2) -> float:
    x = clamp01(x) - 1
    return 1 + (s + 1) * x ** 3 + s * x ** 2


# ----------------------------------------------------------------------------- speed ramps

def speed_at(profile: tuple, p: float) -> float:
    """Playback speed (1 = real time) at position p (0..1) in a shot."""
    kind = profile[0]
    if kind == "const":
        return profile[1]
    if kind in ("decel", "accel"):  # a -> b, eased
        return profile[1] + (profile[2] - profile[1]) * smooth(p)
    if kind == "velocity":  # slow on the beats at both ends, fast in between
        lo, hi = profile[1], profile[2]
        return lo + (hi - lo) * math.sin(math.pi * clamp01(p)) ** 2
    raise ValueError(f"unknown speed profile {kind}")


def remap_times(profile: tuple, n: int, fps: float, scale: float = 1.0) -> np.ndarray:
    """Source time (s, from the shot window start) at each output frame boundary k = 0..n."""
    sub = 8
    grid = np.arange(n * sub + 1) / (n * sub)
    v = np.array([speed_at(profile, p) for p in grid]) * scale
    dt = (n / fps) / (n * sub)
    s = np.concatenate([[0.0], np.cumsum((v[:-1] + v[1:]) / 2 * dt)])
    return s[::sub]


# ----------------------------------------------------------------------------- camera

def cover_zoom(rot_deg: float, tx: float, ty: float, base_wh: tuple, out_wh: tuple) -> float:
    """Smallest zoom at which the rotated/shifted output window stays inside the base frame."""
    bw, bh = base_wh
    ow, oh = out_wh
    th = math.radians(rot_deg)
    c, s = abs(math.cos(th)), abs(math.sin(th))
    hx, hy = c * ow / 2 + s * oh / 2, s * ow / 2 + c * oh / 2
    cs, sn = math.cos(th), math.sin(th)
    offx, offy = abs(cs * tx - sn * ty), abs(sn * tx + cs * ty)
    return max((hx + offx) / (bw / 2), (hy + offy) / (bh / 2))


def cam_matrix(cam: dict, base_wh: tuple, out_wh: tuple) -> np.ndarray:
    """2x3 matrix mapping output pixels to base-frame pixels (use with WARP_INVERSE_MAP)."""
    bw, bh = base_wh
    ow, oh = out_wh
    z = max(cam["z"], 1e-3)
    th = math.radians(cam["rot"])
    c, s = math.cos(th), math.sin(th)
    ox, oy = ow / 2 + cam["tx"], oh / 2 + cam["ty"]
    return np.array([[c / z, -s / z, bw / 2 - (c * ox - s * oy) / z],
                     [s / z, c / z, bh / 2 - (s * ox + c * oy) / z]], np.float32)


def _motion_px(a: dict, b: dict, out_wh: tuple) -> float:
    diag = math.hypot(*out_wh) / 2
    return (abs(a["z"] - b["z"]) / max(a["z"], 1e-3) * diag + abs(math.radians(a["rot"] - b["rot"])) * diag
            + math.hypot(a["tx"] - b["tx"], a["ty"] - b["ty"]))


def shoot(base: np.ndarray, cam_fn, t: float, fps: float, out_wh: tuple, shutter: float = 0.7) -> np.ndarray:
    """Render the base frame through the camera at time t, with motion blur when the camera moves fast."""
    bh, bw = base.shape[:2]
    ow, oh = out_wh
    half = shutter / fps / 2
    a, b = cam_fn(t - half), cam_fn(t + half)
    moved = _motion_px(a, b, out_wh)
    n = 1 if moved < 2.5 else min(9, 2 + int(moved / 6))
    times = [t] if n == 1 else list(np.linspace(t - half, t + half, n))
    acc = None
    for tt in times:
        cam = cam_fn(tt)
        if abs(cam["z"] - 1) < 1e-4 and abs(cam["rot"]) < 1e-3 and abs(cam["tx"]) < 0.5 and abs(cam["ty"]) < 0.5:
            x0, y0 = (bw - ow) // 2, (bh - oh) // 2
            img = base[y0:y0 + oh, x0:x0 + ow]
        else:
            img = cv2.warpAffine(base, cam_matrix(cam, (bw, bh), out_wh), (ow, oh),
                                 flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REFLECT101)
        if n == 1:
            return np.ascontiguousarray(img)
        acc = img.astype(np.float32) if acc is None else acc + img
    return (acc / n).astype(np.uint8)


def blend_frames(frames: list[np.ndarray]) -> np.ndarray:
    """Average several source frames (frame blending: smooth fast-forward)."""
    if len(frames) == 1:
        return frames[0]
    acc = frames[0].astype(np.float32)
    for f in frames[1:]:
        acc += f
    return (acc / len(frames)).astype(np.uint8)


# ----------------------------------------------------------------------------- looks

def rgb_split(img: np.ndarray, k: int) -> np.ndarray:
    if k < 1:
        return img
    out = img.copy()
    out[..., 0] = np.roll(img[..., 0], k, axis=1)
    out[..., 2] = np.roll(img[..., 2], -k, axis=1)
    return out


def glitch(img: np.ndarray, g: float, seed: int) -> np.ndarray:
    """Digital glitch: RGB split, sliced bands shifted sideways, a few inverted/white blocks, scanlines."""
    if g <= 0.02:
        return img
    rng = np.random.default_rng(seed)
    h, w = img.shape[:2]
    out = rgb_split(img, int(48 * g))
    for _ in range(int(4 + 14 * g)):
        y0 = int(rng.integers(0, h - 8))
        bh = int(rng.integers(6, int(16 + 140 * g)))
        shift = int(rng.choice([-1, 1]) * rng.integers(10, int(30 + 380 * g)))
        out[y0:y0 + bh] = np.roll(out[y0:y0 + bh], shift, axis=1)
    if g > 0.45:
        for _ in range(int(1 + 4 * g)):
            bw_, bh_ = int(rng.integers(w // 12, w // 3)), int(rng.integers(h // 40, h // 10))
            x0, y0 = int(rng.integers(0, w - bw_)), int(rng.integers(0, h - bh_))
            r = rng.random()
            blk = out[y0:y0 + bh_, x0:x0 + bw_]
            out[y0:y0 + bh_, x0:x0 + bw_] = 255 - blk if r < 0.4 else (255 if r < 0.7 else blk[..., ::-1])
    out[::3] = (out[::3].astype(np.float32) * (1 - 0.3 * g)).astype(np.uint8)
    return out


def flash_dark(img: np.ndarray, flash: float, dark: float) -> np.ndarray:
    if flash <= 0.01 and dark <= 0.01:
        return img
    f = img.astype(np.float32)
    if flash > 0.01:
        f += flash * (255.0 - f)
    if dark > 0.01:
        f *= 1.0 - dark
    return np.clip(f, 0, 255).astype(np.uint8)


def bloom(img: np.ndarray, strength: float, threshold: int = 150) -> np.ndarray:
    """Glow around bright areas (light, energy, eyes)."""
    if strength <= 0.01:
        return img
    h, w = img.shape[:2]
    small = cv2.resize(img, (w // 4, h // 4), interpolation=cv2.INTER_AREA)
    bright = cv2.subtract(small, np.full_like(small, threshold))
    bright = cv2.GaussianBlur(bright, (0, 0), sigmaX=max(2.0, w / 160))
    up = cv2.resize(bright, (w, h), interpolation=cv2.INTER_LINEAR)
    return cv2.addWeighted(img, 1.0, up, 2.2 * strength, 0)


class Grain:
    """Pre-made film-grain frames (adds a fine, moving texture that hides compression banding)."""

    def __init__(self, w: int, h: int, sigma: float = 5.0, count: int = 4, seed: int = 3):
        rng = np.random.default_rng(seed)
        self.pos, self.neg = [], []
        for _ in range(count):
            n = rng.normal(0, sigma, (h, w)).astype(np.float32)
            n3 = np.repeat(n[..., None], 3, axis=2)
            self.pos.append(np.clip(n3, 0, 255).astype(np.uint8))
            self.neg.append(np.clip(-n3, 0, 255).astype(np.uint8))
        self.i = 0

    def apply(self, img: np.ndarray) -> np.ndarray:
        k = self.i % len(self.pos)
        self.i += 1
        return cv2.subtract(cv2.add(img, self.pos[k]), self.neg[k])


# ----------------------------------------------------------------------------- text

def load_font(size: int) -> ImageFont.FreeTypeFont:
    if DISPLAY_FONT.is_file():
        return ImageFont.truetype(str(DISPLAY_FONT), size)
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if Path(p).is_file():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size=size)


def text_sprite(text: str, size: int, fill=(255, 255, 255), glow=(90, 200, 255), stroke_ratio: float = 0.06):
    """RGBA sprite of a word: white letters, dark outline, coloured glow. Returns (rgb float32, alpha float32)."""
    font = load_font(size)
    stroke = max(2, int(size * stroke_ratio))
    l, t, r, b = font.getbbox(text, stroke_width=stroke)
    pad = int(size * 0.45)
    w, h = r - l + 2 * pad, b - t + 2 * pad
    pos = (pad - l, pad - t)
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).text(pos, text, font=font, fill=glow + (255,), stroke_width=stroke * 3, stroke_fill=glow + (255,))
    halo = halo.filter(ImageFilter.GaussianBlur(size * 0.16))
    ink = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(ink).text(pos, text, font=font, fill=fill + (255,), stroke_width=stroke, stroke_fill=(10, 10, 20, 255))
    arr = np.asarray(Image.alpha_composite(halo, ink)).astype(np.float32)
    return arr[..., :3], arr[..., 3:] / 255.0


def paste(frame: np.ndarray, sprite, cx: float, cy: float, scale: float = 1.0, alpha: float = 1.0) -> np.ndarray:
    """Alpha-blend a text sprite centred at (cx, cy), scaled."""
    rgb, a = sprite
    if alpha <= 0.01 or scale <= 0.01:
        return frame
    if abs(scale - 1) > 1e-3:
        rgb = cv2.resize(rgb, None, fx=scale, fy=scale, interpolation=cv2.INTER_LINEAR)
        a = cv2.resize(a, None, fx=scale, fy=scale, interpolation=cv2.INTER_LINEAR)
        if a.ndim == 2:
            a = a[..., None]
    h, w = rgb.shape[:2]
    H, W = frame.shape[:2]
    x0, y0 = int(round(cx - w / 2)), int(round(cy - h / 2))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0 = max(0, x0), max(0, y0)
    dx1, dy1 = min(W, x0 + w), min(H, y0 + h)
    if dx1 <= dx0 or dy1 <= dy0:
        return frame
    src = rgb[sy0:sy0 + dy1 - dy0, sx0:sx0 + dx1 - dx0]
    al = a[sy0:sy0 + dy1 - dy0, sx0:sx0 + dx1 - dx0] * alpha
    region = frame[dy0:dy1, dx0:dx1].astype(np.float32)
    frame[dy0:dy1, dx0:dx1] = (region * (1 - al) + src * al).astype(np.uint8)
    return frame


class KineticText:
    """Lyrics that pop in word by word on their timings, and big captions that slam in.

    lyrics: [{"start": s, "end": s, "words": [(t, "WORD"), ...]}]   (times in edit seconds)
    """

    def __init__(self, out_wh: tuple, accent=(90, 200, 255)):
        self.ow, self.oh = out_wh
        self.accent = accent
        self.cache: dict = {}
        self.vertical = self.oh > self.ow

    def sprite(self, text: str, size: int, hot: bool = False):
        key = (text, size, hot)
        if key not in self.cache:
            fill = self.accent if hot else (255, 255, 255)
            self.cache[key] = text_sprite(text, size, fill=fill, glow=self.accent)
        return self.cache[key]

    def layout(self, words: list[str], size: int):
        """Wrap words into centred lines; returns [(word, x_centre, line_index)], line_height."""
        font = load_font(size)
        gap = size * 0.28
        widths = [font.getlength(w) for w in words]
        lines, cur, cur_w = [], [], 0.0
        for w, wd in zip(words, widths):
            if cur and cur_w + gap + wd > self.ow * 0.86:
                lines.append(cur)
                cur, cur_w = [], 0.0
            cur.append((w, wd))
            cur_w += (gap if len(cur) > 1 else 0) + wd
        if cur:
            lines.append(cur)
        placed = []
        for li, line in enumerate(lines):
            total = sum(wd for _, wd in line) + gap * (len(line) - 1)
            x = (self.ow - total) / 2
            for w, wd in line:
                placed.append((w, x + wd / 2, li))
                x += wd + gap
        return placed, size * 1.12, len(lines)

    def draw_lyrics(self, frame: np.ndarray, lyrics: list[dict], t: float, beat_kick: float = 0.0) -> np.ndarray:
        size = int(self.ow * (0.115 if self.vertical else 0.07))
        for ph in lyrics:
            if not (ph["start"] - 0.05 <= t <= ph["end"] + 0.12):
                continue
            words = [w for _, w in ph["words"]]
            placed, lh, nlines = self.layout(words, size)
            cy0 = self.oh * (0.60 if self.vertical else 0.66) - (nlines - 1) * lh / 2
            out_e = clamp01((t - ph["end"]) / 0.12)  # phrase exit
            for i, ((wt, _), (w, x, li)) in enumerate(zip(ph["words"], placed)):
                e = (t - wt) / 0.16
                if e < 0:
                    continue
                pop = 1.7 - 0.7 * ease_out_back(e)
                alpha = clamp01(e * 3) * (1 - out_e)
                kick = 1 + 0.06 * beat_kick
                hot = i == len(placed) - 1  # last word of the phrase in the accent colour
                frame = paste(frame, self.sprite(w, size, hot), x, cy0 + li * lh, pop * kick * (1 + 0.3 * out_e), alpha)
        return frame

    def draw_caption(self, frame: np.ndarray, text: str, local_t: float, dur: float, y_frac: float = 0.42) -> np.ndarray:
        size = int(self.ow * (0.17 if self.vertical else 0.11))
        font = load_font(size)
        while font.getlength(text) > self.ow * 0.9 and size > 24:
            size = int(size * 0.9)
            font = load_font(size)
        e = local_t / 0.18
        scale = 1.45 - 0.45 * ease_out_back(e)
        alpha = clamp01(e * 4) * (1 - clamp01((local_t - (dur - 0.08)) / 0.08))
        return paste(frame, self.sprite(text, size, hot=False), self.ow / 2, self.oh * y_frac, scale, alpha)
