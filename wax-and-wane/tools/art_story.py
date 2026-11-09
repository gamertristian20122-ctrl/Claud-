#!/usr/bin/env python3
"""Wax & Wane - the story (v2.5): Martha's diary pages and the kitchen for the new endings.

    python3 tools/art_story.py                 writes the files listed below
    python3 tools/art_story.py --review=<dir>  also writes x6 / x3 contact sheets to look at

Same rules as every other art tool here (tools/art_tower.py, art_monsters.py): the 0x72 DungeonTileset II
palette only (asserted for every file), no anti-aliasing, no semi-transparent pixels, light from the
top-left. The page sprites get the 1 px #222222 outline (art_monsters.render); the ending scene is a flat
backdrop like tower/end_*, its moving parts (fire, sky, pages) drawn by scripts/ui/ending.gd.

Output (assets/art/story/)
  page_f0..f3     a torn diary page fluttering above the floor (the `page` pickup, 12 x 13)
  page_icon       a page for the Journal's Diary tab (14 x 17; a silhouette while it is missing)
  end_kitchen     Martha's corner of the kitchen at night (192 x 96, shown x2 by the ending cards):
                  the black range with its fire, the kettle, the mantel clock, the window (panes left
                  transparent: the ending draws the sky), the table with her diary and teacup, the
                  rocking chair with her shawl, the Book of Rounds on the wall, her keys and apron.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_tower as T      # noqa: E402  palette (art_monsters + the tower's letters), canvas helpers, checks

Canvas = T.Canvas
render = T.render
rect, line, disc = T.rect, T.line, T.disc
ART = T.ART
MADE = {}


def put(name, im):
    MADE[name] = im


def grid(rows, w, h, dx=1, dy=1):
    cv = Canvas(w, h)
    cv.blit(rows, dx, dy)
    return cv


# =========================================================================== the page pickup
# w paper, A its shaded side / back, a and 5 the handwriting, torn on the left (the binding)
PAGE_FRAMES = [
    [".wwwwwww..",
     "wwwwwwwwA.",
     ".w5a55awA.",
     "wwwwwwwwA.",
     ".wa555awA.",
     "wwwwwwwwA.",
     ".w55a5wwA.",
     "wwwwwwwwA.",
     ".wa55wwwA.",
     "wwwwwwwAA.",
     ".wwwwwwA.."],
    [".wwwwAA...",       # the top corner flips forward: its back shows
     "wwwwwAAA..",
     ".w5a5wAA..",
     "wwwwwwwA..",
     ".wa555awA.",
     "wwwwwwwwA.",
     ".w55a5wwA.",
     "wwwwwwwwA.",
     ".wa55wwwA.",
     "wwwwwwwAA.",
     ".wwwwwwA.."],
    ["..wwwww...",       # turned half sideways
     ".wwwwwwA..",
     "..w5a5wA..",
     ".wwwwwwA..",
     "..wa55wA..",
     ".wwwwwwA..",
     "..w5a5wA..",
     ".wwwwwwA..",
     "..wa5wwA..",
     ".wwwwwAA..",
     "..wwwwA..."],
    [".wwwwwww..",       # the bottom corner curls up
     "wwwwwwwwA.",
     ".w5a55awA.",
     "wwwwwwwwA.",
     ".wa555awA.",
     "wwwwwwwwA.",
     ".w55a5wwA.",
     "AAwwwwwwA.",
     ".AA55wwwA.",
     "..AwwwwAA.",
     "...wwwwA.."],
]

PAGE_ICON = [
    ".w.ww.www.w.",
    "wwwwwwwwwwwA",
    "w5a55a5wwwwA",
    "wwwwwwwwwwwA",
    "wa555a55awwA",
    "wwwwwwwwwwwA",
    "w55a5a5wwwwA",
    "wwwwwwwwwwwA",
    "wa555a5a55wA",
    "wwwwwwwwwwwA",
    "w5a55wwwwwwA",
    "wwwwwwwwwwwA",
    "wwwwwwwwwwAA",
    "AAAAAAAAAAA.",
    ".AAAAAAAAA..",
]


def build_pages():
    for i, rows in enumerate(PAGE_FRAMES):
        put("story/page_f%d" % i, render(grid(rows, 12, 13)))
    put("story/page_icon", render(grid(PAGE_ICON, 14, 17)))


# =========================================================================== the kitchen (ending scene)
SW, SH = 192, 96
# the window's panes (left transparent; scripts/ui/ending.gd draws the night or the dawn in them)
PANES = ((101, 11, 11, 14), (113, 11, 11, 14), (101, 26, 11, 14), (113, 26, 11, 14))


def build_end_kitchen():
    cv = Canvas(SW, SH)
    # ---- walls: the house's dark boards (as tower/end_window), a dado rail, a boarded wainscot
    for y in range(0, 56):
        for x in range(SW):
            i = x % 16
            cv.put(x, y, "U" if i == 0 else ("j" if 3 <= i <= 13 else "J"))
    rect(cv, 0, 55, SW, 1, "5")
    rect(cv, 0, 56, SW, 1, "4")
    for y in range(57, 76):
        for x in range(SW):
            cv.put(x, y, "U" if x % 8 == 0 else ("4" if y > 57 else "5"))
    # ---- the floor: flagstones
    for y in range(76, SH):
        row = (y - 76) // 7
        off = 6 if row % 2 else 0
        for x in range(SW):
            edge = (y - 76) % 7 == 6 or (x + off) % 13 == 12
            cv.put(x, y, "U" if edge else ("u" if (x // 13 + row) % 2 else "z"))
    # ---- the range: iron hood and mantel, the chimney pipe, the body, firebox, oven, feet
    rect(cv, 4, 22, 62, 2, "D")                 # the mantel shelf
    rect(cv, 4, 22, 62, 1, "d")
    rect(cv, 4, 24, 62, 1, "F")
    rect(cv, 6, 0, 58, 22, "3")                 # the hood / chimney breast
    rect(cv, 6, 0, 1, 22, "L")
    rect(cv, 63, 0, 1, 22, "1")
    for y in range(3, 22, 6):
        rect(cv, 7, y, 56, 1, "I")              # riveted bands
        for x in range(10, 62, 8):
            cv.put(x, y, "L")
    # on the mantel: a clock, two jars, a brass candlestick
    T.ring_lit(cv, 34, 15, 4.0, 5.6, "c", "o", "R", "y")
    disc(cv, 34, 15, 4.0, "w")
    line(cv, 34, 15, 34, 12, "k")
    line(cv, 34, 15, 36, 15, "k")
    rect(cv, 31, 20, 7, 2, "R")
    for jx, lid, body in ((11, "5", "q"), (16, "5", "T")):
        rect(cv, jx, 16, 4, 6, body)
        rect(cv, jx, 15, 4, 1, lid)
        cv.put(jx, 17, "w")
    rect(cv, 54, 20, 5, 2, "c")                 # the candlestick, an unlit stub in it
    rect(cv, 56, 14, 1, 6, "c")
    rect(cv, 55, 11, 3, 4, "w")
    cv.put(56, 10, "k")
    # the pipe from the hob up into the hood
    rect(cv, 46, 24, 6, 8, "1")
    rect(cv, 46, 24, 1, 8, "3")
    # the body
    rect(cv, 8, 32, 54, 44, "1")
    rect(cv, 8, 32, 54, 3, "3")                 # the hob top
    rect(cv, 8, 32, 54, 1, "L")
    rect(cv, 8, 35, 1, 37, "I")
    # the kettle on the left plate: copper, its spout and handle
    rect(cv, 13, 25, 13, 7, "c")
    rect(cv, 14, 24, 11, 1, "c")
    rect(cv, 13, 25, 1, 7, "o")
    rect(cv, 14, 24, 4, 1, "o")
    rect(cv, 24, 25, 2, 7, "R")
    rect(cv, 13, 31, 13, 1, "R")
    line(cv, 12, 28, 9, 25, "c")
    cv.put(9, 24, "o")
    line(cv, 14, 23, 16, 20, "4")
    line(cv, 16, 20, 22, 20, "4")
    line(cv, 22, 20, 24, 23, "4")
    rect(cv, 18, 23, 3, 1, "R")
    # the firebox: bars over the fire (ending.gd makes it flicker)
    rect(cv, 13, 42, 18, 18, "3")
    rect(cv, 15, 44, 14, 14, "m")
    rect(cv, 15, 52, 14, 6, "R")
    for (x, y, ch) in ((16, 50, "r"), (17, 48, "r"), (18, 47, "o"), (19, 49, "y"), (20, 46, "o"), (21, 48, "r"),
                       (22, 45, "r"), (23, 47, "o"), (24, 49, "y"), (25, 48, "r"), (26, 50, "o"), (27, 49, "r"),
                       (17, 51, "o"), (20, 50, "y"), (23, 51, "o"), (26, 52, "r"), (19, 53, "c"), (24, 54, "c")):
        rect(cv, x, y, 1, 58 - y, ch)
    for x in (16, 19, 22, 25, 28):
        rect(cv, x, 44, 1, 14, "1")
    rect(cv, 13, 42, 18, 1, "L")
    # the ash pan and the oven door with its brass handle
    rect(cv, 13, 63, 18, 6, "3")
    rect(cv, 13, 63, 18, 1, "I")
    rect(cv, 20, 65, 4, 2, "c")
    rect(cv, 35, 41, 23, 24, "3")
    rect(cv, 35, 41, 23, 1, "L")
    rect(cv, 35, 41, 1, 24, "I")
    rect(cv, 38, 44, 17, 18, "1")
    rect(cv, 39, 45, 15, 16, "3")
    rect(cv, 41, 47, 11, 1, "c")
    rect(cv, 41, 47, 3, 1, "y")
    # feet
    rect(cv, 9, 74, 4, 2, "U")
    rect(cv, 57, 74, 4, 2, "U")
    # ---- the pan rail: a copper pan, a ladle, a sieve
    rect(cv, 68, 13, 26, 1, "D")
    rect(cv, 68, 14, 26, 1, "F")
    line(cv, 74, 14, 74, 18, "4")
    disc(cv, 74.5, 24.5, 5.0, "c")
    disc(cv, 74.5, 24.5, 3.5, "R")
    cv.put(72, 21, "o")
    cv.put(73, 21, "o")
    cv.put(71, 22, "o")
    rect(cv, 83, 14, 1, 13, "i")
    rect(cv, 81, 27, 5, 3, "i")
    rect(cv, 82, 27, 3, 1, "S")
    T.ring_lit(cv, 90, 22, 2.5, 4.0, "i", "S", "M")
    line(cv, 90, 14, 90, 18, "4")
    # ---- the window (panes cut out), its sill and Cook's herbs
    rect(cv, 98, 8, 29, 35, "4")
    rect(cv, 98, 8, 29, 1, "5")
    rect(cv, 98, 8, 1, 35, "5")
    for (x, y, w, h) in PANES:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                cv.c[yy][xx] = "."
    rect(cv, 95, 42, 35, 3, "f")
    rect(cv, 95, 42, 35, 1, "X")
    rect(cv, 96, 45, 33, 1, "F")
    rect(cv, 117, 38, 6, 4, "c")
    rect(cv, 117, 38, 6, 1, "o")
    rect(cv, 122, 39, 1, 3, "R")
    for (x, y, ch) in ((117, 36, "G"), (118, 34, "g"), (119, 35, "G"), (120, 33, "g"), (121, 35, "G"), (122, 36, "g"),
                       (119, 37, "g"), (121, 37, "G"), (118, 37, "G")):
        cv.put(x, y, ch)
    # ---- the Book of Rounds, pinned up in a frame over the chair
    rect(cv, 139, 5, 17, 18, "F")
    rect(cv, 140, 6, 15, 16, "A")
    rect(cv, 140, 6, 15, 1, "w")
    for i, y in enumerate(range(9, 21, 2)):
        rect(cv, 142, y, 9 - (i * 3) % 5, 1, "5")
        cv.put(152, y, "a")
    cv.put(147, 4, "y")
    # ---- Martha's keys on their hook, her apron on its peg
    rect(cv, 168, 18, 3, 2, "5")
    T.ring_lit(cv, 169.5, 24.5, 2.0, 3.5, "c", "y", "R")
    for (kx, ln) in ((167, 9), (170, 11), (172, 8)):
        rect(cv, kx, 27, 1, ln, "y")
        rect(cv, kx, 27 + ln - 3, 2, 1, "c")
        rect(cv, kx, 27 + ln - 1, 2, 1, "c")
    rect(cv, 181, 15, 3, 2, "5")
    rect(cv, 179, 18, 7, 9, "A")                # the bib
    rect(cv, 179, 18, 7, 1, "w")
    rect(cv, 176, 27, 13, 1, "a")               # the waist and its strings
    line(cv, 176, 27, 174, 33, "A")
    rect(cv, 177, 28, 11, 22, "A")              # the skirt, its folds
    for x in (179, 182, 185):
        rect(cv, x, 30, 1, 20, "a")
    rect(cv, 177, 28, 1, 22, "w")
    rect(cv, 180, 36, 5, 4, "a")                # the pocket
    rect(cv, 181, 37, 3, 2, "A")
    rect(cv, 177, 49, 11, 1, "a")
    # ---- the rocking chair, her shawl over its back, a cushion
    for x in (136, 156):
        rect(cv, x, 28, 2, 32, "F")
        cv.put(x, 28, "D")
    rect(cv, 136, 28, 1, 32, "D")
    rect(cv, 138, 26, 18, 1, "D")
    rect(cv, 136, 27, 22, 2, "F")
    rect(cv, 136, 27, 22, 1, "D")
    for x in (141, 145, 149, 153):
        rect(cv, x, 29, 1, 26, "F")
    rect(cv, 133, 55, 28, 3, "D")
    rect(cv, 133, 55, 28, 1, "d")
    rect(cv, 133, 58, 28, 1, "F")
    rect(cv, 138, 52, 18, 3, "v")
    rect(cv, 138, 52, 18, 1, "p")
    for x in (134, 159):
        rect(cv, x, 59, 2, 13, "F")
    for x in range(127, 167):
        y = 71 + int(round(((x - 147) / 20.0) ** 2 * -2.0)) + 2
        rect(cv, x, y, 1, 2, "R")
        cv.put(x, y, "F")
    for y in range(27, 34):                     # the shawl over the top rail
        for x in range(137, 157):
            cv.put(x, y, "p" if (x + y) % 2 else "P")
    for y in range(34, 50):                     # and down the left post, in a fold
        for x in range(135, 142 - (y - 34) // 5):
            cv.put(x, y, "p" if (x + y) % 2 else ("m" if x == 135 else "P"))
    for x in range(135, 141, 2):
        cv.put(x, 50, "q")
        cv.put(x + 1, 51, "q")
    rect(cv, 137, 27, 20, 1, "q")
    # ---- the table: a cloth, the open diary, the teacup and saucer
    rect(cv, 78, 59, 41, 3, "D")
    rect(cv, 78, 59, 41, 1, "d")
    rect(cv, 78, 62, 41, 1, "F")
    for x in (82, 113):
        rect(cv, x, 63, 3, 13, "F")
        rect(cv, x, 63, 1, 13, "D")
    rect(cv, 85, 69, 28, 1, "F")
    rect(cv, 89, 59, 21, 1, "w")
    rect(cv, 88, 60, 23, 4, "A")
    for x in range(88, 111, 3):
        cv.put(x, 64, "a")
    rect(cv, 99, 57, 13, 2, "w")                # the diary: open pages, its red cover, the spine
    rect(cv, 99, 56, 5, 1, "w")
    rect(cv, 106, 56, 6, 1, "w")
    rect(cv, 105, 56, 1, 3, "A")
    rect(cv, 98, 59, 15, 1, "p")
    for (x, y, w) in ((100, 57, 4), (107, 57, 4), (100, 58, 3), (107, 58, 2)):
        rect(cv, x, y, w, 1, "a")
    rect(cv, 83, 58, 7, 1, "S")                 # the saucer and the cup
    rect(cv, 84, 54, 5, 4, "h")
    rect(cv, 84, 54, 5, 1, "S")
    rect(cv, 84, 56, 5, 1, "b")
    rect(cv, 89, 55, 1, 2, "S")
    # ---- a rag rug under the chair, and the fire's glow on the flags
    for x in range(124, 172):
        for y in range(76, 80):
            cv.put(x, y, ("m", "p", "v", "R")[(x // 2) % 4] if 0 < x - 124 < 47 else "U")
    for (x, y) in ((12, 77), (18, 76), (24, 78), (30, 77), (36, 76), (15, 79), (27, 80), (40, 78), (21, 81)):
        cv.put(x, y, "R")
        cv.put(x + 1, y, "c")
    put("story/end_kitchen", T.to_img(cv))


# =========================================================================== main
def check(name, im):
    T.check(name, im)


def contact(names, path, scale):
    ims = [MADE[n] for n in names]
    W = sum(i.width for i in ims) * scale + 8 * (len(ims) + 1)
    H = max(i.height for i in ims) * scale + 16
    out = Image.new("RGBA", (W, H), (36, 30, 36, 255))
    x = 8
    for im in ims:
        out.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, 8))
        x += im.width * scale + 8
    out.save(path)


def main():
    review = None
    for a in sys.argv[1:]:
        if a.startswith("--review"):
            review = a.split("=", 1)[1] if "=" in a else "/tmp/claude-0/review_story"
    build_pages()
    build_end_kitchen()
    for name, im in MADE.items():
        check(name, im)
        p = os.path.join(ART, name + ".png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p, optimize=True)
    print("wrote %d files" % len(MADE))
    if review:
        os.makedirs(review, exist_ok=True)
        contact(["story/page_f%d" % i for i in range(4)] + ["story/page_icon"], os.path.join(review, "pages_x8.png"), 8)
        contact(["story/end_kitchen"], os.path.join(review, "kitchen_x4.png"), 4)


if __name__ == "__main__":
    main()
