#!/usr/bin/env python3
"""Wax & Wane - chalk drawings on the floor of the very first room ("meta" stream, v2.0 round 2).

    python3 tools/art_chalk.py                 writes assets/art/chalk/
    python3 tools/art_chalk.py --review=<dir>  also writes a contact sheet (x4) on a cellar-coloured floor

Somebody chalked the controls on the cellar floor for you. One set per device, swapped live in game:

  chalk_move_<dev>   left of Tallow: how to walk      (touch: left thumb ring, keys: W A S D, pad: left stick)
  chalk_aim_<dev>    right of Tallow: how to fire     (touch: right thumb ring, keys: arrow keys,
                                                       mouse: arrow keys or the mouse, pad: right stick)
  chalk_bomb_<dev>   below: the bomb                  (touch: the bomb button, keys: E / SPACE, pad: RB)
  chalk_keep_<dev>   below: the keepsake              (touch: its button, keys: Q, pad: LB)
  chalk_special_<dev> below: the candle's special move (v2.3; touch: the big round button with a star,
                                                       keys: SHIFT / F, pad: LT)
  chalk_wax_time     above: a candle = a clock ("wax = time")

<dev> is touch / keys / mouse / pad (mouse only has its own `aim`; it shares the rest with keys).

Pixel rules: two flat chalk colours from the 0x72 palette (#d3bfa9 warm strokes, #b6cbcf cool accents),
fully opaque, no anti-aliasing, no gradients. The game draws them at one reduced alpha (a single solid
colour). Long strokes lose a pixel here and there and wobble by one, like chalk on stone; letters
(a 3x5 hand) stay whole so they read.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "art", "chalk")

WARM = (0xD3, 0xBF, 0xA9, 255)
COOL = (0xB6, 0xCB, 0xCF, 255)

FONT = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "H": ["101", "101", "111", "101", "101"], "I": ["111", "010", "010", "010", "111"],
    "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["10001", "11011", "10101", "10001", "10001"], "N": ["1001", "1101", "1011", "1001", "1001"],
    "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "011"], "V": ["101", "101", "101", "101", "010"],
    "W": ["10001", "10001", "10101", "11011", "10001"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "G": ["011", "100", "101", "101", "011"],
    "+": ["000", "010", "111", "010", "000"], "=": ["000", "111", "000", "111", "000"],
    "/": ["001", "001", "010", "100", "100"], " ": ["00", "00", "00", "00", "00"],
    "1": ["010", "110", "010", "010", "111"], "2": ["110", "001", "010", "100", "111"],
}


class Chalk:
    def __init__(self, w, h, seed):
        self.w, self.h, self.seed = w, h, seed
        self.px = {}

    def _rnd(self, x, y, salt=0):
        v = (x * 73856093) ^ (y * 19349663) ^ (self.seed * 83492791) ^ (salt * 2654435761)
        v = (v ^ (v >> 13)) * 1274126177
        return ((v ^ (v >> 16)) & 0xFFFF) / 65536.0

    def dot(self, x, y, c=WARM):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def stroke(self, pts, c=WARM, grain=True):
        """A chalk stroke through `pts` (pixel list): drops ~1 in 10 pixels (never two in a row,
        never the ends) and nudges a few sideways by one."""
        last_skip = True
        for i, (x, y) in enumerate(pts):
            r = self._rnd(x, y)
            if grain and 0 < i < len(pts) - 1 and not last_skip and r < 0.10:
                last_skip = True
                continue
            last_skip = False
            self.dot(x, y, c)

    def line(self, x0, y0, x1, y1, c=WARM, grain=True):
        pts = []
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            pts.append((x0, y0))
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        self.stroke(pts, c, grain and len(pts) > 5)

    def circle(self, cx, cy, r, c=WARM, grain=True, gap=None):
        """Midpoint circle; `gap` = (a0, a1) in degrees leaves the stroke open there (chalk rings
        are rarely closed)."""
        import math
        pts = set()
        x, y, d = r, 0, 1 - r
        while x >= y:
            for px, py in ((x, y), (y, x), (-y, x), (-x, y), (-x, -y), (-y, -x), (y, -x), (x, -y)):
                pts.add((cx + px, cy + py))
            y += 1
            if d < 0:
                d += 2 * y + 1
            else:
                x -= 1
                d += 2 * (y - x) + 1
        ordered = sorted(pts, key=lambda p: math.atan2(p[1] - cy, p[0] - cx))
        if gap:
            a0, a1 = gap
            def ok(p):
                a = math.degrees(math.atan2(p[1] - cy, p[0] - cx)) % 360
                return not (a0 <= a <= a1)
            ordered = [p for p in ordered if ok(p)]
        self.stroke(ordered, c, grain and r > 4)

    def disc(self, cx, cy, r, c=WARM):
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r + r * 0.6:
                    self.dot(cx + x, cy + y, c)

    def rrect(self, x, y, w, h, c=WARM, grain=True):
        """A rounded box (keycaps, bumpers): corners cut by one pixel."""
        self.line(x + 1, y, x + w - 2, y, c, grain)
        self.line(x + 1, y + h - 1, x + w - 2, y + h - 1, c, grain)
        self.line(x, y + 1, x, y + h - 2, c, grain)
        self.line(x + w - 1, y + 1, x + w - 1, y + h - 2, c, grain)

    def text(self, x, y, s, c=WARM):
        for ch in s:
            g = FONT[ch]
            for j, row in enumerate(g):
                for i, b in enumerate(row):
                    if b == "1":
                        self.dot(x + i, y + j, c)
            x += len(g[0]) + 1
        return x

    @staticmethod
    def text_w(s):
        return sum(len(FONT[ch][0]) + 1 for ch in s) - 1

    def text_c(self, cx, y, s, c=WARM):
        self.text(cx - self.text_w(s) // 2, y, s, c)

    def arrow(self, x, y, d, c=COOL, n=3):
        """A small arrowhead pointing in d = (dx, dy), tip at (x, y)."""
        dx, dy = d
        for k in range(n):
            if dx:
                self.dot(x - dx * k, y - k, c)
                self.dot(x - dx * k, y + k, c)
            else:
                self.dot(x - k, y - dy * k, c)
                self.dot(x + k, y - dy * k, c)

    def ember(self, x, y, c=COOL):
        """A little flame (a teardrop leaning right with a warm heart), base centre at (x, y)."""
        rows = ["..X..",
                "..XX.",
                ".X.X.",
                "X...X",
                "X.o.X",
                "X...X",
                ".XXX."]
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == "X":
                    self.dot(x - 2 + i, y - 6 + j, c)
                elif ch == "o":
                    self.dot(x - 2 + i, y - 6 + j, WARM)

    def bomb(self, cx, cy, c=WARM):
        self.circle(cx, cy, 4, c, grain=False)
        self.line(cx + 2, cy - 4, cx + 3, cy - 6, c, grain=False)
        self.dot(cx + 4, cy - 7, COOL)
        self.dot(cx + 5, cy - 8, COOL)
        self.dot(cx + 3, cy - 8, COOL)
        self.dot(cx - 2, cy - 1, c)

    def bell(self, cx, cy, c=WARM):
        """A hand bell, mouth at cy."""
        self.dot(cx, cy - 7, c)
        self.line(cx - 1, cy - 6, cx + 1, cy - 6, c, grain=False)
        self.line(cx - 2, cy - 5, cx - 2, cy - 2, c, grain=False)
        self.line(cx + 2, cy - 5, cx + 2, cy - 2, c, grain=False)
        self.line(cx - 4, cy, cx + 4, cy, c, grain=False)
        self.dot(cx - 3, cy - 1, c)
        self.dot(cx + 3, cy - 1, c)
        self.dot(cx, cy + 1, COOL)

    def star(self, cx, cy, c=WARM, big=False):
        """A spark of light (the special move): four long rays, four short ones, a cool heart."""
        n = 4 if big else 3
        for k in range(1, n + 1):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                self.dot(cx + dx * k, cy + dy * k, c)
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            self.dot(cx + dx, cy + dy, c)
            if big:
                self.dot(cx + dx * 2, cy + dy * 2, c)
        self.dot(cx, cy, COOL)

    def keycap(self, x, y, label, w=None, c=WARM):
        w = w or 11
        self.rrect(x, y, w, 11, c)
        self.line(x + 1, y + 11, x + w - 2, y + 11, c, grain=True)   # the key's front edge
        if label:
            if label in "<>^v":
                cx, cy = x + w // 2, y + 5
                d = {"<": (-1, 0), ">": (1, 0), "^": (0, -1), "v": (0, 1)}[label]
                self.arrow(cx + d[0] * 2, cy + d[1] * 2, d, COOL, 3)
                self.line(cx - d[0] * 2, cy - d[1] * 2, cx + d[0], cy + d[1], COOL, grain=False)
            else:
                self.text_c(x + w // 2, y + 3, label)

    def img(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


# --------------------------------------------------------------------------- the drawings

def thumb_ring(cv, cx, cy, knob, arrows=True):
    cv.circle(cx, cy, 11, WARM, gap=(300, 318))
    kx, ky = knob
    cv.circle(cx + kx, cy + ky, 4, WARM, grain=False)
    cv.dot(cx + kx - 1, cy + ky - 1, WARM)
    if arrows:
        cv.arrow(cx, cy - 16, (0, -1))
        cv.arrow(cx, cy + 16, (0, 1))
        cv.arrow(cx - 16, cy, (-1, 0))
        cv.arrow(cx + 16, cy, (1, 0))


def stick(cv, cx, cy, letter, knob=(0, 0)):
    cv.circle(cx, cy, 10, WARM, gap=(110, 124))
    kx, ky = knob
    cv.circle(cx + kx, cy + ky, 5, WARM, grain=False)
    cv.text_c(cx + kx, cy + ky - 2, letter, COOL)


def move_touch():
    cv = Chalk(38, 46, 11)
    thumb_ring(cv, 18, 18, (-1, -2))
    cv.text_c(19, 40, "MOVE")
    return cv


def aim_touch():
    cv = Chalk(50, 46, 12)
    thumb_ring(cv, 18, 18, (3, -1), arrows=False)
    # a dotted line from the thumb out to an ember: drag to aim, hold to fire
    for k in range(4):
        cv.dot(27 + 3 * k, 16 - k, COOL)
        cv.dot(28 + 3 * k, 16 - k, COOL)
    cv.ember(44, 16)
    cv.text_c(23, 40, "AIM+FIRE")
    return cv


def bomb_touch():
    cv = Chalk(30, 34, 13)
    cv.circle(14, 12, 10, WARM, gap=(200, 214))
    cv.bomb(14, 13)
    cv.text_c(15, 28, "BOMB")
    return cv


def keep_touch():
    cv = Chalk(38, 34, 14)
    cv.circle(18, 12, 10, WARM, gap=(330, 344))
    cv.bell(18, 14)
    cv.text_c(19, 28, "KEEPSAKE")
    return cv


def move_keys():
    cv = Chalk(40, 40, 21)
    cv.keycap(14, 2, "W")
    cv.keycap(2, 14, "A")
    cv.keycap(14, 14, "S")
    cv.keycap(26, 14, "D")
    cv.text_c(20, 33, "MOVE")
    return cv


def aim_keys():
    cv = Chalk(40, 40, 22)
    cv.keycap(14, 2, "^")
    cv.keycap(2, 14, "<")
    cv.keycap(14, 14, "v")
    cv.keycap(26, 14, ">")
    cv.text_c(20, 33, "FIRE")
    return cv


def aim_mouse():
    cv = Chalk(62, 40, 23)
    cv.keycap(14, 2, "^")
    cv.keycap(2, 14, "<")
    cv.keycap(14, 14, "v")
    cv.keycap(26, 14, ">")
    cv.text_c(43, 15, "OR")
    # a mouse: rounded body, the left button filled in
    x, y = 50, 6
    cv.rrect(x, y, 10, 15, WARM)
    cv.line(x + 5, y + 1, x + 5, y + 5, WARM, grain=False)
    cv.line(x + 1, y + 6, x + 8, y + 6, WARM, grain=False)
    for yy in range(y + 2, y + 6):
        for xx in range(x + 2, x + 5):
            cv.dot(xx, yy, COOL)
    cv.line(x + 5, y - 1, x + 6, y - 4, WARM, grain=False)   # the cable
    cv.text_c(31, 33, "FIRE")
    return cv


def icon_word(cv, cx, y, icon, word):
    """A pictogram followed by a word, centred on cx; y = the word's top row."""
    w = 9 + 3 + Chalk.text_w(word)
    x = cx - w // 2
    if icon == "bomb":
        cv.bomb(x + 4, y + 3)
    elif icon == "star":
        cv.star(x + 4, y + 2)
    else:
        cv.bell(x + 4, y + 4)
    cv.text(x + 12, y, word)


def bomb_keys():
    cv = Chalk(52, 34, 24)
    cv.keycap(2, 2, "E")
    cv.text(16, 5, "/")
    cv.keycap(22, 2, "SPACE", w=27)
    icon_word(cv, 26, 24, "bomb", "BOMB")
    return cv


def keep_keys():
    cv = Chalk(46, 34, 25)
    cv.keycap(17, 2, "Q")
    icon_word(cv, 23, 24, "bell", "KEEPSAKE")
    return cv


def special_touch():
    # the biggest of the three right-hand buttons: a ring with a star of light in it
    cv = Chalk(40, 36, 15)
    cv.circle(19, 13, 12, WARM, gap=(40, 54))
    cv.circle(19, 13, 9, COOL, grain=True, gap=(220, 260))
    cv.star(19, 13, WARM, big=True)
    cv.text_c(20, 30, "SPECIAL")
    return cv


def special_keys():
    cv = Chalk(54, 34, 26)
    cv.keycap(2, 2, "SHIFT", w=27)
    cv.text(33, 5, "/")
    cv.keycap(39, 2, "F")
    icon_word(cv, 27, 24, "star", "SPECIAL")
    return cv


def special_pad():
    cv = Chalk(46, 34, 35)
    bumper(cv, 14, 3, "LT")
    icon_word(cv, 23, 24, "star", "SPECIAL")
    return cv


def move_pad():
    cv = Chalk(38, 46, 31)
    stick(cv, 18, 18, "L", (-1, -2))
    cv.arrow(18, 3, (0, -1))
    cv.arrow(18, 33, (0, 1))
    cv.arrow(3, 18, (-1, 0))
    cv.arrow(33, 18, (1, 0))
    cv.text_c(19, 40, "MOVE")
    return cv


def aim_pad():
    cv = Chalk(50, 46, 32)
    stick(cv, 18, 18, "R", (3, -1))
    for k in range(4):
        cv.dot(29 + 3 * k, 16 - k, COOL)
        cv.dot(30 + 3 * k, 16 - k, COOL)
    cv.ember(45, 16)
    cv.text_c(23, 40, "AIM+FIRE")
    return cv


def bumper(cv, x, y, label):
    # the shoulder button seen from above: a rounded tab, flat at the bottom
    cv.line(x + 3, y, x + 15, y, WARM, grain=False)
    cv.dot(x + 2, y + 1, WARM)
    cv.dot(x + 16, y + 1, WARM)
    cv.line(x + 1, y + 2, x + 1, y + 8, WARM, grain=False)
    cv.line(x + 17, y + 2, x + 17, y + 8, WARM, grain=False)
    cv.line(x + 1, y + 9, x + 17, y + 9, WARM, grain=True)
    cv.text_c(x + 9, y + 3, label, COOL)


def bomb_pad():
    cv = Chalk(40, 34, 33)
    bumper(cv, 11, 3, "RB")
    icon_word(cv, 20, 24, "bomb", "BOMB")
    return cv


def keep_pad():
    cv = Chalk(46, 34, 34)
    bumper(cv, 14, 3, "LB")
    icon_word(cv, 23, 24, "bell", "KEEPSAKE")
    return cv


def wax_time():
    """A candle = a clock: wax is time."""
    cv = Chalk(48, 30, 41)
    # Tallow (2.0 look): a chubby gumdrop with a drippy lip, dot eyes, stub arms, in his dish
    x = 11
    cv.ember(x, 6)
    cv.dot(x, 7, WARM)                                  # the wick
    cv.rrect(x - 6, 8, 13, 11, WARM)                    # the body
    cv.line(x - 4, 9, x - 4, 11, WARM, grain=False)     # wax drips under the lip ...
    cv.line(x + 3, 9, x + 3, 10, WARM, grain=False)
    cv.dot(x - 7, 10, WARM)                             # ... and a tear stuck on his side
    cv.dot(x - 7, 11, WARM)
    for ex in (x - 3, x + 2):                           # the eyes
        cv.dot(ex, 13, WARM)
        cv.dot(ex, 14, WARM)
    cv.dot(x - 8, 15, WARM)                             # stub arms
    cv.dot(x + 8, 15, WARM)
    cv.line(x - 9, 20, x + 9, 20, WARM, grain=False)    # the dish
    cv.line(x - 7, 21, x + 7, 21, WARM, grain=False)
    cv.text(x + 12, 13, "=")
    # the clock: 12 at the top, the little hand on two
    cx, cy = 35, 14
    cv.circle(cx, cy, 8, WARM, gap=(222, 232))
    cv.dot(cx, cy - 6, COOL)
    cv.dot(cx + 6, cy, COOL)
    cv.dot(cx, cy + 6, COOL)
    cv.dot(cx - 6, cy, COOL)
    cv.line(cx, cy, cx, cy - 5, WARM, grain=False)     # minutes on twelve
    cv.line(cx, cy, cx + 3, cy - 2, WARM, grain=False)  # hours on two
    cv.text_c(11, 25, "WAX")
    cv.text_c(35, 25, "TIME")
    return cv


DRAW = {
    "chalk_move_touch": move_touch, "chalk_aim_touch": aim_touch, "chalk_bomb_touch": bomb_touch,
    "chalk_keep_touch": keep_touch, "chalk_special_touch": special_touch,
    "chalk_special_keys": special_keys, "chalk_special_pad": special_pad,
    "chalk_move_keys": move_keys, "chalk_aim_keys": aim_keys, "chalk_aim_mouse": aim_mouse,
    "chalk_bomb_keys": bomb_keys, "chalk_keep_keys": keep_keys,
    "chalk_move_pad": move_pad, "chalk_aim_pad": aim_pad, "chalk_bomb_pad": bomb_pad, "chalk_keep_pad": keep_pad,
    "chalk_wax_time": wax_time,
}


def check(name, im):
    ok = {WARM, COOL}
    for p in im.get_flattened_data():
        if p[3] == 0:
            continue
        assert p[3] == 255, "%s: semi-transparent pixel %r" % (name, p)
        assert tuple(p) in ok, "%s: off-palette pixel %r" % (name, p)


def main():
    review = None
    for a in sys.argv[1:]:
        if a.startswith("--review="):
            review = a.split("=", 1)[1]
    os.makedirs(OUT, exist_ok=True)
    out = {}
    for name, fn in DRAW.items():
        im = fn().img()
        check(name, im)
        im.save(os.path.join(OUT, name + ".png"))
        out[name] = im
    print("chalk: wrote %d drawings to %s" % (len(out), OUT))
    if review:
        os.makedirs(review, exist_ok=True)
        # each device's set laid out as in the room, on a cellar floor colour, chalk at 55% (as in game)
        floor = (0x48, 0x3B, 0x3A, 255)
        for dev in ["touch", "keys", "mouse", "pad"]:
            bg = Image.new("RGBA", (240, 144), floor)
            def put(nm, cx, cy):
                im = out[nm]
                lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
                px = im.load()
                lp = lay.load()
                for y in range(im.height):
                    for x in range(im.width):
                        if px[x, y][3]:
                            r, g, b, _ = px[x, y]
                            lp[x, y] = (r, g, b, 140)
                bg.alpha_composite(lay, (cx - im.width // 2, cy - im.height // 2))
            d2 = "keys" if dev == "mouse" else dev
            put("chalk_wax_time", 120, 22)
            put("chalk_move_" + d2, 52, 72)
            put("chalk_aim_" + dev, 188, 72)
            put("chalk_bomb_" + d2, 70, 120)
            put("chalk_keep_" + d2, 122, 120)
            put("chalk_special_" + d2, 174, 120)
            bg.resize((960, 576), Image.NEAREST).save(os.path.join(review, "chalk_%s.png" % dev))
        print("chalk: review sheets in", review)


if __name__ == "__main__":
    main()
