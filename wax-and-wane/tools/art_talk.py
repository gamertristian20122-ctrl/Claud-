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
    for name, im in MADE.items():
        T.check(name, im)
        p = os.path.join(ART, name + ".png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p, optimize=True)
    print("wrote %d files" % len(MADE))
    if review:
        os.makedirs(review, exist_ok=True)
        contact(sorted(n for n in MADE if n.startswith("hero/")), os.path.join(review, "faces_x12.png"), 12, (247, 236, 222, 255))
        contact(sorted(n for n in MADE if n.startswith("talk/martha")), os.path.join(review, "martha_x8.png"), 8)


if __name__ == "__main__":
    main()
