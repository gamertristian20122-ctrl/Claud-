"""Shot 1 in Blender Grease Pencil: Rudy squirts ketchup on his ice cream.

blender -b -P tools/gp_shot1.py -- <out_dir> [preview]
Renders RGBA PNG frames at 12 drawings per second (the hand-drawn cadence).
The character is a cutout rig (one GP object per part, FK by object rotation),
the face, ketchup stream and drips are replacement drawings, and a noise modifier
makes the ink boil slightly every other drawing, like hand-traced animation.
"""
import math
import os
import random
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.join(HERE, "..", "..", "..", ".claude", "skills", "scenario-blender-grease-pencil", "scripts")
sys.path.append(os.path.abspath(SKILL))
sys.path.append("/opt/pylib")
import bx_gp as G  # noqa: E402
from shapely import affinity  # noqa: E402
from shapely.geometry import Polygon  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else "/tmp/gp_shot1")
PREVIEW = len(argv) > 1 and argv[1] == "preview"
os.makedirs(OUT, exist_ok=True)

FPS = 12
DUR = 2.6
N_FRAMES = int(round(DUR * FPS))
PX = 0.01                       # 1 px = 1 cm; ortho 19.2 m tall frame
LIGHT = (-0.78, -0.62)          # toward the light, screen coords (y down)
rng = random.Random(1830)

INK = "#33251e"
SKIN, SKIN_SH = "#fbf6ee", "#d6cbd6"
HOOD, HOOD_SH, HOOD_DK = "#2f8c8a", "#1f6670", "#17505b"
CAP, CAP_SH, CAP_DK = "#efb042", "#c4802f", "#9a5f25"
HAIR, HAIR_SH = "#4a2c22", "#2e1a16"
RED, RED_SH = "#e0362b", "#a9201f"
MOUTH, TONGUE = "#5b1f2a", "#ef7f86"
GLOVE, GLOVE_SH = "#ffffff", "#d6d0e0"

# ---------------------------------------------------------------- stage
bpy.ops.wm.read_factory_settings(use_empty=True)
cam = G.scene_2d(res=(1080, 1920), fps=FPS, frame_range=(1, N_FRAMES), ortho_scale=19.2,
                 transparent=True)
sc = bpy.context.scene
sc.grease_pencil_settings.antialias_threshold = 1.0
try:
    sc.render.engine = "BLENDER_EEVEE"
except Exception:
    pass


def W(x, y):
    """screen px (y down, origin top-left) -> world XZ metres."""
    return ((x - 540) * PX, 0.0, (960 - y) * PX)


def rot(p, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)


def catmull(points, samples=8, closed=True):
    pts3 = [(x, 0.0, y) for x, y in points]          # smooth in a neutral space
    out = G.smooth_path(pts3, samples=samples, closed=closed)
    return [(p[0], p[2]) for p in out]


# ---------------------------------------------------------------- rig nodes
class Node:
    """A GP object for one physical part. Drawing data is given in screen px at the rest
    pose; it is stored in the part's own frame so FK rotations act about its pivot."""

    def __init__(self, name, pivot, angle=0.0, parent=None, depth=0.0, upright=False):
        self.name, self.pivot, self.rest, self.parent = name, pivot, angle, parent
        self.upright = upright      # True: points are given already un-rotated (design space)
        self.ob = G.new_object(name, layers=("Art",))
        lay = self.ob.data.layers["Art"]
        lay.use_lights = False
        if parent is None:
            self.ob.location = (W(*pivot)[0], depth, W(*pivot)[2])
        else:
            self.ob.parent = parent.ob
            rel = rot((pivot[0] - parent.pivot[0], pivot[1] - parent.pivot[1]), -parent.rest)
            self.ob.location = (rel[0] * PX, depth, -rel[1] * PX)
        self.set_local(angle - (parent.rest if parent else 0.0))
        self.mats = {}
        self.boil()

    def boil(self):
        m = self.ob.modifiers.new("boil", "GREASE_PENCIL_NOISE")
        m.factor = 0.2
        m.factor_strength = 0.0
        m.factor_thickness = 0.08
        m.noise_scale = 0.6
        m.use_random = True
        m.step = 2
        m.seed = rng.randint(1, 999)

    def mat(self, stroke=None, fill=None):
        key = (stroke, fill)
        if key not in self.mats:
            name = f"M_{stroke or ''}_{fill or ''}"
            self.mats[key] = G.material(self.ob, name, stroke=stroke or INK, fill=fill or "#ffffff")
        return self.mats[key]

    def local(self, p):
        if self.upright:
            q = (p[0] - self.pivot[0], p[1] - self.pivot[1])
        else:
            q = rot((p[0] - self.pivot[0], p[1] - self.pivot[1]), -self.rest)
        return (q[0] * PX, 0.0, -q[1] * PX)

    def set_local(self, deg):
        self.ob.rotation_euler = (0.0, math.radians(deg), 0.0)

    def drawing(self, frame=1):
        return G.key(self.ob, "Art", frame)

    # ---- drawing primitives (all inputs in screen px)
    def shape(self, ctrl, fill, shade, depth=18, line=8, frame=1, smooth=True, ink=True):
        d = self.drawing(frame)
        pts = catmull(ctrl) if smooth else list(ctrl)
        poly = Polygon(pts)
        if not poly.is_valid:
            poly = poly.buffer(0)
        G.add_shape(d, [self.local(p) for p in pts], material=self.mat(fill=fill))
        if depth and shade:
            lit = affinity.translate(poly, LIGHT[0] * depth, LIGHT[1] * depth)
            sh = poly.difference(lit)
            geoms = getattr(sh, "geoms", [sh])
            for g in geoms:
                if g.is_empty or g.area < 30:
                    continue
                ext = [self.local(p) for p in list(g.exterior.coords)[:-1]]
                holes = [[self.local(p) for p in list(r.coords)[:-1]] for r in g.interiors]
                G.add_shape(d, ext, holes=holes, material=self.mat(fill=shade))
        if ink:
            self.outline(pts, line, frame)

    def outline(self, pts, line, frame):
        d = self.drawing(frame)
        n = len(pts)
        area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
        sgn = 1 if area > 0 else -1
        pres = []
        for i in range(n):
            a, b = pts[i - 1], pts[(i + 1) % n]
            tx, ty = b[0] - a[0], b[1] - a[1]
            L = math.hypot(tx, ty) or 1
            nx, ny = (ty / L) * -sgn, (-tx / L) * -sgn      # outward normal (screen, y down)
            facing = nx * LIGHT[0] + ny * LIGHT[1]          # +1 faces the light
            pres.append(0.62 + 0.55 * max(0.0, -facing) + rng.uniform(-0.05, 0.05))
        G.add_stroke(d, [self.local(p) for p in pts], radius=line / 2 * PX, pressure=pres,
                     brush="INK_PEN", material=self.mat(stroke=INK), cyclic=True)

    def line(self, ctrl, w=7, color=INK, frame=1, taper=(0.25, 0.3)):
        d = self.drawing(frame)
        pts = catmull(ctrl, samples=10, closed=False) if len(ctrl) > 2 else list(ctrl)
        G.add_stroke(d, [self.local(p) for p in pts], radius=w / 2 * PX,
                     pressure=G.taper(len(pts), start=taper[0], end=taper[1], floor=0.15),
                     brush="INK_PEN", material=self.mat(stroke=color))

    def dot(self, x, y, rx, ry, color, frame=1, angle=0):
        pts = []
        for i in range(24):
            a = 2 * math.pi * i / 24
            q = rot((rx * math.cos(a), ry * math.sin(a)), angle)
            pts.append((x + q[0], y + q[1]))
        G.add_shape(self.drawing(frame), [self.local(p) for p in pts], material=self.mat(fill=color))


def limb_outline(p0, p1, w0, w1):
    """Tapered sleeve polygon from p0 to p1 with round ends (screen px)."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    pts = []
    for i in range(9):                     # far cap
        a = -math.pi / 2 + math.pi * i / 8
        pts.append((p1[0] + (ux * math.cos(a) + nx * math.sin(a)) * w1 / 2 * -1 * -1,
                    p1[1] + (uy * math.cos(a) + ny * math.sin(a)) * w1 / 2))
    for i in range(9):                     # near cap
        a = math.pi / 2 + math.pi * i / 8
        pts.append((p0[0] + (ux * math.cos(a) + nx * math.sin(a)) * w0 / 2,
                    p0[1] + (uy * math.cos(a) + ny * math.sin(a)) * w0 / 2))
    return pts


def ik(S, T, L1, L2, bend):
    dx, dy = T[0] - S[0], T[1] - S[1]
    d = min(L1 + L2 - 1, max(abs(L1 - L2) + 1, math.hypot(dx, dy)))
    a = math.atan2(dy, dx)
    k = math.acos((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))
    a1 = a + bend * k
    E = (S[0] + L1 * math.cos(a1), S[1] + L1 * math.sin(a1))
    a2 = math.atan2(T[1] - E[1], T[0] - E[0])
    return math.degrees(a1), math.degrees(a2), E


# ================================================================ build Rudy
L1, L2 = 340, 330
SL, HL = (180, 1220), (742, 1070)
SR, HR = (640, 1060), (806, 452)
aL1, aL2, EL = ik(SL, HL, L1, L2, bend=1)
aR1, aR2, ER = ik(SR, HR, L1, L2, bend=-1)
HAND_L_ANG, HAND_R_ANG, BOTTLE_ANG = -70.0, -8.0, 172.0

root = Node("Root", (540, 900), angle=0.0, depth=0.0)
root.ob.modifiers.clear()
body = Node("Body", (450, 1150), parent=root, depth=0.0)
body.shape([(230, 1150), (300, 1080), (430, 1050), (560, 1060), (650, 1110), (600, 1160), (440, 1170), (300, 1180)],
           HOOD_SH, HOOD_DK, depth=12)
body.shape([(40, 2000), (60, 1480), (110, 1270), (210, 1150), (360, 1100), (520, 1095), (680, 1130), (790, 1240),
            (850, 1450), (880, 2000)], HOOD, HOOD_SH, depth=46, line=10)
body.shape([(200, 1640), (640, 1630), (700, 1900), (150, 1910)], HOOD_SH, HOOD_DK, depth=14)
for c in ([(170, 1380), (230, 1470), (240, 1590)], [(700, 1330), (680, 1450), (700, 1560)], [(330, 1620), (420, 1600), (520, 1615)]):
    body.line(c, w=8, color=HOOD_DK)
body.line([(380, 1170), (370, 1270), (382, 1360)], w=11, color="#f2ede4")
body.line([(480, 1172), (494, 1260), (486, 1340)], w=11, color="#f2ede4")

NECK = (450, 1090)
head = Node("Head", NECK, angle=-5.0, parent=body, depth=-0.10, upright=True)
head.shape([(282, 880), (232, 856), (206, 905), (222, 968), (276, 980)], SKIN, SKIN_SH, depth=10)
head.line([(232, 900), (220, 925), (236, 950)], w=6)
head.shape([(250, 880), (265, 770), (330, 700), (440, 680), (550, 700), (630, 760), (660, 860), (640, 980),
            (580, 1060), (470, 1095), (360, 1080), (285, 1010)], SKIN, SKIN_SH, depth=26, line=9)
head.dot(360, 975, 40, 20, "#f3b0a6")
head.dot(620, 960, 24, 14, "#f3b0a6")
head.shape([(246, 860), (270, 840), (296, 868), (278, 900), (300, 930), (262, 930)], HAIR, HAIR_SH, depth=8, line=7)
head.shape([(600, 822), (640, 814), (668, 846), (650, 880), (630, 858)], HAIR, HAIR_SH, depth=8, line=7)
head.shape([(262, 790), (280, 690), (350, 610), (460, 585), (570, 610), (640, 690), (664, 800), (500, 760), (330, 780)],
           CAP, CAP_SH, depth=24, line=9)
head.shape([(244, 860), (270, 770), (420, 732), (590, 748), (668, 800), (672, 856), (600, 820), (430, 806), (290, 840), (250, 900)],
           CAP_SH, CAP_DK, depth=12, line=9)
for x in range(300, 660, 44):
    head.line([(x, 768 + (x - 450) ** 2 / 3000), (x + 6, 820 + (x - 450) ** 2 / 4000)], w=6, color=CAP_DK, taper=(0.3, 0.3))
head.line([(330, 690), (400, 640), (470, 628)], w=16, color="#ffe3a6", taper=(0.4, 0.4))
head.shape([(430, 560), (450, 520), (490, 512), (520, 530), (530, 568), (510, 600), (470, 606), (440, 590)],
           "#f6e7c8", "#d8c2a0", depth=10, line=8)
head.line([(650, 900), (672, 922), (648, 936)], w=7)

brows = Node("Brows", NECK, parent=head, depth=-0.01, upright=True)
brows.line([(395, 846), (432, 826), (470, 832)], w=13)
brows.line([(528, 828), (562, 818), (594, 830)], w=12)

eyes = Node("Eyes", NECK, parent=head, depth=-0.012, upright=True)


def eyes_open(f):
    eyes.dot(440, 896, 18, 28, INK, frame=f, angle=10)
    eyes.dot(560, 890, 15, 24, INK, frame=f, angle=10)
    eyes.dot(446, 884, 6, 6, "#ffffff", frame=f)
    eyes.dot(565, 879, 5, 5, "#ffffff", frame=f)


def eyes_shut(f):
    eyes.line([(420, 900), (440, 910), (462, 898)], w=8, frame=f)
    eyes.line([(542, 894), (560, 903), (580, 892)], w=7, frame=f)


def eyes_happy(f):
    eyes.line([(418, 906), (440, 878), (464, 904)], w=10, frame=f)
    eyes.line([(540, 900), (560, 874), (582, 898)], w=9, frame=f)


mouth = Node("Mouth", NECK, parent=head, depth=-0.012, upright=True)


def mouth_grin(f, big=1.0):
    def M(x, y):
        return (510 + (x - 510) * big, 1000 + (y - 1000) * big)
    m = [M(*p) for p in [(400, 975), (500, 985), (618, 958), (606, 1012), (560, 1052), (480, 1058), (424, 1022)]]
    mouth.shape(m, MOUTH, None, depth=0, line=8, frame=f)
    mouth.shape([M(*p) for p in [(406, 980), (505, 994), (612, 964), (606, 980), (505, 1006), (414, 994)]],
                "#ffffff", None, depth=0, frame=f, ink=False, smooth=False)
    mouth.shape([M(*p) for p in [(452, 1036), (510, 1018), (572, 1030), (548, 1054), (482, 1058)]],
                TONGUE, None, depth=0, frame=f, ink=False)
    mouth.line([M(392, 968), M(412, 980)], w=6, frame=f)


# ---- right arm (raised) with the bottle
upR = Node("UpperR", SR, aR1, parent=body, depth=-0.20)
upR.shape(limb_outline(SR, ER, 150, 132), HOOD, HOOD_SH, depth=30, line=9)
foR = Node("ForeR", ER, aR2, parent=upR, depth=-0.01)
foR.shape(limb_outline(ER, HR, 132, 112), HOOD, HOOD_SH, depth=26, line=9)
cuffR = [(HR[0] + (ER[0] - HR[0]) * t, HR[1] + (ER[1] - HR[1]) * t) for t in (0.0, 0.09)]
foR.shape(limb_outline(cuffR[1], cuffR[0], 120, 120), HOOD_SH, HOOD_DK, depth=8, line=8)


def glove_pts(cx, cy, s, angle, flip):
    sx = -1 if flip else 1

    def P(x, y):
        q = rot((x * s * sx, y * s), angle)
        return (cx + q[0], cy + q[1])
    return P


def draw_glove(node, cx, cy, s, angle, flip):
    P = glove_pts(cx, cy, s, angle, flip)
    node.shape([P(-46, -40), P(30, -52), P(56, -10), P(52, 40), P(10, 58), P(-44, 44), P(-58, 0)], GLOVE, GLOVE_SH, depth=10, line=8)
    for y in (-30, -2, 26):
        node.shape([P(4, y - 15), P(58, y - 17), P(68, y), P(58, y + 15), P(4, y + 14)], GLOVE, GLOVE_SH, depth=6, line=6)
    node.shape([P(-40, -46), P(-6, -70), P(24, -62), P(10, -40), P(-30, -26)], GLOVE, GLOVE_SH, depth=6, line=6)


bottle = Node("Bottle", HR, BOTTLE_ANG, parent=foR, depth=-0.01, upright=True)
handR = Node("HandR", HR, HAND_R_ANG, parent=foR, depth=-0.02, upright=True)
draw_glove(handR, HR[0], HR[1], 1.25, 0, True)


def bottle_design():
    """Bottle in its own upright frame (nozzle toward -y); grip at HR, offset 22 px along the nozzle."""
    def B(x, y):
        return (HR[0] + x, HR[1] + y - 22)
    bottle.shape([B(-16, -204), B(16, -204), B(8, -244), B(-8, -244)], "#f8f4ec", "#cfc8cf", depth=5, line=6, smooth=False)
    bottle.shape([B(-40, -206), B(40, -206), B(40, -162), B(-40, -162)], "#f8f4ec", "#cfc8cf", depth=8, line=7, smooth=False)
    body_pts = []
    for i in range(32):
        a = 2 * math.pi * i / 32
        x, y = 58 * math.cos(a), 115 * math.sin(a)
        x = max(-58, min(58, x * 1.18))
        body_pts.append(B(x, -55 + y))
    bottle.shape(body_pts, RED, RED_SH, depth=20, line=8, smooth=False)
    bottle.line([B(-36, -150), B(-40, -60), B(-34, 20)], w=16, color="#ff8f78", taper=(0.4, 0.4))
    bottle.dot(B(0, -70)[0], B(0, -70)[1], 42, 52, "#fbecc9")
    bottle.dot(B(0, -64)[0], B(0, -64)[1], 22, 22, RED)


bottle_design()

# ---- left arm with the cone
upL = Node("UpperL", SL, aL1, parent=body, depth=-0.30)
upL.shape(limb_outline(SL, EL, 150, 132), HOOD, HOOD_SH, depth=30, line=9)
foL = Node("ForeL", EL, aL2, parent=upL, depth=-0.01)
foL.shape(limb_outline(EL, HL, 132, 112), HOOD, HOOD_SH, depth=26, line=9)
cuffL = [(HL[0] + (EL[0] - HL[0]) * t, HL[1] + (EL[1] - HL[1]) * t) for t in (0.0, 0.09)]
foL.shape(limb_outline(cuffL[1], cuffL[0], 120, 120), HOOD_SH, HOOD_DK, depth=8, line=8)

cone = Node("Cone", HL, 0.0, parent=foL, depth=-0.01, upright=True)


def C(x, y):
    return (470 + 1.05 * x, 430 + 1.05 * y)


cone.shape([C(250, 560), C(420, 560), C(350, 820), C(325, 830)], "#e9a85b", "#b9773a", depth=18, line=8)
for a, b in ((270, 370), (310, 400), (350, 420), (290, 260)):
    cone.line([C(a, 572), C(b, 760)], w=5, color="#a86a2c")
cone.shape([C(240, 560), C(250, 500), C(300, 470), C(370, 468), C(425, 500), C(432, 560), C(400, 585), C(360, 570),
            C(330, 590), C(290, 572), C(260, 590)], "#fff0d8", "#e2c9b6", depth=16, line=8)
cone.shape([C(262, 470), C(270, 410), C(320, 380), C(380, 388), C(412, 430), C(408, 476), C(380, 490), C(340, 482),
            C(300, 492)], "#f7a8bf", "#d77d9c", depth=14, line=8)

BLOB_BASE = C(335, 440)
blob = Node("Blob", BLOB_BASE, 0.0, parent=cone, depth=-0.005, upright=True)
blob.shape([C(250, 420), C(262, 380), C(300, 352), C(350, 340), C(398, 356), C(420, 392), C(414, 430), C(404, 470),
            C(392, 430), C(370, 440), C(352, 500), C(336, 444), C(300, 440), C(282, 476), C(266, 432)],
           RED, RED_SH, depth=12, line=8)
blob.line([C(292, 372), C(330, 356), C(360, 358)], w=12, color="#ff9c86", taper=(0.4, 0.4))

handL = Node("HandL", HL, HAND_L_ANG, parent=foL, depth=-0.03, upright=True)
draw_glove(handL, HL[0], HL[1], 1.25, 0, False)

stream = Node("Stream", (540, 960), parent=root, depth=-0.25)
G.end_exposure(stream.ob, "Art", 1)

# ================================================================ animation (one drawing per frame at 12 fps)


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def back(t, s=1.7):
    t = max(0.0, min(1.0, t)) - 1
    return t * t * ((s + 1) * t + s) + 1


def lerp(a, b, t):
    return a + (b - a) * t


def lerp2(a, b, t):
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t))


def keyed(ob, frame):
    ob.keyframe_insert("rotation_euler", frame=frame)
    ob.keyframe_insert("location", frame=frame)
    ob.keyframe_insert("scale", frame=frame)


root.set_local(-4.0)   # dutch tilt for the whole shot, matching the painted background
nodes = [root, body, head, brows, eyes, mouth, upR, foR, bottle, handR, upL, foL, cone, blob, handL, stream]
rest_loc = {n.name: tuple(n.ob.location) for n in nodes}

eyes_open(1)
mouth_grin(1)
blink_at = 8
squeeze = 1 + round(1.12 * FPS)      # "ketchup"
everything = 1 + round(1.77 * FPS)   # "everything"

for fr in range(1, N_FRAMES + 1):
    t = (fr - 1) / FPS
    # bottle hand: anticipation up, then a squeeze down on "ketchup", a second pump on "everything"
    hand = HR
    b_ang = BOTTLE_ANG
    if t < 0.95:
        k = ease((t - 0.35) / 0.5)
        hand = lerp2(HR, (822, 418), k)
        b_ang = lerp(BOTTLE_ANG, 164, k)
    elif t < 1.4:
        k = back((t - 0.95) / 0.22, 2.2)
        hand = lerp2((822, 418), (802, 470), k)
        b_ang = lerp(164, 176, k)
    else:
        k = ease((t - 1.4) / 0.4)
        hand = lerp2((802, 470), (806, 458), k)
        b_ang = lerp(176, 173, k)
    if everything - 1 <= fr <= everything + 1:
        hand = (hand[0], hand[1] + 10)
    a1, a2, E = ik(SR, hand, L1, L2, bend=-1)
    upR.set_local(a1)
    foR.set_local(a2 - a1)
    handR.set_local(HAND_R_ANG - a2)
    bottle.set_local(b_ang - a2)
    sq = 1.0
    if squeeze - 1 <= fr <= squeeze + 3:
        sq = [1.14, 1.18, 1.1, 1.04, 1.0][fr - (squeeze - 1)]
    bottle.ob.scale = (sq, 1.0, 1.0 / sq)

    # cone hand rises a touch to meet the ketchup, then settles
    k = ease((t - 0.9) / 0.4) - 0.6 * ease((t - 1.6) / 0.5)
    chand = lerp2(HL, (748, 1054), k)
    c1, c2, _ = ik(SL, chand, L1, L2, bend=1)
    upL.set_local(c1)
    foL.set_local(c2 - c1)
    handL.set_local(HAND_L_ANG - c2)
    cone.set_local(0.0 - c2)

    # head: look up, bob on "everything"
    hk = back((t - 1.72) / 0.3, 2.5) - ease((t - 2.05) / 0.4) * 0.6
    head.set_local(-5.0 - 5.0 * hk)
    lx, ly, lz = rest_loc["Head"]
    head.ob.location = (lx, ly, lz + 0.10 * math.sin(min(1.0, max(0.0, (t - 1.72) / 0.35)) * math.pi))
    bx, by, bz = rest_loc["Brows"]
    brows.ob.location = (bx, by, bz + (0.12 if fr >= everything else 0.0))
    # body breathes and sways slightly
    body.set_local(0.8 * math.sin(t * 2.2))
    body.ob.scale = (1.0, 1.0, 1.0 + 0.006 * math.sin(t * 4.4))

    # ketchup blob grows when the squirt lands
    g = back((t - 1.25) / 0.3, 1.6)
    s = max(0.05, g)
    blob.ob.scale = (s, 1.0, s)

    for n in nodes:
        keyed(n.ob, fr)

    # the stream: a fresh drawing every frame while the bottle is squeezed
    if squeeze - 1 <= fr <= squeeze + 5:
        tip_local = (0, -244 - 22)
        q = rot(tip_local, b_ang)
        handpos = hand
        tip = (handpos[0] + q[0], handpos[1] + q[1])
        top = C(335, 348)
        grow = min(1.0, (fr - (squeeze - 2)) / 2.0)
        end = lerp2(tip, top, grow)
        mid = ((tip[0] + end[0]) / 2 + 10 + rng.uniform(-4, 4), (tip[1] + end[1]) / 2)
        w = 24 if fr < squeeze + 4 else 14
        stream.line([tip, mid, end], w=w + 12, color=INK, frame=fr, taper=(0.05, 0.2))
        stream.line([tip, mid, end], w=w, color=RED, frame=fr, taper=(0.05, 0.2))
    elif fr == squeeze + 6:
        G.end_exposure(stream.ob, "Art", fr)

# eye replacements: blink, then happy squint on "everything"
eyes_shut(blink_at)
G.key(eyes.ob, "Art", blink_at + 1, mode="instance", source=1)
eyes_happy(everything)
mouth_grin(everything, big=1.12)

# hold every transform for the whole drawing (no in-between smoothing between drawings)
for n in nodes:
    ad = n.ob.animation_data
    if ad and ad.action:
        for layer in getattr(ad.action, "layers", []):
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = "CONSTANT"
        for fc in getattr(ad.action, "fcurves", []) or []:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"

for n in nodes:
    print(n.name, G.verdict(G.report(n.ob)))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "shot1.blend"))
if PREVIEW:
    for fr in (1, squeeze, everything):
        G.render_frame(os.path.join(OUT, f"f{fr:03d}.png"), fr)
else:
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filepath = os.path.join(OUT, "frame_")
    bpy.ops.render.render(animation=True)
print("DONE", OUT)
