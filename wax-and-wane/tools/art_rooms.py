#!/usr/bin/env python3
"""Wax & Wane - room art generator ("rooms" job).

Re-runnable:  python3 tools/art_rooms.py            (writes assets/art/rooms/)
              python3 tools/art_rooms.py --review   (also writes contact sheets + previews
                                                     to /tmp/claude-0/review_rooms/ and, for the
                                                     candelabra / trapdoor / decals, to
                                                     /tmp/claude-0/review_rooms2/)

Everything is built from the CC0 0x72 DungeonTileset II frames in assets/0x72/frames/
(walls, floors, door leaf, banners, skull ...) plus hand-placed pixel art defined below
as character grids.  Only colours from the 0x72 sheet are used.  Output is pixel-exact
RGBA PNG with no semi-transparent pixels.
"""
import os
import sys
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAMES = os.path.join(ROOT, "assets", "0x72", "frames")
SHEET = os.path.join(ROOT, "art_source", "0x72_DungeonTilesetII_v1.7.png")
OUT = os.path.join(ROOT, "assets", "art", "rooms")
REVIEW = "/tmp/claude-0/review_rooms"
REVIEW2 = "/tmp/claude-0/review_rooms2"      # candelabra / trapdoor / decals

ROOM_W, ROOM_H = 272, 192
SLOTS = {  # door sprite top-left inside the room image + size (DESIGN.md)
    "top": (120, 0, 32, 32),
    "bottom": (120, 176, 32, 16),
    "left": (0, 88, 16, 32),
    "right": (256, 88, 16, 32),
}


# --------------------------------------------------------------------------- helpers
def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def sheet_palette():
    a = np.array(Image.open(SHEET).convert("RGBA")).reshape(-1, 4)
    a = a[a[:, 3] > 0]
    return {tuple(int(v) for v in p[:3]) for p in np.unique(a, axis=0)}


_tiles = {}


def tile(name):
    if name not in _tiles:
        _tiles[name] = Image.open(os.path.join(FRAMES, name + ".png")).convert("RGBA")
    return _tiles[name].copy()


def paste(dst, src, x, y):
    dst.alpha_composite(src, (x, y))


def grid(rows, pal):
    """Character grid -> RGBA image.  '.' (or ' ') = transparent."""
    rows = [r for r in rows]
    h = len(rows)
    w = len(rows[0])
    for i, r in enumerate(rows):
        assert len(r) == w, "row %d has %d chars, expected %d: %r" % (i, len(r), w, r)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in ". ":
                continue
            if ch not in pal:
                raise KeyError("char %r not in palette (row %d)" % (ch, y))
            c = pal[ch]
            if c is None:
                continue
            px[x, y] = rgb(c) + (255,)
    return im


def G(text):
    """Multiline string -> list of rows (strips indentation and blank lines)."""
    return [ln.strip() for ln in text.strip("\n").splitlines() if ln.strip()]


def mirror_rows(rows):
    return [r[::-1] for r in rows]


def overlay_rows(base, over, keep="_"):
    """Overlay grid `over` onto grid `base`; `keep` chars leave the base pixel."""
    out = []
    for b, o in zip(base, over):
        assert len(b) == len(o), (b, o)
        out.append("".join(bc if oc == keep else oc for bc, oc in zip(b, o)))
    return out


def remap(im, mapping):
    """Exact colour remap {'#src': '#dst'} on opaque pixels."""
    a = np.array(im)
    out = a.copy()
    for s, d in mapping.items():
        s, d = rgb(s), rgb(d)
        m = (a[:, :, 0] == s[0]) & (a[:, :, 1] == s[1]) & (a[:, :, 2] == s[2]) & (a[:, :, 3] > 0)
        out[m, 0], out[m, 1], out[m, 2] = d
    return Image.fromarray(out)


def remap_region(im, box, mapping):
    x0, y0, x1, y1 = box
    sub = im.crop(box)
    im.paste(remap(sub, mapping), (x0, y0))


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    im.save(path, optimize=True)
    return path


# --------------------------------------------------------------------------- palette
# 0x72 stone ramp (as used by wall_mid / wall_top_* / floor_*)
O, S1, S2, S3, S4 = "#222222", "#483b3a", "#775c55", "#aa8d7a", "#d3bfa9"

# Theme remaps.  'wall' applies to walls/caps, 'floor' to floor tiles.  'ring' (the darker
# 1-tile vignette along the walls) and 'shadow' (hard cast shadow under the top/left wall)
# are applied AFTER the theme map, so their keys are the theme's own colours.
THEMES = {
    "cellar": dict(
        wall={},
        floor={},
        ring={S1: "#3b3332"},
        shadow={S1: "#302c2b", S2: "#3b3332"},
        seed=1201,
    ),
    "crypt": dict(
        wall={S1: "#323e4f", S2: "#414859", S3: "#7b8994", S4: "#b6cbcf"},
        floor={S1: "#323e4f", S2: "#414859"},
        ring={"#323e4f": "#2a2a3a"},
        shadow={"#323e4f": "#222222", "#414859": "#2a2a3a"},
        seed=1202,
    ),
    "chapel": dict(
        wall={O: "#1f1833", S1: "#2a2a3a", S2: "#5f2d56", S3: "#c38d70", S4: "#e2b694"},
        floor={O: "#1f1833", S1: "#2a2a3a", S2: "#5f2d56"},
        ring={"#2a2a3a": "#23151d"},
        shadow={"#2a2a3a": "#1f1833", "#5f2d56": "#2a2a3a"},
        seed=1203,
    ),
    "belfry": dict(
        wall={O: "#21141b", S1: "#38262d", S2: "#8a503e", S3: "#c38d70", S4: "#e2b694"},
        floor={O: "#21141b", S1: "#38262d", S2: "#8a503e"},
        ring={"#38262d": "#23151d"},
        shadow={"#38262d": "#21141b", "#8a503e": "#38262d"},
        seed=1204,
    ),
}


# --------------------------------------------------------------------------- room
FLOOR_X0, FLOOR_Y0, FLOOR_COLS, FLOOR_ROWS = 16, 32, 15, 9

# Joint rows of the thin side-wall strips (0x72 wall_edge style: B... then C lip then A joint).
# Chosen so the strip has a lit lip right above each side door slot (y 87) and starts a fresh
# stone right below it (y 120), so a door overlay meets a clean joint.
STRIP_JOINTS = [22, 31, 40, 47, 56, 63, 72, 79, 88, 95, 104, 111, 119, 128, 135, 144, 151,
                160, 167, 174]


def strip_column():
    """Fill pattern of the left side strip, y -> 'B' fill, 'C' lip, 'A' joint (y 13..179)."""
    col = {}
    for y in range(13, 180):
        col[y] = "B"
    for j in STRIP_JOINTS:
        col[j] = "A"
        col[j - 1] = "C"
    col[179] = "C"  # the bottom cap lip runs under the strip
    return col


def floor_layout(rng):
    """15x9 grid of floor tile names: mostly floor_1, sparse non-repeating variation."""
    lay = [["floor_1"] * FLOOR_COLS for _ in range(FLOOR_ROWS)]
    # keep the tiles in front of the doors clean
    keep_clear = {(7, 0), (7, 8), (0, 3), (0, 4), (0, 5), (14, 3), (14, 4), (14, 5),
                  (6, 0), (8, 0), (6, 8), (8, 8)}
    light = ["floor_3", "floor_5", "floor_2", "floor_6"]          # small cracks / chips
    heavy = ["floor_4", "floor_7", "floor_8"]                     # big dark breaks (rare)
    cells = [(c, r) for r in range(FLOOR_ROWS) for c in range(FLOOR_COLS)
             if (c, r) not in keep_clear]
    rng.shuffle(cells)
    placed = []
    want_light, want_heavy = rng.randint(9, 12), rng.randint(1, 2)
    pool = []
    heavy_pool = heavy[:]
    rng.shuffle(heavy_pool)
    for i in range(want_light):
        pool.append(light[i % len(light)])
    rng.shuffle(pool)
    pool = heavy_pool[:want_heavy] + pool
    for name in pool:
        for k, (c, r) in enumerate(cells):
            ok = True
            for (pc, pr, pn) in placed:
                d = max(abs(pc - c), abs(pr - r))
                if d < 2 or (pn == name and d < 6):
                    ok = False
                    break
            if ok:
                placed.append((c, r, name))
                lay[r][c] = name
                cells.pop(k)
                break
    return lay


def build_room(theme, decor=True):
    T = THEMES[theme]
    rng = random.Random(T["seed"])
    W, H = ROOM_W, ROOM_H

    # ---- floor -------------------------------------------------------------------
    floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lay = floor_layout(rng)
    for r in range(FLOOR_ROWS):
        for c in range(FLOOR_COLS):
            paste(floor, tile(lay[r][c]), FLOOR_X0 + 16 * c, FLOOR_Y0 + 16 * r)
    if decor:
        decorate_floor(theme, floor, lay, rng)
    floor = remap(floor, T["floor"])
    # 1-tile vignette ring along the walls (ambient occlusion), then hard cast shadows
    # (light comes from the top-left: the top wall and the left wall throw a short shadow).
    fx0, fy0 = FLOOR_X0, FLOOR_Y0
    fx1, fy1 = FLOOR_X0 + 16 * FLOOR_COLS, FLOOR_Y0 + 16 * FLOOR_ROWS
    ring = T["ring"]
    for box in [(fx0, fy0, fx1, fy0 + 16), (fx0, fy1 - 16, fx1, fy1),
                (fx0, fy0 + 16, fx0 + 16, fy1 - 16), (fx1 - 16, fy0 + 16, fx1, fy1 - 16)]:
        remap_region(floor, box, ring)
    sh = {}
    for k, v in T["shadow"].items():
        sh[k] = v
    for k, v in ring.items():  # the ring colour also darkens inside the shadow
        if k in T["shadow"]:
            sh[v] = T["shadow"][k]
    remap_region(floor, (fx0, fy0, fx1, fy0 + 3), sh)          # under the top wall
    remap_region(floor, (fx0, fy0 + 3, fx0 + 2, fy1), sh)      # right of the left wall

    # ---- walls -------------------------------------------------------------------
    wall = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # top wall face (y 16..31)
    faces = wall_faces(theme, rng) if decor else ["wall_mid"] * 15
    for i, name in enumerate(faces):
        paste(wall, tile(name), 16 + 16 * i, 16)
    # top caps (y 12..15)
    for i in range(15):
        paste(wall, tile("wall_top_mid"), 16 + 16 * i, 0)
    # bottom caps (y 176..179), tiled with an 8 px phase shift so they don't echo the top
    cap = tile("wall_top_mid").crop((0, 12, 16, 16))
    for x in range(8, 264, 16):
        paste(wall, cap, x, 176)
    # bottom wall outer face (y 180..191), the south face of the wall seen from the front
    face = tile("wall_mid").crop((0, 0, 16, 12))
    for x in range(0, W, 16):
        paste(wall, face, x, 180)
    px = wall.load()
    for y in range(176, 192):
        for x in list(range(0, 11)) + list(range(261, W)):
            px[x, y] = (0, 0, 0, 0)
    for y in range(176, 192):
        px[11, y] = rgb(O) + (255,)
        px[260, y] = rgb(O) + (255,)
    for x in range(11, 261):
        px[x, 176] = rgb(O) + (255,)
    # side strips (left x 11..15, right x 256..260) incl. the four corners
    col = strip_column()
    cB, cC, cA = rgb(S3) + (255,), rgb(S4) + (255,), rgb(O) + (255,)
    for side in ("left", "right"):
        xo = 11 if side == "left" else 256      # outer/inner outline columns
        xs = [xo, xo + 1, xo + 2, xo + 3, xo + 4]
        if side == "right":
            xs = xs[::-1]   # xs[0] is the outer (void-side) outline column
        outer, f1, f2, f3, inner = xs
        # top corner: cap top outline row
        for x in xs:
            px[x, 12] = cA
        for y in range(13, 180):
            v = col[y]
            px[outer, y] = cA
            fill = {"B": cB, "C": cC, "A": cA}[v]
            for x in (f1, f2, f3):
                px[x, y] = fill
            if 13 <= y <= 15 or 177 <= y <= 179:
                px[inner, y] = fill          # strip merges with the cap at the corners
            else:
                px[inner, y] = cA
    # caps: the lip row stops where the strip passes in front (top corners)
    wall = remap(wall, T["wall"])
    # outer face of the bottom wall is a touch darker (it faces away from the room light)
    if T.get("face_out"):
        remap_region(wall, (12, 180, 260, 192), T["face_out"])

    room = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    room.alpha_composite(floor)
    room.alpha_composite(wall)
    return room


def wall_faces(theme, rng):
    """Face tiles for the top wall (15 tiles).  Tiles 6..8 sit behind the top door: plain."""
    faces = ["wall_mid"] * 15
    free = [i for i in range(15) if i not in (6, 7, 8)]
    if theme == "cellar":
        for i, n in zip(rng.sample([1, 3, 4, 10, 12, 13], 2), ["wall_hole_1", "wall_hole_2"]):
            faces[i] = n
    elif theme == "crypt":
        faces[2] = "wall_hole_2"
        faces[12] = "wall_hole_1"
        faces[4] = "wall_goo"
    elif theme == "chapel":
        faces[2] = faces[12] = "wall_banner_red"
        faces[4] = faces[10] = "wall_banner_blue"
    elif theme == "belfry":
        faces[1] = "wall_hole_1"
        faces[11] = "wall_hole_2"
    return faces


def decorate_floor(theme, floor, lay, rng):
    if theme == "crypt":
        # slime dribbling from the goo on the wall (face tile 4) onto the floor tile below
        paste(floor, tile("wall_goo_base"), FLOOR_X0 + 16 * 4, FLOOR_Y0)


# --------------------------------------------------------------------------- doors
# Every door uses the same rule in every theme: the frame is 0x72 sandstone (the colours of
# the 0x72 door arch), the leaf is the 0x72 red-brown plank door with cyan-steel iron, and
# an open door shows a dark corridor floor ('f' = floor_1 recoloured very dark, aligned to
# the room's tile grid).  Variants: boss = blood-red stone + bone skull, black iron, red-lit
# corridor; gold = gilded frame + gem, gold iron.
DOOR_PAL = {
    "normal": {"A": "#222222", "B": "#aa8d7a", "C": "#d3bfa9", "D": "#775c55", "E": "#483b3a",
               "G": "#111111", "H": "#8f4029", "I": "#62232f", "J": "#72d6ce", "K": "#fdf7ed"},
    "boss":   {"A": "#21141b", "B": "#9f294e", "C": "#da4e38", "D": "#62232f", "E": "#38262d",
               "G": "#111111", "H": "#62232f", "I": "#38262d", "J": "#545454", "K": "#b6cbcf"},
    "gold":   {"A": "#222222", "B": "#ee8e2e", "C": "#facb3e", "D": "#c56025", "E": "#8f4029",
               "G": "#111111", "H": "#8f4029", "I": "#62232f", "J": "#facb3e", "K": "#fdf7ed"},
}
CORRIDOR = {  # floor_1 recolour for the corridor seen through an open door: f = near, F = far
    "normal": {"f": {"#222222": "#222222", "#483b3a": "#333333", "#775c55": "#494949"},
               "F": {"#222222": "#111111", "#483b3a": "#2b2929", "#775c55": "#333333"}},
    "boss":   {"f": {"#222222": "#21141b", "#483b3a": "#38262d", "#775c55": "#62232f"},
               "F": {"#222222": "#111111", "#483b3a": "#23151d", "#775c55": "#38262d"}},
    "gold":   {"f": {"#222222": "#222222", "#483b3a": "#3b3332", "#775c55": "#8a503e"},
               "F": {"#222222": "#111111", "#483b3a": "#2b2929", "#775c55": "#3b3332"}},
}
BONE = {"S": "#fdf7ed", "s": "#d3bfa9", "t": "#aa8d7a", "R": "#da4e38", "x": "#21141b"}
GOLDX = {"Y": "#fdf7ed", "y": "#facb3e", "o": "#ee8e2e", "q": "#c56025", "x": "#222222",
         "g": "#72d6ce", "h": "#3c9f9c", "w": "#cae6f5"}


def render_door(rows, variant, slot):
    """Grid -> image.  'f' samples the dark corridor floor at room coordinates."""
    sx, sy, w, h = SLOTS[slot]
    pal = dict(DOOR_PAL[variant])
    pal["f"] = pal["F"] = None
    im = grid(rows, pal)
    fl = {k: remap(tile("floor_1"), m).load() for k, m in CORRIDOR[variant].items()}
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in fl:
                px[x, y] = fl[ch][(sx + x) % 16, (sy + y - 32) % 16]
    return im


# ---- top door, 32x32: left half of the frame, mirrored.  ',' = opening (leaf / corridor).
TOP_FRAME_L = G("""
..........AAAAAA
.......AAACCCACC
.....AACCCBBBABB
....ACCBBAAAAAAA
...ACBBAAAEEEEEE
..ACBAAEEE,,,,,,
.ACBAEE,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
AAAAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
AAAAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
AAAAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAE,,,,,,,,,,,
ACBAAAAAAAAAAAAA
ACBABBBBBABBBBBB
ADDAEEEEEAEEEEEE
AAAAAAAAAAAAAAAA
""")


def _pad_leaf(inner, top=5):
    """22-char interior rows (x 5..26) -> 32-wide rows starting at y=top."""
    rows = ["." * 32] * top
    for r in inner:
        assert len(r) == 22, (len(r), r)
        rows.append("....." + r + ".....")
    while len(rows) < 32:
        rows.append("." * 32)
    return rows


# closed leaf: five planks (G seams), grain streaks, lit from the left
TOP_LEAF_CLOSED = _pad_leaf([
    "GGGGGGGGGGGGGGGGGGGGGG",   # y5
    "GGHHIGHHIGHHHIGHHIGGGG",
    "GHHHIGHHIGHHHIGHHIGHHG",
    "GHHHIGHHIGHHHIGHIIGHIG",
    "GHHIIGHIIGHHIIGHHIGHIG",
    "GHIHIGHHIGHHHIGHHIGIIG",   # y10
    "GHHHIGHHIGIHHIGHHIGHIG",
    "GHHHIGHHIGHHHIGHIIGHIG",
    "GHHIIGHIIGHHHIGHHIGHIG",
    "GHHHIGHHIGHHIIGHHIGIIG",
    "GHHHIGHHIGHHHIGHHIGHIG",   # y15
    "GHIHIGHHIGHHHIGHHIGHIG",
    "GHHHIGHHIGHIHIGHHIGHIG",
    "GHHHIGHHIGHHHIGHHIGIIG",
    "GHHIIGHIIGHHHIGIHIGHIG",
    "GHHHIGHHIGHHHIGHHIGHIG",   # y20
    "GHHHIGHHIGHHIIGHHIGHIG",
    "GHIHIGHHIGHHHIGHHIGHIG",
    "GHHHIGHHIGHHHIGHIIGIIG",
    "GHHHIGIHIGHHHIGHHIGHIG",
    "GHHIIGHHIGHHHIGHHIGHIG",   # y25
    "GHHHIGHHIGHHIIGHHIGHIG",
    "GGGGGGGGGGGGGGGGGGGGGG",   # y27 shadow under the leaf
])
# iron on the closed leaf: two hinge straps from the left jamb + a ring pull on the right
TOP_IRON = G("""
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
__JAAAAAAA______________________
__JKJJKJJA______________________
__JAAAAAAA______________________
____________________AAJAA_______
___________________AJJJJJA______
___________________AJAAAJA______
___________________AKAAAKA______
___________________AAKKKAA______
____________________AAAAA_______
__JAAAAAAA______________________
__JKJJKJJA______________________
__JAAAAAAA______________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
________________________________
""")
# open: the leaf has swung inwards (edge-on at the left with its hinges); beyond it the
# corridor is dark, its first flagstones catching a little of the room's light.
TOP_LEAF_OPEN = _pad_leaf(
    ["IHGGGGGGGGGGGGGGGGGGGG"] * 8 +
    ["JKGGGGGGGGGGGGGGGGGGGG"] +
    ["IHGGGGGGGGGGGGGGGGGGGG"] * 4 +
    ["IHFFFFFFFFFFFFFFFFFFFF"] * 3 +
    ["IHFFFFFFFFFFFFFFFFFFFF"] * 1 +
    ["JKffffffffffffffffffff"] +
    ["IHffffffffffffffffffff"] * 5
)


def door_top(state, variant):
    full = [l + l[::-1] for l in TOP_FRAME_L]
    leaf = TOP_LEAF_CLOSED if state == "closed" else TOP_LEAF_OPEN
    rows = ["".join((lc if lc != "." else "G") if fc == "," else fc for fc, lc in zip(fr, lr))
            for fr, lr in zip(full, leaf)]
    if state == "closed":
        rows = overlay_rows(rows, TOP_IRON)
    im = render_door(rows, variant, "top")
    if variant == "boss":
        paste(im, grid(BOSS_SKULL_TOP, BONE), 11, 0)
    if variant == "gold":
        paste(im, grid(GOLD_GEM_TOP, GOLDX), 12, 0)
    return im


BOSS_SKULL_TOP = G("""
..xxxxxx..
.xSSSSSsx.
xSSSSSSSsx
xSxxSSxxsx
xSxRSsxRsx
xSSSxxSssx
.xSsSsSsx.
.xsxsxsxx.
..xxxxxx..
""")
GOLD_GEM_TOP = G("""
..xxxx..
.xyYyox.
xyxwgxqx
xoxghxqx
.xqxxqx.
..xxxx..
""")


# ---- bottom door, 32x16: seen from the front.  The doorway cuts the cap; two sandstone
# posts frame it.  x 0 / 31 stay transparent so the room's own wall shows there.
_BOT_POST = ["AAAAAA", "ACBBBA", "ABBBBA", "ACCCCA", "ACBBDA", "ACBBDA", "ACBBDA", "ACBBDA",
             "AAAAAA", "ACBBDA", "ACBBDA", "ACBBDA", "ACBBDA", "ACBBDA", "ACBBDA", "AAAAAA"]
_BOT_CLOSED = [
    "AAAAAAAAAAAAAAAAAA",   # y0 top edge of the leaf
    "HHHIHHHHIHHHHHIHHH",   # y1 top of the leaf seen from above
    "IIIIIIIIIIIIIIIIII",
    "AAAAAAAAAAAAAAAAAA",
    "HHHIGHHHIGHHIIGHHI",   # y4 front: planks
    "AAAAAAAHIGHHIIGHHI",
    "KJJKJJAHIGHHIIGHHI",
    "AAAAAAAHIGHHIIGHHI",
    "HHHIGHHHIGHHAJJJAI",
    "HHHIGHIHIGHHJAAAJI",
    "HIHIGHHHIGHIKAAAKI",
    "HHHIGHHHIGHHAKKKAI",
    "AAAAAAAHIGHHIAAAHI",
    "KJJKJJAHIGHHIIGHHI",
    "AAAAAAAHIGHIIIGHHI",
    "AAAAAAAAAAAAAAAAAA",
]
_BOT_OPEN = ["ffffffffffffffffff"] * 6 + ["FFFFFFFFFFFFFFFFFF"] * 5 + ["GGGGGGGGGGGGGGGGGG"] * 5


def door_bottom(state, variant):
    gap = _BOT_CLOSED if state == "closed" else _BOT_OPEN
    rows = ["." + p + g + p + "." for p, g in zip(_BOT_POST, gap)]
    im = render_door(rows, variant, "bottom")
    if variant == "boss":
        paste(im, grid(BOSS_SKULL_SMALL, BONE), 0, 3)
        paste(im, grid(BOSS_SKULL_SMALL, BONE), 24, 3)
    if variant == "gold":
        paste(im, grid(GOLD_GEM_SMALL, GOLDX), 0, 4)
        paste(im, grid(GOLD_GEM_SMALL, GOLDX), 25, 4)
    return im


# ---- side doors, 16x32 (left; the right one is the mirror).  The side wall is seen
# edge-on: two sandstone posts stand in the wall line, the corridor runs off into the dark,
# and when closed the leaf (seen from above, iron straps across it) fills the wall line.
_SIDE_POST = [".......AAAAAAAAA", ".......ACCBBBBBA", ".......ACBBBBBBA", ".......ABBBBBBBA",
              ".......ACCCCCCCA", ".......ADDDDDDDA", ".......AEEEEEEEA", ".......AAAAAAAAA"]
_SIDE_OPEN = ["GFFFFFFfffffffff"] * 16
_SIDE_CLOSED = [
    "GFFFFFFffAHHHIAf",   # y8
    "GFFFFFFffAHHIIAf",
    "GFFFFFFfAAAAAAAf",
    "GFFFFFFfAKJJKJAf",
    "GFFFFFFfAAAAAAAf",
    "GFFFFFFffAHIHIAf",
    "GFFFFFFffAHHHIAf",
    "GFFFFFFffAHHIIAf",
    "GFFFFFFffAHHHIAf",   # y16
    "GFFFFFFffAHIHIAf",
    "GFFFFFFffAHHHIAf",
    "GFFFFFFfAAAAAAAf",
    "GFFFFFFfAKJJKJAf",
    "GFFFFFFfAAAAAAAf",
    "GFFFFFFffAHHIIAf",
    "GFFFFFFffAHHHIAf",   # y23
]


def door_side(state, variant, side="left"):
    mid = _SIDE_CLOSED if state == "closed" else _SIDE_OPEN
    # the room's floor shows through the transparent cells at x 15 next to the leaf
    rows = _SIDE_POST + mid + _SIDE_POST
    im = render_door(rows, variant, "left")
    if variant == "boss":
        paste(im, grid(BOSS_SKULL_SMALL, BONE), 8, 0)
        paste(im, grid(BOSS_SKULL_SMALL, BONE), 8, 24)
    if variant == "gold":
        paste(im, grid(GOLD_GEM_SMALL, GOLDX), 8, 1)
        paste(im, grid(GOLD_GEM_SMALL, GOLDX), 8, 25)
    if side == "right":
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


BOSS_SKULL_SMALL = G("""
.xxxxx.
xSSSSsx
xSSSSsx
xRxSRxx
xSSxSsx
.xSxsx.
..xxx..
""")
GOLD_GEM_SMALL = G("""
.xxxxx.
xyYyyox
xyxwgxq
xoxghxq
.xqqqx.
..xxx..
""")


# --------------------------------------------------------------------------- props
# Shared prop palette (all 0x72 colours).  Light comes from the top-left; every prop has a
# 1 px #222222 outline and a solid contact shadow on the floor (no alpha).
PROP = {
    "A": "#222222",                                   # outline
    "x": "#21141b",                                   # contact shadow on the floor
    "C": "#d3bfa9", "B": "#aa8d7a", "D": "#775c55", "E": "#483b3a", "F": "#2b2929",  # stone
    # clay
    "h": "#fccba3", "w": "#e46e33", "q": "#c56025", "r": "#8f4029", "d": "#62232f",
    "k": "#111111",                                   # dark inside a pot / hole
    # iron + brass
    "i": "#545454", "j": "#3f3f3f", "l": "#333333", "Y": "#facb3e", "o": "#ee8e2e",
    # wax
    "W": "#fdf7ed", "V": "#e2b694", "U": "#d8a57d", "T": "#b58057",
    # wood
    "H": "#8f4029", "I": "#62232f", "P": "#c56025",
    # bone / web
    "S": "#fdf7ed", "s": "#d3bfa9", "b": "#b6cbcf", "g": "#7b8994",
}

ROCK = G("""
................
................
................
.......AAAA.....
.....AACCBBAA...
....ACCBBBBBDA..
...ACBBBBBBBDDA.
..ACBBBBBBBDDDA.
..ABBBBBBBDDDEA.
.ACBBBBBDDDDEEA.
.ABBDDDDDDDEEEA.
.ADDDDDDDDEEEEA.
.AEDDDDDEEEEEAx.
.xAEEEEEEEEAAxx.
..xxAAAAAAAxxx..
...xxxxxxxxxx...
""")
ROCK_B = G("""
................
................
................
................
...AAAAA........
..ACCBBBAA......
.ACBBBBBDDA.....
.ABBBBBDDDEAAAA.
.ABBBDDDDEAACBBA
.ADDDDDDEAACBBDA
.AEDDDDEEACBBDDA
.xAEEEEEAABDDDEA
.xxAAAAAAEDDEEEA
..xxxxxxAAEEEEAx
.......xxxAAAAxx
........xxxxxxx.
""")
URN = G("""
................
.....AAAAAA.....
....AhwwwwqA....
....AqqqqqrA....
.....AkkkkA.....
.....AqqqrA.....
....AwwqqqrA....
...AwhwqqqqrA...
..AwhwqqqqqqrA..
..AwwYYYYYYorA..
..AwqqqqqqqrdA..
..AqqqqqqqrrdA..
...AqqqqqrrdA...
....AArrrddAA...
...xxAAAAAAxx...
....xxxxxxxx....
""")
URN_BROKEN = G("""
................
................
................
................
................
................
................
................
...A.A.AA..A....
..AwAkAkkAAqA...
..AwhkkkkkkqA.A.
..AwwYYYYYYorAqA
..AwqqqqqqqrdA.A
.AwAqqqqqqrrdA..
.AA.AArrrddAAA..
..xxxAAAAAAxxAqA
""")
PIT = G("""
................
..AAAAAAAAAAAA..
.AEEDEEEEDEEEEA.
.AFEEFEEEFEEFEA.
.AFFFFFFFFFFFFA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.AkkkkkkkkkkkkA.
.ADDDDDDDDDDDDA.
..AAAAAAAAAAAA..
................
""")


def build_props():
    out = {}
    out["rock"] = grid(ROCK, PROP)
    out["rock_b"] = grid(ROCK_B, PROP)
    out["urn"] = grid(URN, PROP)
    out["urn_broken"] = grid(URN_BROKEN, PROP)
    out["pit"] = grid(PIT, PROP)
    return out


# --------------------------------------------------------------------------- candelabra
# 16x24 floor candelabra (anchored bottom-centre by the game).  Old brass stand, lit from
# the top-left (o lit edge, q body, r shade, d deepest, a few Y glints), three cream
# candles (W/V/U like the hero's wax), 1 px #222222 outline, solid contact shadow 'x'.
# Unlit: a dark wick pixel above each candle.  Lit: the wick glows (#8f4029, like the base
# of the hero flame) and a tiny flame (FLAME_SHAPES) sits on top of it.
CANDELABRA = G("""
................
................
................
.......A........
......AWVA......
......AWUA......
..A...AVUA...A..
AWVA..AVUA..AWVA
AWUA.AoYoqA.AWUA
AVUA..ArdA..AVUA
AVUA..AoqA..AVUA
AoYqA.AoqA.AoYqA
.ArdA.AoqA.ArdA.
..AqA.AoqA.AqA..
..AqAAAoqAAAqA..
..AoqqqYqqqqrA..
...ArrrqrrrrA...
....AAAqrAAA....
......AoqA......
.....AoYqrA.....
......ArdA......
....AAoqqrAA....
..AAoYqqqqrrAA..
..xxAAAAAAAAxx..
""")
# wick pixel of each candle (left, centre, right) and whether its flame is mirrored so the
# flame's core sits over the wick (left candle: wick on its inner = right wax column).
CANDLE_WICKS = [(2, 6, True), (7, 3, False), (13, 6, False)]
# tiny flames, 2 px wide, 2-3 px tall: W = white-yellow core, Y = #facb3e, o = #ee8e2e.
# Drawn bottom-aligned on the row above the wick, core column over the wick.
FLAME_SHAPES = [
    G("""
    o.
    YY
    WY
    """),
    G("""
    .o
    Yo
    WY
    """),
    G("""
    Yo
    WY
    """),
    G("""
    o.
    Wo
    YY
    """),
]
FLAME_PHASE = [2, 0, 3]   # per candle (left, centre, right) so they never flicker in unison
FLAME_PAL = {"W": "#fdf7ed", "Y": "#facb3e", "o": "#ee8e2e"}
WICK_LIT = "#8f4029"


def candelabra(frame=None):
    """frame None -> unlit; 0..3 -> lit loop frame."""
    im = grid(CANDELABRA, PROP)
    if frame is None:
        return im
    px = im.load()
    for (wx, wy, mirrored), ph in zip(CANDLE_WICKS, FLAME_PHASE):
        px[wx, wy] = rgb(WICK_LIT) + (255,)
        shape = FLAME_SHAPES[(frame + ph) % len(FLAME_SHAPES)]
        if mirrored:
            shape = mirror_rows(shape)
        fl = grid(shape, FLAME_PAL)
        paste(im, fl, wx - 1 if mirrored else wx, wy - len(shape))
    return im


# --------------------------------------------------------------------------- trapdoor
# 32x32 hatch set in a sandstone frame (same stone + plank + cyan iron colours as the
# doors, so it reads as part of the same house in every theme).  Closed: like a door leaf
# lying in the floor - vertical planks, two riveted hinge straps from knuckles on the left
# frame edge, ring pull on the right.  Open: the leaf is gone (only the knuckles remain),
# the shaft's far wall catches a little light and a ladder runs down into the dark (0x72
# floor_ladder idea at 2x2 tiles: the ladder wood darkens with depth).
TRAP_PAL = {
    "A": "#222222", "B": "#aa8d7a", "C": "#d3bfa9", "D": "#775c55", "E": "#483b3a",
    "G": "#111111", "H": "#8f4029", "I": "#62232f", "P": "#c56025", "J": "#72d6ce",
    "K": "#fdf7ed", "k": "#111111", "Q": "#38262d", "Z": "#23151d",
    "3": "#3b3332", "2": "#302c2b", "F": "#2b2929",
}
# frame, ',' = the 24x24 opening (x 4..27, y 4..27)
TRAP_FRAME = G("""
.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.
ACCCCCCCCCCACCCCCCCCACCCCCCCCCBA
ACBBBBBBBBBABBBBBBBBABBBBBBBBBDA
ACBAAAAAAAAAAAAAAAAAAAAAAAAAABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
AAAA,,,,,,,,,,,,,,,,,,,,,,,,AAAA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
AAAA,,,,,,,,,,,,,,,,,,,,,,,,AAAA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBA,,,,,,,,,,,,,,,,,,,,,,,,ABDA
ACBAAAAAAAAAAAAAAAAAAAAAAAAAABDA
ACBBBBBBBBBABBBBBBBBABBBBBBBBBDA
ABDDDDDDDDDADDDDDDDDADDDDDDDDDDA
.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.
""")
# closed leaf (24x24): six vertical planks (H H, I shade, G seam) like the door leaves;
# the top row and left column sit in the frame's shadow, a dark gap runs along the right
# and bottom edges.  A few hand-placed I streaks for grain.
TRAP_LEAF = G("""
IIIGIIIGIIIGIIIGIIIGIIIG
IHIGHHIGHHIGHHIGHHIGHHIG
IHIGHHIGHIIGHHIGHHIGHHIG
IHIGHHIGHIIGHHIGHHIGHHIG
IHIGHHIGHHIGHHIGHHIGHHIG
IHIGHHIGHHIGHHIGHHIGHHIG
IHIGHHIGHHIGHHIGIHIGHHIG
IHIGIHIGHHIGHHIGIHIGHHIG
IHIGIHIGHHIGHHIGHHIGHHIG
IHIGHHIGHHIGHIIGHHIGHHIG
IHIGHHIGHHIGHIIGHHIGHHIG
IIIGHHIGHHIGHHIGHHIGHIIG
IHIGHHIGHHIGHHIGHHIGHIIG
IHIGHHIGHHIGHHIGHHIGHHIG
IHIGHHIGHIIGHHIGHHIGHHIG
IHIGHHIGHIIGHHIGHHIGHHIG
IHIGHHIGHHIGHHIGHHIGHHIG
IHIGHIIGHHIGHHIGHHIGHHIG
IHIGHIIGHHIGHHIGIHIGHHIG
IHIGHHIGHHIGHHIGIHIGHHIG
IHIGHHIGHHIGHHIGHHIGHHIG
IHIGHHIGHHIGHIIGHHIGIHIG
IHIGHHIGHHIGHHIGHHIGHHIG
GGGGGGGGGGGGGGGGGGGGGGGG
""")
# iron on the closed leaf ('_' keeps the wood): two hinge straps from the left frame edge
# (riveted on every plank, tapered ends) and a ring pull on the right, as on the doors.
TRAP_IRON = G("""
________________________
________________________
________________________
AAAAAAAAAAAAAAA_________
JKJJJKJJJKJJJKJA________
AAAAAAAAAAAAAAA_________
________________________
________________________
________________________
_________________AAJAA__
________________AJJJJJA_
________________AJAAAJA_
________________AKAAAKA_
________________AAKKKAA_
_________________AAAAA__
________________________
________________________
AAAAAAAAAAAAAAA_________
JKJJJKJJJKJJJKJA________
AAAAAAAAAAAAAAA_________
________________________
________________________
________________________
________________________
""")
# hinge knuckles on the left frame edge (both states), level with the straps
TRAP_HINGES = [(1, 7), (1, 21)]
TRAP_HINGE = {"closed": G("""
AAA
KJJ
AAA
"""), "open": G("""
AA.
KJ.
AA.
""")}
# open: the shaft (24x24).  Far wall: two courses of dark stone, then black.
TRAP_SHAFT = G("""
EEEEEEEFEEEEEEEFEEEEEEEF
3333333F3333333F3333333F
FFFFFFFFFFFFFFFFFFFFFFFF
222F2222222F2222222F2222
FFFFFFFFFFFFFFFFFFFFFFFF
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
kkkkkkkkkkkkkkkkkkkkkkkk
""")
# ladder over the shaft ('_' keeps the shaft): rails x 6..7 / 16..17, a rung every 4 rows,
# wood darkening with depth P/H -> H/I -> I/Q -> Q/Z, gone in the dark near the bottom.
# On the lit far wall the ladder has an outline and each rung throws a shadow.
TRAP_LADDER = G("""
_____APHA______APHA_____
_____APHPPPPPPPPPHA_____
_____APHAAAAAAAAPHA_____
_____APHA______APHA_____
_____APHA______APHA_____
_____AHIHHHHHHHHHIA_____
______HI________HI______
______HI________HI______
______HI________HI______
______IQIIIIIIIIIQ______
______IQ________IQ______
______IQ________IQ______
______IQ________IQ______
______QZQQQQQQQQQZ______
______QZ________QZ______
______QZ________QZ______
______QZ________QZ______
______ZkZZZZZZZZZk______
______Z_________Z_______
______Z_________Z_______
________________________
________________________
________________________
________________________
""")
# the rail tops stick up out of the hole over the frame's inner edge (sprite row 3)
TRAP_LADDER_TOP = [(10, 3, "P"), (11, 3, "H"), (20, 3, "P"), (21, 3, "H")]


def trapdoor(state):
    rows = list(TRAP_FRAME)
    inner = overlay_rows(TRAP_LEAF, TRAP_IRON) if state == "closed" else \
        overlay_rows(TRAP_SHAFT, TRAP_LADDER)
    for i, r in enumerate(inner):
        y = 4 + i
        rows[y] = rows[y][:4] + r + rows[y][28:]
    if state == "open":
        for x, y, c in TRAP_LADDER_TOP:
            rows[y] = rows[y][:x] + c + rows[y][x + 1:]
    im = grid(rows, TRAP_PAL)
    for hx, hy in TRAP_HINGES:
        paste(im, grid(TRAP_HINGE[state], TRAP_PAL), hx, hy)
    return im


# --------------------------------------------------------------------------- decals
# Flat floor decals: subtle, no contact shadow.  Cracks use only the floor's own dark
# (#222222) and a deeper #111111 chip so they work on every theme's floor; bones copy the
# 0x72 skull (no outline, #d3bfa9 / #aa8d7a, #222222 underside); web = dusty steel threads.
DECAL = {"A": "#222222", "k": "#111111", "s": "#d3bfa9", "t": "#aa8d7a", "g": "#7b8994",
         "b": "#b6cbcf", "W": "#fdf7ed", "V": "#e2b694", "U": "#d8a57d", "T": "#b58057"}
DECAL_CRACKS = [
    G("""
    .........A
    .......AA.
    ......A...
    ...AAA....
    ..A..A....
    AA....A...
    """),
    G("""
    .............A
    ...........AA.
    .......AAAA...
    ......Ak......
    ...AAA.A......
    ..A.....A.....
    AA.......A....
    """),
    G("""
    A...........
    .A..........
    .A..........
    ..AA........
    ....A.......
    ....A..A....
    .....AA.....
    ......A.....
    .......AA...
    .........A..
    .........A..
    ..........AA
    """),
    G("""
    ..............A
    ............AA.
    ..........AA...
    .........A.....
    ........kA.....
    ....AAAk.A.....
    ..AA......A....
    .A.........AA..
    A..............
    """),
]
# corner web for the TOP-LEFT floor corner (the game mirrors it): a small bright hub in
# the corner, five radials (both walls, 26/45/63 degrees) and three rings that sag
# between the radials, so the outer edge is scalloped.  Threads never clump.
DECAL_COBWEB = G("""
bbggg....g....g.
bb..g...g....g..
g.b.gg..g...g...
g..g..ggg...g...
ggg.g...gg..g...
..g..g.g..ggg...
...g..g.....g...
...g.g.g...g....
.gggg...g..g....
g...g....gg.....
.....g...gg.....
.....g.gg.......
..ggggg.........
.g..............
g...............
................
""")
# a femur, a smaller bone and a chip, coloured like the 0x72 skull: lit top/left (s),
# shade (t), #222222 under the shafts
DECAL_BONES = G("""
.......s..t....
.......sstt....
........stA....
........stA....
.......sstt..s.
.......s..t..t.
...............
ss.......ss....
.sssssssss.....
.ttttttttt.....
ttAAAAAAAtt....
""")
# a flat, lobed pool of spilt wax: one body tone (no dome shading), the front edge a
# shade darker, a one-pixel glint and one stray drop
DECAL_WAX = G("""
..VVV..VV....
.VWVVVVVVV...
VVVVVVVVVVV..
.UVVVVVVVVU.U
..UUUUUUUU...
""")


def build_room_extras():
    out = {}
    out["candelabra_unlit"] = candelabra(None)
    for f in range(4):
        out["candelabra_lit_f%d" % f] = candelabra(f)
    out["trapdoor_closed"] = trapdoor("closed")
    out["trapdoor_open"] = trapdoor("open")
    for i, rows in enumerate(DECAL_CRACKS):
        out["decal_crack_%d" % i] = grid(rows, DECAL)
    out["decal_cobweb"] = grid(DECAL_COBWEB, DECAL)
    out["decal_bones"] = grid(DECAL_BONES, DECAL)
    out["decal_wax_puddle"] = grid(DECAL_WAX, DECAL)
    return out


# --------------------------------------------------------------------------- review
def contact(items, path, scale=6, cols=6, bg=(26, 20, 24, 255), label=True):
    """items: list of (name, image).  Nearest-neighbour contact sheet."""
    cw = max(im.size[0] for _, im in items) * scale + 16
    ch = max(im.size[1] for _, im in items) * scale + (22 if label else 12)
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * min(cols, len(items)), ch * rows), bg)
    d = ImageDraw.Draw(sheet)
    for k, (n, im) in enumerate(items):
        x = (k % cols) * cw + 8
        y = (k // cols) * ch + (16 if label else 6)
        sheet.alpha_composite(im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST),
                              (x, y))
        if label:
            d.text((x, y - 14), n, fill=(230, 230, 230, 255))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    return path


def on_bg(im, bg=(9, 7, 9, 255)):
    out = Image.new("RGBA", im.size, bg)
    out.alpha_composite(im)
    return out


def compose_preview(made, theme, doors, props=()):
    """Room + doors {dir: suffix_state} + props [(name, x, y)] on the game's clear colour."""
    im = on_bg(made["room_" + theme])
    for d, st in doors.items():
        x, y, w, h = SLOTS[d]
        spr = made["door_%s%s" % (d, st)]
        assert spr.size == (w, h), (d, spr.size)
        im.alpha_composite(spr, (x, y))
    for name, x, y in props:
        spr = made[name] if name in made else tile(name)
        im.alpha_composite(spr, (x, y))
    return im


def review_extras(made):
    """Contact sheet (8x on #1a1418) + cellar composites for the candelabra/trapdoor/decals."""
    names = list(build_room_extras().keys())
    contact([(n, made[n]) for n in names], os.path.join(REVIEW2, "extras_8x.png"),
            scale=8, cols=6)
    # the same sprites on the cellar floor colour, closer to how they are seen in game
    contact([(n, on_bg(made[n], (72, 59, 58, 255))) for n in names],
            os.path.join(REVIEW2, "extras_on_floor_8x.png"), scale=8, cols=6)
    web_r = made["decal_cobweb"].transpose(Image.FLIP_LEFT_RIGHT)
    for tag, lit, trap in (("lit", True, "trapdoor_open"), ("unlit", False, "trapdoor_closed")):
        im = compose_preview(made, "cellar", {"top": "_open" if lit else "_closed",
                                              "bottom": "_open" if lit else "_closed",
                                              "left": "_open" if lit else "_closed",
                                              "right": "_open" if lit else "_closed"})
        im.alpha_composite(made["decal_cobweb"], (16, 32))
        im.alpha_composite(web_r, (256 - 16, 32))
        # the bottom corners show the web on its own (mirrored as the game would)
        im.alpha_composite(made["decal_cobweb"].transpose(Image.FLIP_TOP_BOTTOM), (16, 160))
        im.alpha_composite(web_r.transpose(Image.FLIP_TOP_BOTTOM), (240, 160))
        for name, x, y in (("decal_crack_0", 60, 140), ("decal_crack_1", 190, 70),
                           ("decal_crack_2", 90, 60), ("decal_crack_3", 200, 150),
                           ("decal_bones", 44, 92), ("decal_wax_puddle", 30, 56),
                           ("decal_wax_puddle", 112, 150), (trap, 144, 112)):
            im.alpha_composite(made[name], (x, y))
        cand = made["candelabra_lit_f0" if lit else "candelabra_unlit"]
        for cx in (24, 248):                     # bottom-centre on the floor, top corners
            im.alpha_composite(cand, (cx - 8, 52 - 24))
        im.resize((ROOM_W * 4, ROOM_H * 4), Image.NEAREST).save(
            os.path.join(REVIEW2, "cellar_extras_%s_4x.png" % tag))
        im.crop((0, 0, 136, 96)).resize((136 * 8, 96 * 8), Image.NEAREST).save(
            os.path.join(REVIEW2, "cellar_extras_%s_corner_8x.png" % tag))


def main():
    review = "--review" in sys.argv
    pal = sheet_palette()
    made = {}
    for theme in THEMES:
        made["room_" + theme] = build_room(theme)
    for variant in ("normal", "boss", "gold"):
        suf = "" if variant == "normal" else "_" + variant
        for state in ("open", "closed"):
            made["door_top%s_%s" % (suf, state)] = door_top(state, variant)
            made["door_bottom%s_%s" % (suf, state)] = door_bottom(state, variant)
            made["door_left%s_%s" % (suf, state)] = door_side(state, variant, "left")
            made["door_right%s_%s" % (suf, state)] = door_side(state, variant, "right")
    made.update(build_props())
    made.update(build_room_extras())
    for name, im in made.items():
        a = np.array(im)
        assert set(np.unique(a[:, :, 3])) <= {0, 255}, name + " has semi-transparent pixels"
        cols = {tuple(int(v) for v in p[:3]) for p in a.reshape(-1, 4) if p[3]}
        bad = cols - pal
        assert not bad, "%s uses colours outside the 0x72 palette: %s" % (
            name, ["#%02x%02x%02x" % c for c in bad])
        save(im, name)
    if review:
        for theme in THEMES:
            on_bg(made["room_" + theme]).resize((ROOM_W * 4, ROOM_H * 4), Image.NEAREST).save(
                os.path.join(REVIEW, "room_%s_4x.png" % theme))
        for theme in THEMES:
            pv = compose_preview(made, theme, {"top": "_open", "bottom": "_open", "left": "_open",
                                               "right": "_open"})
            pv.resize((ROOM_W * 4, ROOM_H * 4), Image.NEAREST).save(
                os.path.join(REVIEW, "rooms_preview_%s.png" % theme))
        pv = compose_preview(made, "cellar", {"top": "_closed", "bottom": "_closed",
                                              "left": "_closed", "right": "_closed"})
        pv.resize((ROOM_W * 4, ROOM_H * 4), Image.NEAREST).save(
            os.path.join(REVIEW, "doors_closed_cellar.png"))
        pv = compose_preview(made, "crypt", {"top": "_boss_closed", "bottom": "_gold_closed",
                                             "left": "_boss_open", "right": "_gold_open"})
        pv.resize((ROOM_W * 4, ROOM_H * 4), Image.NEAREST).save(
            os.path.join(REVIEW, "doors_special_crypt.png"))
        props = [(n, on_bg(im, (72, 59, 58, 255))) for n, im in made.items()
                 if not n.startswith(("door_", "room_"))]
        contact(props, os.path.join(REVIEW, "props.png"), scale=8, cols=6)
        doors = [(n, on_bg(im)) for n, im in made.items() if n.startswith("door_")]
        contact(doors, os.path.join(REVIEW, "doors.png"), scale=8, cols=6)
        review_extras(made)
    print("wrote %d files to %s" % (len(made), OUT))


if __name__ == "__main__":
    main()
