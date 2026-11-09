"""Wax & Wane - boss sprites for tools/art_monsters.py (imported from there; not run alone).

The Wax Mother (floor 1), the Sexton (floor 2), the Melted Choir (floor 3) and the Great
Pendulum (floor 4). Same rules as the small monsters: 0x72 palette, 1 px #222222 outline,
flat fills, one shade on the back and underside, fixed geometry (no randomness).
"""
import math

Canvas = ellipse = render = save_anim = shade_body = None


def bind(mod):
    """Use the drawing helpers of the running art_monsters module (avoids a second import)."""
    global Canvas, ellipse, render, save_anim, shade_body
    Canvas, ellipse, render, save_anim, shade_body = mod.Canvas, mod.ellipse, mod.render, mod.save_anim, mod.shade_body


def rect(cv, x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cv.put(x, y, ch)


def line(cv, x0, y0, x1, y1, ch, thick=1):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        for t in range(thick):
            cv.put(x0 + t, y0, ch)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def trapezoid(cv, cx, y0, y1, w0, w1, ch):
    for y in range(y0, y1 + 1):
        k = 0 if y1 == y0 else (y - y0) / (y1 - y0)
        w = int(round(w0 + (w1 - w0) * k))
        x0 = int(math.floor(cx - w / 2.0 + 0.5))
        for x in range(x0, x0 + w):
            cv.put(x, y, ch)


def top_of(cv, x):
    for y in range(cv.h):
        if cv.c[y][x] != ".":
            return y
    return cv.h


def candle(cv, post, x, base_y, h, flame):
    """A 3 px cream candle stub standing on base_y, wick + flame on top."""
    for y in range(base_y - h + 1, base_y + 1):
        cv.put(x, y, "w")
        cv.put(x + 1, y, "X")
        cv.put(x + 2, y, "d")
    top = base_y - h + 1
    cv.put(x + 2, top + 1, "X")
    cv.put(x + 2, top + 2, "X")
    post.put(x + 1, top - 1, "4")
    f = flame % 4
    post.put(x + 1, top - 2, "y")
    post.put(x + 1 + (1 if f == 2 else 0), top - 3, "o" if f != 3 else "y")
    if f != 1:
        post.put(x + 1 + (1 if f == 2 else (-1 if f == 3 else 0)), top - 4, "r" if f != 3 else "o")


# --------------------------------------------------------------------------
# THE WAX MOTHER (40x36): a mound of rose wax with three lit stubs in her crown
# --------------------------------------------------------------------------
def wax_mother_frame(w=34, h=24, mouth=0, flame=0, lid=True):
    cv = Canvas(40, 36)
    post = Canvas(40, 36)
    bottom = 34
    top = ellipse(cv, 19.5, bottom, w, h, "p")
    ellipse(cv, 4.5, bottom, 9, 6, "p")
    ellipse(cv, 34.5, bottom, 9, 6, "p")
    shade_body(cv, "p", hi="P", sh="v", deep="m")
    # a rim of fresh rose wax round her crown, running down in long drips
    for x in range(8, 33):
        t = top_of(cv, x)
        if cv.get(x, t + 1) == "p":
            cv.put(x, t + 1, "P")
    for x, ln in ((8, 6), (13, 4), (16, 8), (24, 5), (28, 7), (32, 4)):
        t = top_of(cv, x)
        for y in range(t + 1, t + 1 + ln):
            cv.put(x, y, "P")
        cv.put(x, t + 1 + ln, "q")
    # stubs sunk in her crown, cream wax pouring over her
    for i, (x, hh) in enumerate(((10, 6), (16, 10), (22, 8), (28, 5))):
        base = top_of(cv, x + 1) + 2
        candle(cv, post, x, base, hh, flame + i)
        cv.put(x + 2, base + 1, "X")
        cv.put(x + 2, base + 2, "X")
    # sorrowful eyes: deep sockets, a far-off glint, heavy wax lids and tears
    ey = top + 10
    for ex in (11, 25):
        rect(cv, ex, ey, ex + 3, ey + 2, "1")
        rect(cv, ex + 1, ey + 3, ex + 2, ey + 3, "1")
        cv.put(ex + 2, ey + 1, "w" if not lid else "1")
        cv.put(ex + 1, ey + 1, "1")
        for k in range(4):
            cv.put(ex + k, ey - 1, "P")
        if lid:
            for k in range(4):
                cv.put(ex + k, ey, "v")
            cv.put(ex + 2, ey + 1, "w")
        for y in range(ey + 4, ey + 8):
            cv.put(ex + (0 if ex < 20 else 3), y, "q")
    # the shed children peeping from her skirts
    for bx in (3, 34):
        cv.put(bx, 31, "1")
        cv.put(bx + 2, 31, "1")
    my = top + 17
    if mouth:
        ellipse(cv, 19.5, my + 2 + mouth, 8, 4 + mouth, "1")
        rect(cv, 17, my - 1 + 1, 22, my - 1 + 1, "m")
    else:
        for x in range(15, 25):
            cv.put(x, my + (1 if x in (15, 24) else 0) + (1 if x in (16, 23) else 0) * 0, "m")
        cv.put(15, my + 2, "m")
        cv.put(24, my + 2, "m")
    return render(cv, post)


def build_wax_mother():
    idle = [wax_mother_frame(34, 24, 0, 0), wax_mother_frame(34, 24, 0, 1),
            wax_mother_frame(35, 23, 0, 2), wax_mother_frame(35, 23, 0, 3, lid=False)]
    run = [wax_mother_frame(35, 23, 0, 0), wax_mother_frame(33, 25, 0, 1),
           wax_mother_frame(34, 24, 0, 2), wax_mother_frame(36, 22, 0, 3)]
    atk = [wax_mother_frame(33, 25, 1, 0, lid=False), wax_mother_frame(36, 23, 2, 2, lid=False)]
    save_anim("wax_mother", "idle", idle)
    save_anim("wax_mother", "run", run)
    save_anim("wax_mother", "atk", atk)


# --------------------------------------------------------------------------
# THE SEXTON (32x36): the hooded gravedigger, spade in hand
# --------------------------------------------------------------------------
def sexton_frame(step=0, dy=0, eyes="y", spade="hold", blink=False):
    cv = Canvas(32, 36)
    b = 34
    bx = {0: (9, 16), 1: (8, 17), 2: (11, 15)}[step]
    rect(cv, bx[0], b - 1, bx[0] + 3, b, "3")
    rect(cv, bx[1], b - 1, bx[1] + 3, b, "3")
    trapezoid(cv, 14, 17 + dy, b - 2, 10, 16, "F")
    shade_body(cv, "F", hi="f", sh="R", deep="m")
    for x in range(4, 26):
        if cv.get(x, 25 + dy) != ".":
            cv.put(x, 25 + dy, "D")
    cv.put(15, 26 + dy, "D")
    cv.put(15, 27 + dy, "D")
    for y in range(27 + dy, b - 2):
        cv.put(12, y, "R")
    ellipse(cv, 15.5, 20 + dy, 13, 12, "4")
    shade_body(cv, "4", hi="5", sh="3", deep=None)
    ellipse(cv, 17.5, 19 + dy, 7, 7, "1")
    if not blink:
        cv.put(16, 15 + dy, eyes)
        cv.put(19, 15 + dy, eyes)
    if spade == "hold":
        line(cv, 25, 8 + dy, 23, 27 + dy, "D")
        line(cv, 26, 9 + dy, 24, 27 + dy, "F")
        rect(cv, 23, 7 + dy, 27, 7 + dy, "D")
        rect(cv, 21, 28 + dy, 26, b - 1, "i")
        rect(cv, 21, 28 + dy, 21, b - 1, "S")
        rect(cv, 22, b - 1, 26, b - 1, "s")
        hand = (21, 20 + dy)
    elif spade == "raise":
        line(cv, 21, 2 + dy, 25, 20 + dy, "D")
        line(cv, 22, 2 + dy, 26, 20 + dy, "F")
        rect(cv, 24, 20 + dy, 29, 26 + dy, "i")
        rect(cv, 24, 20 + dy, 24, 26 + dy, "S")
        rect(cv, 25, 26 + dy, 29, 26 + dy, "s")
        hand = (20, 13 + dy)
    else:
        line(cv, 18, 14 + dy, 26, 29, "D")
        line(cv, 19, 14 + dy, 27, 29, "F")
        rect(cv, 24, 30, 30, b, "i")
        rect(cv, 24, 30, 24, b, "S")
        rect(cv, 25, b, 30, b, "s")
        hand = (21, 20 + dy)
    line(cv, 17, 22 + dy, hand[0], hand[1] + 1, "F", 2)
    rect(cv, hand[0], hand[1], hand[0] + 2, hand[1] + 1, "A")
    cv.put(hand[0], hand[1] + 1, "a")
    return render(cv)


def sexton_mound(k):
    cv = Canvas(32, 36)
    line(cv, 22, 12 - k, 21, 27 - k, "D")
    line(cv, 23, 13 - k, 22, 27 - k, "F")
    rect(cv, 20, 11 - k, 24, 11 - k, "D")
    ellipse(cv, 15.5, 34, 26, 8 + k, "F")
    shade_body(cv, "F", hi="f", sh="4", deep="4")
    for x, y in ((9, 30), (14, 29), (20, 29), (24, 31), (12, 32)):
        cv.put(x, y - k, "f")
    return render(cv)


def build_sexton():
    idle = [sexton_frame(0), sexton_frame(0), sexton_frame(0, 1), sexton_frame(0, 1, blink=True)]
    run = [sexton_frame(1), sexton_frame(0, -1), sexton_frame(2), sexton_frame(0, -1)]
    atk = [sexton_frame(0, 0, "w", "raise"), sexton_frame(0, 1, "w", "strike")]
    save_anim("sexton", "idle", idle)
    save_anim("sexton", "run", run)
    save_anim("sexton", "atk", atk)
    save_anim("sexton", "mound", [sexton_mound(0), sexton_mound(1)])


# --------------------------------------------------------------------------
# THE MELTED CHOIR (48x40): three wax choristers who sing in turn
# --------------------------------------------------------------------------
CHOIR_HEAD = """
....HHHHHH....
...HHHHHHHH...
..HHHHHHHHHH..
..HHwwAAAAHH..
..aA11AA11Aa..
..aA11AA11Aa..
..aAaAAAAaAa..
..aAaAMMAaAa..
...aAAMMAAa...
....aAAAAa....
"""
CHOIR_BODY = """
..wAwwwwwwAw..
.wAwAwAwAwAww.
..rwwwwwwwwr..
.rrwwwwwwwwrr.
.rAwwwwwwwwAr.
.rAwwwwwwwwAr.
.rwAwAwAwAwwr.
..Rrrrrrrrrr..
..Rrrrrrrrrr..
..RrrrRrrrrr..
..Rrrrrrrrrr..
.RRrrrrrRrrrr.
.mmmmmmmmmmmm.
"""


def chorister(cv, post, x0, b, hair, sing=False, sway=0, flame=0):
    head = rows_of(CHOIR_HEAD)
    body = rows_of(CHOIR_BODY)
    top = b - len(body) + 1
    cv.blit(body, x0, top)
    if sing:
        head = head[:]
        head[4] = head[4].replace("11AA11", "1wAA1w")
        head[7] = head[7].replace("MM", "11")
        head[8] = head[8].replace("MM", "11")
        head[9] = head[9].replace("aAAAAa", "aA11Aa")
        hy = top - len(head) - 1
    else:
        head = [r.replace("MM", "AA") for r in head]
        head[7] = head[7].replace("aAaAAAAaAa", "aAaAaaAaAa")
        hy = top - len(head) + 1
    cv.blit(head, x0 + sway, hy, remap={"H": hair})
    # a lit candle held before the chest
    candle(cv, post, x0 + 8, top + 7, 6, flame)
    cv.put(x0 + 7, top + 6, "w")
    cv.put(x0 + 11, top + 6, "A")


def rows_of(block):
    return [ln.strip() for ln in block.split("\n") if ln.strip()]


def choir_frame(sing=(), sway=(0, 0, 0), flame=0):
    cv = Canvas(48, 40)
    post = Canvas(48, 40)
    rect(cv, 15, 36, 32, 38, "F")
    rect(cv, 15, 36, 32, 36, "f")
    rect(cv, 15, 38, 32, 38, "R")
    chorister(cv, post, 17, 35, "i", 1 in sing, sway[1], flame + 1)
    chorister(cv, post, 2, 38, "F", 0 in sing, sway[0], flame)
    chorister(cv, post, 32, 38, "3", 2 in sing, sway[2], flame + 2)
    return render(cv, post)


def build_choir():
    idle = [choir_frame((), (0, 0, 0), 0), choir_frame((), (-1, 0, 1), 1),
            choir_frame((), (0, 1, 0), 2), choir_frame((), (1, 0, -1), 3)]
    save_anim("choir", "idle", idle)
    save_anim("choir", "run", idle)
    save_anim("choir", "sing", [choir_frame((0,)), choir_frame((1,)), choir_frame((2,)), choir_frame((0, 1, 2))])


# --------------------------------------------------------------------------
# THE GREAT PENDULUM (32x34): the house clock's brass bob, with a stern face
# --------------------------------------------------------------------------
def pendulum_frame(glint=0, angry=False):
    cv = Canvas(32, 34)
    # the hanging loop the rod runs through
    rect(cv, 13, 0, 18, 4, "c")
    rect(cv, 15, 1, 16, 3, ".")
    cv.put(13, 0, "o")
    cv.put(18, 0, "o")
    ellipse(cv, 15.5, 32, 28, 28, "y")
    shade_body(cv, "y", hi="w", sh="o", deep="c")
    # an engraved dial ring with twelve hour marks
    inner = Canvas(32, 34)
    ellipse(inner, 15.5, 29, 22, 22, "y")
    for y in range(34):
        for x in range(32):
            if inner.get(x, y) != "." and any(inner.get(x + dx, y + dy) == "."
                                              for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.put(x, y, "o")
    for h in range(12):
        a = h * math.pi / 6.0
        x = int(round(15.5 + math.sin(a) * 9.0 - 0.5 + 0.5))
        y = int(round(18.5 - math.cos(a) * 9.0))
        cv.put(x, y, "c")
    # the face: heavy brows, deep-set eyes, a hard mouth
    ey = 15
    for ex in (9, 19):
        rect(cv, ex, ey - 2, ex + 3, ey - 2, "c")
        cv.put(ex + (3 if ex < 15 else 0), ey - 1, "c")
        rect(cv, ex, ey, ex + 3, ey + 1, "R")
        cv.put(ex + 1, ey, "r" if angry else "o")
        cv.put(ex + 2, ey, "r" if angry else "o")
    rect(cv, 15, 16, 16, 19, "o")
    cv.put(15, 19, "c")
    cv.put(16, 19, "c")
    if angry:
        rect(cv, 12, 22, 19, 24, "1")
        rect(cv, 12, 22, 19, 22, "R")
    else:
        rect(cv, 12, 23, 19, 23, "R")
        cv.put(11, 24, "c")
        cv.put(20, 24, "c")
    gl = [(7, 10), (6, 13), (5, 17), (6, 13)][glint]
    cv.put(gl[0], gl[1], "w")
    cv.put(gl[0] + 1, gl[1] - 1, "w")
    return render(cv)


def build_pendulum():
    idle = [pendulum_frame(i) for i in range(4)]
    save_anim("pendulum", "idle", idle)
    save_anim("pendulum", "run", idle)
    save_anim("pendulum", "atk", [pendulum_frame(0, True), pendulum_frame(2, True)])


# --------------------------------------------------------------------------
# THE HOLLOW WARDEN (36x40): empty vestments that still keep watch. A pewter cowl and robe
# hovering over a ragged hem, a wine stole, nothing in the hood but two cold eye-lights, and
# a brass lantern hanging from an empty sleeve. The eye-lights and the lantern glass use the
# pale/cyan pair (h, t) that nothing else on it uses: the game draws exactly those colours
# unlit (Enemy.DEFS["necro_boss"]["glow_px"]), so they shine in the dark chapel.
# --------------------------------------------------------------------------
LANTERN = """
...o...
..o.o..
.yoooy.
.chthc.
.ctwtc.
.ctwtc.
.cTtTc.
.yoooy.
..ccc..
"""


def spans(cv, rows, x0, y0, ch):
    """rows = [(left, right), ...] inclusive pixel spans, one per row from y0; None skips a row."""
    for i, r in enumerate(rows):
        if r:
            for x in range(x0 + r[0], x0 + r[1] + 1):
                cv.put(x, y0 + i, ch)


def warden_frame(bob=0, hem=0, lean=0, swing=0, arm="hold", eyes="open"):
    cv = Canvas(36, 40)
    post = Canvas(36, 40)
    d = bob
    cx = 15
    # the robe: a long bell from the shoulders to a ragged hem that never touches the floor
    trapezoid(cv, cx + 0.5 + lean * 0.5, 19 + d, 34 + d, 15, 21, "i")
    for x in range(cx - 10, cx + 12):
        if cv.get(x, 34 + d) == "i":
            ln = (1, 3, 4, 2, 3)[(x + hem) % 5]
            for y in range(35 + d, 35 + d + ln):
                cv.put(x, y, "i")
    shade_body(cv, "i", hi="S", sh="s", deep="2")
    for y in range(22 + d, 33 + d):                          # three long folds
        cv.put(cx - 4 + lean, y, "s")
    for y in range(24 + d, 34 + d):
        cv.put(cx + 1 + lean, y, "s")
    for y in range(27 + d, 35 + d):
        cv.put(cx + 7, y, "s")
    # the mantle: a short cape over the shoulders
    hx = cx + lean
    trapezoid(cv, hx + 0.5, 15 + d, 20 + d, 13, 18, "i")
    for x in range(hx - 9, hx + 10):
        if cv.get(x, 20 + d) == "i":
            cv.put(x, 20 + d, "s")
            if cv.get(x, 21 + d) in ("i", "S"):
                cv.put(x, 21 + d, "2")
    # the stole: two wine bands from the collar, gold fringe at the ends
    for bx, y1 in ((cx - 2 + lean, 30), (cx + 3 + lean, 31)):
        for y in range(16 + d, y1 + d):
            cv.put(bx, y, "m" if bx < cx else "p")
            cv.put(bx + 1, y, "p")
        cv.put(bx, y1 + d, "y")
        cv.put(bx + 1, y1 + d, "o")
    # the cowl: a tall hood with its point falling back
    spans(cv, [(-4, -3), (-5, -1), (-6, 2), (-6, 3), (-6, 4), (-6, 5), (-6, 5), (-6, 6), (-6, 6), (-6, 6),
               (-6, 6), (-6, 6), (-6, 6), (-5, 6)], hx, 3 + d, "i")
    shade_body(cv, "i", hi="S", sh="s", deep=None)
    # nothing inside: a deep void with the cloth's pale front edge round it
    spans(cv, [(1, 3), (0, 4), (-1, 5), (-1, 5), (-1, 5), (-1, 5), (-1, 5), (0, 5), (0, 4)], hx, 7 + d, "1")
    for y in range(7 + d, 16 + d):
        cv.put(hx + 6, y, "S")
    ey = 11 + d
    if eyes == "blink":
        for ex in (hx, hx + 3):
            cv.put(ex, ey + 1, "t")
            cv.put(ex + 1, ey + 1, "t")
    else:
        for ex in (hx, hx + 3):
            cv.put(ex, ey, "h")
            cv.put(ex + 1, ey, "h")
            if eyes == "flare":
                cv.put(ex, ey + 1, "t")
                cv.put(ex + 1, ey + 1, "t")
    # the lantern arm: a wide empty sleeve reaching forward, the lantern hangs from inside it
    if arm == "raise":
        spans(cv, [(10, 13), (8, 13), (6, 13), (5, 12), (4, 11), (4, 9)], hx, 9 + d, "i")
        for y in range(9 + d, 12 + d):
            cv.put(hx + 13, y, "1")
            cv.put(hx + 12, y, "1")
        for y in range(10 + d, 15 + d):
            if cv.get(hx + 5, y) == "i":
                cv.put(hx + 5, y, "s")
        top, lx = 12 + d, hx + 13 + swing
    else:
        spans(cv, [(5, 8), (5, 10), (5, 11), (5, 12), (6, 13), (8, 13)], hx, 18 + d, "i")
        for y in range(20 + d, 24 + d):
            cv.put(hx + 13, y, "1")
        cv.put(hx + 12, 22 + d, "1")
        cv.put(hx + 12, 23 + d, "1")
        for x in range(hx + 6, hx + 12):
            cv.put(x, 23 + d, "s")
        top, lx = 24 + d, hx + 13 + swing
    post.put(hx + 13, top, "S")
    post.put(lx, top + 1, "S")
    cv.blit(rows_of(LANTERN), lx - 3, top + 2)
    return render(cv, post)


def build_warden():
    idle = [warden_frame(0, 0, swing=0), warden_frame(0, 1, swing=1),
            warden_frame(1, 2, swing=0), warden_frame(1, 3, swing=-1, eyes="blink")]
    run = [warden_frame(0, 0, 1, 1), warden_frame(1, 2, 1, 0),
           warden_frame(0, 4, 1, -1), warden_frame(1, 1, 1, 0)]
    atk = [warden_frame(0, 0, arm="raise", eyes="flare"), warden_frame(1, 2, arm="raise", swing=1, eyes="flare"),
           warden_frame(0, 4, arm="raise", eyes="flare"), warden_frame(1, 1, arm="raise", swing=-1, eyes="flare")]
    save_anim("necro_boss", "idle", idle)
    save_anim("necro_boss", "run", run)
    save_anim("necro_boss", "atk", atk)


# ==========================================================================
# v2.1: one more guardian per floor (scripts/game/guardians_v21.gd)
# ==========================================================================

# --------------------------------------------------------------------------
# THE COAL FURNACE (40x40): the cellar boiler come alive. A squat pot-bellied iron stove on claw feet,
# a riveted seam round its belly, a grate of iron teeth over live coals for a mouth, two slit vents
# that glare, a stovepipe on top. The coals and eye-slits are its only y / o / e / w pixels: the game
# draws exactly those unlit (Enemy.DEFS["furnace"]["glow_px"]), so it glows from inside in the dark.
# Anims: idle, run, atk (the door flung open), mound (= the vent-stall: door hanging open, coals low).
# --------------------------------------------------------------------------
# hot spots in the coal bed per flicker step (x, y relative to the door centre)
FURNACE_COALS = [((-3, 0), (1, 1), (4, -1)), ((-2, 1), (2, 0), (3, 1)), ((-4, 1), (0, 0), (3, 0)),
                 ((-1, 1), (2, 1), (-3, -1))]


def furnace_frame(bob=0, step=0, coal=0, door="shut", eyes="glare", arms="down"):
    cv = Canvas(40, 40)
    post = Canvas(40, 40)
    d = bob
    # claw feet: the back pair peeks out behind the belly, the front pair carries it
    for x0 in (11, 26):
        rect(cv, x0, 31, x0 + 2, 36, "2")
    for i, x0 in enumerate((7, 28)):
        up = 1 if step == i + 1 else 0
        rect(cv, x0 + 1, 31 - up, x0 + 3, 37 - up, "s")
        rect(cv, x0, 38 - up, x0 + 4, 39 - up, "s")
    # the belly, the dome and the stovepipe
    ellipse(cv, 19.5, 35 + d, 30, 23, "s")
    ellipse(cv, 19.5, 16 + d, 22, 10, "s")
    rect(cv, 25, 2 + d, 28, 9 + d, "s")
    rect(cv, 24, 1 + d, 29, 2 + d, "s")
    # two stubby pipe arms with iron mitts (raised when it stokes up)
    for sx in (-1, 1):
        x0 = 19.5 + sx * 14.5
        if arms == "up":
            pts = [(0, 21), (1, 20), (2, 19), (3, 18), (3, 17)]
        else:
            pts = [(0, 21), (1, 22), (2, 23), (2, 24), (2, 25)]
        for dx, y in pts:
            x = int(x0 + sx * dx)
            cv.put(x, y + d, "s")
            cv.put(x - sx, y + d, "s")
        mx, my = int(x0 + sx * pts[-1][0]), pts[-1][1] + d + (-2 if arms == "up" else 1)
        rect(cv, min(mx, mx + sx), my, max(mx, mx + sx) + (0 if sx > 0 else 0), my + 2, "s")
        cv.put(mx + sx, my + 2, ".")
    shade_body(cv, "s", hi="i", sh="2", deep="1")
    # roundness: a lit crescent high on the belly's front, a shaded flank behind
    for y in range(21 + d, 31 + d):
        xs = [x for x in range(40) if cv.get(x, y) in ("s", "i", "2", "1")]
        if not xs:
            continue
        x0, x1 = min(xs), max(xs)
        if y < 27 + d and cv.get(x1 - 2, y) == "s":
            cv.put(x1 - 2, y, "i")
        if cv.get(x0 + 1, y) == "s":
            cv.put(x0 + 1, y, "2")
    for x in range(22, 30):
        if cv.get(x, 14 + d) == "s":
            cv.put(x, 14 + d, "i")
    # the stovepipe's dark mouth and a bright lip; the damper key
    rect(cv, 25, 1 + d, 28, 1 + d, "1")
    cv.put(29, 2 + d, "S")
    cv.put(28, 2 + d, "i")
    rect(cv, 24, 6 + d, 29, 6 + d, "2")
    cv.put(29, 6 + d, "S")
    # a riveted seam round the belly
    for x in range(4, 36):
        if cv.get(x, 19 + d) in ("s", "i", "2"):
            cv.put(x, 19 + d, "i")
            if cv.get(x, 20 + d) in ("s", "i", "2"):
                cv.put(x, 20 + d, "2")
    for x in (8, 13, 18, 23, 28, 32):
        cv.put(x, 19 + d, "S")
    # eye-slits in the dome: a hard iron brow over a hot slit
    ey = 12 + d
    for ex, inner in ((11, 16), (23, 22)):
        rect(cv, ex, ey, ex + 4, ey, "1")
        if eyes == "dim":
            rect(cv, ex, ey + 1, ex + 4, ey + 1, "R")
        elif eyes == "blink":
            rect(cv, ex, ey + 1, ex + 4, ey + 1, "1")
            rect(cv, ex + 1, ey + 1, ex + 3, ey + 1, "e")
        else:
            rect(cv, ex, ey + 1, ex + 4, ey + 1, "o")
            rect(cv, ex + 1, ey + 1, ex + 3, ey + 1, "y")
            if eyes == "wide":
                rect(cv, ex, ey + 2, ex + 4, ey + 2, "e")
                cv.put(ex + 2, ey + 1, "w")
        cv.put(inner, ey - 1, "1")       # the brows slant down to the middle: it glares
        cv.put(inner + (1 if inner > 20 else -1), ey - 1, "1")
    # the fire door (its mouth): an iron ring round the coal bed
    dc = 28 + d
    ellipse(cv, 19.5, dc + 5, 18, 12, "2")
    ellipse(cv, 19.5, dc + 4, 14, 9, "e" if door != "low" else "R")
    for x in range(10, 30):
        for y in range(dc - 8, dc - 4):
            if cv.get(x, y) == "2" and cv.get(x, y + 1) in ("e", "R"):
                cv.put(x, y - 1 if cv.get(x, y - 1) == "2" else y, "i")
                break
    for dx, dy in FURNACE_COALS[coal % 4]:
        if door != "low":
            cv.put(20 + dx, dc + 1 + dy, "y")
            cv.put(19 + dx, dc + 1 + dy, "o")
        else:
            cv.put(20 + dx, dc + 1 + dy, "e")
    if door == "shut":
        for bx in (14, 17, 20, 23):          # the grate: a grin of iron teeth
            for y in range(dc - 4, dc + 5):
                if cv.get(bx + 1, y) in ("e", "y", "o"):
                    cv.put(bx + 1, y, "1")
    elif door == "open":
        # flung open: white-hot inside, the door plate swung out to its hinge on the left
        ellipse(cv, 19.5, dc + 2, 8, 5, "y")
        rect(cv, 18, dc - 1, 21, dc, "w")
        rect(cv, 4, dc - 4, 7, dc + 4, "i")
        rect(cv, 5, dc - 3, 6, dc + 3, "2")
        cv.put(8, dc - 2, "1")
        cv.put(8, dc + 2, "1")
    else:
        # "low" (the vent-stall): the door hangs open and the coals are spent: it has run out of draw
        rect(cv, 4, dc - 1, 7, dc + 6, "i")
        rect(cv, 5, dc, 6, dc + 5, "2")
        cv.put(8, dc + 1, "1")
    return render(cv, post)


def build_furnace():
    idle = [furnace_frame(0, 0, 0), furnace_frame(0, 0, 1), furnace_frame(1, 0, 2), furnace_frame(1, 0, 3, eyes="blink")]
    run = [furnace_frame(0, 1, 0), furnace_frame(1, 0, 1), furnace_frame(0, 2, 2), furnace_frame(1, 0, 3)]
    atk = [furnace_frame(0, 0, 1, "open", "wide", "up"), furnace_frame(1, 0, 3, "open", "wide", "up")]
    stall = [furnace_frame(1, 0, 0, "low", "dim"), furnace_frame(1, 0, 2, "low", "dim")]
    save_anim("furnace", "idle", idle)
    save_anim("furnace", "run", run)
    save_anim("furnace", "atk", atk)
    save_anim("furnace", "mound", stall)


# --------------------------------------------------------------------------
# THE OSSUARY (44x40): every bone the crypt ever tidied away, heaped up and walking. A mound of bones
# with a ribcage, skulls peering out of the pile and a great skull on top with grave-light eyes (its
# only t / T pixels: Enemy.DEFS["ossuary"]["glow_px"]). Long arm bones reach out of the heap.
# Anims: idle, run, atk (an arm swings a skull up and over), mound (fallen apart: a flat spill of bones),
# rise (pulling itself back together). Plus ossuary_roll_f0-3: one skull rolling (the swarm it splits into).
# --------------------------------------------------------------------------
BIG_SKULL = """
....AAAAAAA.....
..AAAAAAAAAwA...
.AAAAAAAAAAAwA..
.aAAAAAAAAAAAAA.
aaAAAAAAAAAAAAA.
aA11111AA11111A.
aA11111AA11111A.
aA11111AA11111A.
.aA111AAAA111AA.
.aaAAAAA1AAAAA..
..aAAAA111AAA...
...a1A1A1A1A....
...aAAAAAAAA....
....aaaaaaa.....
"""
SMALL_SKULL = """
.AAAA.
AAAAwA
A11A1A
aAAAAA
.a1a1.
"""
ROLL_SKULL = """
..AAAAA..
.AAAAAAA.
AAAAAAAAA
AAAAA11A1
AAAAA11A1
AAAAAAA1A
.AAAA1A1A
..AAAAAA.
...aaa...
"""


def bone(cv, x0, y0, x1, y1, ch="A", knob="A"):
    """A long bone: a 1 px shaft between two 2x2 knuckles, with a shade line under the shaft."""
    line(cv, x0, y0 + 1, x1, y1 + 1, "a")
    line(cv, x0, y0, x1, y1, ch)
    for x, y in ((x0, y0), (x1, y1)):
        rect(cv, x - 1, y - 1, x, y, knob)
        cv.put(x - 1, y + 1, "a")
        cv.put(x, y + 1, "a")


# the heap's bones and lesser skulls (fixed so every frame is the same pile); jig moves the odd ones
HEAP_BONES = ((6, 34, 14, 31), (29, 31, 37, 35), (8, 38, 17, 35), (25, 37, 34, 38), (12, 30, 7, 26),
              (31, 26, 35, 30), (17, 36, 27, 33), (10, 27, 15, 22), (28, 21, 32, 26), (5, 37, 10, 36),
              (33, 37, 38, 36), (19, 38, 24, 38))
HEAP_SKULLS = ((5, 29), (32, 30), (14, 33), (24, 31), (33, 23))


def ossuary_frame(lean=0, jig=0, eyes="glow", arm="rest", jaw=0, part="whole", lift=0):
    cv = Canvas(44, 40)
    post = Canvas(44, 40)
    if part == "mound":
        # fallen apart: a low spill of bones, the skulls rolled off to do its fighting
        ellipse(cv, 21.5, 39, 42, 10, "5")
        for b in ((4, 36, 13, 33), (16, 37, 27, 35), (28, 33, 38, 36), (10, 33, 19, 37), (22, 32, 31, 32)):
            bone(cv, b[0], b[1] - jig, b[2], b[3] - jig)
        cv.blit(rows_of(SMALL_SKULL), 18, 32 - jig)
        return render(cv, post)
    # the heap: a dark mound packed with bones (the dark between them is the pile's shadow)
    ellipse(cv, 21.5 + lean * 0.5, 39, 36, 21 + lift, "5")
    for x in range(44):
        for y in range(39, 15, -1):
            if cv.get(x, y) == "5" and cv.get(x, y + 1) == ".":
                cv.put(x, y, "4")
    for i, b in enumerate(HEAP_BONES):
        j = jig if i % 2 else 0
        if b[1] - j >= 41 - (21 + lift) or b[3] - j >= 41 - (21 + lift):
            bone(cv, b[0] + lean, b[1] - j, b[2] + lean, b[3] - j)
    for i, (x, y) in enumerate(HEAP_SKULLS):
        if y > 39 - (21 + lift):
            cv.blit(rows_of(SMALL_SKULL), x + lean, y - (jig if i % 2 else 0))
    # the ribcage under the great skull: curved ribs round a dark hollow, a spine down the middle
    rc = 21 + lean
    ry = 21 - lift
    ellipse(cv, rc + 0.5, ry + 10, 16, 12, "4")
    for i in range(4):
        y = ry + 2 + 2 * i
        w = (5, 6, 6, 5)[i]
        for x in range(rc - w, rc + w + 2):
            cv.put(x, y, "A")
        cv.put(rc - w - 1, y + 1, "A")
        cv.put(rc + w + 2, y + 1, "A")
        cv.put(rc - w, y + 1, "a")
    for y in range(ry, ry + 10):
        cv.put(rc, y, "A")
        cv.put(rc + 1, y, "a")
    # arms: a long arm bone each side with a three-fingered hand; "up" swings the right one high with
    # a skull in its fingers, "throw" follows through empty-handed
    lx = 4 + lean
    bone(cv, lx + 9, 22 - lift, lx + 1, 27 - lift)
    bone(cv, lx + 1, 27 - lift, lx - 1, 35 - lift)
    for k in range(3):
        cv.put(lx - 3 + k * 2, 37 - lift, "A")
        cv.put(lx - 3 + k * 2, 38 - lift, "A")
    rx = 38 + lean
    if arm == "rest":
        bone(cv, rx - 8, 22 - lift, rx, 27 - lift)
        bone(cv, rx, 27 - lift, rx + 2, 35 - lift)
        for k in range(3):
            cv.put(rx + k * 2, 37 - lift, "A")
            cv.put(rx + k * 2, 38 - lift, "A")
    elif arm == "up":
        bone(cv, rx - 8, 22 - lift, rx, 17 - lift)
        bone(cv, rx, 17 - lift, rx + 1, 10 - lift)
        cv.blit(rows_of(SMALL_SKULL), rx - 2, 4 - lift)
    else:   # "throw": the arm follows through, empty-handed
        bone(cv, rx - 8, 22 - lift, rx + 1, 20 - lift)
        bone(cv, rx + 1, 20 - lift, rx + 4, 25 - lift)
        for k in range(3):
            cv.put(rx + 3 + k, 27 - lift, "A")
    # the great skull on top
    sx, sy = 14 + lean, 7 - lift
    cv.blit(rows_of(BIG_SKULL), sx, sy)
    if jaw:
        rect(cv, sx + 3, sy + 12, sx + 11, sy + 12 + jaw, "1")
        rect(cv, sx + 4, sy + 13 + jaw, sx + 11, sy + 13 + jaw, "A")
    for ex in (sx + 3, sx + 10):
        if eyes == "glow":
            cv.put(ex, sy + 6, "t")
            cv.put(ex + 1, sy + 6, "t")
            cv.put(ex, sy + 7, "T")
            cv.put(ex + 1, sy + 7, "T")
        elif eyes == "flare":
            rect(cv, ex - 1, sy + 5, ex + 2, sy + 7, "T")
            cv.put(ex, sy + 6, "t")
            cv.put(ex + 1, sy + 6, "t")
        elif eyes == "dim":
            cv.put(ex, sy + 7, "T")
    return render(cv, post)


def roll_skull_frame(k):
    cv = Canvas(11, 11)
    rows = rows_of(ROLL_SKULL)
    n = len(rows)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == ".":
                continue
            # rotate the face a quarter turn per frame (it rolls), the light stays top-left
            X, Y = [(x, y), (n - 1 - y, x), (n - 1 - x, n - 1 - y), (y, n - 1 - x)][k]
            cv.put(X + 1, Y + 1, "A" if ch == "a" else ch)
    shade_body(cv, "A", hi="w", sh="a", deep="5", hi_frac=0.5)
    return render(cv)


def build_ossuary():
    idle = [ossuary_frame(0, 0), ossuary_frame(0, 1), ossuary_frame(0, 0, jaw=1), ossuary_frame(0, 1, eyes="dim")]
    run = [ossuary_frame(-1, 0), ossuary_frame(0, 1), ossuary_frame(1, 0), ossuary_frame(0, 1)]
    atk = [ossuary_frame(0, 0, "flare", "up"), ossuary_frame(1, 1, "flare", "throw", jaw=2)]
    mound = [ossuary_frame(0, 0, part="mound"), ossuary_frame(0, 1, part="mound")]
    rise = [ossuary_frame(0, 0, "dim", lift=-6), ossuary_frame(0, 1, "dim", lift=-3), ossuary_frame(0, 0, "flare", jaw=2)]
    save_anim("ossuary", "idle", idle)
    save_anim("ossuary", "run", run)
    save_anim("ossuary", "atk", atk)
    save_anim("ossuary", "mound", mound)
    save_anim("ossuary", "rise", rise)
    save_anim("ossuary", "roll", [roll_skull_frame(k) for k in range(4)])


# --------------------------------------------------------------------------
# THE ORGANIST (48x50): the chapel organ that learned to play itself. A mahogany case on lion feet, a
# rank of seven brass pipes, two stop-knob eyes (their pale centres are its only h pixels:
# Enemy.DEFS["organist"]["glow_px"]), a keyboard for a mouth and a pair of pale empty hands that play
# it. ORGAN_PIPES (x of each pipe's centre, y of its mouth) is mirrored in guardians_v21.gd (PIPES).
# Anims: idle, run, atk (hands up, then down on the keys: the mouths light), sing (the chord: every
# pipe at once, hands spread).
# --------------------------------------------------------------------------
ORGAN_PIPES = [(11, 19), (15, 19), (19, 19), (23, 19), (27, 19), (31, 19), (35, 19)]
ORGAN_TOPS = [13, 9, 5, 1, 5, 9, 13]


def organist_frame(bob=0, hands="rest", eyes="open", lit=(), sway=0):
    cv = Canvas(48, 50)
    post = Canvas(48, 50)
    d = bob
    # lion feet and the plinth
    for fx in (7, 36):
        rect(cv, fx, 46, fx + 4, 49, "R")
        cv.put(fx, 49, "m")
        cv.put(fx + 2, 49, "m")
        cv.put(fx + 4, 49, "m")
    rect(cv, 6, 43 + d, 41, 46, "R")
    # the case
    rect(cv, 8, 24 + d, 39, 43 + d, "R")
    shade_body(cv, "R", hi="c", sh="m", deep="m")
    # carved arches in the lower panel
    for ax in (12, 26):
        rect(cv, ax, 41 + d, ax + 9, 43 + d, "m")
        rect(cv, ax + 1, 40 + d, ax + 8, 40 + d, "m")
        rect(cv, ax + 3, 39 + d, ax + 6, 39 + d, "m")
    # the cornice over the case top
    rect(cv, 6, 22 + d, 41, 24 + d, "c")
    rect(cv, 6, 22 + d, 41, 22 + d, "y")
    rect(cv, 7, 24 + d, 40, 24 + d, "R")
    # the rank of pipes (brass: shaded left, lit right), each with a dark mouth near its foot
    for i, (px, my) in enumerate(ORGAN_PIPES):
        top = ORGAN_TOPS[i] + d
        rect(cv, px - 1, top, px + 1, 21 + d, "y")
        for y in range(top, 22 + d):
            cv.put(px - 1, y, "o")
        cv.put(px + 1, top, "w")
        cv.put(px + 1, top + 1, "w")
        cv.put(px, top, "o")
        rect(cv, px - 1, my + d, px + 1, my + d, "1")
        cv.put(px, my + d + 1, "1")
        if i in lit:
            post.put(px, my + d, "w")
            cv.put(px - 1, my + d, "y")
            cv.put(px + 1, my + d, "y")
    # stop-knob eyes under heavy carved brows
    ey = 28 + d
    for ex in (13, 30):
        rect(cv, ex, ey, ex + 4, ey + 3, "1")
        if eyes == "shut":
            rect(cv, ex + 1, ey + 2, ex + 3, ey + 2, "i")
        else:
            rect(cv, ex + 1, ey + 1, ex + 3, ey + 2, "S")
            rect(cv, ex + 2, ey + 1, ex + 2, ey + 2, "h")
            if eyes == "wide":
                rect(cv, ex + 1, ey + 1, ex + 3, ey + 2, "h")
        cv.put(ex, ey, "R")
        cv.put(ex + 4, ey, "R")
        cv.put(ex, ey + 3, "R")
        cv.put(ex + 4, ey + 3, "R")
    for k in range(5):        # the brows slant to a frown
        cv.put(13 + k, ey - 1 - (1 if k < 2 else 0), "m")
        cv.put(30 + k, ey - 1 - (1 if k > 2 else 0), "m")
    # the keyboard mouth: a ledge, ivory keys, black keys between
    ky = 35 + d
    rect(cv, 9, ky - 1, 38, ky - 1, "c")
    rect(cv, 10, ky, 37, ky + 3, "w")
    for x in range(10, 38):
        if (x - 10) % 3 == 2:
            for y in range(ky, ky + 4):
                cv.put(x, y, "A")
            if (x - 10) % 21 not in (8, 20):
                cv.put(x, ky, "1")
                cv.put(x, ky + 1, "1")
    rect(cv, 9, ky + 4, 38, ky + 4, "m")
    # the pale hands that play it
    if hands != "none":
        hy = {"rest": ky - 1, "up": ky - 3, "down": ky, "spread": ky - 3}[hands]
        xs = {"rest": (14, 29), "up": (10, 33), "down": (14, 29), "spread": (8, 35)}[hands]
        for i, hx in enumerate(xs):
            hx += sway * (1 if i == 0 else -1)
            rect(cv, hx, hy, hx + 4, hy + 1, "S")
            for f in range(4):
                cv.put(hx + f + (0 if i == 0 else 1), hy + 2, "S" if f % 2 == 0 else "i")
            cv.put(hx + (4 if i == 0 else 0), hy - 1, "S")    # thumbs
    return render(cv, post)


def build_organist():
    idle = [organist_frame(0), organist_frame(0, sway=1), organist_frame(0), organist_frame(0, eyes="shut", sway=-1)]
    run = [organist_frame(0), organist_frame(1, sway=1), organist_frame(0), organist_frame(1, sway=-1)]
    atk = [organist_frame(0, "up", "wide"), organist_frame(1, "down", "wide", lit=(0, 2, 4, 6))]
    sing = [organist_frame(0, "spread", "wide"), organist_frame(1, "spread", "wide", lit=tuple(range(7)))]
    save_anim("organist", "idle", idle)
    save_anim("organist", "run", run)
    save_anim("organist", "atk", atk)
    save_anim("organist", "sing", sing)


# --------------------------------------------------------------------------
# THE WEATHERCOCK (44x52): the copper rooster off the belfry roof, green with a century of rain. It
# stands on its arrow, on a spindle over a compass cross, with a red comb and one hot eye (its only y
# pixels: Enemy.DEFS["weathercock"]["glow_px"]).
# Anims: idle, run (a wing-beat), atk (wings flung wide, crowing up a gale), grab (= the spin: side,
# front, other side, back; the vane turns on its spindle while the cross stays put).
# --------------------------------------------------------------------------
def _fan(cv, cx, cy, r0, r1, a0, a1, cols, notch=True):
    """A solid fan of feathers: the ring sector r0..r1 between angles a0..a1 (radians, screen y down),
    cut into len(cols) wedges that alternate colours; the tips are notched between feathers."""
    n = len(cols)
    for y in range(int(cy - r1) - 1, int(cy + r1) + 2):
        for x in range(int(cx - r1) - 1, int(cx + r1) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            rr = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            lo, hi = min(a0, a1), max(a0, a1)
            while a < lo:
                a += 2 * math.pi
            if a > hi or rr < r0 or rr > r1:
                continue
            k = min(n - 1, int((a - lo) / (hi - lo) * n))
            frac = (a - lo) / (hi - lo) * n - k
            if notch and rr > r1 - 1.6 and (frac < 0.22 or frac > 0.78):
                continue
            cv.put(x, y, cols[k])


def _cock_base(cv, view):
    """The compass cross on the floor and the spindle up to the arrow (y 28)."""
    rect(cv, 3, 48, 40, 49, "s")
    for ex, dx in ((1, 1), (42, -1)):
        cv.put(ex, 48, "s")
        cv.put(ex, 49, "s")
        cv.put(ex + dx, 47, "s")
        cv.put(ex + dx, 50, "s")
    rect(cv, 21, 45, 22, 51, "s")
    ellipse(cv, 21.5, 50, 8, 5, "s")
    rect(cv, 21, 26, 22, 46, "s")
    ellipse(cv, 21.5, 40, 6, 5, "o")     # a gilt ball on the spindle


def _cock_side(cv, d, wings="fold", beak="shut", eye="open", tail=0, flip=False):
    """The rooster in profile facing right (mirrored for the other side), standing on its arrow."""
    w = Canvas(44, 52)
    # the arrow: a feathered tail vane, the shaft, the head (pointing the way it faces)
    rect(w, 6, 29, 37, 30, "s")
    for x0 in range(1, 8):
        h = (3, 3, 2, 3, 2, 2, 1)[x0 - 1]
        rect(w, x0, 29 - h, x0, 30 + h, "i" if x0 % 2 else "S")
    for k in range(6):
        rect(w, 37 + k, 27 + k // 2, 37 + k, 32 - k // 2, "s")
    # tail: sickle feathers sweeping up from the rump and falling back over (a solid fan)
    _fan(w, 10, 18 + d, 3, 11 + tail, math.pi * 1.02, math.pi * 1.62, ["G", "T", "G", "T", "G"])
    # body, chest, neck and head
    ellipse(w, 17.5, 25 + d, 20, 12, "T")
    ellipse(w, 25.5, 22 + d, 9, 11, "T")
    ellipse(w, 27, 15 + d, 6, 9, "T")
    ellipse(w, 28.5, 10 + d, 7, 7, "T")
    shade_body(w, "T", hi="t", sh="G", deep="2")
    if wings == "wide":
        # flung up and back, every flight feather spread
        _fan(w, 20, 19 + d, 2, 14, math.pi * 1.08, math.pi * 1.5, ["t", "T", "t", "T", "t", "T"])
    if wings == "fold":
        # the folded wing: a darker shield with two feather edges
        ellipse(w, 17.5, 23 + d, 12, 7, "G")
        for x in range(12, 23):
            if w.get(x, 23 + d) == "G":
                w.put(x, 22 + d, "t" if x % 3 == 0 else "G")
        line(w, 12, 21 + d, 22, 19 + d, "t")
    elif wings == "half":
        for k in range(3):
            line(w, 19, 19 + d, 9 + k * 4, 9 + d + k, "G", 2)
        line(w, 19, 18 + d, 9, 9 + d, "t")
    # comb, beak, wattle, eye
    for k, (cx, ch) in enumerate(((26, 2), (28, 1), (30, 2))):
        rect(w, cx, 4 + d + (ch - 1), cx + 1, 6 + d, "r")
        w.put(cx, 6 + d, "R")
    if beak == "open":
        rect(w, 32, 8 + d, 34, 8 + d, "o")
        w.put(35, 7 + d, "o")
        rect(w, 32, 11 + d, 34, 11 + d, "c")
        w.put(35, 12 + d, "c")
        rect(w, 32, 9 + d, 33, 10 + d, "1")
    else:
        rect(w, 32, 9 + d, 34, 9 + d, "o")
        w.put(35, 10 + d, "o")
        rect(w, 32, 10 + d, 33, 10 + d, "c")
    rect(w, 30, 12 + d, 31, 15 + d, "r")
    w.put(31, 16 + d, "R")
    if eye == "open":
        w.put(29, 8 + d, "y")
        w.put(30, 8 + d, "1")
    else:
        w.put(29, 8 + d, "G")
        w.put(30, 8 + d, "G")
    # legs down to the arrow
    for lx in (18, 22):
        rect(w, lx, 26 + d, lx, 28, "1")
        w.put(lx - 1, 28, "1")
        w.put(lx + 1, 28, "1")
    for y in range(52):
        for x in range(44):
            ch = w.c[y][x]
            if ch != ".":
                cv.put(43 - x if flip else x, y, ch)


def _cock_front(cv, d, back=False):
    """Head-on (or from behind): the arrow points at you, the tail fans out round the body."""
    w = Canvas(44, 52)
    # the tail fans out round the body (seen from behind it covers the back)
    _fan(w, 21.5, 22 + d, 2, 14, math.pi * 1.05, math.pi * 1.95, ["G", "T", "G", "T", "G", "T", "G"])
    ellipse(w, 21.5, 27 + d, 13, 14, "T")
    ellipse(w, 21.5, 14 + d, 7, 9, "T")
    shade_body(w, "T", hi="t", sh="G", deep="2")
    for k, top in enumerate((5, 3, 4, 3)):      # the comb seen edge-on: a thin serrated crest
        rect(w, 20 + k, top + d, 20 + k, 6 + d, "r")
        w.put(20 + k, 6 + d, "R")
    if not back:
        rect(w, 21, 11 + d, 22, 12 + d, "o")
        w.put(21, 13 + d, "c")
        w.put(22, 13 + d, "c")
        rect(w, 21, 14 + d, 22, 16 + d, "r")
        w.put(19, 10 + d, "y")
        w.put(24, 10 + d, "y")
        ellipse(w, 21.5, 31, 5, 5, "s")       # the arrow, end-on
        w.put(21, 29, "i")
    else:
        _fan(w, 21.5, 26 + d, 1, 10, math.pi * 1.1, math.pi * 1.9, ["G", "T", "G", "T", "G"])
        rect(w, 21, 24, 22, 32, "i")          # the arrow's tail vane, edge-on
    for lx in (19, 24):
        rect(w, lx, 27 + d, lx, 28, "1")
    for y in range(52):
        for x in range(44):
            if w.c[y][x] != ".":
                cv.put(x, y, w.c[y][x])


def weathercock_frame(d=0, view="side", **kw):
    cv = Canvas(44, 52)
    _cock_base(cv, view)
    shade_body(cv, "s", hi="i", sh="2", deep="1")
    shade_body(cv, "o", hi="w", sh="c", deep="c")
    if view in ("side", "other"):
        _cock_side(cv, d, flip=(view == "other"), **kw)
    else:
        _cock_front(cv, d, back=(view == "back"))
    return render(cv)


def build_weathercock():
    idle = [weathercock_frame(0), weathercock_frame(0, tail=1), weathercock_frame(1, tail=1),
            weathercock_frame(1, eye="shut")]
    run = [weathercock_frame(1), weathercock_frame(0, wings="half"), weathercock_frame(-1, wings="half", tail=1),
           weathercock_frame(0)]
    atk = [weathercock_frame(0, wings="wide", beak="open"), weathercock_frame(-1, wings="wide", beak="open", tail=1)]
    spin = [weathercock_frame(0), weathercock_frame(0, "front"), weathercock_frame(0, "other"), weathercock_frame(0, "back")]
    save_anim("weathercock", "idle", idle)
    save_anim("weathercock", "run", run)
    save_anim("weathercock", "atk", atk)
    save_anim("weathercock", "grab", spin)


BOSS_NAMES = ["wax_mother", "sexton", "choir", "pendulum", "necro_boss", "furnace", "ossuary", "organist", "weathercock"]


def build_bosses():
    build_wax_mother()
    build_sexton()
    build_choir()
    build_pendulum()
    build_warden()
    build_furnace()
    build_ossuary()
    build_organist()
    build_weathercock()
