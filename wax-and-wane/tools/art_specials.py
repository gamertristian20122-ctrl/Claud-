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
        .AAAAA.AAAAA
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
