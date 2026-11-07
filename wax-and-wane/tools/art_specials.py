#!/usr/bin/env python3
"""Wax & Wane - special rooms art ("specials" stream, v2.0 round 2).

    python3 tools/art_specials.py                 writes assets/art/specials/
    python3 tools/art_specials.py --review=<dir>  also writes contact sheets (x8) and in-room previews

Everything is original pixel art drawn as character grids in the 0x72 DungeonTileset II palette (CC0),
matched to the existing doors and props: 1 px #222222 outline, light from the top-left, flat shading,
a solid contact shadow under things that stand on the floor, no anti-aliasing, no semi-transparent pixels.

  door_<dir>_<style>_<state>   doors of the five special rooms, built with the same frame / leaf / corridor
                               rules as tools/art_rooms.py (so they line up with every room wall), with
                               their own stone and an ornament on the arch:
                                 seance  slate-blue stone, a brass hand bell
                                 mirror  a dark door: black stone, pewter iron, a cracked silver glass
                                 musicbox rose lacquer with gold trim, a winding key
                                 study   green stone, an open book
                                 font    pale wax with drips running down the frame, a wax drop
  bell_f0..f3, bell_done       the Seance bell on its frame (rest, swing left, rest, swing right)
  mirror_f0..f3, mirror_veiled, mirror_broken
                               the Cracked Mirror (a glint crossing the glass), covered by a cloth, shattered
  musicbox_f0..f3, musicbox_broken
                               the Music Box (the crank turns, the dancer spins), and with its spring sprung
  lectern_f0..f1               the Study lectern (a page lifting)
  font_0..font_6, font_spent   the Wax Font: six pips on its rim light up as you feed it, wax rises
  offer_map, offer_tonics, offer_veil
                               16x16 icons for the Study / Mirror choices that are not relics
  map_<kind>                   minimap marks (5x4, the "?" 3x5)
  mini_<sprite>_<anim>_fN      mini-bosses: every frame of a lodger redrawn at twice the size (Scale2x
                               edges, then the outline is thinned back to 1 px so it matches the rest)
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_rooms as AR   # noqa: E402  (grid helpers, door builders, palette check)

ROOT = AR.ROOT
OUT = os.path.join(ROOT, "assets", "art", "specials")
MON = os.path.join(ROOT, "assets", "art", "monsters")
F72 = os.path.join(ROOT, "assets", "0x72", "frames")

# --------------------------------------------------------------------------- palette
P = {
    "A": "#222222",  # outline
    "x": "#21141b",  # contact shadow
    "k": "#111111",  # deep dark
    # wood
    "o": "#ee8e2e", "P": "#c56025", "H": "#8f4029", "I": "#62232f", "J": "#38262d", "h": "#fccba3",
    # brass / gold / fire
    "F": "#ffcc68", "Y": "#facb3e", "Z": "#ffad3b", "R": "#da4e38", "r": "#9f294e", "p": "#62232f",
    # iron / silver / glass
    "n": "#b6cbcf", "m": "#7b8994", "i": "#545454", "j": "#3f3f3f", "l": "#333333",
    "C": "#cae6f5", "c": "#72d6ce", "b": "#5698cc", "d": "#417089", "e": "#38607c", "f": "#243f4c",
    "D": "#314152", "q": "#2a2a3a",
    # stone ramp
    "1": "#2b2929", "2": "#483b3a", "3": "#775c55", "4": "#aa8d7a", "5": "#d3bfa9",
    # wax / paper / bone
    "W": "#fdf7ed", "s": "#d3bfa9", "t": "#aa8d7a", "V": "#e2b694", "U": "#d8a57d", "T": "#b58057",
    "u": "#8a503e",
    # greens
    "G": "#3d734f", "g": "#4ba747", "L": "#97da3f",
    # purples / pinks
    "v": "#5956bd", "w": "#5f2d56", "z": "#dc4a7b", "y": "#f78697", "K": "#38262d",
}


def G(text):
    return AR.G(text)


def img(rows, pal=P):
    try:
        return AR.grid(rows, pal)
    except (KeyError, AssertionError) as e:
        raise SystemExit("bad grid starting %r...: %s" % (rows[:3], e))


def paste(dst, src, x, y):
    dst.alpha_composite(src, (x, y))


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def shear_rows(rows, shifts):
    """Shift each row of a grid sideways by shifts[y] pixels (a swing / sway pose)."""
    w = len(rows[0])
    out = []
    for r, s in zip(rows, shifts):
        if s > 0:
            r = "." * s + r[:w - s]
        elif s < 0:
            r = r[-s:] + "." * (-s)
        out.append(r)
    return out


# --------------------------------------------------------------------------- doors
# The frame, leaf and corridor come from art_rooms (same rows, same joints); each style only brings its
# own stone, plank and iron colours and an ornament on top of the arch.
STYLES = {
    #            A outline   B stone     C lip       D shade     E dark      G seams     H plank     I plank sh  J iron      K iron hi
    "seance":   {"A": "#222222", "B": "#417089", "C": "#b6cbcf", "D": "#314152", "E": "#2a2a3a",
                 "G": "#111111", "H": "#5f2d56", "I": "#38262d", "J": "#facb3e", "K": "#fdf7ed"},
    "mirror":   {"A": "#111111", "B": "#333333", "C": "#545454", "D": "#2b2929", "E": "#21141b",
                 "G": "#111111", "H": "#2b2929", "I": "#21141b", "J": "#7b8994", "K": "#b6cbcf"},
    "musicbox": {"A": "#222222", "B": "#dc4a7b", "C": "#fccba3", "D": "#9f294e", "E": "#62232f",
                 "G": "#111111", "H": "#8f4029", "I": "#62232f", "J": "#facb3e", "K": "#fdf7ed"},
    "study":    {"A": "#222222", "B": "#3d734f", "C": "#4ba747", "D": "#314152", "E": "#2a2a3a",
                 "G": "#111111", "H": "#8f4029", "I": "#62232f", "J": "#facb3e", "K": "#fdf7ed"},
    "font":     {"A": "#222222", "B": "#e2b694", "C": "#fdf7ed", "D": "#b58057", "E": "#8a503e",
                 "G": "#111111", "H": "#8f4029", "I": "#62232f", "J": "#aa8d7a", "K": "#fdf7ed"},
}
CORRIDORS = {
    "seance":   {"f": {"#222222": "#21141b", "#483b3a": "#2a2a3a", "#775c55": "#314152"},
                 "F": {"#222222": "#111111", "#483b3a": "#1f1833", "#775c55": "#2a2a3a"}},
    "mirror":   {"f": {"#222222": "#111111", "#483b3a": "#1d1218", "#775c55": "#21141b"},
                 "F": {"#222222": "#111111", "#483b3a": "#111111", "#775c55": "#140c11"}},
    "musicbox": {"f": {"#222222": "#222222", "#483b3a": "#38262d", "#775c55": "#62232f"},
                 "F": {"#222222": "#111111", "#483b3a": "#23151d", "#775c55": "#38262d"}},
    "study":    {"f": {"#222222": "#222222", "#483b3a": "#302c2b", "#775c55": "#3e5442"},
                 "F": {"#222222": "#111111", "#483b3a": "#2b2929", "#775c55": "#302c2b"}},
    "font":     {"f": {"#222222": "#222222", "#483b3a": "#3b3332", "#775c55": "#8a503e"},
                 "F": {"#222222": "#111111", "#483b3a": "#2b2929", "#775c55": "#3b3332"}},
}
SIDE_STUD = {"seance": "#facb3e", "mirror": "#b6cbcf", "musicbox": "#facb3e", "study": "#fdf7ed",
             "font": "#fdf7ed"}

# ornaments on top of the arch (pasted over the keystone) and smaller ones on the bottom door's posts
ORN_TOP = {
    "seance": (11, 0, G("""
        ...AAAA...
        ...AYYA...
        ..AFYYoA..
        ..AFYYoA..
        .AFYYYoPA.
        .AFYYooPA.
        AFYYYooPPA
        AAAAAAAAAA
        ....AHA...
        ....AAA...
    """)),
    "mirror": (12, 0, G("""
        ..AAAA..
        .AnnnmA.
        AnCfeDmA
        AnfWeDmA
        AmeDWDiA
        AmDDfWiA
        .AmiiiA.
        ..AAAA..
    """)),
    "musicbox": (10, 1, G("""
        .AAA...AAA..
        AFYoA.AFYoA.
        AYAoAAAYAoA.
        AYoPYYYYYoPA
        .AAAAAoPAAA.
        ......AYA...
        .....AYoPA..
        ......AAA...
    """)),
    "study": (10, 1, G("""
        .AAAAA.AAAAA.
        AWWWWsAsWWWWA
        AWsssWAWsssWA
        AWWWWsAsWWWWA
        AWssWsAsWssWA
        AWWWWsAsWWWWA
        AAAAAAAAAAAAA
        .AIIIIAIIIIA.
        ..AAAAAAAAA..
    """)),
    "font": (12, 0, G("""
        ...AA...
        ..AWVA..
        .AWWVUA.
        AWWWVUTA
        AWWVVUTA
        AVVUUTTA
        .AUUTTA.
        ..AAAA..
    """)),
}
ORN_SMALL = {
    "seance": G("""
        ..AAA..
        .AFYoA.
        .AYYoA.
        AFYooPA
        AAAAAAA
        ..AHA..
    """),
    "mirror": G("""
        .AAAA.
        AnCemA
        AnWDmA
        AmDWiA
        .AAAA.
    """),
    "musicbox": G("""
        AAA.AAA
        AYoAAYA
        AAAoPAA
        ..AYoA.
        ..AAAA.
    """),
    "study": G("""
        AAAAAAA
        AWWAsWA
        AWsAWsA
        AWWAsWA
        AAAAAAA
    """),
    "font": G("""
        ..AA..
        .AWVA.
        AWWVUA
        AVVUTA
        .AAAA.
    """),
}
# wax drips running down the Font door's frame: (x, y, length) on the top door (mirrored on the right)
FONT_DRIPS_TOP = [(1, 9, 4), (2, 15, 3), (1, 21, 5), (3, 4, 2)]


def _with_style(style):
    AR.DOOR_PAL[style] = STYLES[style]
    AR.CORRIDOR[style] = CORRIDORS[style]
    AR.SIDE_STUD[style] = SIDE_STUD[style]


def _drip(im, x, y, n, top="#fdf7ed", body="#e2b694", tip="#d8a57d"):
    px = im.load()
    for k in range(n):
        if y + k >= im.height or px[x, y + k][3] == 0:
            break
        px[x, y + k] = AR.rgb(top if k == 0 else (tip if k == n - 1 else body)) + (255,)


def door_set(style):
    _with_style(style)
    out = {}
    for state in ("open", "closed"):
        top = AR.door_top(state, style)
        ox, oy, orn = ORN_TOP[style]
        paste(top, img(orn), ox, oy)
        bot = AR.door_bottom(state, style)
        sm = img(ORN_SMALL[style])
        paste(bot, sm, 0, 4 if sm.height < 6 else 3)
        paste(bot, sm, 32 - sm.width, 4 if sm.height < 6 else 3)
        left = AR.door_side(state, style, "left")
        if style == "font":
            for (x, y, n) in FONT_DRIPS_TOP:
                _drip(top, x, y, n)
                _drip(top, 31 - x, y + 2, n)
            _drip(bot, 2, 8, 4)
            _drip(bot, 29, 9, 3)
            _drip(left, 12, 3, 4)
            _drip(left, 14, 20, 3)
        out["door_top_%s_%s" % (style, state)] = top
        out["door_bottom_%s_%s" % (style, state)] = bot
        out["door_left_%s_%s" % (style, state)] = left
        out["door_right_%s_%s" % (style, state)] = flip(left)
    return out


# --------------------------------------------------------------------------- a tiny canvas
class Cv:
    """Character canvas: draw fills with palette chars, then outline() adds the 1 px dark edge
    (8-neighbour, like the 0x72 creatures) around everything opaque."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["."] * w for _ in range(h)]

    def px(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "."

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, ch)

    def hline(self, x0, x1, y, ch):
        self.rect(x0, y, x1, y, ch)

    def vline(self, x, y0, y1, ch):
        self.rect(x, y0, x, y1, ch)

    def grid(self, rows, x, y, keep="."):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch != keep:
                    self.px(x + i, y + j, ch)

    def outline(self, ch="A", skip="x"):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] != ".":
                    continue
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        c = self.get(x + dx, y + dy)
                        if c != "." and c not in skip and c != ch:
                            add.append((x, y))
                            break
                    else:
                        continue
                    break
        for x, y in add:
            self.g[y][x] = ch
        return self

    def rows(self):
        return ["".join(r) for r in self.g]

    def image(self, pal=P):
        return img(self.rows(), pal)


def shadow(cv, x0, x1, y):
    """Solid contact shadow under something standing on the floor."""
    for x in range(x0, x1 + 1):
        if cv.get(x, y) == ".":
            cv.px(x, y, "x")


# --------------------------------------------------------------------------- the Seance bell
BELL = G("""
    ....AAAAA....
    ....AFYoA....
    ...AAFYoAA...
    ..AFFYYYooA..
    ..AFYYYYooA..
    ..AFYYYYooA..
    ..AYYYYYooA..
    .AFYYYYYoooA.
    .AFYYYYYooPA.
    AFYYYYYYoooPA
    AYYYYYYooooPA
    AoooooooPPPHA
    AAAAAAAAAAAAA
    .....AYoA....
    .....AAAA....
""")


def bell_stand(swing=0, done=False):
    W_, H_ = 23, 31
    cv = Cv(W_, H_)
    # the frame: two dark posts, a crossbeam, splayed feet
    for x0 in (1, 18):
        cv.rect(x0, 7, x0 + 3, 26, "A")
        cv.vline(x0 + 1, 8, 26, "P")
        cv.vline(x0 + 2, 8, 26, "H")
        cv.rect(x0 - 1, 26, x0 + 4, 29, "A")
        cv.hline(x0, x0 + 3, 27, "P")
        cv.hline(x0, x0 + 3, 28, "I")
    cv.rect(0, 3, 22, 7, "A")
    cv.hline(1, 21, 4, "P")
    cv.hline(1, 21, 5, "H")
    cv.hline(1, 21, 6, "I")
    for x in (2, 6, 16, 20):              # pegs on the beam
        cv.px(x, 5, "J")
    # a stub of candle on each post, the wax run down the beam
    for cx in (2, 19):
        cv.rect(cx - 1, 0, cx + 2, 3, "A")
        cv.vline(cx, 1, 2, "W")
        cv.vline(cx + 1, 1, 2, "V")
        cv.px(cx, 0, "A")
        cv.px(cx + 1, 0, ".")
        cv.px(cx - 1, 0, ".")
        cv.px(cx + 2, 0, ".")
        cv.px(cx, 4, "W")
        cv.px(cx + 1, 4, "V")
    # rope from the beam to the bell
    cv.px(11, 8, "s")
    cv.px(11, 9, "t")
    cv.px(10, 8, "A")
    cv.px(12, 8, "A")
    cv.px(10, 9, "A")
    cv.px(12, 9, "A")
    # feet shadows
    shadow(cv, 0, 6, 30)
    shadow(cv, 16, 22, 30)
    bell = BELL
    if done:   # rung out: the brass goes dull and the clapper is tied off
        bell = [r.translate(str.maketrans({"F": "o", "Y": "P", "o": "H", "P": "I", "H": "I"})) for r in BELL]
    if swing:
        n = len(bell)
        shifts = [int(round(swing * i / (n - 1))) for i in range(n)]
        pad = ["..." + r + "..." for r in bell]
        bell = shear_rows(pad, shifts)
        cv.grid(bell, 5 - 3, 10)
    else:
        cv.grid(bell, 5, 10)
    return cv.image()


# --------------------------------------------------------------------------- the Cracked Mirror
def mirror(state="f0"):
    """A standing pier glass on a stone step.  f0..f3: a glint crosses the glass."""
    W_, H_ = 24, 36
    cv = Cv(W_, H_)
    # stone step
    cv.rect(1, 29, 22, 34, "A")
    cv.hline(2, 21, 30, "5")
    cv.rect(2, 31, 21, 32, "4")
    cv.hline(2, 21, 33, "3")
    cv.px(8, 32, "3")
    cv.px(15, 31, "3")
    shadow(cv, 1, 22, 35)
    # the pewter frame: an arch
    arch = G("""
        ......AAAAAAAAAA......
        ....AAnnnnnnnnmmAA....
        ...AnnAAAAAAAAAAmmA...
        ..AnnA..........AmiA..
        .AnmA............AmiA.
        .AnmA............AmiA.
    """)
    cv.grid(arch, 1, 0)
    for y in range(6, 29):
        cv.grid(["AnmA"], 2, y)
        cv.grid(["AmiA"], 18, y)
    cv.rect(2, 28, 21, 29, "A")
    cv.hline(3, 20, 28, "m")
    cv.px(3, 28, "n")
    # feet of the frame
    cv.grid(["AnmA"], 2, 28)
    cv.grid(["AmiA"], 18, 28)
    # glass
    glass = []
    for y in range(3, 28):
        for x in range(4, 20):
            if cv.get(x, y) == "." and not (y == 3 and (x < 7 or x > 16)) and not (y == 4 and (x < 5 or x > 18)):
                glass.append((x, y))
    for (x, y) in glass:
        cv.px(x, y, "f" if (x + y) % 7 else "e")
    for (x, y) in glass:   # dark lower-right, cold light upper-left
        if x + y > 37:
            cv.px(x, y, "q")
        elif x + y < 17:
            cv.px(x, y, "e")
    # reflections: two soft vertical streaks
    for y in range(6, 25):
        if cv.get(6, y) in "feq":
            cv.px(6, y, "d")
    for y in range(8, 18):
        if cv.get(8, y) in "feq":
            cv.px(8, y, "e")
    if state == "veiled":
        cloth = []
        for y in range(1, 30):
            for x in range(1, 23):
                if cv.get(x, y) in "fedqDnmiA" and y < 29:
                    cloth.append((x, y))
        for (x, y) in cloth:
            cv.px(x, y, "w")
        for y in range(2, 30):
            for x in (6, 11, 16):
                if cv.get(x + (y // 9) % 2, y) == "w":
                    cv.px(x + (y // 9) % 2, y, "K")
            if cv.get(4, y) == "w" and y > 4:
                cv.px(4, y, "z")
        cv.px(9, 1, "z")
        cv.px(10, 1, "z")
        # the hem hangs over the step
        for x in range(2, 22):
            if x % 4 != 1:
                cv.px(x, 29, "w" if x % 4 else "K")
                cv.px(x, 30, "A")
        cv2 = Cv(W_, H_)
        cv2.g = [r[:] for r in cv.g]
        return cv2.image()
    # the crack: a bright jagged line from a strike point
    crack = [(13, 9), (12, 10), (12, 11), (11, 12), (13, 12), (14, 13), (10, 13), (15, 14), (9, 14),
             (16, 15), (11, 15), (10, 16), (16, 16), (17, 17), (10, 17), (9, 18), (17, 18), (8, 19),
             (13, 11), (14, 10), (15, 10), (12, 13), (12, 14), (13, 15), (13, 16), (14, 17), (14, 18)]
    if state == "broken":
        for (x, y) in glass:
            if (x * 7 + y * 3) % 5 == 0 or (12 <= x <= 15 and 10 <= y <= 18):
                cv.px(x, y, "k")
        for (x, y) in crack:
            cv.px(x, y, "m")
        # shards on the step
        for (x, y, ch) in ((6, 30, "C"), (7, 30, "e"), (15, 31, "C"), (16, 31, "d"), (11, 30, "n")):
            cv.px(x, y, ch)
        return cv.image()
    for (x, y) in crack:
        cv.px(x, y, "n")
    for (x, y) in ((13, 10), (12, 12), (14, 12), (11, 14)):
        cv.px(x, y, "C")
    # the glint: a diagonal band moving down-right
    k = int(state[1:]) if state.startswith("f") else 0
    if k in (1, 2):
        off = 0 if k == 1 else 8
        for (x, y) in glass:
            dd = (x + y) - (12 + off)
            if dd in (0, 1) and cv.get(x, y) in "fedq":
                cv.px(x, y, "C" if dd == 0 else "c")
            elif dd == 3 and cv.get(x, y) in "fedq":
                cv.px(x, y, "b")
    if k == 3:
        cv.px(7, 5, "W")
        cv.px(6, 6, "C")
        cv.px(8, 6, "C")
        cv.px(7, 7, "C")
    return cv.image()


# --------------------------------------------------------------------------- the Music Box
DANCER = [
    G("""
        ..A.A..
        .AWAWA.
        ..AWA..
        .AyyyA.
        AyzzzyA
        .AAWAA.
        ..AAA..
    """),
    G("""
        ...A...
        ..AWA..
        ..AWA..
        ..AyA..
        .AyzyA.
        ..AWA..
        ..AAA..
    """),
]
KEY = [
    G("""
        .....
        AA.AA
        AYAoA
        AAoAA
        .AYA.
        .AoA.
        .AAA.
    """),
    G("""
        .....
        ..AAA
        .AYoA
        AYoAA
        AoA..
        AAA..
        .....
    """),
    G("""
        .....
        AAAAA
        AYYoA
        AAAAA
        .....
        .....
        .....
    """),
    G("""
        .....
        AAA..
        AoYA.
        AAoYA
        ..AoA
        ..AAA
        .....
    """),
]


def music_box(frame=0, broken=False):
    W_, H_ = 24, 25
    cv = Cv(W_, H_)
    # carved stand
    cv.rect(3, 19, 18, 21, "A")
    cv.hline(4, 17, 20, "P")
    for x0 in (4, 15):
        cv.rect(x0, 21, x0 + 2, 23, "A")
        cv.px(x0 + 1, 22, "H")
    shadow(cv, 3, 18, 24)
    # lacquered box
    cv.rect(2, 10, 19, 19, "A")
    cv.rect(3, 11, 18, 18, "z")
    cv.hline(3, 18, 11, "y")
    cv.vline(3, 12, 18, "y")
    cv.rect(16, 12, 18, 18, "r")
    cv.hline(4, 18, 18, "r")
    cv.hline(3, 18, 13, "Y")          # gold trim
    cv.hline(3, 18, 16, "o")
    cv.px(3, 13, "F")
    for x in (5, 16):                 # little gold studs
        cv.px(x, 14, "Y")
        cv.px(x, 15, "o")
    cv.rect(8, 14, 13, 15, "Y")       # the plate, and its keyhole
    cv.hline(8, 13, 15, "o")
    cv.px(8, 14, "F")
    cv.px(10, 14, "k")
    cv.px(10, 15, "I")
    if broken:
        # lid slammed shut and askew, the spring hangs out of the side
        cv.rect(1, 7, 19, 10, "A")
        cv.hline(2, 18, 8, "y")
        cv.hline(2, 18, 9, "z")
        cv.px(19, 8, "A")
        cv.px(20, 8, "A")
        for (x, y) in ((20, 11), (21, 12), (20, 13), (21, 14), (20, 15)):
            cv.px(x, y, "m")
        for (x, y) in ((19, 11), (22, 12), (19, 13), (22, 14), (19, 15), (21, 16), (20, 16)):
            if cv.get(x, y) == ".":
                cv.px(x, y, "A")
        return cv.image()
    # open lid, tipped back, with a mirror in it
    cv.rect(3, 2, 18, 10, "A")
    cv.rect(4, 3, 17, 9, "r")
    cv.rect(5, 4, 16, 8, "e")
    cv.hline(5, 16, 4, "d")
    cv.px(6, 5, "C")
    cv.px(7, 5, "c")
    cv.px(6, 6, "c")
    cv.hline(4, 17, 3, "z")
    cv.hline(3, 18, 10, "A")
    cv.hline(4, 17, 10, "p")          # the dark inside of the box
    # the dancer on her spindle
    d = DANCER[0 if frame % 2 == 0 else 1]
    if frame == 2:
        d = [r[::-1] for r in d]
    cv.grid(d, 7, 2)
    cv.px(10, 9, "Y")
    # the winding key on the right
    cv.grid(KEY[frame % 4], 19, 10)
    return cv.image()


# --------------------------------------------------------------------------- the Study lectern
def lectern(frame=0):
    W_, H_ = 22, 30
    cv = Cv(W_, H_)
    # foot
    cv.rect(3, 24, 18, 27, "A")
    cv.hline(4, 17, 25, "P")
    cv.hline(4, 17, 26, "H")
    shadow(cv, 3, 18, 28)
    shadow(cv, 4, 17, 29)
    # column (green paint over wood, a gold band)
    cv.rect(8, 14, 13, 24, "A")
    cv.vline(9, 15, 23, "g")
    cv.vline(10, 15, 23, "G")
    cv.vline(11, 15, 23, "G")
    cv.vline(12, 15, 23, "D")
    cv.hline(9, 12, 19, "Y")
    cv.px(12, 19, "o")
    # slanted desk
    desk = G("""
        ..AAAAAAAAAAAAAAAAA.
        .AHPPPPPPPPPPPPPPPHA
        AHPPPPPPPPPPPPPPPPHA
        AHHHHHHHHHHHHHHHHHIA
        .AIIIIIIIIIIIIIIIIA.
        ..AAAAAAAAAAAAAAAA..
    """)
    cv.grid(desk, 1, 10)
    # the open book
    book = G("""
        ....AAAAA.AAAAA....
        ..AAWWWWWAWWWWsAA..
        .AWWWsWWWAWWsWWWsA.
        AWWsssWWsAWssWWsssA
        AWWWWWWWWAWWWWWWWsA
        AGGGGGGGGAGGGGGGGGA
        .AAAAAAAAAAAAAAAAA.
    """)
    cv.grid(book, 1, 5)
    if frame == 1:   # a page lifts on the draught
        for (x, y, ch) in ((11, 3, "A"), (12, 3, "A"), (13, 3, "A"), (11, 4, "W"), (12, 4, "W"),
                           (13, 4, "s"), (14, 4, "A"), (10, 4, "A"), (10, 5, "A"), (11, 5, "W"),
                           (12, 5, "W"), (13, 5, "W"), (14, 5, "s"), (15, 5, "A")):
            cv.px(x, y, ch)
    # a ribbon marker
    cv.px(14, 11, "R")
    cv.px(14, 12, "r")
    cv.px(14, 13, "R")
    return cv.image()


# --------------------------------------------------------------------------- the Wax Font
PIPS = (4, 7, 10, 12, 15, 18)


def font(uses=0, spent=False):
    """A stone basin of warm wax; six pips on its rim light up as it is fed and the wax rises."""
    W_, H_ = 24, 25
    cv = Cv(W_, H_)
    # base and pedestal
    cv.rect(4, 20, 19, 23, "A")
    cv.hline(5, 18, 21, "4")
    cv.hline(5, 18, 22, "3")
    shadow(cv, 4, 19, 24)
    cv.rect(8, 15, 15, 20, "A")
    cv.vline(9, 16, 19, "4")
    cv.rect(10, 16, 13, 19, "3")
    cv.vline(14, 16, 19, "2")
    # the bowl: a wide rim seen from above, the stone cup under it
    bowl = G("""
        .....AAAAAAAAAAAAAA.....
        ...AA55555555555555AA...
        ..A55AAAAAAAAAAAAAA44A..
        .A5AA11111111111111AA4A.
        .A5A1111111111111111A4A.
        .A4A2222222222222222A3A.
        .A4AA22222222222222AA3A.
        ..A44AAAAAAAAAAAAAA33A..
        ..A444444444444444433A..
        ...A4444444444444433A...
        ....A33333333333332A....
        .....AAA33333332AAA.....
        .......AAAAAAAAA........
    """)
    cv.grid(bowl, 0, 3)
    # the wax pool inside rises with each use: rows 6..9 of the canvas are the inside
    inside = [(x, y) for y in range(6, 10) for x in range(24) if cv.get(x, y) in "12"]
    level = 0 if spent else uses
    fill_rows = {0: 0, 1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 4}[level]
    if spent:
        fill_rows = 2
    for (x, y) in inside:
        if y >= 10 - fill_rows:
            top = y == 10 - fill_rows
            if spent:
                cv.px(x, y, "T" if top else "u")
            else:
                cv.px(x, y, "W" if top and x < 9 else ("V" if top else "U"))
    if not spent and level > 0:
        cv.px(14, 10 - fill_rows, "W")    # a bubble catching the light
    # the band with the six pips
    for i, x in enumerate(PIPS):
        lit = i < uses and not spent
        cv.px(x, 11, "Y" if lit else "3")
        cv.px(x + 1, 11, "o" if lit else "2")
    if spent:
        for (x, y) in ((6, 12), (7, 13), (7, 14), (8, 14)):
            cv.px(x, y, "2")
    else:
        for (x, y, n) in ((5, 11, 2), (18, 12, 2)):   # warm drips down the cup
            for k in range(n):
                cv.px(x, y + k, "V" if k < n - 1 else "U")
    return cv.image()


# --------------------------------------------------------------------------- offer icons (16x16)
OFFER_MAP = G("""
    ................
    ................
    ..AAAAA..AAAAA..
    .AVVVVVAAVVVVUA.
    .AVHHHVAUVHHHUA.
    .AVHVHVAUVHVHUA.
    .AVHHHHHHHHHVUA.
    .AVVVHVAUVVHVUA.
    .AVVVHVAUVRVRUA.
    .AVHHHVAUVVRVUA.
    .AVHVVVAUVRVRUA.
    .AVHHHVAUVVVVUA.
    .AUUUUUAATTTTTA.
    ..AAAAA..AAAAA..
    ................
    ................
""")
OFFER_TONICS = G("""
    ................
    ...AAA....AAA...
    ...AnA....AnA...
    ...AsA....AsA...
    ..AAnAA..AAnAA..
    .AnCCmA..AnCCmA.
    AnCRRRmAAnCbbbmA
    AnRRRRmAAncbbbmA
    AmRRRRmAAmbbbdmA
    AmRrrrmAAmbddddA
    .AmrrmA..AmddmA.
    ..AAAA....AAAA..
    ................
    ................
    ................
    ................
""")
OFFER_VEIL = G("""
    ................
    ................
    ................
    ....AAAAAAA.....
    ...AzzwwwwwA....
    ..AzwwwwwwwwA...
    ..AwwwKwwwwKA...
    ..AwwwKwwwwKA...
    ..AwwKwwwwwKA...
    ..AwwKwwwwKwA...
    .AzwwKwwwwKwwA..
    .AwwKwwwwwKwwA..
    .AwKKwwwKKwwKA..
    ..AAAAAAAAAAAA..
    ................
    ................
""")

# minimap marks (5x4), and the "?" (3x5) for special rooms you have not looked into yet
MAP = {
    "seance": (G("""
        .bbb.
        .bCb.
        bbbbb
        ..b..
    """), {"b": "#cae6f5", "C": "#5698cc"}),
    "mirror": (G("""
        .mmm.
        mCdem
        mdeem
        .mmm.
    """), {"m": "#b6cbcf", "C": "#fdf7ed", "d": "#5698cc", "e": "#314152"}),
    "musicbox": (G("""
        ..zz.
        ..z.z
        zzz..
        zzz..
    """), {"z": "#f78697"}),
    "study": (G("""
        gg.gg
        gWgWg
        gWgWg
        ggggg
    """), {"g": "#97da3f", "W": "#fdf7ed"}),
    "font": (G("""
        ..W..
        .WVW.
        WVVVU
        .VUU.
    """), {"W": "#fdf7ed", "V": "#e2b694", "U": "#b58057"}),
    "mini": (G("""
        R.R.R
        RRRRR
        RYRYR
        RRRRR
    """), {"R": "#da4e38", "Y": "#facb3e"}),
}
MAP_Q = (G("""
    QQQ
    ..Q
    .QQ
    ...
    .Q.
"""), {"Q": "#d3bfa9"})


# --------------------------------------------------------------------------- floor dressing
def seance_circle():
    """A chalk ring on the floor round the bell (a flat decal: no outline, like the cracks)."""
    import math
    W_, H_ = 96, 52
    cv = Cv(W_, H_)
    cx, cy, rx, ry = 47.5, 25.5, 45.0, 24.0
    pts = set()
    for k in range(1440):
        a = k * math.tau / 1440
        pts.add((int(round(cx + rx * math.cos(a))), int(round(cy + ry * math.sin(a)))))
    # thin the ring to a clean 1 px line: drop pixels whose two 4-neighbours on the ring make a corner
    ring = sorted(pts)
    keep = set(ring)
    for (x, y) in ring:
        if ((x + 1, y) in keep or (x - 1, y) in keep) and ((x, y + 1) in keep or (x, y - 1) in keep):
            if (x + 1, y + 1) in keep or (x - 1, y - 1) in keep or (x + 1, y - 1) in keep or (x - 1, y + 1) in keep:
                keep.discard((x, y))
    for (x, y) in keep:
        a = math.atan2((y - cy) / ry, (x - cx) / rx)
        seg = int((a + math.pi) / math.tau * 40)
        if seg % 7 == 3:                 # chalk breaks here and there
            continue
        cv.px(x, y, "t" if (x * 3 + y) % 5 == 0 else "s")
    # four little marks on the ring, and a five-point star of chalk ticks inside
    for (x, y) in ((47, 1), (47, 50), (2, 25), (93, 25)):
        cv.px(x, y, "W")
        cv.px(x - 1, y, "s")
        cv.px(x + 1, y, "s")
    for k in range(5):
        a = -math.pi / 2 + k * math.tau / 5
        x = int(round(cx + rx * 0.62 * math.cos(a)))
        y = int(round(cy + ry * 0.62 * math.sin(a)))
        cv.px(x, y, "s")
        cv.px(x + 1, y, "t")
    return cv.image()


SEANCE_CANDLE = G("""
    .A..
    AWVA
    AWVA
    AVUA
    AUTA
    xAAx
""")
SHARDS = G("""
    ....A.......
    ...ACA..A...
    ..ACeA.AnA..
    ..AAA..AAA.A
    .A.....A..AC
    AnA..A.....A
    .A..ACA.....
""")


# --------------------------------------------------------------------------- mini-bosses (2x)
MINIS = ["sootling", "skelet", "chort", "wogol", "deathwatch", "ice_zombie"]


def _frames_of(name):
    """{anim: [Image...]} for a creature, the same sources Enemy.frames_for() uses."""
    out = {}
    own = [f for f in sorted(os.listdir(MON)) if f.startswith(name + "_") and f.endswith(".png")]
    if own:
        for a in ("idle", "run", "atk"):
            fr = []
            k = 0
            while os.path.exists(os.path.join(MON, "%s_%s_f%d.png" % (name, a, k))):
                fr.append(Image.open(os.path.join(MON, "%s_%s_f%d.png" % (name, a, k))).convert("RGBA"))
                k += 1
            if fr:
                out[a] = fr
        return out

    def seq(prefix):
        fr = []
        k = 0
        while os.path.exists(os.path.join(F72, "%s_f%d.png" % (prefix, k))):
            fr.append(Image.open(os.path.join(F72, "%s_f%d.png" % (prefix, k))).convert("RGBA"))
            k += 1
        return fr
    idle = seq(name + "_idle_anim") or seq(name + "_anim")
    run = seq(name + "_run_anim") or idle
    out["idle"] = idle
    out["run"] = run
    return out


def scale2x(im):
    a = np.array(im)
    h, w = a.shape[:2]
    pad = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    P_ = pad[1:-1, 1:-1]
    A_ = pad[:-2, 1:-1]
    B_ = pad[1:-1, 2:]
    C_ = pad[1:-1, :-2]
    D_ = pad[2:, 1:-1]

    def eq(x, y):
        return np.all(x == y, axis=2)
    e0 = np.where((eq(C_, A_) & ~eq(C_, D_) & ~eq(A_, B_))[..., None], A_, P_)
    e1 = np.where((eq(A_, B_) & ~eq(A_, C_) & ~eq(B_, D_))[..., None], B_, P_)
    e2 = np.where((eq(D_, C_) & ~eq(D_, B_) & ~eq(C_, A_))[..., None], C_, P_)
    e3 = np.where((eq(B_, D_) & ~eq(B_, A_) & ~eq(D_, C_))[..., None], D_, P_)
    out = np.zeros((h * 2, w * 2, 4), dtype=np.uint8)
    out[0::2, 0::2] = e0
    out[0::2, 1::2] = e1
    out[1::2, 0::2] = e2
    out[1::2, 1::2] = e3
    return out


def redraw_2x(im):
    """A lodger at twice the size: Scale2x keeps the diagonals clean (no new colours), then the
    outline, now 2 px thick, is thinned back to 1 px so the champion matches the house's art."""
    src = np.array(im)
    h, w = src.shape[:2]
    op = src[:, :, 3] > 0
    dark = op & (src[:, :, :3].max(axis=2) < 0x30)
    pad = np.pad(op, 1)
    near_clear = np.zeros_like(op)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near_clear |= ~pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
    edge = dark & near_clear
    big = scale2x(im)
    H2, W2 = big.shape[:2]
    bop = big[:, :, 3] > 0
    bdark = bop & (big[:, :, :3].max(axis=2) < 0x30)
    cand = bdark & np.repeat(np.repeat(edge, 2, axis=0), 2, axis=1)
    out = big.copy()
    bpad = np.pad(bop, 1)
    for y in range(H2):
        for x in range(W2):
            if not cand[y, x]:
                continue
            if not (bpad[y, x + 1] and bpad[y + 2, x + 1] and bpad[y + 1, x] and bpad[y + 1, x + 2]):
                continue          # touches the outside: this is the outline we keep
            cols = {}
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < H2 and 0 <= xx < W2 and bop[yy, xx] and not bdark[yy, xx]:
                        k = tuple(int(v) for v in big[yy, xx])
                        cols[k] = cols.get(k, 0) + 1
            if cols:
                out[y, x] = max(cols.items(), key=lambda kv: kv[1])[0]
    return Image.fromarray(out)


def build_minis():
    made = {}
    for name in MINIS:
        for a, frames in _frames_of(name).items():
            for k, fr in enumerate(frames):
                made["mini_%s_%s_f%d" % (name, a, k)] = redraw_2x(fr)
    return made


# --------------------------------------------------------------------------- build
def build_all():
    made = {}
    for style in STYLES:
        made.update(door_set(style))
    for k, sw in enumerate((0, -3, 0, 3)):
        made["bell_f%d" % k] = bell_stand(sw)
    made["bell_done"] = bell_stand(0, True)
    for k in range(4):
        made["mirror_f%d" % k] = mirror("f%d" % k)
    made["mirror_veiled"] = mirror("veiled")
    made["mirror_broken"] = mirror("broken")
    for k in range(4):
        made["musicbox_f%d" % k] = music_box(k)
    made["musicbox_broken"] = music_box(0, True)
    for k in range(2):
        made["lectern_f%d" % k] = lectern(k)
    for u in range(7):
        made["font_%d" % u] = font(u)
    made["font_spent"] = font(6, True)
    made["offer_map"] = img(OFFER_MAP)
    made["offer_tonics"] = img(OFFER_TONICS)
    made["offer_veil"] = img(OFFER_VEIL)
    for k, (rows, pal) in MAP.items():
        made["map_" + k] = AR.grid(rows, pal)
    made["map_unknown"] = AR.grid(MAP_Q[0], MAP_Q[1])
    made["seance_circle"] = seance_circle()
    made["seance_candle"] = img(SEANCE_CANDLE)
    made["mirror_shards"] = img(SHARDS)
    made.update(build_minis())
    return made


def check(made, pal):
    for name, im in made.items():
        a = np.array(im)
        assert set(np.unique(a[:, :, 3])) <= {0, 255}, name + " has semi-transparent pixels"
        cols = {tuple(int(v) for v in p[:3]) for p in a.reshape(-1, 4) if p[3]}
        bad = cols - pal
        assert not bad, "%s uses colours outside the 0x72 palette: %s" % (
            name, ["#%02x%02x%02x" % c for c in bad])


def review(made, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    floor = (72, 59, 58, 255)
    props = [(n, AR.on_bg(im, floor)) for n, im in made.items()
             if n.startswith(("bell", "mirror", "musicbox", "lectern", "font", "offer", "seance"))]
    AR.contact(props, os.path.join(out_dir, "props_8x.png"), scale=8, cols=6)
    doors = [(n, AR.on_bg(im)) for n, im in made.items() if n.startswith("door_")]
    AR.contact(doors, os.path.join(out_dir, "doors_6x.png"), scale=6, cols=8)
    marks = [(n, AR.on_bg(im, (119, 92, 85, 255))) for n, im in made.items() if n.startswith("map_")]
    AR.contact(marks, os.path.join(out_dir, "map_16x.png"), scale=16, cols=7)
    minis = [(n, AR.on_bg(im, floor)) for n, im in made.items() if n.startswith("mini_") and n.endswith("_f0")]
    AR.contact(minis, os.path.join(out_dir, "minis_6x.png"), scale=6, cols=6)
    # in-room previews: each special room in its floor's theme with its doors and prop
    rooms = {"seance": ("cellar", "bell_f0"), "mirror": ("crypt", "mirror_f1"),
             "musicbox": ("chapel", "musicbox_f0"), "study": ("crypt", "lectern_f0"),
             "font": ("belfry", "font_3")}
    for style, (theme, prop) in rooms.items():
        bg = Image.open(os.path.join(AR.OUT, "room_%s.png" % theme)).convert("RGBA")
        im = AR.on_bg(bg)
        for d in ("top", "bottom", "left", "right"):
            x, y, w, h = AR.SLOTS[d]
            im.alpha_composite(made["door_%s_%s_%s" % (d, style, "open" if d != "left" else "closed")], (x, y))
        if style == "seance":
            ci = made["seance_circle"]
            im.alpha_composite(ci, (136 - ci.width // 2, 106 - ci.height // 2))
        spr = made[prop]
        im.alpha_composite(spr, (136 - spr.width // 2, 112 - spr.height))
        im.resize((272 * 4, 192 * 4), Image.NEAREST).save(os.path.join(out_dir, "room_%s_4x.png" % style))


def main():
    out_dir = None
    for a in sys.argv[1:]:
        if a.startswith("--review="):
            out_dir = a.split("=", 1)[1]
    pal = AR.sheet_palette()
    made = build_all()
    check(made, pal)
    os.makedirs(OUT, exist_ok=True)
    for name, im in made.items():
        im.save(os.path.join(OUT, name + ".png"), optimize=True)
    if out_dir:
        review(made, out_dir)
    print("wrote %d files to %s" % (len(made), OUT))


if __name__ == "__main__":
    main()
