#!/usr/bin/env python3
"""Wax & Wane - the house bestiary: original monsters, bosses and their bolts.

Every creature here is drawn to sit next to the 0x72 DungeonTileset II creatures:
  * the 0x72 palette only (PAL below, same letters as tools/art_hero_fx_items.py),
  * a 1 px #222222 outline all round (8-neighbour, so square corners stay square),
  * flat fills with one shade on the back (left) side and the underside,
  * white/dark 2 px eyes, 4-frame idle and 4-frame run loops that bob 1-2 px,
  * small foes on a 16x16 canvas, tall ones 16x22, bosses 32x36 .. 48x40,
    feet on the bottom row so the game can anchor them bottom-centre.

Shapes are hand-authored character grids (one character = one pixel). A few round
bodies (wax blobs, the Wax Mother, the pendulum bob) are pixel ellipses built from
fixed integer maths, so running the script always produces identical PNGs.

Usage:
    python3 tools/art_monsters.py               # write assets/art/monsters/*.png + fx bolts
    python3 tools/art_monsters.py --review DIR  # also write x4 contact sheets to DIR
"""
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
OUTDIR = os.path.join(ART, "monsters")
OX72 = os.path.join(ROOT, "assets", "0x72", "frames")

PAL = {
    ".": None,
    "k": "#222222", "K": "#21141b", "1": "#111111", "2": "#2a2a3a",
    "3": "#333333", "4": "#483b3a", "5": "#775c55",
    "w": "#fdf7ed", "y": "#facb3e", "o": "#ee8e2e", "e": "#e46e33",
    "r": "#da4e38", "c": "#c56025", "R": "#8f4029", "m": "#62232f",
    "p": "#9f294e", "P": "#dc4a7b", "q": "#f78697", "v": "#5f2d56",
    "b": "#5698cc", "B": "#417089", "n": "#5956bd", "t": "#72d6ce",
    "T": "#49a790", "h": "#cae6f5", "g": "#4ba747", "G": "#3d734f",
    "l": "#97da3f", "s": "#314152", "S": "#b6cbcf", "i": "#7b8994",
    "a": "#aa8d7a", "A": "#d3bfa9", "x": "#fccba3", "X": "#e2b694",
    "d": "#d8a57d", "D": "#b58057", "f": "#c38d70", "F": "#8a503e",
}


def rgba(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


# --------------------------------------------------------------------------
# char canvases
# --------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = [["."] * w for _ in range(h)]

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h and ch != ".":
            self.c[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.c[y][x]
        return "."

    def blit(self, rows, dx=0, dy=0, remap=None):
        rows = rows_of(rows)
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch == ".":
                    continue
                if remap and ch in remap:
                    ch = remap[ch]
                self.put(x + dx, y + dy, ch)
        return self

    def copy(self):
        n = Canvas(self.w, self.h)
        n.c = [r[:] for r in self.c]
        return n


def rows_of(block):
    if isinstance(block, (list, tuple)):
        return list(block)
    out = []
    for ln in block.split("\n"):
        s = ln.strip()
        if s:
            out.append(s)
    return out


def render(base, post=None, mode=8, outline_col="#222222"):
    """Canvas -> RGBA image with a 1 px outline round every opaque shape. `post` is
    drawn after the outline (antennae, sparks: details that must stay 1 px thin)."""
    W, H = base.w, base.h
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(H):
        for x in range(W):
            ch = base.c[y][x]
            if ch != ".":
                px[x, y] = rgba(PAL[ch])
    oc = rgba(outline_col)
    nb = ((1, 0), (-1, 0), (0, 1), (0, -1))
    if mode == 8:
        nb += ((1, 1), (-1, 1), (1, -1), (-1, -1))
    add = []
    for y in range(H):
        for x in range(W):
            if base.c[y][x] != ".":
                continue
            for dx, dy in nb:
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H and base.c[Y][X] != ".":
                    add.append((x, y))
                    break
    for x, y in add:
        px[x, y] = oc
    if post is not None:
        for y in range(H):
            for x in range(W):
                ch = post.c[y][x]
                if ch != ".":
                    px[x, y] = rgba(PAL[ch])
    return im


def ellipse(cv, cx, bottom, w, h, fill="P"):
    """A flat pixel ellipse w x h sitting on row `bottom`, centred on cx (cx may be .5)."""
    top = bottom - h + 1
    ry = h / 2.0
    rx = w / 2.0
    cy = top + ry - 0.5
    for y in range(top, bottom + 1):
        dy = (y - cy) / ry
        half = math.sqrt(max(0.0, 1.0 - dy * dy)) * rx
        x0 = int(math.floor(cx - half + 0.5))
        x1 = int(math.ceil(cx + half - 0.5)) - 1
        for x in range(x0, x1 + 1):
            cv.put(x, y, fill)
    return top


def shade_body(cv, fill, hi=None, sh=None, deep=None, hi_frac=0.55):
    """0x72-style flat shading for a single-colour body: a highlight on the top rim of
    the front (right) half, a shade down the back (left) edge, a deep underside."""
    W, H = cv.w, cv.h
    pts = [(x, y) for y in range(H) for x in range(W) if cv.c[y][x] == fill]
    if not pts:
        return
    xs = [p[0] for p in pts]
    x0, x1 = min(xs), max(xs)
    out = cv.copy()
    for x, y in pts:
        up = cv.get(x, y - 1) == "."
        dn = cv.get(x, y + 1) == "."
        lf = cv.get(x - 1, y) == "."
        if deep and dn:
            out.c[y][x] = deep
        elif sh and lf:
            out.c[y][x] = sh
        elif hi and up and x >= x0 + (x1 - x0) * (1 - hi_frac):
            out.c[y][x] = hi
    cv.c = out.c


# --------------------------------------------------------------------------
# output
# --------------------------------------------------------------------------
OUT = []
SHEET = {}


def save(im, name):
    os.makedirs(OUTDIR, exist_ok=True)
    p = os.path.join(OUTDIR, name + ".png")
    im.save(p)
    OUT.append(p)


def save_anim(mon, anim, frames):
    for i, im in enumerate(frames):
        save(im, "%s_%s_f%d" % (mon, anim, i))
    SHEET.setdefault(mon, []).append((anim, frames))


def save_fx(im, name):
    p = os.path.join(ART, "fx", name + ".png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)
    OUT.append(p)
    SHEET.setdefault("_bolts", [("bolts", [])])[0][1].append(im)


# ==========================================================================
# 1. WAX BLOB (16x16) and its WAX DRIBBLE children (16x16, smaller body)
#    rose church-candle wax: q light, P base, p shade, v deep
# ==========================================================================
def wax_blob_frame(w, h, lift=0, flame=0, eyes=True, wick=True, look=0):
    cv = Canvas(16, 16)
    bottom = 14 - lift
    top = ellipse(cv, 7.5, bottom, w, h, "P")
    shade_body(cv, "P", hi="q", sh="p", deep="v")
    # wax drips running down the front
    cv.put(10, top + 2, "q")
    cv.put(10, top + 3, "q")
    cv.put(5, top + 3, "q")
    # eyes: 2x2 dark with a glint, set on the upper body
    if eyes:
        ey = top + max(2, h // 2 - 1)
        for ex in (5 + look, 9 + look):
            cv.put(ex, ey, "k")
            cv.put(ex + 1, ey, "w")
            cv.put(ex, ey + 1, "k")
            cv.put(ex + 1, ey + 1, "k")
        cv.put(7 + look, ey + 2, "v")
        cv.put(8 + look, ey + 2, "v")
    post = Canvas(16, 16)
    if wick:
        cv.put(8, top - 1, "4")
        fl = [("y", "o", 8), ("y", "e", 8), ("y", "o", 9), ("o", "r", 8)][flame % 4]
        post.put(8, top - 2, fl[0])
        post.put(fl[2], top - 3, fl[1])
    return render(cv, post)


def build_wax_blob():
    idle = [wax_blob_frame(12, 8, 0, 0), wax_blob_frame(12, 8, 0, 1),
            wax_blob_frame(13, 7, 0, 2), wax_blob_frame(13, 7, 0, 3)]
    run = [wax_blob_frame(13, 7, 0, 0, look=1), wax_blob_frame(11, 9, 1, 1, look=1),
           wax_blob_frame(10, 10, 2, 2, look=1), wax_blob_frame(12, 8, 0, 3, look=1)]
    save_anim("wax_blob", "idle", idle)
    save_anim("wax_blob", "run", run)


def dribble_frame(w, h, lift=0):
    cv = Canvas(16, 16)
    top = ellipse(cv, 7.5, 14 - lift, w, h, "P")
    shade_body(cv, "P", hi="q", sh="p", deep="v")
    ey = top + 2
    cv.put(6, ey, "k")
    cv.put(9, ey, "k")
    cv.put(9, top + 1, "q")
    return render(cv)


def build_dribble():
    idle = [dribble_frame(7, 5), dribble_frame(7, 5), dribble_frame(8, 4), dribble_frame(8, 4)]
    run = [dribble_frame(8, 4), dribble_frame(6, 6, 1), dribble_frame(6, 6, 2), dribble_frame(7, 5)]
    save_anim("wax_bit", "idle", idle)
    save_anim("wax_bit", "run", run)


# ==========================================================================
# 2. LAMP MOTH (16x16, flying, front view): dusty wings with ember eye-spots
# ==========================================================================
MOTH_WINGS = [
    # wings up
    """
    ................
    ................
    ................
    ..aA........Aa..
    ..aAA......AAa..
    ..aAoA.44.AoAa..
    ...aAAA45AAAa...
    ...aAAA45AAAa...
    ....aAA45AAa....
    ......a45a......
    .....5a45a5.....
    ......a44a......
    .......44.......
    ................
    ................
    ................
    """,
    # wings level
    """
    ................
    ................
    ................
    ................
    ................
    ..aAA..44..AAa..
    .aAAAA.45.AAAAa.
    .aAoAAA45AAAoAa.
    .aAAAAA45AAAAAa.
    ..aAAAA45AAAAa..
    ...a5A.45.A5a...
    ...aa5.44.5aa...
    ....a..44..a....
    ................
    ................
    ................
    """,
    # wings down
    """
    ................
    ................
    ................
    ................
    ................
    ................
    .......44.......
    ..aAAA.45.AAAa..
    .aAAAAA45AAAAAa.
    .aAoAAA45AAAoAa.
    .aAAAAA45AAAAAa.
    ..aa5A.45.A5aa..
    ...aa5.44.5aa...
    ....a......a....
    ................
    ................
    """,
]


def moth_frame(k, dy=0):
    cv = Canvas(16, 16)
    # ash-grey wings, ember eye-spots: never confused with the friendly Moth Friend relic (beige)
    cv.blit(MOTH_WINGS[k], 0, dy, remap={"A": "i", "a": "s", "o": "r", "5": "2", "4": "3"})
    for y in range(16):
        for x in range(16):
            if cv.get(x, y) == "i" and cv.get(x, y - 1) == "." and cv.get(x - 1, y) != ".":
                cv.put(x, y, "S")
    post = Canvas(16, 16)
    # thin feathery antennae (outline colour, never outlined again)
    head = [r for r in range(16) if cv.get(7, r) != "."][0]
    post.put(6, head - 2, "k")
    post.put(9, head - 2, "k")
    post.put(5, head - 3, "k")
    post.put(10, head - 3, "k")
    return render(cv, post)


def build_moth():
    idle = [moth_frame(0), moth_frame(1), moth_frame(2), moth_frame(1)]
    run = [moth_frame(0, 1), moth_frame(1), moth_frame(2, -1), moth_frame(1)]
    save_anim("moth", "idle", idle)
    save_anim("moth", "run", run)


# ==========================================================================
# 3. SNUFFER (16x22): an iron candle snuffer that walks; two embers peep from
#    under its brass rim. Dashes after a wind-up.
# ==========================================================================
SNUFFER_BODY = """
.......yo.......
.......oc.......
......SSis......
.....sSSiis.....
.....sSiiis.....
.....sSiiis.....
.....sSiiis.....
....ssSiiiis....
...ssSSiiiiis...
..yyyyyyyyyyoo..
..oooooooooocc..
...1111111111...
"""


def snuffer_frame(legs, dy=0, eye="ry", lift=0):
    cv = Canvas(16, 22)
    top = 22 - 1 - 12 - 3 + dy - lift
    cv.blit(SNUFFER_BODY, 0, top)
    ey = top + 11
    cv.put(5, ey, eye[0])
    cv.put(6, ey, eye[1])
    cv.put(10, ey, eye[0])
    cv.put(11, ey, eye[1])
    lg = {
        "stand": ["....33....33....", "....33....33...."],
        "step_a": ["....33.....33...", "...33......33..."],
        "step_b": [".....33..33.....", ".....33..33....."],
        "tuck": ["....33....33....", "................"],
    }[legs]
    for i, r in enumerate(lg):
        cv.blit([r], 0, top + 12 + i)
    return render(cv)


def build_snuffer():
    idle = [snuffer_frame("stand"), snuffer_frame("stand"), snuffer_frame("tuck", 1), snuffer_frame("stand")]
    run = [snuffer_frame("step_a"), snuffer_frame("stand", 0, lift=1), snuffer_frame("step_b"), snuffer_frame("stand", 0, lift=1)]
    atk = [snuffer_frame("tuck", 1, eye="ww"), snuffer_frame("step_a", 0, eye="ww")]
    save_anim("snuffer", "idle", idle)
    save_anim("snuffer", "run", run)
    save_anim("snuffer", "atk", atk)


# ==========================================================================
# 4. GRAVE LIGHT (16x16): a cold corpse-candle flame that blinks about
# ==========================================================================
WISP = [
    """
    ........t.......
    .......tt.......
    .......tTt......
    ......ttTt......
    .....tthtTt.....
    ....tthhhtTt....
    ....thhhhhhT....
    ...tthkhhkhtT...
    ...thhkhhkhhT...
    ...thhhhhhhhT...
    ...Tthhhkhhhh...
    ....Tthhhhht....
    ....TTtttttT....
    .....TTTTTT.....
    """,
    """
    .......t........
    .......tt.......
    ......tTt.......
    ......tTtt......
    .....tTthtt.....
    ....ttThhhtt....
    ....Thhhhhht....
    ...tThkhhkhtt...
    ...Thhkhhkhht...
    ...Thhhhhhhht...
    ...hhhhkhhhtT...
    ....thhhhhtT....
    ....TtttttTT....
    .....TTTTTT.....
    """,
    """
    .........t......
    ........tt......
    .......tTt......
    ......ttTt......
    .....tthtTt.....
    ....tthhhtTt....
    ....thhhhhhT....
    ...tthkhhkhtT...
    ...thhkhhkhhT...
    ...thhhhhhhhT...
    ...TthhhkhhhT...
    ....Tthhhhht....
    ....TTtttttT....
    .....TTTTTT.....
    """,
    """
    ......t.........
    ......tt........
    ......tTt.......
    ......tTtt......
    .....tTthtt.....
    ....ttThhhtt....
    ....Thhhhhht....
    ...tThkhhkhtt...
    ...Thhkhhkhht...
    ...Thhhhhhhht...
    ...hhhhkhhhtT...
    ....thhhhhtT....
    ....TtttttTT....
    .....TTTTTT.....
    """,
]


def wisp_frame(k, dy=0, eyes="k"):
    cv = Canvas(16, 16)
    cv.blit(WISP[k], 0, 1 + dy, remap={"k": eyes} if eyes != "k" else None)
    return render(cv, mode=4, outline_col="#2a2a3a")


def build_wisp():
    idle = [wisp_frame(0), wisp_frame(1, 0), wisp_frame(2, 1), wisp_frame(3, 0)]
    run = [wisp_frame(1), wisp_frame(0, -1), wisp_frame(3), wisp_frame(2, 1)]
    atk = [wisp_frame(0, 0, "w"), wisp_frame(2, 0, "w")]
    save_anim("wisp", "idle", idle)
    save_anim("wisp", "run", run)
    save_anim("wisp", "atk", atk)


# ==========================================================================
# 5. SOOTLING (16x16): a puff of chimney soot with two coal-bright eyes
# ==========================================================================
SOOT = [
    """
    ................
    ................
    ................
    ................
    ......5..5......
    .....45445......
    ....43333345....
    ...4333333334...
    ..433333333334..
    ..33yo3333yo33..
    ..33oo3333oo33..
    ..43333333333...
    ..2333311333332.
    ...23333333332..
    ....2.22.22.2...
    ................
    """,
    """
    ................
    ................
    ................
    ................
    .......5..5.....
    .....54454......
    ....54333334....
    ...4333333334...
    ..433333333334..
    ..33yo3333yo33..
    ..33oo3333oo33..
    ...3333333333...
    .23333311333332.
    ..23333333332...
    ...2.22.22.2....
    ................
    """,
]


def soot_frame(k, dy=0, blink=False):
    cv = Canvas(16, 16)
    rows = rows_of(SOOT[k])
    if blink:
        rows = [r.replace("yo", "33") if i == 9 else r.replace("oo", "oo") for i, r in enumerate(rows)]
    cv.blit(rows, 0, dy)
    return render(cv)


def build_soot():
    idle = [soot_frame(0), soot_frame(1), soot_frame(0, 1), soot_frame(1, 1, blink=True)]
    run = [soot_frame(0, -1), soot_frame(1, -2), soot_frame(0, -1), soot_frame(1, 0)]
    save_anim("sootling", "idle", idle)
    save_anim("sootling", "run", run)


# ==========================================================================
# 6. WAXWORK (16x22): a pale wax bride from the parlour. Moves only unwatched.
#    veil w/S (cool), skin x/X/d (warm wax), gown A/a with w lace.
# ==========================================================================
WAXWORK = """
......SwwwS.....
.....SxXXXdS....
.....SXkXkdS....
.....SXXXXdS....
.....SSdddSSS...
....SaAwwwAaS...
....aAAAAAAXXd..
....aAAAAAAa....
.....awwwwa.....
.....aAAAAa.....
....aAAAAAAa....
....aAAAAAAa....
...aAAAAAAAAa...
...aAAAAAAAAa...
..aAAAAAAAAAAa..
..awAwAwAwAwAa..
"""
WAX_HEMS = ["..aaaaaaaaaaaa..", ".aaaaaaaaaaaa...", "...aaaaaaaaaaaa."]


def waxwork_frame(hem=0, dy=0, eyes="k", reach=False):
    cv = Canvas(16, 22)
    rows = rows_of(WAXWORK)
    if reach:
        rows = rows[:]
        rows[5] = "....SaAwwwAAXXd."
        rows[6] = "....aAAAAAAa.dd."
    top = 22 - 1 - len(rows) - 1 + dy
    cv.blit(rows, 0, top, remap={"k": eyes} if eyes != "k" else None)
    cv.blit([WAX_HEMS[hem]], 0, top + len(rows))
    return render(cv)


def build_waxwork():
    idle = [waxwork_frame(0), waxwork_frame(0), waxwork_frame(0), waxwork_frame(0)]
    run = [waxwork_frame(1, 0, "r", True), waxwork_frame(0, -1, "r", True),
           waxwork_frame(2, 0, "r", True), waxwork_frame(0, -1, "r", True)]
    save_anim("waxwork", "idle", idle)
    save_anim("waxwork", "run", run)


# ==========================================================================
# 7. CINDER RAT (16x16): a cellar rat whose back still smoulders
# ==========================================================================
RAT_BODY = """
...........45...
....rooor..455..
...o55555o5555..
..r5555555555rw.
..45555555555...
...4455555544...
"""
RAT_LEGS = {
    "a": ["....4..4..4.4..."],
    "b": ["...4..4....4.4.."],
    "c": [".....44...44...."],
}


def rat_frame(legs, dy=0, tail=0, glow="o"):
    cv = Canvas(16, 16)
    top = 8 + dy
    cv.blit(RAT_BODY, 0, top, remap={"o": glow})
    cv.blit(RAT_LEGS[legs], 0, top + 6)
    post = Canvas(16, 16)
    # thin tail with a live ember at the tip
    tl = [[(1, top + 3), (0, top + 2)], [(1, top + 4), (0, top + 4)], [(1, top + 3), (0, top + 3)]][tail]
    post.put(tl[0][0], tl[0][1], "k")
    post.put(tl[1][0], tl[1][1], "y" if tail != 1 else "o")
    return render(cv, post)


def build_rat():
    idle = [rat_frame("a"), rat_frame("a", 0, 1, "e"), rat_frame("a", 0, 2), rat_frame("a", 0, 1, "e")]
    run = [rat_frame("b", 0, 0), rat_frame("c", -1, 1), rat_frame("a", 0, 2), rat_frame("c", -1, 1)]
    save_anim("cinder_rat", "idle", idle)
    save_anim("cinder_rat", "run", run)


# ==========================================================================
# 8. RESTLESS PSALTER (16x16): a hymn book that flaps its pages at you
# ==========================================================================
PSALTER_BODY = """
.wwwwwwkkwwwwww.
.waaaaAkkAaaaaw.
.wwwwwAkkAwwwww.
.waaawAkkAaaaaw.
.wwwwwAkkAwwwww.
.waaaaAkkAaawww.
.RwwwwAkkAwwwwR.
..RRRRRmmRRRRR..
"""
PSALTER_TOPS = [
    ["..wwwww..wwwww.."],
    ["..ww......wwww..", "..wwwww..wwwww.."],
    ["..wwww......ww..", "..wwwww..wwwww.."],
]
PSALTER_RIBBON = [[(7, 0), (7, 1), (8, 2)], [(8, 0), (8, 1), (7, 2)], [(7, 0), (6, 1), (6, 2)]]


def psalter_frame(k, dy=0, eye=False):
    cv = Canvas(16, 16)
    tops = PSALTER_TOPS[k]
    body = rows_of(PSALTER_BODY)
    if eye:
        body = body[:]
        for i in (2, 3):
            body[i] = body[i][:7] + "rr" + body[i][9:]
        body[1] = body[1][:7] + "kw" + body[1][9:]
    y0 = 4 + dy
    for i, r in enumerate(tops):
        cv.blit([r], 0, y0 - len(tops) + i)
    cv.blit(body, 0, y0)
    post = Canvas(16, 16)
    for (x, y) in PSALTER_RIBBON[k]:
        post.put(x, y0 + len(body) + y, "r")
    return render(cv, post)


def build_psalter():
    idle = [psalter_frame(0), psalter_frame(1), psalter_frame(0, 1), psalter_frame(2, 1)]
    run = [psalter_frame(1), psalter_frame(0, -1), psalter_frame(2), psalter_frame(0, 1)]
    atk = [psalter_frame(0, 0, True), psalter_frame(1, 0, True)]
    save_anim("psalter", "idle", idle)
    save_anim("psalter", "run", run)
    save_anim("psalter", "atk", atk)


# ==========================================================================
# 9. CLAPPER BAT (16x16): a belfry bat carrying a tiny brass bell
# ==========================================================================
BAT = [
    """
    ................
    ................
    ..v..........v..
    ..pv...vv...vp..
    ..ppv.vvvv.vpp..
    ..pvvvvwvwvvvp..
    ...vv.vvvv.vv...
    ...v...vv...v...
    .......yy.......
    ......yyyo......
    ......ooco......
    .......c........
    ................
    """,
    """
    ................
    ................
    ................
    ................
    .......vv.......
    .pvv..vvvv..vvp.
    .ppvvvvwvwvvvpp.
    ..pvv.vvvv.vvp..
    ...v...vv...v...
    .......yy.......
    ......yyyo......
    ......ooco......
    .......c........
    """,
    """
    ................
    ................
    ................
    ................
    .......vv.......
    ......vvvv......
    ..vvvvvwvwvvvv..
    .pvvv.vvvv.vvvp.
    .pv....vv....vp.
    .p.....yy.....p.
    ......yyyo......
    ......ooco......
    .......c........
    """,
]


def bat_frame(k, dy=0, ring=False):
    cv = Canvas(16, 16)
    rows = rows_of(BAT[k])
    if ring:
        rows = [r.replace("yyyo", "wwyy").replace("yy.", "ww.") for r in rows]
    cv.blit(rows, 0, 1 + dy)
    return render(cv)


def build_bat():
    idle = [bat_frame(0), bat_frame(1), bat_frame(2), bat_frame(1)]
    run = [bat_frame(0, 1), bat_frame(1), bat_frame(2, -1), bat_frame(1)]
    atk = [bat_frame(1, 0, True), bat_frame(0, 0, True)]
    save_anim("clapper_bat", "idle", idle)
    save_anim("clapper_bat", "run", run)
    save_anim("clapper_bat", "atk", atk)


# ==========================================================================
# 10. DEATHWATCH BEETLE (16x16, top-down): clockwork beetle with a wind-up key
# ==========================================================================
BEETLE = """
....yyyyyo......
...yyyyoooc.....
..yyyoooRocc33..
..yyooooRocc3w3.
..oooooRcccR333.
..RcccccRRRR.33.
"""
BEETLE_KEY = [
    ["....SiS.........", ".....i.........."],
    ["....SSS.........", ".....i.........."],
    [".....S..........", ".....i.........."],
    ["....SSS.........", ".....i.........."],
]
BEETLE_LEGS = ["...3.3.3..3.3...", "..3.3.3..3.3...."]


def beetle_frame(k, dy=0):
    cv = Canvas(16, 16)
    top = 8 + dy
    cv.blit(BEETLE_KEY[k], 0, top - 2)
    cv.blit(BEETLE, 0, top)
    cv.blit([BEETLE_LEGS[k % 2]], 0, top + 6)
    return render(cv)


def build_beetle():
    save_anim("deathwatch", "idle", [beetle_frame(0), beetle_frame(1), beetle_frame(2), beetle_frame(3)])
    save_anim("deathwatch", "run", [beetle_frame(0), beetle_frame(1, -1), beetle_frame(2), beetle_frame(3, -1)])


# ==========================================================================
# 11. GRAVE HAND (16x16): burrows under the floor and grabs from below
# ==========================================================================
MOUND = """
................
................
................
................
................
................
................
................
................
................
................
......f..f......
....FfFFfFFF....
..4FFfFFFFfFF4..
..44FFFFFFFF44..
................
"""
HAND_UP = """
................
................
.....A.A.A......
.....A.A.AA.....
.....AAAAA.A....
....aAAAAAAA....
....aAAGAAAa....
....aAAAAAAa....
.....aAAGAa.....
.....aAAAAa.....
.....aAAAAa.....
......f..f......
....FfFFfFFF....
..4FFfFFFFfFF4..
..44FFFFFFFF44..
................
"""
HAND_FINGERS = """
................
................
................
................
................
................
................
.....A.A.A......
.....A.A.AA.....
....aAAAAAAa....
....aAGAAAAa....
......f..f......
....FfFFfFFF....
..4FFfFFFFfFF4..
..44FFFFFFFF44..
................
"""
HAND_FIST = """
................
................
................
................
.....AAAAA......
....aAAAAAA.....
....aAGAAAAA....
....aAAAAAAa....
....aAAAAAAa....
.....aAAGAa.....
.....aAAAAa.....
......f..f......
....FfFFfFFF....
..4FFfFFFFfFF4..
..44FFFFFFFF44..
................
"""


def hand_frame(block, dy=0):
    cv = Canvas(16, 16)
    cv.blit(block, 0, dy)
    return render(cv)


def build_hand():
    up = hand_frame(HAND_UP)
    up2 = hand_frame(HAND_UP, 1)
    save_anim("grave_hand", "idle", [up, up, up2, up2])
    save_anim("grave_hand", "run", [up, up2, up, up2])
    save_anim("grave_hand", "rise", [hand_frame(MOUND), hand_frame(HAND_FINGERS), up])
    save_anim("grave_hand", "grab", [hand_frame(HAND_FIST)])
    save_anim("grave_hand", "mound", [hand_frame(MOUND), hand_frame(MOUND, 1)])


# ==========================================================================
# 12. GUTTERSPOUT (16x18): a crouched stone gargoyle; fires along its line
# ==========================================================================
GARGOYLE = """
...S........S...
...Si......iS...
....SiiiiiiS....
...sSiiiiiiis...
..ssSkkiikkiss..
..ssSyyiiyyiss..
..ssiiiiiiiiss..
.sssSi1111iiss..
.ssssi1kk1issss.
.sssssi11iisss..
..sssiiiiiisss..
...siSiiiiSis...
...siiiiiiiis...
...ss.ss.ss.s...
"""


def gargoyle_frame(eyes="yy", mouth="kk", dy=0):
    cv = Canvas(16, 18)
    rows = rows_of(GARGOYLE)
    rows[5] = rows[5].replace("yy", eyes)
    rows[8] = rows[8].replace("kk", mouth)
    cv.blit(rows, 0, 17 - len(rows) + dy)
    return render(cv)


def build_gargoyle():
    idle = [gargoyle_frame(), gargoyle_frame(), gargoyle_frame("ii"), gargoyle_frame()]
    save_anim("gutterspout", "idle", idle)
    save_anim("gutterspout", "run", idle)
    save_anim("gutterspout", "atk", [gargoyle_frame("ww", "rr"), gargoyle_frame("ww", "oo")])


# ==========================================================================
# BOLTS (7x7 enemy shots): drawn by tools/art_fx2.py, which owns every enemy shot (fix/art UX-02:
# dark-rimmed, white-hot tokens that never read as Tallow's embers). Written here too so a run of
# this tool alone leaves them current, and shown on the --review sheet.
# ==========================================================================
def build_bolts():
    import art_fx2
    for n, im in art_fx2.enemy_shot_images(["bolt_page", "bolt_ring", "bolt_wax", "bolt_bone"]).items():
        save_fx(im, n)


# ==========================================================================
# 0x72 creatures that ship with odd frame names: copy them under our scheme
# ==========================================================================
def build_0x72_fixups():
    # zombie_anim ships as f10, f1, f2, f3 (no f0)
    src = ["zombie_anim_f10", "zombie_anim_f1", "zombie_anim_f2", "zombie_anim_f3"]
    frames = []
    for s in src:
        p = os.path.join(OX72, s + ".png")
        if not os.path.exists(p):
            return
        frames.append(Image.open(p).convert("RGBA"))
    save_anim("zombie", "idle", frames)
    save_anim("zombie", "run", [frames[1], frames[2], frames[3], frames[0]])


# ==========================================================================
# House touches on 0x72 lodgers (fix/art): the 0x72 frames with a few pixels of our own, written
# under our naming so Enemy.frames_for() picks them up instead of the stock frames. Edits are placed
# from each frame's top row, so they ride the stock idle/run bob exactly.
# ==========================================================================
def ox72_frames(name, anim):
    """The stock frames of `anim` ("idle" / "run"; the single `_anim` set for creatures that have one)."""
    out = []
    for f in range(4):
        for stem in ("%s_%s_anim_f%d" % (name, anim, f), "%s_anim_f%d" % (name, f)):
            p = os.path.join(OX72, stem + ".png")
            if os.path.exists(p):
                out.append(Image.open(p).convert("RGBA"))
                break
    return out


def top_row(im):
    a = im.split()[3].load()
    for y in range(im.height):
        if any(a[x, y] for x in range(im.width)):
            return y
    return im.height


def build_house_touches():
    # Puddle Lump (muddy): coal dust and rainwater. A drop of rainwater glints in each eye hole, the one
    # light thing on it, so it never vanishes on a dark floor (Enemy.DEFS glow_px #cae6f5, UX-03).
    glint = rgba(PAL["h"])
    for anim in ("idle", "run"):
        frames = []
        for im in ox72_frames("muddy", anim):
            im = im.copy()
            t = top_row(im)
            for x in (6, 11):
                im.putpixel((x, t + 3), glint)
            frames.append(im)
        if frames:
            save_anim("muddy", anim, frames)
    # The three stock lodgers met first (the opening rooms, the trailer) get the house in them:
    for anim in ("idle", "run"):
        save_anim("tiny_zombie", anim, [shambler(im, i) for i, im in enumerate(ox72_frames("tiny_zombie", anim))])
        save_anim("goblin", anim, [larder_thief(im, i) for i, im in enumerate(ox72_frames("goblin", anim))])
        save_anim("tiny_slug", anim, [damp_slug(im, i) for i, im in enumerate(ox72_frames("tiny_slug", anim))])


def recolour_px(im, x, y, src, dst):
    if 0 <= x < im.width and 0 <= y < im.height and im.getpixel((x, y)) == rgba(PAL[src]):
        im.putpixel((x, y), rgba(PAL[dst]))


def overlay(base, draw):
    """Draw extra bits on a char canvas the size of `base` (outlined by render) and lay them over it."""
    cv, post = Canvas(base.width, base.height), Canvas(base.width, base.height)
    draw(cv, post)
    out = base.copy()
    out.alpha_composite(render(cv, post))
    return out


def shambler(im, i):
    """Coal-Bin Shambler (tiny_zombie): a cap of coal dust on its head, dust down its face, and two
    coal-bright sparks in its eye holes (glow_px #ee8e2e)."""
    im = im.copy()
    t = top_row(im)
    for x in range(5, 12):
        recolour_px(im, x, t + 1, "A", "4" if x not in (9, 10) else "5")
    for x in (5, 7, 11):
        recolour_px(im, x, t + 2, "A", "4")
    recolour_px(im, 8, t + 2, "A", "5")
    for x in (7, 11):
        im.putpixel((x, t + 3), rgba(PAL["o"]))
    return im


def larder_thief(im, i):
    """Larder Thief (goblin): wears a stolen candle end on its head, still lit (glow_px: the flame)."""
    t = top_row(im)

    def draw(cv, post):
        _bosses.candle(cv, post, 5, t - 1, 3, i)
    return overlay(im, draw)


def damp_slug(im, i):
    """Damp Slug (tiny_slug): has crawled into a brass candle cup and wears it as a shell."""
    t = top_row(im)
    a = im.split()[3].load()
    # the hump: the topmost body row under the eye stalks
    y0 = t + 4 if any(a[x, t + 4] for x in range(4, 8)) else t + 5

    def draw(cv, post):
        for x, ch in zip(range(4, 9), "yyyyo"):
            cv.put(x, y0 - 1, ch)
        for x, ch in zip(range(4, 9), "oooco"):
            cv.put(x, y0, ch)
        for x in range(5, 8):
            cv.put(x, y0 + 1, "c")
        cv.put(5, y0 - 2, "A")   # a crust of old wax on the rim
        cv.put(6, y0 - 2, "X")
    return overlay(im, draw)


# ==========================================================================
# review sheets
# ==========================================================================
def contact_sheet(path, names, bg=(36, 30, 36, 255), scale=4):
    rows = []
    for n in names:
        anims = SHEET.get(n, [])
        ims = [im for _, fr in anims for im in fr]
        if ims:
            rows.append(ims)
    if not rows:
        return
    W = max(sum(i.width + 3 for i in r) for r in rows) + 3
    H = sum(max(i.height for i in r) + 3 for r in rows) + 3
    sheet = Image.new("RGBA", (W, H), bg)
    y = 3
    for r in rows:
        x = 3
        hh = max(i.height for i in r)
        for im in r:
            sheet.paste(im, (x, y + hh - im.height), im)
            x += im.width + 3
        y += hh + 3
    sheet.resize((W * scale, H * scale), Image.NEAREST).save(path)


TOWER_OWNED = ("cog_sentry_", "minute_wraith_", "keeper_")


def main():
    # clear old PNGs (keep Godot's .import files so re-running does not churn the import cache),
    # but never the Clock Tower creatures: tools/art_tower.py writes those into the same folder
    os.makedirs(OUTDIR, exist_ok=True)
    for f in os.listdir(OUTDIR):
        if f.endswith(".png") and not f.startswith(TOWER_OWNED):
            os.remove(os.path.join(OUTDIR, f))
    build_wax_blob()
    build_dribble()
    build_moth()
    build_snuffer()
    build_wisp()
    build_soot()
    build_waxwork()
    build_rat()
    build_psalter()
    build_bat()
    build_beetle()
    build_hand()
    build_gargoyle()
    build_bosses()
    build_bolts()
    build_0x72_fixups()
    build_house_touches()
    if "--review" in sys.argv:
        d = sys.argv[sys.argv.index("--review") + 1]
        os.makedirs(d, exist_ok=True)
        small = [n for n in SHEET if not n.startswith("_") and n not in BOSS_NAMES]
        contact_sheet(os.path.join(d, "monsters.png"), small)
        contact_sheet(os.path.join(d, "monsters_light.png"), small, bg=(120, 150, 120, 255))
        contact_sheet(os.path.join(d, "bosses.png"), BOSS_NAMES, scale=3)
        contact_sheet(os.path.join(d, "bolts.png"), ["_bolts"], scale=8)
    print("wrote %d files" % len(OUT))


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_monsters_bosses as _bosses  # noqa: E402

BOSS_NAMES = _bosses.BOSS_NAMES


def build_bosses():
    _bosses.bind(sys.modules[__name__])
    _bosses.build_bosses()


if __name__ == "__main__":
    main()
