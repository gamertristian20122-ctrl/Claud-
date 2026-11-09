#!/usr/bin/env python3
"""Wax & Wane - the talking scenes (v2.7 dialogue stream, docs/streams/v27_dialogue.md).

    python3 tools/art_talk.py                 writes the files listed below
    python3 tools/art_talk.py --review=<dir>  also writes zoomed contact sheets to look at

Same rules as every other art tool here: the 0x72 DungeonTileset II palette only (asserted for every file), no
anti-aliasing, no semi-transparent pixels, light from the top-left, a 1 px outline on sprites. New art only where
the game had none: everything else in the scenes is the game's own (Tallow's body is drawn in code, the guardians'
portraits are their own frames, the story panels reuse the v2.5 / tower scenes).

Output
  hero/face_open_talk, face_worried_talk, face_tired_talk, face_happy_talk      11 x 6: Tallow's faces with the mouth
  hero/face_teary, face_teary_talk, face_blink_teary                            open (or shut) for the 2-frame talk,
                                                                                and "teary" (worried, crying wax: a
                                                                                blue tear under each eye). Built from
                                                                                the concept's own face parts
                                                                                (art_source/hero_reborn/draw.py).
  talk/martha_f0, martha_f1, martha_blink, martha_smile                         24 x 24: Martha Fenn as a memory, a
                                                                                warm sepia bust (shown x2 in the talk
                                                                                box): mouth shut / open, a blink, eyes
                                                                                creased in a smile.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_tower as T      # noqa: E402  palette (art_monsters + the tower's letters), canvas helpers, checks

ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "art_source", "hero_reborn"))
import draw as concept     # noqa: E402  the hero's single source of truth (faces, flames, dish)

Canvas = T.Canvas
render = T.render
rect, line, disc = T.rect, T.line, T.disc
ART = T.ART
MADE = {}


def put(name, im):
    MADE[name] = im


def rgba(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


# =========================================================================== Tallow's talking faces
# The concept's draw_face(eyes, mouth) is what tools/art_hero_fx_items.py builds face_* from; the talk frames are the
# same eyes with another of its mouths. Tears: a glint-blue drop under each eye's outer corner (b over t).
FACES = {
    "hero/face_open_talk": ("open", "open", False),
    "hero/face_worried_talk": ("worried", "ouch", False),
    "hero/face_tired_talk": ("tired", "ouch", False),
    "hero/face_happy_talk": ("happy", "v", False),
    "hero/face_teary": ("worried", "flat", True),
    "hero/face_teary_talk": ("worried", "ouch", True),
    "hero/face_blink_teary": ("blink", "flat", True),
}


def tallow_face(eyes, mouth, tears):
    sp = concept.Spr()
    concept.draw_face(sp, 0, 0, eyes, mouth)
    sp.px = {k: v for k, v in sp.px.items() if v != "c"}   # cheeks: drawn in code per candle
    if tears:
        for x in (-4, 4):           # under each eye's outer corner
            sp.put(x, 3, "b")
            sp.put(x, 4, "t")
    im = Image.new("RGBA", (11, 6), (0, 0, 0, 0))
    for (x, y), c in sp.px.items():
        X, Y = 5 + x, y
        if 0 <= X < 11 and 0 <= Y < 6:
            im.putpixel((X, Y), rgba(concept.PAL[c]))
    return im


def build_faces():
    for name, (eyes, mouth, tears) in FACES.items():
        put(name, tallow_face(eyes, mouth, tears))


# =========================================================================== Martha Fenn, a memory (sepia)
# Only the warm browns of the palette: cream w, cap shade A, grey hair a / 5, skin x X d f, blush D, lips and brows F,
# the dress 4 J, the eyes K. A mob cap with a frilled band, grey hair at the temples, crow's feet and a kind mouth,
# a dark high-necked dress with a white collar and a brooch. Shown x2 (24 x 24 -> 48 x 48), like the guardians.
MARTHA = [
    "........................",
    "........AwwwwwwA........",
    "......AwwwwwwwwwwA......",
    ".....AwwwwwwwwwwwwA.....",
    "....AwwwwwwwwwwwwwwA....",
    "....AwAwwAwwwwAwwAwA....",
    "...aaAaaaaaaaaaaaaAaa...",
    "...aaxxxxxxxxxxxXXXaa...",
    "...aaxxxxxxxxxxxXXXaa...",
    "...a5xxaaxxxxxxaaXX5a...",
    "....5xxKKxxxxxxKKXd5....",
    "....xxxKKxxxxxxKKXd.....",
    ".....xxxxxxxdXXXXXd.....",
    "......xxxFxxxxFXXd......",
    "......dxxxFFFFXXXd......",
    ".......dxxxxxXXXd.......",
    "........ddXXXXdd........",
    "..........dddd..........",
    "........4wwwwwww4.......",
    "......444wAwwwAw444.....",
    "....4445444wwXwAw4445...",
    "...44454444wAwwA444454..",
    "..4445444444wAAw44444544",
    ".44454444444444444444454",
]
# talking: the smile opens (rows 14-15)
MOUTH_OPEN = {14: "......dxxxFDDFXXXd......", 15: ".......dxxxFFXXXd......."}
EYES = ((7, 10), (8, 10), (7, 11), (8, 11), (15, 10), (16, 10), (15, 11), (16, 11))


def martha(kind):
    rows = [r[:24].ljust(24, ".") for r in MARTHA]
    cv = Canvas(24, 24)
    cv.blit(rows)
    if kind in ("f0", "f1"):   # a glint in each eye (warm cream), lit from the top left
        cv.put(7, 10, "w")
        cv.put(15, 10, "w")
    if kind == "f1":
        for y, r in MOUTH_OPEN.items():
            for x, ch in enumerate(r):
                if ch != ".":
                    cv.put(x, y, ch)
    if kind in ("blink", "smile"):
        for (x, y) in EYES:
            cv.put(x, y, "x" if x < 12 else "X")
        if kind == "blink":   # shut: a lash line
            for x in (7, 8, 15, 16):
                cv.put(x, 11, "F")
        else:                 # creased in a smile: ^ ^
            for (x, y) in ((6, 11), (7, 10), (8, 10), (9, 11), (14, 11), (15, 10), (16, 10), (17, 11)):
                cv.put(x, y, "F")
    return render(cv)


def build_martha():
    for k in ("f0", "f1", "blink", "smile"):
        put("talk/martha_" + k, martha(k))


# =========================================================================== the opening: Martha at the kitchen table
# Standing by the kitchen table of story/end_kitchen (scene scale: she is 52 px tall, her shoulders at the height of the
# candle's wick on the table), facing right, in her cap, a dark dress, the white apron, the keys at her hip. Three
# poses of the near arm: hands folded ("stand"), a struck match held up ("match"), the match at the wick ("light").
# The flame tip of "light" is MATCH_TIP (scripts/ui/opening.gd lines it up with Tallow's wick).
MW, MH = 36, 52
MATCH_TIP = (32, 2)


def _shape(cv, rows, x0, y0, fill):
    """rows: [(y, x_from, x_to)] filled with `fill`."""
    for (y, a, b) in rows:
        for x in range(a, b + 1):
            cv.put(x0 + x, y0 + y, fill)


def martha_stand(pose):
    cv = Canvas(MW, MH)
    # ---- the skirt (dark slate, lit on the left), widening to the hem
    for y in range(30, 49):
        k = (y - 30) / 18.0
        a = int(round(9 - 4 * k))
        b = int(round(19 + 4 * k))
        for x in range(a, b + 1):
            ch = "s"
            if x <= a + 1:
                ch = "M"
            elif x >= b - 1:
                ch = "2"
            elif (x - a) % 4 == 2 and y > 33:
                ch = "2"   # folds
            cv.put(x, y, ch)
    # the apron's skirt over the front (right) of it
    for y in range(30, 48):
        k = (y - 30) / 17.0
        a = int(round(15 + 1 * k))
        b = int(round(20 + 3 * k))
        for x in range(a, b + 1):
            cv.put(x, y, "A" if x == a or y == 47 or (x == a + 3 and y > 34) else "w")
    # shoes, the right one stepping forward
    rect(cv, 8, 49, 4, 2, "2")
    rect(cv, 15, 49, 6, 2, "2")
    rect(cv, 19, 48, 2, 1, "2")
    # ---- the bodice, the apron bib, the strings at the waist
    for y in range(17, 30):
        a = 10 if y > 18 else 11
        b = 19 if y > 18 else 18
        for x in range(a, b + 1):
            cv.put(x, y, "M" if x <= a + 1 else ("2" if x == b else "s"))
    rect(cv, 15, 19, 4, 10, "w")
    rect(cv, 15, 19, 1, 10, "A")
    rect(cv, 10, 29, 10, 1, "A")
    # her keys at the hip: a brass ring and three keys
    cv.put(9, 30, "c")
    cv.put(9, 31, "c")
    for (kx, ln) in ((8, 4), (10, 3), (11, 4)):
        rect(cv, kx, 32, 1, ln, "y")
    # ---- the collar and the neck
    rect(cv, 12, 15, 4, 2, "X")
    rect(cv, 11, 16, 8, 1, "w")
    # ---- the head: the face in profile (looking right), grey hair and a bun at the back, the cap and its frill
    _shape(cv, [(5, 11, 17), (6, 10, 18), (7, 10, 18), (8, 10, 18), (9, 10, 18), (10, 10, 18), (11, 10, 18),
                (12, 10, 17), (13, 11, 17), (14, 12, 16)], 0, 0, "x")
    for y in range(6, 14):
        cv.put(10, y, "X")      # the shade at the back of the face
    for y in (12, 13):
        cv.put(17, y, "X")
    cv.put(19, 9, "x")          # the nose
    cv.put(19, 10, "X")
    cv.put(16, 8, "K")          # the eye, the brow, a blush, the mouth
    cv.put(16, 9, "K")
    rect(cv, 15, 7, 3, 1, "a")
    cv.put(15, 11, "q")
    cv.put(14, 11, "q")
    cv.put(17, 12, "f")
    _shape(cv, [(4, 6, 9), (5, 5, 9), (6, 5, 9), (7, 6, 9), (8, 7, 9), (9, 8, 10), (10, 8, 10), (11, 9, 10)], 0, 0, "a")
    for (x, y) in ((6, 5), (7, 6), (6, 6), (8, 8), (9, 10)):
        cv.put(x, y, "5")
    _shape(cv, [(0, 10, 15), (1, 9, 17), (2, 8, 18), (3, 8, 18), (4, 9, 18)], 0, 0, "w")
    for x in range(10, 19):
        cv.put(x, 5, "w" if x % 2 else "A")   # the frill over her brow
    for (x, y) in ((9, 2), (9, 3), (10, 4), (16, 1), (17, 2), (18, 3)):
        cv.put(x, y, "A")
    # ---- the near arm
    if pose == "stand":   # hands folded on the apron
        _shape(cv, [(18, 13, 16), (19, 13, 16), (20, 13, 16), (21, 13, 16), (22, 14, 17), (23, 14, 17), (24, 14, 17),
                    (25, 15, 18)], 0, 0, "s")
        for y in range(18, 25):
            cv.put(13 if y < 22 else 14, y, "M")
        rect(cv, 15, 26, 4, 2, "x")
        cv.put(18, 27, "X")
    elif pose == "match":   # the struck match held up before her face
        _shape(cv, [(18, 13, 16), (19, 13, 16), (20, 13, 16), (21, 14, 17), (22, 15, 18), (21, 18, 19), (20, 18, 20),
                    (19, 19, 21)], 0, 0, "s")
        for y in range(18, 22):
            cv.put(13 if y < 21 else 14, y, "M")
        rect(cv, 21, 16, 2, 3, "x")
        cv.put(22, 18, "X")
        line(cv, 23, 15, 24, 12, "D")
        for (x, y, ch) in ((24, 11, "r"), (24, 10, "y"), (23, 10, "o"), (25, 10, "o"), (24, 9, "w"), (24, 8, "y"), (24, 7, "o")):
            cv.put(x, y, ch)
    else:                   # "light": her arm reaching up and out, a long kitchen match to the wick (her hand stays
        # clear of the candle: the match is long enough that only its tip meets the wick)
        _shape(cv, [(18, 13, 16), (19, 13, 16), (20, 14, 16)], 0, 0, "s")
        for k in range(3):
            line(cv, 15, 19 - k, 22, 13 - k, "s")
        line(cv, 14, 17, 21, 11, "M")
        line(cv, 16, 20, 23, 14, "2")
        cv.put(13, 18, "M")
        rect(cv, 22, 10, 3, 3, "x")
        cv.put(24, 12, "X")
        line(cv, 25, 9, 31, 3, "D")
        for (x, y, ch) in ((32, 3, "r"), (32, 2, "w"), (31, 2, "y"), (33, 2, "y"), (32, 1, "y"), (32, 0, "o")):
            cv.put(x, y, ch)
    return render(cv)


def build_martha_stand():
    for pose in ("stand", "match", "light"):
        put("talk/martha_" + pose, martha_stand(pose))


# =========================================================================== the opening: the cellar, at twelve
# 192 x 96 like the other story scenes (shown x2): rough stone walls, flagstones, the wooden stairs going up on the
# right to a door with warm light under it (the way up), barrels and crates and the coal heap on the left, cobwebs,
# and Martha's chalk on the floor where the candle wakes (a circle and an arrow to the stairs). The scene starts in
# the dark: scripts/ui/opening.gd lights it from the candle.
def build_open_cellar():
    SW, SH = 192, 96
    cv = Canvas(SW, SH)
    # ---- the back wall: rows of rough stone blocks, offset every row
    for y in range(0, 70):
        row = y // 7
        off = (row * 5) % 11
        for x in range(SW):
            mort = y % 7 == 6 or (x + off) % 11 == 10
            if mort:
                ch = "U"
            else:
                shade = ((x + off) // 11 * 3 + row * 7) % 5
                ch = ("j", "4", "j", "u", "j")[shade]
                if y % 7 == 0 and not (x + off) % 11 == 10:
                    ch = "4" if ch != "4" else "5"   # the lit top edge of each block
            cv.put(x, y, ch)
    # a cellar grate high on the wall, moonlight through it
    rect(cv, 60, 6, 18, 9, "U")
    rect(cv, 61, 7, 16, 7, "Q")
    for x in range(62, 77, 3):
        rect(cv, x, 7, 1, 7, "1")
    # ---- the floor: flagstones
    for y in range(70, SH):
        row = (y - 70) // 7
        off = 6 if row % 2 else 0
        for x in range(SW):
            edge = (y - 70) % 7 == 6 or (x + off) % 14 == 13
            cv.put(x, y, "U" if edge else ("u" if (x // 14 + row) % 2 else "z"))
    rect(cv, 0, 70, SW, 1, "C")
    # ---- the stairs going up on the right (steps of 6 x 6), their dark underside, a rail
    for i in range(9):
        sx = 132 + i * 6
        sy = 70 - i * 6
        rect(cv, sx, sy - 6, SW - sx, 6, "F")       # the riser block
        rect(cv, sx, sy - 6, 6, 1, "f")             # the tread's lit edge
        rect(cv, sx, sy - 5, 1, 5, "D")
        rect(cv, sx + 5, sy - 5, 1, 5, "R")
    for y in range(16, 70):
        for x in range(SW):
            if x >= 132 + (70 - y) and cv.get(x, y) not in ("F", "f", "D", "R"):
                pass
    line(cv, 130, 52, 186, -4, "D")                  # the hand rail and two posts
    line(cv, 130, 53, 186, -3, "R")
    rect(cv, 130, 52, 1, 18, "R")
    rect(cv, 160, 22, 1, 18, "R")
    # the door at the top, light under it and through its cracks
    rect(cv, 174, 0, 18, 16, "C")
    rect(cv, 176, 0, 14, 15, "F")
    rect(cv, 182, 0, 1, 15, "R")
    rect(cv, 176, 15, 14, 1, "Y")
    for (x, y) in ((179, 3), (186, 6), (178, 10)):
        cv.put(x, y, "Z")
    # ---- the left: the coal heap, two barrels, a crate, cobwebs
    for (cx, cy, r) in ((22, 70, 14.0), (34, 70, 9.0)):
        for y in range(int(cy - r), int(cy) + 1):
            for x in range(int(cx - r - 3), int(cx + r + 3)):
                if ((x - cx) / (r + 3.0)) ** 2 + ((y - cy) / r) ** 2 <= 1.0:
                    lump = (x * 7 + y * 13) % 11
                    cv.put(x, y, "L" if lump == 0 else ("3" if lump in (1, 5) or y <= cy - r + 1 else "1"))
    for bx in (46, 60):
        rect(cv, bx, 51, 12, 19, "F")
        rect(cv, bx + 1, 50, 10, 1, "F")
        rect(cv, bx + 1, 51, 3, 19, "f")
        rect(cv, bx + 10, 51, 2, 19, "R")
        for yy in (54, 64):
            rect(cv, bx, yy, 12, 1, "i")
        rect(cv, bx + 2, 50, 8, 1, "D")
    rect(cv, 4, 56, 14, 14, "D")
    rect(cv, 4, 56, 14, 1, "d")
    rect(cv, 4, 62, 14, 1, "F")
    line(cv, 4, 56, 17, 69, "F")
    for (x0, y0, x1, y1) in ((0, 14, 12, 0), (0, 8, 7, 0), (0, 20, 18, 0), (3, 5, 9, 10)):
        line(cv, x0, y0, x1, y1, "S")
    # ---- Martha's chalk on the floor: a circle where the candle stands, an arrow to the stairs
    cx, cy = 96, 82
    for k in range(48):
        import math
        a = k / 48.0 * 2 * math.pi
        x = int(round(cx + math.cos(a) * 16))
        y = int(round(cy + math.sin(a) * 6))
        if k % 6 != 5:
            cv.put(x, y, "A")
    line(cv, 114, 82, 126, 78, "A")
    line(cv, 126, 78, 123, 77, "A")
    line(cv, 126, 78, 123, 80, "A")
    put("talk/open_cellar", T.to_img(cv))


def preview_kitchen(review):
    """The kitchen with Martha in each pose and the candle on the table (for looking at, not shipped)."""
    kitchen = Image.open(os.path.join(ART, "story", "end_kitchen.png")).convert("RGBA")
    hero = Image.open(os.path.join(ART, "hero", "hero_preview.png")).convert("RGBA")
    outs = []
    for pose in ("stand", "match", "light"):
        im = kitchen.copy()
        im.alpha_composite(MADE["talk/martha_" + pose], (98 - MATCH_TIP[0], 39 - MATCH_TIP[1]))
        im.alpha_composite(hero, (98 - 12, 60 - 26))   # the candle stands in front of her (as the opening draws it)
        outs.append(im)
    W = 192 * 4
    out = Image.new("RGBA", (W, 96 * 4 * 3 + 16), (36, 30, 36, 255))
    for i, im in enumerate(outs):
        out.alpha_composite(im.resize((W, 96 * 4), Image.NEAREST), (0, i * (96 * 4 + 8)))
    out.save(os.path.join(review, "kitchen_martha_x4.png"))


# =========================================================================== main
def contact(names, path, scale, bg=(36, 30, 36, 255)):
    ims = [MADE[n] for n in names]
    W = sum(i.width for i in ims) * scale + 8 * (len(ims) + 1)
    H = max(i.height for i in ims) * scale + 16
    out = Image.new("RGBA", (W, H), bg)
    x = 8
    for im in ims:
        out.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, 8))
        x += im.width * scale + 8
    out.save(path)


def main():
    review = None
    for a in sys.argv[1:]:
        if a.startswith("--review"):
            review = a.split("=", 1)[1] if "=" in a else "/tmp/review_talk"
    build_faces()
    build_martha()
    build_martha_stand()
    build_open_cellar()
    for name, im in MADE.items():
        T.check(name, im)
        p = os.path.join(ART, name + ".png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p, optimize=True)
    print("wrote %d files" % len(MADE))
    if review:
        os.makedirs(review, exist_ok=True)
        contact(sorted(n for n in MADE if n.startswith("hero/")), os.path.join(review, "faces_x12.png"), 12, (247, 236, 222, 255))
        contact(["talk/martha_" + k for k in ("f0", "f1", "blink", "smile")], os.path.join(review, "martha_x8.png"), 8)
        contact(["talk/martha_" + k for k in ("stand", "match", "light")], os.path.join(review, "martha_stand_x8.png"), 8)
        contact(["talk/open_cellar"], os.path.join(review, "cellar_x4.png"), 4)
        preview_kitchen(review)


if __name__ == "__main__":
    main()
