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


BOSS_NAMES = ["wax_mother", "sexton", "choir", "pendulum", "necro_boss"]


def build_bosses():
    build_wax_mother()
    build_sexton()
    build_choir()
    build_pendulum()
    build_warden()
